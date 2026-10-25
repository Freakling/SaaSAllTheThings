#!/usr/bin/env bash
# SaaSAllTheThings self-test. It installs the framework into temporary copies of examples/order-desk and
# tests the installer, the architecture check, the command and authority guards, the Stop hook and
# the pre-commit hook. Run it after every change to the framework.
#
#   bash selftest.sh
#
# Nothing here needs a toolchain except the last part: where the .NET SDK is installed, the
# example's full check (build and tests) runs too. KEEP=1 keeps the temporary folder.
# The /ui-design tests use Node when it's installed; the capture of the fixture web app also needs
# Playwright with Chromium, once: cd tests/ui-web && npm install && npx playwright install chromium
# (or SATT_PLAYWRIGHT=<a node_modules folder that has playwright>). Without them they're skipped.

set -u
src="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
if [ "${KEEP:-0}" = "1" ]; then echo "keeping $work"; else trap 'rm -rf "$work"' EXIT; fi

passed=0; failed=0
ok()  { passed=$((passed + 1)); echo "  ok    $1"; }
bad() { failed=$((failed + 1)); echo "  FAIL  $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | tail -n 15 | sed 's/^/          /'; }
expect_status() { # <what> <expected> <actual> [output]
  if [ "$3" -eq "$2" ]; then ok "$1"; else bad "$1 (exit $3, expected $2)" "${4:-}"; fi
}
# Bash's own regex matching (ERE), because process starts are slow on Windows.
expect_output() { # <what> <extended regex> <output>
  if [[ $3 =~ $2 ]]; then ok "$1"; else bad "$1 (no match for /$2/)" "$3"; fi
}
expect_no_output() { # <what> <extended regex> <output>
  if [[ $3 =~ $2 ]]; then bad "$1 (unexpected /$2/)" "$3"; else ok "$1"; fi
}
# put <file> <text>: write a file (and its folder) with builtins where possible.
put() { [ -d "${1%/*}" ] || mkdir -p "${1%/*}"; printf '%s\n' "$2" > "$1"; }
# keep <file> / restore <file>: save a file's content in memory, then put it back (or delete it).
keep() { kept_file="$1"; kept_text=""; kept_existed=0; [ -f "$1" ] && { kept_existed=1; IFS= read -r -d '' kept_text < "$1"; }; return 0; }
restore() { if [ "$kept_existed" -eq 1 ]; then printf '%s' "$kept_text" > "$kept_file"; else rm -f "$kept_file"; fi; }
git_q() { git -c user.name=selftest -c user.email=selftest@localhost "$@"; }
hash_of() { git hash-object --stdin < "$1"; }
finish() {
  echo "selftest: $passed passed, $failed failed"
  [ "$failed" -eq 0 ]
  exit $?
}
new_repo() { # new_repo <folder>: an empty git repository with one commit
  mkdir -p "$1" && (cd "$1" && git init -q && git config core.autocrlf false && printf '# app\n' > README.md && git add -A && git_q commit -qm init)
}
# An SDK, not just the runtime host: a machine can have dotnet on its PATH with no SDK installed, and
# then `dotnet --list-sdks` prints nothing. Both .NET checks below use this one probe.
dotnet_sdk=0
if command -v dotnet >/dev/null 2>&1; then
  sdks="$(dotnet --list-sdks </dev/null 2>/dev/null)"
  [[ $sdks =~ [0-9]+\.[0-9]+ ]] && dotnet_sdk=1
fi

# --- framework files ----------------------------------------------------------------------------
echo "framework"
plugin_version="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$src/.claude-plugin/plugin.json")"
[ "$plugin_version" = "$(tr -d '\r\n' < "$src/VERSION")" ] && ok "plugin.json version matches VERSION" \
  || bad "plugin.json version ($plugin_version) matches VERSION ($(cat "$src/VERSION"))"
version="$(tr -d '\r\n' < "$src/VERSION")"
pinned_ref="$(sed -n 's/.*"ref"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$src/.claude-plugin/marketplace.json")"
[ "$pinned_ref" = "v$version" ] && ok "the marketplace pins the plugin to the release v<VERSION>" \
  || bad "the marketplace pins the plugin to '$pinned_ref', VERSION is $version"
for skill in "$src"/skills/*/SKILL.md; do
  folder="${skill%/SKILL.md}"; folder="${folder##*/}"
  name=""; description=""; skill_version=""; branch=""; clones=0; angle=0; dashes=0
  while IFS= read -r line; do
    [ "$line" = "---" ] && { dashes=$((dashes + 1)); continue; }
    if [ "$dashes" -eq 1 ]; then
      case "$line" in *'<'*|*'>'*) angle=1 ;; esac
      case "$line" in name:\ *) name="${line#name: }" ;; description:\ *) description="${line#description: }" ;; *version:\ *) skill_version="${line##*version: }" ;; esac
    fi
    [[ $line =~ --branch[[:space:]]+v([0-9.]+) ]] && branch="${BASH_REMATCH[1]}"
    [[ $line =~ git.*[[:space:]]clone[[:space:]] ]] && clones=1
  done < "$skill"
  [[ $name =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] && [ "$name" = "$folder" ] && [[ ! $name =~ claude|anthropic ]] \
    && ok "the public skill $folder is named after its folder, in lowercase with hyphens" || bad "skill $folder is named '$name'"
  [ "$angle" -eq 0 ] && [ -n "$description" ] && [ "${#description}" -lt 1024 ] \
    && ok "its frontmatter has a description under 1024 characters and no < or >" || bad "skill $folder's frontmatter (description ${#description} characters, angle brackets: $angle)"
  if [ "$clones" -eq 1 ]; then
    [ "$skill_version" = "$version" ] && [ "$branch" = "$version" ] \
      && ok "its metadata.version and the release it clones match VERSION" || bad "skill $folder: version '$skill_version', clones v$branch, VERSION is $version"
  else
    [ "$skill_version" = "$version" ] && ok "its metadata.version matches VERSION" || bad "skill $folder: version '$skill_version', VERSION is $version"
  fi
done
out="$(bash "$src/bundle.sh" --check 2>&1)"; expect_status "the design-session skill's references/ match framework/.satt/ (bash bundle.sh)" 0 $? "$out"
cmp -s "$src/LICENSE" "$src/framework/.satt/LICENSE" && ok "the installed LICENSE copy matches LICENSE" \
  || bad "framework/.satt/LICENSE differs from LICENSE"
missing=""
for skill in "$src"/framework/.claude/skills/*/SKILL.md; do
  name="${skill%/SKILL.md}"; name="${name##*/}"
  if [ ! -f "$src/framework/.satt/procedures/$name.md" ]; then
    # Allow deprecated aliases that redirect to an existing procedure under a different name
    alt_proc=""
    while IFS= read -r line; do [[ $line =~ procedures/([a-z-]+)\.md ]] && alt_proc="${BASH_REMATCH[1]}" && break; done < "$skill"
    { [ -n "$alt_proc" ] && [ -f "$src/framework/.satt/procedures/$alt_proc.md" ]; } || missing="$missing $name"
  fi
  named=0
  while IFS= read -r line; do [ "$line" = "name: $name" ] && { named=1; break; }; done < "$skill"
  [ "$named" -eq 1 ] || missing="$missing $name(name)"
done
[ -z "$missing" ] && ok "every skill points to an existing procedure" || bad "skills without procedures:$missing"
missing=""
for procedure in "$src"/framework/.satt/procedures/*.md; do
  name="${procedure##*/}"; name="${name%.md}"
  case "$name" in build|review) continue ;; esac
  [ -f "$src/framework/.claude/skills/$name/SKILL.md" ] || missing="$missing $name"
done
[ -z "$missing" ] && ok "every procedure has a skill (except build and review, which are subagents)" || bad "procedures without skills:$missing"
# Every .md a rule, procedure or reference topic names: one awk pass prints "doc<TAB>ref" pairs.
missing=""
other=" mapping.md contract.md prd.md director-brief.md decisions.md as-built.md interpretations.md prd-before.md postmortem.md README.md TEMPLATE.md ONBOARDING.md CHANGELOG.md AGENTS.md CLAUDE.md TASKS.md TASKS-archive.md adr.md integration-contract.md "
while IFS="$(printf '\t')" read -r doc ref; do
  case "$ref" in
    reference/*) [ -f "$src/framework/.satt/$ref" ] || missing="$missing ${doc##*/}→$ref" ;;
    rules.md|tasks.md|research-domain.md) [ -f "$src/framework/.satt/$ref" ] || missing="$missing ${doc##*/}→$ref" ;;
    *) [ -f "$src/framework/.satt/procedures/$ref" ] && continue
       [ -f "$src/framework/.satt/reference/$ref" ] && continue
       [ -f "$src/framework/.satt/workshops/$ref" ] && continue
       [ -f "$src/framework/.satt/templates/$ref" ] && continue
       case "$other" in *" $ref "*) ;; *) missing="$missing ${doc##*/}→$ref" ;; esac ;;
  esac
done < <(awk '{ s = " " $0
    while (match(s, /[^A-Za-z0-9_.*-](reference\/)?[a-z-]+\.md/)) {
      r = substr(s, RSTART + 1, RLENGTH - 1); if (!seen[FILENAME, r]++) print FILENAME "\t" r; s = substr(s, RSTART + RLENGTH)
    } }' \
  "$src"/framework/.satt/rules.md "$src"/framework/.satt/procedures/*.md "$src"/framework/.satt/reference/*.md "$src"/framework/.satt/workshops/*.md \
  "$src"/project/TASKS.md "$src/ONBOARDING.md")
[ -z "$missing" ] && ok "rules, procedures and reference topics only point to files that exist" || bad "dangling references:$missing"
missing=""
for agent in "$src"/framework/.claude/agents/*.md; do
  procedure=""
  while IFS= read -r line; do
    [[ $line =~ \.satt/procedures/([a-z-]+\.md) ]] && { procedure="${BASH_REMATCH[1]}"; break; }
  done < "$agent"
  [ -n "$procedure" ] && [ -f "$src/framework/.satt/procedures/$procedure" ] || missing="$missing ${agent##*/}"
done
[ -z "$missing" ] && ok "every subagent points to an existing procedure" || bad "subagents without procedures:$missing"
# The research assistant: every piece exists and is wired in, and the researcher can read and search but not change anything.
missing=""
for file in framework/.satt/procedures/research.md framework/.satt/research-domain.md \
    framework/.claude/agents/researcher.md framework/.claude/skills/research/SKILL.md \
    project/product/research/README.md examples/order-desk/product/research/README.md; do
  [ -f "$src/$file" ] || missing="$missing $file"
done
[ -z "$missing" ] && ok "the research assistant's files exist" || bad "research assistant files missing:$missing"
researcher="$src/framework/.claude/agents/researcher.md"
settings="$src/framework/.claude/settings.json"
if [ "$(sed -n 's/^tools: //p' "$researcher" | tr -d '\r')" = "Read, Grep, Glob, WebSearch, WebFetch" ] \
    && grep -q '^model: inherit' "$researcher" \
    && awk '/"allow": *\[/ { s = "allow" } /"ask": *\[/ { s = "ask" } /"deny": *\[/ { s = "deny" }
        s == "allow" && /^ *"(WebSearch|WebFetch)",? *$/ { n++ }
        s != "allow" && /"(WebSearch|WebFetch)/ { other++ }
        END { exit !(n == 2 && other == 0) }' "$settings"; then
  ok "the researcher has read, search and fetch tools only, and settings.json allows web search and fetch"
else
  bad "researcher.md must have exactly the tools Read, Grep, Glob, WebSearch, WebFetch (no edit, write or shell), and only settings.json › allow lists WebSearch and WebFetch"
fi
wired=""
satt="$src/framework/.satt"
grep -q 'research-domain\.md' "$satt/procedures/research.md" || wired="$wired research.md>research-domain.md"
grep -q 'never go into a public search query' "$satt/procedures/research.md" || wired="$wired research.md(confidentiality)"
grep -q 'never accepts an ADR' "$satt/procedures/research.md" || wired="$wired research.md(never accepts an ADR)"
grep -q 'researcher' "$satt/procedures/next-task.md" && grep -q '^## Research items' "$satt/procedures/next-task.md" || wired="$wired next-task.md"
grep -q 'research\.md' "$satt/procedures/design.md" && grep -q 'product/research/' "$satt/procedures/design.md" || wired="$wired design.md"
grep -q 'research\.md' "$satt/procedures/architect.md" && grep -q 'product/research/' "$satt/procedures/architect.md" || wired="$wired architect.md"
grep -q 'R<n>' "$satt/tasks.md" && grep -q '^- \*\*Research\.\*\*' "$satt/tasks.md" || wired="$wired tasks.md"
grep -q 'research' "$satt/procedures/align.md" || wired="$wired align.md"
grep -q 'research\.md' "$satt/rules.md" && grep -q 'product/research/' "$satt/rules.md" || wired="$wired rules.md"
grep -q '/research' "$src/README.md" && grep -q '/research' "$src/ONBOARDING.md" || wired="$wired README.md/ONBOARDING.md"
grep -q '^\*\*Next IDs:\*\* T[0-9]* · B[0-9]* · R[0-9]*$' "$src/project/TASKS.md" || wired="$wired project/TASKS.md(Next IDs)"
grep -q '^\*\*Next IDs:\*\* T[0-9]* · B[0-9]* · R[0-9]*$' "$src/examples/order-desk/TASKS.md" || wired="$wired order-desk/TASKS.md(Next IDs)"
[ -z "$wired" ] && ok "the research assistant is wired into the procedures, the item format, the seeds and the docs" \
  || bad "the research assistant isn't wired into:$wired"
# Two sessions that build each get a worktree, and the rule says why (half-written files and shared build artefacts).
grep -q 'git worktree add' "$satt/rules.md" && grep -q 'half-written' "$satt/rules.md" && grep -q 'Stop hook' "$satt/rules.md"   && grep -q 'build artefacts' "$satt/rules.md" && grep -q 'two coding sessions' "$satt/rules.md"   && ok "the worktree rule for parallel building sessions is in the rules, with its reason"   || bad "the worktree rule for parallel building sessions is missing or doesn't say why (rules.md › Two sessions that build at once)"
# Every subagent launch sets its model explicitly from the mapping, so none inherits the session's model:
# next-task.md says so for the builder, the reviewer, the researcher and an escalated retry, and
# rules.md states the rule the launches apply.
launch=""
nt="$satt/procedures/next-task.md"
grep -qF 'Every subagent launch sets its model explicitly' "$nt" || launch="$launch launch-rule"
grep -qF "A launch never lets a subagent inherit the session's model" "$nt" || launch="$launch no-inherit"
grep -qF 'Where the mapping has no entry for the size, or model sizing is off, the launch passes the session model explicitly' "$nt" \
  || launch="$launch session-fallback"
grep -qF 'the builder, the reviewer (Review), the researcher (Research items) and an escalated retry' "$nt" || launch="$launch launches"
grep -qF 'Pass that model as `model: <id>`' "$nt" || launch="$launch builder-model"
grep -qF 'or in a subagent if your tool has them, with its model set as Build says' "$nt" || launch="$launch builder-other-tools"
grep -qF 'subagent, with its model set as Build says for the item' "$nt" || launch="$launch reviewer"
grep -qF 'in the foreground (`run_in_background: false`), with its model set as Build says' "$nt" || launch="$launch researcher"
grep -qF 'a subagent if your tool has them, with its model set as Build says.' "$nt" || launch="$launch research-other-tools"
grep -qF 'the model mapped to the new size, set on the launch as Build says' "$nt" || launch="$launch escalation"
grep -qF "rerun it once on the next size's model, set on the launch as Build says" "$nt" || launch="$launch research-escalation"
grep -qF 'If no entry exists for this size, use the session model' "$nt" && launch="$launch old-fallback"
grep -qF 'turn on model sizing' "$nt" && launch="$launch old-research"
grep -qF 'Every subagent launch sets its model explicitly' "$satt/rules.md" \
  && grep -qF 'A size with no entry, or model sizing off, passes the session model, also explicitly' "$satt/rules.md" \
  || launch="$launch rules.md"
grep -qF 'A size with no entry uses the session model.' "$satt/rules.md" && launch="$launch rules-old"
[ -z "$launch" ] && ok "every subagent launch sets its model explicitly, and next-task.md and rules.md say so" \
  || bad "the subagent model wording is missing or has drifted:$launch"
# The human-written product brief: the SaaS variant ships as a seed (and in the example), keeps the
# director's structure and adds the SaaS sections, and onboarding, the assessment and the README present it.
wired=""
for file in project/product/director-brief.md examples/order-desk/product/director-brief.md; do
  grep -q '^# Product Brief: \[App Name\]' "$src/$file" && grep -q '^## 1\. Executive Summary' "$src/$file" \
    && grep -q '^## 7\. Enterprise Architecture' "$src/$file" && grep -q '^\*\*Identity provider:\*\*\|^\* \*\*Identity provider:\*\*' "$src/$file" \
    && grep -q '^\* \*\*Data residency:\*\*' "$src/$file" && grep -q '^\* \*\*Hosting constraints:\*\*' "$src/$file" \
    && grep -q '^### Functional requirements' "$src/$file" && grep -q '^### Non-functional requirements' "$src/$file" \
    && grep -q '^## 9\. Security Requirements' "$src/$file" && grep -q '^## 10\. Control Frameworks' "$src/$file" \
    && grep -q 'security framework' "$src/$file" || wired="$wired $file"
done
cmp -s "$src/project/product/director-brief.md" "$src/examples/order-desk/product/director-brief.md" || wired="$wired example copy differs from the seed"
grep -q 'product/director-brief\.md' "$src/ONBOARDING.md" && grep -q '(from your document)' "$src/ONBOARDING.md" \
  && grep -q '(inferred, please confirm)' "$src/ONBOARDING.md" && grep -q 'alternative to the chat interview or an addition to it' "$src/ONBOARDING.md" \
  && grep -q 'sets the stage for later development' "$src/ONBOARDING.md" || wired="$wired ONBOARDING.md"
grep -q 'director-brief\.md' "$satt/procedures/assess.md" && grep -q '(from the brief)' "$satt/procedures/assess.md" \
  && grep -q 'director-brief\.md' "$src/skills/saas-assessment/SKILL.md" || wired="$wired assess.md, saas-assessment"
grep -q 'product/director-brief\.md' "$src/README.md" || wired="$wired README.md"
[ -z "$wired" ] && ok "the SaaS product brief template ships as a seed and in the example, and onboarding, the assessment and the README present it" \
  || bad "the SaaS product brief isn't wired into:$wired"
# The README's Start here step comes first in how-to-use, before the assessment and the install, and links the brief template
# at the release tag; the template's header carries the same link, so a copied file says where the latest one is.
brief_link="https://raw.githubusercontent.com/Freakling/SaaSAllTheThings/v$version/project/product/director-brief.md"
start_line="$(grep -n '^### Start here' "$src/README.md" | head -n 1 | cut -d: -f1)"
assess_line="$(grep -n '^### Assess first' "$src/README.md" | head -n 1 | cut -d: -f1)"
[ -n "$start_line" ] && [ -n "$assess_line" ] && [ "$start_line" -lt "$assess_line" ] \
  && grep -qF "$brief_link" "$src/README.md" && grep -qF "$brief_link" "$src/project/product/director-brief.md" \
  && grep -qF "$brief_link" "$src/examples/order-desk/product/director-brief.md" \
  && ok "the README's Start here step links the brief template at v$version, and the template's header carries the same link" \
  || bad "the README's Start here step or the template header doesn't link the brief at v$version"
# The design-session skill runs in the Claude apps without subagents, so it leaves the research procedure out and says so.
if [ ! -e "$src/skills/saas-design-session/references/procedures/research.md" ] && [ ! -e "$src/skills/saas-design-session/references/research-domain.md" ] \
    && grep -q 'research assistant' "$src/skills/saas-design-session/SKILL.md"; then
  ok "the design-session skill leaves out the research procedure and says so"
else
  bad "the design-session skill must not carry research.md or research-domain.md, and its SKILL.md must say why"
fi
# /ui-design: every piece exists and is wired in, the same way the research assistant is.
missing=""
for file in framework/.satt/procedures/ui-design.md framework/.claude/skills/ui-design/SKILL.md \
    framework/tools/ui_capture.sh framework/tools/ui/capture.mjs framework/tools/ui/lint.mjs framework/tools/ui/drawing.mjs \
    framework/tools/ui/overlay.mjs framework/tools/ui/verify.mjs framework/tools/ui/common.mjs framework/tools/ui/package.json \
    framework/tools/ui/.npmrc project/tools/ui/screens.mjs project/tools/ui_capture.cfg project/product/ui/README.md \
    examples/order-desk/tools/ui/screens.mjs examples/order-desk/tools/ui_capture.cfg examples/order-desk/product/ui/README.md \
    tests/ui-drawing/fixture.excalidraw tests/ui-drawing/fixture-scaled.excalidraw tests/ui-drawing/fixture-conflict.excalidraw tests/ui-drawing/fixture.elements.json \
    tests/ui-drawing/fixture.expected.json tests/ui-drawing/fixture.png tests/ui-drawing/starter.expected.excalidraw \
    tests/ui-drawing/fixture.godot.drawing.json tests/ui-drawing/fixture-scaled.godot.drawing.json \
    tests/ui-drawing/README.md tests/ui-web/serve.mjs tests/ui-web/package.json tests/ui-web/site/index.html tests/ui-web/site/lint.html \
    tests/ui-web/site/order.html tests/ui-web/site/away.html tests/ui-web/site/modal.html tests/ui-web/site/reload.html; do
  [ -f "$src/$file" ] || missing="$missing $file"
done
[ -z "$missing" ] && ok "the /ui-design files exist" || bad "/ui-design files missing:$missing"
wired=""
uiproc="$satt/procedures/ui-design.md"
grep -q 'procedures/ui-design\.md' "$src/framework/.claude/skills/ui-design/SKILL.md" || wired="$wired SKILL.md"
grep -q '^- `process <screen>`' "$uiproc" && grep -q 'tools/ui/drawing\.mjs' "$uiproc" && grep -q '\.drawing\.json' "$uiproc" \
  && grep -q '\.starter\.excalidraw' "$uiproc" && grep -q 'Never read the raw' "$uiproc" && grep -q '^### The screen spec' "$uiproc" \
  && grep -q "^## If you can't view images" "$uiproc" && grep -q -- '--verify' "$uiproc" && grep -q 'seeded test tenant' "$uiproc" \
  && grep -q 'real tenant, account, token' "$uiproc" && grep -q 'architect\.md' "$uiproc" || wired="$wired ui-design.md"
grep -q 'product/ui/<screen>\.md' "$satt/rules.md" && grep -q '`director/ui/`' "$satt/rules.md" && grep -q 'tools/ui/screens\.mjs' "$satt/rules.md" \
  && grep -q 'data-testid' "$satt/rules.md" && grep -q '^## Protected space' "$satt/rules.md" && grep -q 'ui-design\.md' "$satt/rules.md" || wired="$wired rules.md"
grep -q '^- \*\*`UI:`\*\*' "$satt/tasks.md" || wired="$wired tasks.md"
grep -q '\*\*Screens\*\*' "$satt/procedures/build.md" && grep -q 'Screen: <' "$satt/procedures/build.md" \
  && grep -q 'ui_capture\.sh <id> --verify' "$satt/procedures/build.md" || wired="$wired build.md"
grep -q '`UI:`' "$satt/procedures/review.md" && grep -q 'compare@' "$satt/procedures/review.md" || wired="$wired review.md"
grep -q '`UI:`' "$satt/procedures/acceptance.md" && grep -q 'compare@' "$satt/procedures/acceptance.md" || wired="$wired acceptance.md"
grep -q -- '--missing' "$satt/procedures/align.md" && grep -q -- '--static' "$satt/procedures/align.md" \
  && grep -q '/product/ui/captures/' "$satt/procedures/align.md" || wired="$wired align.md"
grep -q 'ui-design\.md' "$satt/procedures/design.md" || wired="$wired design.md"
grep -q 'ui-design\.md' "$satt/procedures/feedback.md" || wired="$wired feedback.md"
grep -q '"Bash(bash tools/ui_capture.sh \*)"' "$settings" && grep -q '"Bash(node tools/ui/drawing.mjs \*)"' "$settings" \
  && grep -q '"Bash(node tools/ui/verify.mjs \*)"' "$settings" && ! grep -q '"Bash(node tools/ui/\*)"' "$settings" || wired="$wired settings.json"
grep -q 'director' "$src/framework/.claude/hooks/guard-authority.sh" || wired="$wired guard-authority.sh"
grep -q '/ui-design' "$src/README.md" && grep -q '/ui-design' "$src/ONBOARDING.md" && grep -q 'UI / screen layout' "$src/ONBOARDING.md" \
  && grep -q '^### Protected workspace' "$src/ONBOARDING.md" && grep -q 'UI / screen layout' "$src/project/AGENTS.md" \
  && grep -q '`product/ui/`' "$src/project/AGENTS.md" || wired="$wired README.md/ONBOARDING.md/AGENTS.md"
grep -q '"/product/ui/captures/" "/tools/ui/node_modules/" "/tools/ui/.auth/"' "$src/install.sh" || wired="$wired install.sh"
[ -z "$wired" ] && ok "/ui-design is wired into the rules, the item format, the procedures, the settings, the hook, the seeds and the docs" \
  || bad "/ui-design isn't wired into:$wired"
# The design-session skill runs without Node or the app's repository, so it leaves /ui-design out and says so.
if [ ! -e "$src/skills/saas-design-session/references/procedures/ui-design.md" ] && grep -q 'ui-design' "$src/skills/saas-design-session/SKILL.md"; then
  ok "the design-session skill leaves out the /ui-design procedure and says so"
else
  bad "the design-session skill must not carry ui-design.md, and its SKILL.md must say why"
fi
# The check must not start needing Node: it never runs the capture tools.
if grep -qiE 'ui_capture|tools/ui/|playwright' "$src/framework/tools/check.sh" "$src/framework/tools/setup-clone.sh" "$src/framework/tools/archcheck.awk"; then
  bad "the check and setup-clone never run the capture tools (they would need Node)"
else
  ok "the check and setup-clone never run the capture tools (they would need Node)"
fi
_pw_range() { sed -n 's/.*"playwright"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1"; }
[ "$(_pw_range "$src/framework/tools/ui/package.json")" = "$(_pw_range "$src/tests/ui-web/package.json")" ] \
  && ok "the selftest's Playwright is the version range capture asks for" \
  || bad "framework/tools/ui/package.json and tests/ui-web/package.json ask for different Playwright versions"
grep -qF "drift-reset.md" "$src/framework/.satt/procedures/align.md" \
  && ok "align.md recommends a drift reset for recurring or cross-cutting conflicts" \
  || bad "align.md doesn't point to drift-reset.md"
grep -qx "disable-model-invocation: true" "$src/framework/.claude/skills/drift-reset/SKILL.md" \
  && ok "the drift-reset skill runs only when the human starts it" \
  || bad "the drift-reset skill lacks disable-model-invocation: true"
awk_rules="$(sed -n 's/^  rules = "\(.*\)"$/\1/p' "$src/framework/tools/archcheck.awk" | tr ' ' '\n' | LC_ALL=C sort | tr '\n' ' ')"
doc_rules="$(sed -n 's/^| `\([a-z-]*\)` | .*/\1/p' "$src/framework/.satt/reference/README.md" | LC_ALL=C sort | tr '\n' ' ')"
[ -n "$awk_rules" ] && [ "$awk_rules" = "$doc_rules" ] && ok "the check's rules match reference/README.md › What the check enforces" \
  || bad "rules differ: archcheck.awk has '$awk_rules', reference/README.md has '$doc_rules'"
# Extract "SIZE:model-id" pairs from model sizing blocks, sorted, pipe-separated.
_model_ids() {
  awk '/^[[:space:]]*-[[:space:]]*(XS|S|M|L|XL):[[:space:]]+[a-z]/{
    line=$0; sub(/^[[:space:]]*-[[:space:]]*/,"",line); gsub(/:[[:space:]]+/,":",line); gsub(/[[:space:]]/,"",line); print line
  }' "$1" | LC_ALL=C sort | tr '\n' '|'
}
refresh_ids="$(_model_ids "$src/framework/.satt/procedures/refresh-model-sizing.md")"
onboarding_ids="$(_model_ids "$src/ONBOARDING.md")"
[ -n "$refresh_ids" ] && [ "$refresh_ids" = "$onboarding_ids" ] \
  && ok "default model IDs in ONBOARDING.md match the refresh-model-sizing procedure" \
  || bad "model ID mismatch: ONBOARDING: '$onboarding_ids' refresh-model-sizing: '$refresh_ids'"
grep -qF "retries once on the next size" "$src/README.md" \
  && ok "README.md model sizing paragraph matches the canonical wording" \
  || bad "README.md model sizing paragraph is missing the canonical wording"
git -C "$src" grep -qrl $'\xe2\x80\x93\|\xe2\x80\x94' -- '*.md' '*.sh' '*.txt' '*.cfg' 2>/dev/null \
  && bad "en/em dashes found in tracked text files: run the dash removal" \
  || ok "no en/em dashes in tracked text files"

# --- check workflow template ----------------------------------------------------------------------
echo "check workflow template"
wf="$src/framework/.satt/templates/check-workflow.yml"
if [ -f "$wf" ]; then
  ok "the check workflow template exists"
  wf_flat="$(grep -v '^[[:space:]]*#' "$wf" | tr '\n' ' ' | tr -s ' ')"   # comments dropped, one line
  yaml_out="$(python3 -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1]))' "$wf" 2>&1)"; yaml_status=$?
  case "$yaml_out" in *"No module named"*|*"not found"*|*"was not found"*) ok "no YAML parser here: the grep checks below stand in" ;;
    *) expect_status "the check workflow template is valid YAML" 0 "$yaml_status" "$yaml_out" ;; esac
  expect_output "the workflow runs on pull_request" ' on: pull_request: ' " $wf_flat"
  expect_output "the workflow runs on pushes to main" 'push: branches: \[main\]' "$wf_flat"
  expect_output "the workflow has read-only contents permission" 'permissions: contents: read ' "$wf_flat"
  expect_no_output "the workflow grants no write permission" '(contents|actions|id-token|packages): write' "$wf_flat"
  expect_output "the workflow runs bash tools/check.sh and keeps its output" 'bash tools/check\.sh 2>&1 \| tee ' "$wf_flat"
  expect_output "the workflow fails on the check's exit code (pipefail)" 'set -o pipefail' "$wf_flat"
  expect_output "the workflow uploads with if: always()" 'if: always\(\) uses: actions/upload-artifact@v[0-9]+ ' "$wf_flat"
  expect_output "the artifact name carries the run number" 'name: check-\$\{\{ github\.run_number \}\}' "$wf_flat"
  expect_no_output "the workflow sets no retention-days" 'retention-days' "$wf_flat"
  expect_no_output "every action is pinned to a major version tag" 'uses: [^@ ]+@([^v ]|v[0-9]+\.)' "$wf_flat"
  expect_output "the workflow skips secrets.txt when it collects logs" 'secrets\.txt\) continue' "$wf_flat"
  expect_output "dependency review runs only on pull requests" 'dependency-review: if: github\.event_name == .pull_request. runs-on' "$wf_flat"
  expect_output "dependency review uses the v4 action at high severity" 'uses: actions/dependency-review-action@v4 with: fail-on-severity: high' "$wf_flat"
  expect_no_output "dependency review comments on pull requests (needs pull-requests: write)" 'comment-summary-in-pr|pull-requests: write' "$wf_flat"
  expect_output "the SBOM job runs only on pushes" 'sbom: if: github\.event_name == .push. runs-on' "$wf_flat"
  expect_output "the SBOM comes from the dependency-graph endpoint with the job token" 'GH_TOKEN: \$\{\{ github\.token \}\} run: .*/repos/\$\{GITHUB_REPOSITORY\}/dependency-graph/sbom' "$wf_flat"
  expect_output "the SBOM is written to sbom.spdx.json and checked as SPDX" '--jq .\.sbom. > sbom\.spdx\.json grep -q .\"spdxVersion\". sbom\.spdx\.json' "$wf_flat"
  expect_output "the SBOM is uploaded with upload-artifact v4" 'uses: actions/upload-artifact@v4 with: name: sbom-\$\{\{ github\.run_number \}\}-\$\{\{ github\.run_attempt \}\} path: sbom\.spdx\.json' "$wf_flat"
else
  bad "the check workflow template is missing: framework/.satt/templates/check-workflow.yml"
fi
onboarding_text="$(cat "$src/ONBOARDING.md")"
expect_output "onboarding names the workflow template and its target path" '\.satt/templates/check-workflow\.yml.*\.github/workflows/check\.yml' "$onboarding_text"
expect_output "onboarding never overwrites an existing check.yml" 'Never overwrite an existing `\.github/workflows/check\.yml`' "$onboarding_text"
expect_output "release.md names the CI run and artifact as the check's record" 'CI run for the release commit' "$(cat "$src/framework/.satt/procedures/release.md")"
infra_text="$(cat "$src/framework/.satt/reference/infra.md")"
expect_output "infra.md has the dependencies and SBOM section" '## Dependencies and the SBOM' "$infra_text"
expect_output "infra.md says vulnerability response stays the customer's process" "Vulnerability response stays the customer.s process" "$infra_text"
expect_output "infra.md says what the SBOM and review don't cover" 'Not covered: vulnerabilities in the app' "$infra_text"

# --- installer ----------------------------------------------------------------------------------
echo "installer"
app="$work/order-desk"
cp -R "$src/examples/order-desk" "$app"
rm -rf "$app/.satt" "$app/.claude" "$app/.githooks" "$app/tools/check.sh"
(cd "$app" && git init -q && git config core.autocrlf false && git add -A && git_q commit -qm "example") || exit 1
cd "$app" || exit 1

out="$(bash "$src/install.sh" . 2>&1)"; expect_status "installs" 0 $? "$out"
if [ -f .satt/manifest ] && [ -f .satt/procedures/next-task.md ] && [ -f .satt/reference/tenancy.md ] && [ -f tools/archcheck.awk ] \
    && [ -f tools/stacks/dotnet.sh ] && [ -f .claude/skills/next-task/SKILL.md ] && [ -f .claude/hooks/guard-authority.sh ]; then
  ok "copies the core and the Claude adapter, and writes the manifest"
else
  bad "copies the core and the Claude adapter, and writes the manifest" "$out"
fi
if [ -f .satt/procedures/research.md ] && [ -f .satt/research-domain.md ] && [ -f .claude/agents/researcher.md ] \
    && [ -f .claude/skills/research/SKILL.md ] && [ -f product/research/README.md ]; then
  ok "installs the research assistant: procedure, domain file, researcher, skill and note folder"
else
  bad "installs the research assistant: procedure, domain file, researcher, skill and note folder" "$out"
fi
if [ -f .satt/procedures/ui-design.md ] && [ -f .claude/skills/ui-design/SKILL.md ] && [ -x tools/ui_capture.sh ] \
    && [ -f tools/ui/capture.mjs ] && [ -f tools/ui/drawing.mjs ] && [ -f tools/ui/package.json ] && [ -f tools/ui/.npmrc ] \
    && [ -f tools/ui/screens.mjs ] && [ -f tools/ui_capture.cfg ] && [ -f product/ui/README.md ]; then
  ok "installs /ui-design: procedure, skill, capture tools, catalog, settings and the drawing guide"
else
  bad "installs /ui-design: procedure, skill, capture tools, catalog, settings and the drawing guide" "$out"
fi
grep -qx '/product/ui/captures/' .gitignore && grep -qx '/tools/ui/node_modules/' .gitignore && grep -qx '/tools/ui/.auth/' .gitignore \
  && grep -qx '/tools/ui/\*\* text eol=lf' .gitattributes \
  && ok "ignores captures, the capture tools' packages and test users' saved sign-ins" || bad "the /ui-design .gitignore and .gitattributes lines" "$(cat .gitignore)"
grep -q "$(printf '\t')tools/ui/capture.mjs$" .satt/manifest && ! grep -q "$(printf '\t')tools/ui/screens.mjs$" .satt/manifest \
  && ok "the manifest lists the capture tools, not the app's own catalog" || bad "the manifest lists the capture tools, not the app's own catalog"
grep -q "Order Desk" AGENTS.md && ok "keeps the project's own files" || bad "keeps the project's own files"
git add -A >/dev/null 2>&1 && git_q commit -qm "install" >/dev/null 2>&1
out="$(bash "$src/install.sh" . 2>&1)"; expect_output "a second run changes nothing" "0 new, 0 updated" "$out"
[ -z "$(git status --porcelain)" ] && ok "adds no duplicate .gitignore/.gitattributes lines" || bad "adds no duplicate lines" "$(git status --porcelain)"

echo "# my own note" >> .satt/procedures/prune.md
out="$(bash "$src/install.sh" . 2>&1)"
if grep -q "my own note" .satt/procedures/prune.md && [ ! -f .satt/procedures/prune.md.satt-new ]; then
  ok "keeps a local edit when this version doesn't change the file"
else
  bad "keeps a local edit when this version doesn't change the file" "$out"
fi
# Pretend the installed version had a different prune.md: now both sides changed.
awk -F'\t' -v OFS='\t' '$2 == ".satt/procedures/prune.md" { $1 = "0000000000000000000000000000000000000000" } { print }' \
  .satt/manifest > "$work/manifest" && cp "$work/manifest" .satt/manifest
out="$(bash "$src/install.sh" . 2>&1)"
if [ -f .satt/procedures/prune.md.satt-new ] && grep -q "my own note" .satt/procedures/prune.md; then
  ok "writes .satt-new when both sides changed a file"
else
  bad "writes .satt-new when both sides changed a file" "$out"
fi
mv .satt/procedures/prune.md.satt-new .satt/procedures/prune.md
# An unchanged file from an older version is replaced.
printf 'old version\n' > .satt/procedures/align.md
awk -F'\t' -v OFS='\t' -v h="$(hash_of .satt/procedures/align.md)" '$2 == ".satt/procedures/align.md" { $1 = h } { print }' \
  .satt/manifest > "$work/manifest" && cp "$work/manifest" .satt/manifest
out="$(bash "$src/install.sh" . 2>&1)"
cmp -s .satt/procedures/align.md "$src/framework/.satt/procedures/align.md" \
  && ok "replaces a file unchanged since the last install" || bad "replaces a file unchanged since the last install" "$out"

printf 'retired\n' > tools/retired.sh
printf '%s\ttools/retired.sh\n' "$(hash_of tools/retired.sh)" >> .satt/manifest
out="$(bash "$src/install.sh" . 2>&1)"
[ ! -f tools/retired.sh ] && ok "removes a file this version no longer ships" || bad "removes a file this version no longer ships" "$out"

core_only="$work/core-only"; new_repo "$core_only"
out="$(bash "$src/install.sh" --tools none "$core_only" 2>&1)"
if [ ! -e "$core_only/.claude" ] && [ ! -e "$core_only/CLAUDE.md" ] && [ -f "$core_only/AGENTS.md" ] && [ -f "$core_only/.satt/rules.md" ]; then
  ok "--tools none installs the tool-neutral core only"
else
  bad "--tools none installs the tool-neutral core only" "$out"
fi
if [ -f "$core_only/.satt/procedures/research.md" ] && [ -f "$core_only/.satt/research-domain.md" ] \
    && [ -f "$core_only/product/research/README.md" ] && grep -q '^\*\*Next IDs:\*\* T[0-9]* · B[0-9]* · R[0-9]*$' "$core_only/TASKS.md"; then
  ok "a new app gets the research procedure and domain file, the note folder, and an R counter in TASKS.md, even with --tools none"
else
  bad "a new app gets the research procedure and domain file, the note folder, and an R counter in TASKS.md" "$out"
fi
if [ -f "$core_only/product/director-brief.md" ] && grep -q '^## 10\. Control Frameworks' "$core_only/product/director-brief.md"; then
  ok "a new app gets the product brief template, even with --tools none"
else
  bad "a new app gets the product brief template, even with --tools none" "$out"
fi
# Installing from a SaaSAllTheThings folder that is itself a git clone, or sits inside the app.
s_clone="$work/satt-clone"; cp -R "$src" "$s_clone"; rm -rf "$s_clone/.git"
(cd "$s_clone" && git init -q && git config core.autocrlf false && git add -A && git_q commit -qm satt) >/dev/null 2>&1
from_clone="$work/from-clone"; new_repo "$from_clone"
out="$(bash "$s_clone/install.sh" "$from_clone" 2>&1)"; expect_status "installs from a SaaSAllTheThings git clone" 0 $? "$out"
inside="$work/inside"; new_repo "$inside"; cp -R "$s_clone" "$inside/SaaSAllTheThings"; rm -rf "$inside/SaaSAllTheThings/.git"
printf '/SaaSAllTheThings/\n' >> "$inside/.git/info/exclude"
out="$(bash "$inside/SaaSAllTheThings/install.sh" "$inside" 2>&1)"; expect_status "installs from a SaaSAllTheThings folder inside the app" 0 $? "$out"
[ -f "$inside/.satt/LICENSE" ] && ok "installs the license copy" || bad "installs the license copy" "$out"
mkdir -p "$core_only/sub"
out="$(bash "$src/install.sh" "$core_only/sub" 2>&1)"; expect_status "refuses a folder that isn't the repository root" 1 $? "$out"

# An install says when its source has unreleased changes: the manifest's first line and the closing
# lines carry it, with the commit when the source is a git checkout. A release records the plain version.
src_copy() { # src_copy <folder> <CHANGELOG.md to use>: a fresh git checkout of this framework, with that changelog
  rm -rf "$1" && cp -R "$src" "$1" && rm -rf "$1/.git" && cp "$2" "$1/CHANGELOG.md" \
    && (cd "$1" && git init -q && git config core.autocrlf false && git add -A && git_q commit -qm source) >/dev/null 2>&1
}
printf '# Changelog\n\n## Unreleased\n\n- **A change not released yet.**\n\n## 0.9.0 (2026-10-16)\n\n- Earlier.\n' > "$work/changelog-unreleased.md"
printf '# Changelog\n\n## Unreleased\n\n## 0.9.0 (2026-10-16)\n\n- Earlier.\n' > "$work/changelog-empty.md"
printf '# Changelog\n\n## 0.9.0 (2026-10-16)\n\n- Earlier.\n' > "$work/changelog-none.md"
unrel_src="$work/unreleased-src"; src_copy "$unrel_src" "$work/changelog-unreleased.md"
unrel_sha="$(git -C "$unrel_src" rev-parse --short HEAD)"
unrel_app="$work/unreleased-app"; new_repo "$unrel_app"
out="$(bash "$unrel_src/install.sh" "$unrel_app" 2>&1)"; expect_status "installs from a checkout with unreleased changes" 0 $? "$out"
if [ "$(head -n 1 "$unrel_app/.satt/manifest" | tr -d '\r')" = "# saasallthethings $version + unreleased ($unrel_sha)" ] \
    && grep -qxF "# source $unrel_sha" "$unrel_app/.satt/manifest" && grep -qxF "# tools claude" "$unrel_app/.satt/manifest"; then
  ok "the manifest records '+ unreleased (<commit>)' and the source commit, and keeps the tools line"
else
  bad "the manifest records '+ unreleased (<commit>)' and the source commit" "$(head -n 3 "$unrel_app/.satt/manifest")"
fi
printf '%s\n' "$out" | grep -qxF "Installed $version + unreleased ($unrel_sha): a development snapshot, not a release. The latest release is at https://github.com/Freakling/SaaSAllTheThings/releases." \
  && ok "the closing lines say it's a development snapshot, with the commit" || bad "the closing lines don't say it's a development snapshot" "$out"
# A release zip has no .git: the same changelog records the version without a commit.
zip_src="$work/unreleased-zip"; rm -rf "$zip_src" && cp -R "$src" "$zip_src" && rm -rf "$zip_src/.git" && cp "$work/changelog-unreleased.md" "$zip_src/CHANGELOG.md"
zip_app="$work/unreleased-zip-app"; new_repo "$zip_app"
out="$(bash "$zip_src/install.sh" "$zip_app" 2>&1)"
if [ "$(head -n 1 "$zip_app/.satt/manifest" | tr -d '\r')" = "# saasallthethings $version + unreleased" ] \
    && ! grep -q '^# source ' "$zip_app/.satt/manifest" && printf '%s\n' "$out" | grep -qxF "Installed $version + unreleased: a development snapshot, not a release. The latest release is at https://github.com/Freakling/SaaSAllTheThings/releases."; then
  ok "a source without a git checkout (a release zip) records '+ unreleased' with no commit"
else
  bad "a source without a git checkout records '+ unreleased' with no commit" "$out"
fi
for empty in empty none; do
  rel_src="$work/release-$empty"; src_copy "$rel_src" "$work/changelog-$empty.md"
  rel_sha="$(git -C "$rel_src" rev-parse --short HEAD)"
  rel_app="$work/release-$empty-app"; new_repo "$rel_app"
  out="$(bash "$rel_src/install.sh" "$rel_app" 2>&1)"; expect_status "installs from a release ($empty Unreleased)" 0 $? "$out"
  if [ "$(head -n 1 "$rel_app/.satt/manifest" | tr -d '\r')" = "# saasallthethings $version" ] && grep -qxF "# source $rel_sha" "$rel_app/.satt/manifest" \
      && ! printf '%s' "$out" | grep -qE 'unreleased|development snapshot'; then
    ok "a release ($empty Unreleased) records the plain version and its commit, and doesn't say unreleased"
  else
    bad "a release ($empty Unreleased) records the plain version and its commit" "$(head -n 3 "$rel_app/.satt/manifest")"
  fi
done
# Upgrade detection reads the version out of an unreleased manifest, and skips the source line.
up_app="$work/upgrade-app"; new_repo "$up_app"
bash "$work/release-none/install.sh" "$up_app" >/dev/null 2>&1
{ printf '# saasallthethings 0.8.0 + unreleased (abc1234)\n'; tail -n +2 "$up_app/.satt/manifest"; } > "$work/manifest-up" && cp "$work/manifest-up" "$up_app/.satt/manifest"
out="$(bash "$work/release-none/install.sh" "$up_app" 2>&1)"
expect_output "an upgrade from an unreleased 0.8.0 reads the old version as 0.8.0" "upgraded from 0.8.0 to $version" "$out"
{ printf '# saasallthethings %s + unreleased (abc1234)\n' "$version"; tail -n +2 "$up_app/.satt/manifest"; } > "$work/manifest-up" && cp "$work/manifest-up" "$up_app/.satt/manifest"
out="$(bash "$work/release-none/install.sh" "$up_app" 2>&1)"
expect_output "a reinstall over an unreleased manifest of the same version says reinstalled" "$version reinstalled" "$out"

# A Windows clone with core.autocrlf=true, and an editor that saved CRLF.
crlf_src="$work/crlf-src"; new_repo "$crlf_src"
bash "$src/install.sh" "$crlf_src" >/dev/null 2>&1 && (cd "$crlf_src" && git add -A && git_q commit -qm install)
git -c core.autocrlf=true clone -q "$crlf_src" "$work/crlf" && cd "$work/crlf" && git config core.autocrlf true
[ -f .satt/rules.md ] && ok "a clone carries the installed framework" || bad "a clone carries the installed framework"
awk '{ printf "%s\r\n", $0 }' .satt/rules.md > "$work/crlf-rules" && cp "$work/crlf-rules" .satt/rules.md
out="$(bash "$src/install.sh" . 2>&1)"; status=$?
expect_status "reinstalls in a CRLF clone" 0 "$status" "$out"
expect_output "reports that clone as reinstalled" "reinstalled" "$out"
expect_no_output "CRLF line endings don't count as local edits" "CONFLICT|kept your changes" "$out"
cd "$app" || exit 1
git checkout -q -- .satt 2>/dev/null; git add -A >/dev/null 2>&1; git_q commit -qm "after installer tests" >/dev/null 2>&1

# --- command guard (Claude Code PreToolUse hook on Bash) ----------------------------------------
echo "command guard"
guard() { # guard <expected exit> <command>
  local escaped="${2//\\/\\\\}"
  escaped="${escaped//\"/\\\"}"
  escaped="${escaped//$'\n'/\\n}"   # a real command line carries newlines as \n in the JSON
  printf '{"session_id":"s","tool_name":"Bash","tool_input":{"command":"%s","description":"run"}}' "$escaped" \
    | bash .claude/hooks/guard-commands.sh >/dev/null 2>&1
  local got=$?
  if [ "$got" -eq "$1" ]; then ok "$([ "$1" -eq 2 ] && echo blocks || echo allows): $2"; else bad "guard exit $got, expected $1: $2"; fi
}
for cmd in 'git commit -m x --no-verify' 'git commit -nm "x"' 'git push origin main --force' \
    'git push --force-with-lease=main origin' 'git push origin +main' 'git reset HEAD --hard' \
    'git -c core.hooksPath=/dev/null commit -m x' 'git config core.hooksPath ""' 'cd x && git clean -fd' \
    'git checkout -- .' 'git restore .' 'git stash drop' 'git branch -D topic' 'git checkout -f main' \
    'azd down --purge' 'az group delete -n rg-orderdesk-dev --yes' 'az cosmosdb delete -n x -g y' \
    'az deployment group create -g rg --template-file main.bicep --mode Complete' \
    'az keyvault secret sh''ow --vault-name kv --name db' 'az ad app credential reset --id 123'; do
  guard 2 "$cmd"
done
for cmd in 'git status --short' 'git commit -m "feat: x (T12)" -- a.cs' 'git commit --amend --no-edit' \
    'git push origin feature-flag' 'git restore --staged a.cs' 'git checkout -b topic' 'bash tools/check.sh' \
    'git commit -m "docs: az group delete is for the human" -- a.md' "git commit -m 'fix: handle -f flag' -- a.cs" \
    'git reset --soft HEAD~1' 'az deployment group what-if -g rg --template-file infra/main.bicep' \
    'az bicep build --file infra/main.bicep' 'az ad app federated-credential create --id 1 --parameters fc.json' 'dotnet test'; do
  guard 0 "$cmd"
done

# Hangs: an empty heredoc into Python, a polling loop without a limit, a lone long sleep.
nlc=$'\n'
for cmd in "python3 - <<'EOF' 2>/dev/null || echo \"no python\"${nlc}EOF" "python3 - <<EOF${nlc}EOF" \
    "py.exe - <<'PY'${nlc}PY" "python3 - <<'EOF' 2>/dev/null || python - <<'EOF2'${nlc}EOF${nlc}x${nlc}EOF2" \
    "cd x && /usr/bin/python3 - <<'EOF'${nlc}EOF" "python3 - <<'EOF'${nlc}EOF${nlc}echo after" \
    'until grep -q "^exit" /tmp/t/tasks/b1.output; do sleep 5; done' 'while true; do sleep 10; done' \
    'until [ -f done.flag ]; do sleep 2; done' 'timeout 900 bash -c "until [ -f f ]; do sleep 2; done"' \
    "timeout 300 bash -c 'until [ -f f ]; do sleep 2; done'" 'timeout 5m bash -c "while sleep 1; do :; done"' \
    'timeout 0 bash -c "until [ -f f ]; do sleep 2; done"' 'while ! grep -q ok /tmp/t/tasks/b1.output; do sleep 3; done' \
    'sleep 300' 'sleep 5m' 'echo hi && sleep 1h' 'sleep 281'; do
  guard 2 "$cmd"
done
for cmd in "python - <<-'EOF'${nlc}${nlc}EOF" "python3 - <<'EOF'${nlc}print(1)${nlc}EOF" "python3 - <<EOF 2>/dev/null || echo no${nlc}import sys${nlc}EOF" 'python3 --version' \
    "python3 -c 'print(1)'" 'timeout 240 bash -c "until [ -f f ]; do sleep 2; done"' \
    "(timeout 240s bash -c 'while [ ! -f f ]; do sleep 2; done')" 'cd x && timeout 4m bash -c "until [ -f f ]; do sleep 2; done"' \
    'timeout -k 5 280 bash -c "until [ -f f ]; do sleep 2; done"' \
    'until grep -q "exited with code" /tmp/t/tasks/b1.output; do sleep 5; done' \
    'until grep -qE "exited with code|\[killed\]" /tmp/t/tasks/b1.output; do sleep 5; done' \
    'sleep 5' 'sleep 280' 'sleep 4m' 'sleep 0.5' 'echo "wait: sleep 600"' 'git commit -m "no until loop with sleep" -- a.md' \
    'while read -r l; do echo "$l"; done < f'; do
  guard 0 "$cmd"
done
grep -q '"matcher": "Bash|Monitor"' .claude/settings.json && ok "the command guard runs for Monitor too" || bad "settings.json runs guard-commands.sh for Monitor"
grep -q 'run_in_background' .satt/rules.md && grep -q 'empty heredoc' .satt/rules.md && grep -q 'time limit under five minutes' .satt/rules.md \
  && ok "rules.md names the time limit, run_in_background and the empty heredoc" || bad "rules.md says: time limits, run_in_background, never an empty heredoc"
grep -vE '^[[:space:]]*#' .claude/hooks/guard-commands.sh | grep -qE '\$\([^(]|`' \
  && bad "the guard starts no other processes" || ok "the guard starts no other processes"

# --- authority guard (Claude Code PreToolUse hook on Edit and Write) -----------------------------
echo "authority guard"
authority() { # authority <expect ask|none> <what> <json>
  local out
  out="$(printf '%s' "$3" | bash .claude/hooks/guard-authority.sh 2>&1)"
  if [ "$1" = "ask" ]; then expect_output "asks the human: $2" '"permissionDecision":"ask"' "$out"
  else expect_no_output "lets through: $2" 'permissionDecision' "$out"; fi
}
authority ask "an edit to the reference architecture (Windows path)" \
  '{"tool_name":"Edit","tool_input":{"file_path":"C:\\git\\app\\.satt\\reference\\tenancy.md","old_string":"a","new_string":"b"}}'
authority ask "an edit to the check" '{"tool_name":"Write","tool_input":{"file_path":"/home/u/app/tools/archcheck.awk","content":"x"}}'
authority ask "accepting an ADR" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/home/u/app/adr/ADR-2-windows-client-ui.md","old_string":"- **Status:** proposed","new_string":"- **Status:** accepted"}}'
authority none "another edit to an ADR" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/home/u/app/adr/ADR-2-windows-client-ui.md","old_string":"a","new_string":"b"}}'
authority none "an edit to product code" '{"tool_name":"Edit","tool_input":{"file_path":"/home/u/app/src/OrderDesk.Domain/Orders/Order.cs","old_string":"a","new_string":"b"}}'
authority none "the builder's state marker" '{"tool_name":"Write","tool_input":{"file_path":"/home/u/app/.satt/state/building","content":""}}'

# director/ is the director's own workspace: the hook blocks writes there (exit 2), wherever the path is spelled from.
protected() { # protected <expected exit> <what> <file_path as JSON> [project dir]
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}' "$3" \
    | CLAUDE_PROJECT_DIR="${4:-/home/u/app}" bash .claude/hooks/guard-authority.sh >/dev/null 2>&1
  local got=$?
  if [ "$got" -eq "$1" ]; then ok "$([ "$1" -eq 2 ] && echo blocks || echo allows): $2"; else bad "guard-authority exit $got, expected $1: $2"; fi
}
protected 2 "a drawing in director/ui/" "/home/u/app/director/ui/orders.excalidraw"
protected 2 "director/ itself, by a relative path" "director"
protected 2 "director/ (a Windows path, another spelling of the project folder)" 'C:\\git\\App\\director\\notes.md' "/c/git/app"
protected 0 "a folder named director inside the code" "/home/u/app/src/director/Director.cs"
protected 0 "a screen spec" "/home/u/app/product/ui/orders.md"
protected 2 "a path that climbs into director/" "/home/u/app/src/../director/ui/orders.excalidraw"
protected 0 "a path that climbs elsewhere" "/home/u/app/src/../product/ui/orders.md"
printf '{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"/home/u/app/director/analysis.ipynb","new_source":"x"}}'   | CLAUDE_PROJECT_DIR=/home/u/app bash .claude/hooks/guard-authority.sh >/dev/null 2>&1
expect_status "blocks a notebook edit in director/" 2 $?
grep -q '"matcher": "Edit|Write|MultiEdit|NotebookEdit"' .claude/settings.json && ok "the hook runs on notebook edits too"   || bad "settings.json runs guard-authority.sh on NotebookEdit"

# --- architecture check -------------------------------------------------------------------------
echo "architecture"
arch() { bash tools/check.sh --architecture 2>&1; }
out="$(arch)"; status=$?
expect_status "the example passes" 0 "$status" "$out"
expect_output "counts the example's files per layer" "24 source files in layers \(contracts 5 · domain 5 · application 6 · host 3 · tests 5\)" "$out"
expect_output "notes the proposed ADR" "ADR-2 is proposed" "$out"

change() { # change <file> <text to append, or @ to replace the file with the text>
  keep "$1"
  case "$2" in @*) put "$1" "${2#@}" ;; *) printf '%s\n' "$2" >> "$1" ;; esac
}
fault() { # fault <what> <file> <text, as for change> <regex the output must contain>
  change "$2" "$3"
  out="$(arch)"; status=$?
  expect_status "fails on $1" 1 "$status" "$out"
  expect_output "names the cause of $1" "$4" "$out"
  restore
}
clean() { # clean <what> <file> <text, as for change>: must still pass
  change "$2" "$3"
  out="$(arch)"; expect_status "doesn't fail on $1" 0 $? "$out"
  restore
}
domain=src/OrderDesk.Domain/Orders/Order.cs
host=src/OrderDesk.Functions/Orders/PlaceOrderFunction.cs
fault "the domain importing the application" $domain 'using OrderDesk.Application.Ports;' '\[layers\] src/OrderDesk.Domain/Orders/Order.cs:[0-9]+: domain must not depend on application'
fault "a project reference from the domain" src/OrderDesk.Domain/OrderDesk.Domain.csproj \
  '@<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><ProjectReference Include="..\OrderDesk.Application\OrderDesk.Application.csproj" /></ItemGroup></Project>' \
  'domain must not depend on application \(references src/OrderDesk.Application/OrderDesk.Application.csproj\)'
fault "a package in the domain" src/OrderDesk.Domain/OrderDesk.Domain.csproj \
  '@<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><PackageReference Include="Microsoft.Azure.Cosmos" Version="3.*" /></ItemGroup></Project>' \
  'domain takes no external packages \(Microsoft.Azure.Cosmos\)'
fault "a client importing the domain" clients/windows/OrderView.cs '@using OrderDesk.Domain.Orders;' 'client must not depend on domain'
fault "a host importing the domain" $host 'using OrderDesk.Domain.Orders;' 'host must not depend on domain'
fault "the domain reading the clock" $domain 'public static class Today { public static DateTimeOffset Now => DateTimeOffset.UtcNow; }' '\[domain-purity\].*DateTimeOffset.UtcNow'
fault "the domain making ids" $domain 'public static class Ids { public static Guid Next() => Guid.NewGuid(); }' '\[domain-purity\].*Guid.NewGuid'
fault "the domain reading the environment" $domain 'public static class Cfg { public static string? X => Environment.GetEnvironmentVariable("X"); }' '\[domain-purity\]'
clean "the clock named in a comment" $domain '// Never DateTime.UtcNow here: the time comes in as an input.'
clean "the clock in a block comment" $domain "$(printf '/* Guid.NewGuid() is\n   not allowed here */')"
fault "a tenant from a header" $host 'public static class H { public static string T(HttpRequest r) => r.Headers["x-tenant-id"]!; }' '\[tenant-source\]'
fault "a tenant from the query string" $host 'public static class Q { public static string? T(HttpRequest r) => r.Query["tenantId"]; }' '\[tenant-source\]'
fault "a tenant in a route" src/OrderDesk.Functions/Orders/ListOrders.cs \
  '@public sealed class ListOrders { [Function("ListOrders")] public void Run([HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "tenants/{tenantId}/orders")] HttpRequest r) { } }' '\[tenant-source\]'
fault "a tenant id in an API contract" src/OrderDesk.Contracts/Api/PlaceOrderRequest.cs \
  '@namespace OrderDesk.Contracts.Api; public sealed record PlaceOrderRequest(string TenantId, string CustomerNumber);' 'API contracts never carry the tenant'
clean "the tenant from the token in a host" $host 'public static class Ok { public static string Who(FunctionContext c, HttpRequest r) => c.GetTenant().TenantId + r.Headers.Authorization; }'
clean "a platform object named in a host" $host 'public static class P { public static object T(dynamic platform) => platform.Tenants; }'
clean "a log line naming a route and a tenant" $host 'public static class L { public static string M => "Handling route {Route} for tenant {TenantId}"; }'
fault "code that names a tenant" src/OrderDesk.Application/Orders/Special.cs \
  '@namespace OrderDesk.Application.Orders; public static class Special { public static bool Is(Tenancy.TenantContext t) => t.TenantId.ToString() == "contoso"; }' '\[tenant-branching\]'
fault "a literal compared with a tenant" src/OrderDesk.Application/Orders/Special.cs \
  '@namespace OrderDesk.Application.Orders; public static class Special { public static bool Is(string tenantId) => "contoso" == tenantId; }' '\[tenant-branching\]'
clean "a tenant's status compared with a literal" src/OrderDesk.Application/Orders/Status.cs \
  '@namespace OrderDesk.Application.Orders; public static class Status { public static bool On(string tenantStatus) => tenantStatus == "active"; }'
clean "an empty tenant check" $domain 'public static class Guard { public static bool Empty(string tenantId) => tenantId == ""; }'
fault "an unversioned event" src/OrderDesk.Contracts/Events/OrderShipped.cs '@namespace OrderDesk.Contracts.Events; public sealed record OrderShipped(string OrderId);' '\[message-version\].*OrderShippedV1'
fault "an unversioned command" src/OrderDesk.Contracts/Commands/SyncOrder.cs '@namespace OrderDesk.Contracts.Commands; public sealed record class SyncOrder(string OrderId);' '\[message-version\]'
clean "a versioned command" src/OrderDesk.Contracts/Commands/SyncOrderToNavisionV1.cs '@namespace OrderDesk.Contracts.Commands; public sealed record SyncOrderToNavisionV1(string OrderId);'
# Fake secrets, assembled at run time so this file doesn't look like it holds any.
fake_key="Account""Key=q2Vh4dN0k3sRm7Yy1PzT8wLx6Jc9Bf5Ga0Hu2Ie4Kd7Ms="
fake_client_secret="abc8""Q~kd93jfLs02mdmZpQ8x7Vbn1Lk3Tt5WwYy9o"
fake_pem="-----BEGIN RSA PRIVATE"" KEY-----"
fault "a storage key" src/OrderDesk.Functions/appsettings.json \
  "@{ \"Storage\": \"DefaultEndpointsProtocol=https;AccountName=x;$fake_key;EndpointSuffix=core.windows.net\" }" '\[secrets\] src/OrderDesk.Functions/appsettings.json:1'
expect_no_output "never prints the secret itself" "q2Vh4dN0k3sRm7" "$out"
fault "a client secret" src/OrderDesk.Functions/appsettings.json "@{ \"AzureAd\": { \"ClientSecret\": \"$fake_client_secret\" } }" '\[secrets\]'
fault "a private key" infra/key.pem "@$fake_pem" '\[secrets\] infra/key.pem'
clean "the Azurite development key" src/OrderDesk.Functions/local.json \
  '@{ "Storage": "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;Account''Key=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;" }'
clean "a password placeholder" src/OrderDesk.Functions/local.json '@{ "Nav": "Server=nav;User=svc;Password=<from Key Vault>;" }'
fault "a long domain file" src/OrderDesk.Domain/Orders/Long.cs "@$(awk 'BEGIN { for (i = 1; i <= 301; i++) print "// line " i }')" '\[file-size\] src/OrderDesk.Domain/Orders/Long.cs: 301 lines, over 300'
fault "a fat function" src/OrderDesk.Functions/Orders/Fat.cs "@$(awk 'BEGIN { for (i = 1; i <= 81; i++) print "// line " i }')" '\[host-size\].*81 lines, over 80'
fault "a premium plan in Bicep" infra/modules/plan.bicep "@resource plan 'Microsoft.Web/serverfarms@2024-04-01' = { name: 'asp', location: 'norwayeast', sku: { name: 'EP1' } }" '\[cost-sku\] infra/modules/plan.bicep:1'
fault "provisioned Cosmos DB throughput" infra/modules/cosmos.bicep "@resource c 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  properties: {
    options: { throughput: 400 }
  }
}" '\[cost-sku\] infra/modules/cosmos.bicep:3'
clean "the default Flex Consumption plan" infra/modules/plan.bicep "@resource plan 'Microsoft.Web/serverfarms@2024-04-01' = { name: 'asp', location: 'norwayeast', sku: { tier: 'FlexConsumption', name: 'FC1' } }"
# network-public: public network access and local authentication in Bicep (reference/network.md).
sb_bad="resource sb 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
  name: 'sb'
  sku: { name: 'Standard', tier: 'Standard' }
  properties: { publicNetworkAccess: 'Enabled' }
}"
sb_ok="resource sb 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
  name: 'sb'
  sku: { name: 'Standard', tier: 'Standard' }
  properties: { disableLocalAuth: true }
}"
cosmos_ok="resource db 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: 'db'
  properties: {
    publicNetworkAccess: 'Disabled'
    disableLocalAuth: true
  }
}"
fault "Cosmos DB with public access and keys left on" infra/modules/cosmos.bicep "@resource db 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: 'db'
  properties: { databaseAccountOfferType: 'Standard' }
}" '\[network-public\] infra/modules/cosmos.bicep:1: microsoft.documentdb/databaseaccounts must set publicNetworkAccess'
fault "Cosmos DB with public access enabled" infra/modules/cosmos.bicep "@resource db 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  properties: { publicNetworkAccess: 'Enabled', disableLocalAuth: true }
}" '\[network-public\] infra/modules/cosmos.bicep:1'
fault "Cosmos DB with local authentication on" infra/modules/cosmos.bicep "@resource db 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  properties: { publicNetworkAccess: 'Disabled', disableLocalAuth: false }
}" 'must set disableLocalAuth: true'
fault "Service Bus Standard with local authentication on" infra/modules/bus.bicep "@$sb_bad" 'microsoft.servicebus/namespaces must set disableLocalAuth: true'
fault "Premium Service Bus with public access on" infra/modules/bus.bicep "@resource sb 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
  sku: { name: 'Premium' }
  properties: { disableLocalAuth: true }
}" 'must set publicNetworkAccess'
fault "a Key Vault with public access on" infra/modules/vault.bicep "@resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  properties: { publicNetworkAccess: 'Enabled' }
}" '\[network-public\] infra/modules/vault.bicep:1: microsoft.keyvault/vaults must set publicNetworkAccess'
fault "a storage account with shared keys on" infra/modules/storage.bicep "@resource st 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  properties: { publicNetworkAccess: 'Disabled' }
}" 'must set allowSharedKeyAccess: false'
clean "Cosmos DB with public access and keys off" infra/modules/cosmos.bicep "@$cosmos_ok"
clean "Service Bus Standard with local authentication off" infra/modules/bus.bicep "@$sb_ok"
clean "a Key Vault with public access off" infra/modules/vault.bicep "@resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  properties: { publicNetworkAccess: 'Disabled' }
}"
clean "a storage account with public access and shared keys off" infra/modules/storage.bicep "@resource st 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  properties: { publicNetworkAccess: 'Disabled', allowSharedKeyAccess: false }
}"
printf '# ADR-4 · Private bus

- **Status:** accepted
- Exception: cost-sku infra/modules/bus.bicep
' > adr/ADR-4-private-bus.md
clean "a correct Premium Service Bus namespace (its cost-sku excused by an ADR)" infra/modules/bus.bicep "@resource sb 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
  sku: { name: 'Premium' }
  properties: { publicNetworkAccess: 'Disabled', disableLocalAuth: true }
}"
rm -f adr/ADR-4-private-bus.md
clean "existing Key Vault and Storage references" infra/modules/refs.bicep "@resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: 'kv'
}
resource st 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: 'st'
  scope: resourceGroup('other')
}"
fault "a bad storage account followed by a module that names the property" infra/modules/storage.bicep "@resource st 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  properties: { allowSharedKeyAccess: false }
}
module m './other.bicep' = { params: { publicNetworkAccess: 'Disabled' } }" 'storageaccounts must set publicNetworkAccess'
clean "a good storage account followed by a module" infra/modules/storage.bicep "@resource st 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  properties: { publicNetworkAccess: 'Disabled', allowSharedKeyAccess: false }
}
module m './other.bicep' = { params: { tier: 'Standard' } }"
clean "a property named in a block comment and a URL in a string" infra/modules/vault.bicep "@resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  /* publicNetworkAccess: 'Enabled' */
  tags: { docs: 'https://example.com' }
  properties: { publicNetworkAccess: 'Disabled' }
}"
clean "a function app, which stays the public surface" infra/modules/func.bicep "@resource fn 'Microsoft.Web/sites@2024-04-01' = {
  properties: { publicNetworkAccess: 'Enabled' }
}"
clean "a type the rule doesn't cover, named in a comment" infra/modules/bus.bicep "@// publicNetworkAccess: 'Enabled' is never used
resource t 'Microsoft.ServiceBus/namespaces/topics@2024-01-01' = { name: 'orders' }"
# An accepted ADR excuses it, by rule and path.
adr=adr/ADR-3-open-bus.md
printf '# ADR-3 · Open bus\n\n- **Status:** accepted\n- Exception: network-public infra/modules/bus.bicep\n' > $adr
change infra/modules/bus.bicep "@$sb_bad"
out="$(arch)"; expect_status "an accepted ADR's network-public exception excuses the Bicep" 0 $? "$out"
expect_output "and counts it" "1 exceptions, 1 violations excused" "$out"
restore; rm -f $adr
# Off, and absent, both mean the rule doesn't run (an upgraded app's own check.cfg has no key).
grep -q '^network-public = on$' tools/check.cfg && ok "the example's check.cfg turns network-public on" || bad "the example's check.cfg has network-public = on"
cp tools/check.cfg "$work/cfg-with-rule"
change infra/modules/bus.bicep "@$sb_bad"
sed 's/^network-public = on$/network-public = off/' "$work/cfg-with-rule" > tools/check.cfg
out="$(arch)"; expect_status "network-public = off skips the rule" 0 $? "$out"
expect_output "and says it is off" "network-public is off" "$out"
grep -v '^network-public' "$work/cfg-with-rule" > tools/check.cfg
out="$(arch)"; expect_status "an absent network-public key means off" 0 $? "$out"
cp "$work/cfg-with-rule" tools/check.cfg
out="$(arch)"; expect_status "and turning it back on fails the same file" 1 $? "$out"
restore
grep -q '^network-public = on$' "$src/project/tools/check.cfg" && ok "the seed check.cfg turns network-public on" || bad "project/tools/check.cfg has network-public = on"
grep -q 'network-public' "$src/framework/.satt/reference/network.md" && grep -q 'Service Bus.*Premium' "$src/framework/.satt/reference/cost.md" && ok "network.md and cost.md say the posture and the Premium exception" || bad "network.md or cost.md lacks the posture or the Premium cost note"
fault "an unknown layer in tools/check.cfg" tools/check.cfg "$(printf '[layers]\nweb = web/*')" "isn't a layer"

# The compliance mapping: seeded, and read by the procedures that keep it true.
map="$src/project/compliance/mapping.md"
{ [ -f "$map" ] && grep -q '^| Control | Requirement | Met by | Label | Evidence |$' "$map" \
  && grep -q 'framework.s name never marks a control met' "$map" && grep -q 'EXAMPLE' "$map" \
  && grep -q '`direct`' "$map" && grep -q '`partial`' "$map" && grep -q '`interpretive`' "$map" && grep -q '`unverified`' "$map"; } \
  && ok "the seed compliance/mapping.md has the header, the columns, the four labels and an example row" || bad "project/compliance/mapping.md lacks its header, columns, labels or example"
missing=""
for p in architect review align; do grep -q 'compliance/mapping.md' "$src/framework/.satt/procedures/$p.md" || missing="$missing $p"; done
[ -z "$missing" ] && ok "architect, review and align name compliance/mapping.md" || bad "procedures that don't name compliance/mapping.md:$missing"
grep -q 'compliance/mapping.md' "$src/ONBOARDING.md" && ok "onboarding names compliance/mapping.md" || bad "ONBOARDING.md doesn't name compliance/mapping.md"
grep -q 'Never add a `direct` row without naming what meets it' "$src/framework/.satt/procedures/architect.md" \
  && grep -q "labelled \`direct\` whose Met by is \`none yet\`" "$src/framework/.satt/procedures/align.md" \
  && ok "architect forbids a direct row with no evidence and align reports one" || bad "architect or align lacks the direct-row rule"

# Exceptions come only from accepted ADRs.
adr=adr/ADR-3-legacy-clock.md
printf '\nnamespace OrderDesk.Domain.Orders; public static class LegacyClock { public static DateTime Now => DateTime.Now; }\n' > src/OrderDesk.Domain/Orders/LegacyClock.cs
printf '# ADR-3 · Legacy clock\n\n- **Status:** proposed\n\n## Check exceptions\n- Exception: domain-purity src/OrderDesk.Domain/Orders/LegacyClock.cs\n' > $adr
out="$(arch)"; expect_status "a proposed ADR excuses nothing" 1 $? "$out"
expect_output "says the proposed ADR's exceptions wait" "ADR-3 is proposed.*once it's accepted" "$out"
sed 's/proposed/accepted/' $adr > "$work/adr" && cp "$work/adr" $adr
out="$(arch)"; expect_status "an accepted ADR's exception excuses the violation" 0 $? "$out"
expect_output "counts what it excused" "1 exceptions, 1 violations excused" "$out"
rm -f src/OrderDesk.Domain/Orders/LegacyClock.cs
out="$(arch)"; expect_output "notes an exception that excuses nothing" "ADR-3's exception 'domain-purity .*' excuses nothing now" "$out"
printf '# ADR-3 · Everything\n\n- **Status:** accepted\n- Exception: layers **\n' > $adr
out="$(arch)"; expect_status "refuses an exception for every path" 1 $? "$out"
printf '# ADR-3 · Typo\n\n- **Status:** accepted\n- Exception: purity src/OrderDesk.Domain\n' > $adr
out="$(arch)"; expect_status "refuses an exception for an unknown rule" 1 $? "$out"
expect_output "names the unknown rule" "names 'purity', which isn't a rule" "$out"
printf '# ADR-3 · No status\n' > $adr
out="$(arch)"; expect_status "refuses an ADR without a status" 1 $? "$out"
rm -f $adr

# Other stacks' import and purity rules, in a repository of their own.
poly="$work/poly"; new_repo "$poly"; bash "$src/install.sh" "$poly" >/dev/null 2>&1
cd "$poly" || exit 1
cat > tools/check.cfg <<'CFG'
[project]
stack = none
[layers]
host = packages/functions functions
contracts = packages/contracts src/*/contracts
domain = packages/domain src/*/domain
application = packages/application src/*/application
infrastructure = packages/infrastructure src/*/infrastructure
tests = **/*.test.ts tests
[imports]
contracts = @od/contracts orderdesk.contracts
domain = @od/domain orderdesk.domain
application = @od/application orderdesk.application
infrastructure = @od/infrastructure orderdesk.infrastructure
CFG
mkdir -p packages/domain/src packages/infrastructure/src packages/functions/src packages/contracts/src/events src/orderdesk/domain functions
printf "import { Line } from './line';\nexport const total = (lines: Line[]) => lines.length;\n" > packages/domain/src/order.ts
printf "export interface Line { qty: number }\n" > packages/domain/src/line.ts
printf "export const db = 1;\n" > packages/infrastructure/src/db.ts
printf "from dataclasses import dataclass\nfrom datetime import datetime\n\n@dataclass\nclass Order:\n    placed_at: datetime\n" > src/orderdesk/domain/order.py
out="$(arch)"; expect_status "TypeScript and Python layers pass" 0 $? "$out"
fault "a relative import across layers (TypeScript)" packages/domain/src/order.ts "import { db } from '../../infrastructure/src/db';" 'domain must not depend on infrastructure \(imports \.\./\.\./infrastructure/src/db\)'
fault "a package import across layers (TypeScript)" packages/domain/src/order.ts "import { db } from '@od/infrastructure';" 'domain must not depend on infrastructure'
fault "an external package in the domain (TypeScript)" packages/domain/src/order.ts "import axios from 'axios';" 'domain takes no external packages \(imports axios\)'
fault "the clock in the domain (TypeScript)" packages/domain/src/order.ts "export const now = () => Date.now();" '\[domain-purity\]'
fault "a tenant from the headers (TypeScript)" packages/functions/src/placeOrder.ts "@const tenant = request.headers.get('x-tenant-id');" '\[tenant-source\]'
fault "an unversioned event (TypeScript)" packages/contracts/src/events/orderPlaced.ts "@export interface OrderPlaced { orderId: string }" '\[message-version\]'
fault "the clock in the domain (Python)" src/orderdesk/domain/order.py "def stamp():
    return datetime.now()" '\[domain-purity\]'
fault "I/O in the domain (Python)" src/orderdesk/domain/order.py "import requests" '\[domain-purity\]'
fault "an import across layers (Python)" src/orderdesk/domain/order.py "from orderdesk.infrastructure.db import session" 'domain must not depend on infrastructure'
fault "a tenant from the route parameters (Python)" functions/place_order.py "@tenant = req.route_params.get('tenant_id')" '\[tenant-source\]'
cd "$app" || exit 1

# --- the full check without a toolchain ---------------------------------------------------------
echo "check"
sed 's/^stack = dotnet$/stack = none/' tools/check.cfg > "$work/cfg" && cp "$work/cfg" tools/check.cfg
out="$(bash tools/check.sh 2>&1)"; expect_status "passes with stack none" 0 $? "$out"
out="$(bash tools/check.sh --if-changed 2>&1)"; expect_output "--if-changed reuses the last pass" "nothing changed since the last passing run" "$out"
sed 's/^stack = none$/stack = cobol/' tools/check.cfg > "$work/cfg2" && cp "$work/cfg2" tools/check.cfg
out="$(bash tools/check.sh 2>&1)"; expect_status "fails on a stack without a profile" 1 $? "$out"
sed 's/^stack = cobol$/stack = ..\/..\/x/' tools/check.cfg > "$work/cfg2" && cp "$work/cfg2" tools/check.cfg
out="$(bash tools/check.sh 2>&1)"; expect_status "refuses a stack name that is a path" 1 $? "$out"
if [ "$dotnet_sdk" -eq 0 ]; then
  sed 's/^stack = .*$/stack = dotnet/' tools/check.cfg > "$work/cfg2" && cp "$work/cfg2" tools/check.cfg
  out="$(bash tools/check.sh 2>&1)"; expect_status "exits 3 when the stack's toolchain is missing" 3 $? "$out"
  expect_output "still runs the architecture rules" "architecture: PASS" "$out"
fi
cp "$work/cfg" tools/check.cfg
printf 'exit 1\n' > tools/check.local.sh
out="$(bash tools/check.sh 2>&1)"; expect_status "fails when tools/check.local.sh fails" 1 $? "$out"
rm -f tools/check.local.sh
if timeout --version 2>/dev/null | grep -qi coreutils; then
  cp tools/check.cfg "$work/cfg-timeout"
  printf '[tests]
timeout = 1
' >> tools/check.cfg
  printf 'sleep 20
' > tools/check.local.sh
  out="$(bash tools/check.sh 2>&1)"; expect_status "exits 3 when a test command runs past [tests] timeout" 3 $? "$out"
  expect_output "and says it was stopped at the limit" "ran past the 1-second limit" "$out"
  printf 'sleep 20
exit 1
' > tools/check.local.sh
  out="$(CHECK_TIMEOUT=1 bash tools/check.sh 2>&1)"; expect_status "CHECK_TIMEOUT overrides the limit" 3 $? "$out"
  printf 'exit 0
' > tools/check.local.sh
  out="$(bash tools/check.sh 2>&1)"; expect_status "a test command under the limit passes" 0 $? "$out"
  rm -f tools/check.local.sh; cp "$work/cfg-timeout" tools/check.cfg
fi
grep -q '^timeout = 600' "$src/project/tools/check.cfg" && ok "check.cfg ships [tests] timeout = 600" || bad "check.cfg has [tests] timeout = 600"
git add -A >/dev/null 2>&1; git_q commit -qm "stack none for the hook tests" >/dev/null 2>&1

# --- Stop hook ----------------------------------------------------------------------------------
echo "stop hook"
hook() { echo '{}' | CLAUDE_PROJECT_DIR="$app" bash .claude/hooks/stop-check.sh 2>&1; }
out="$(hook)"; expect_status "does nothing when code is unchanged" 0 $? "$out"
printf '# notes\n' > notes.md
out="$(hook)"; expect_status "does nothing for a docs-only change" 0 $? "$out"
rm -f notes.md
put product/research/2026-10-15-azure-region.md '# Norway East or West Europe
R1 · Informs: Q4 · Verified as of 2026-10-15 · Size: M'
out="$(hook)"; expect_status "does nothing for a research note" 0 $? "$out"
rm -f product/research/2026-10-15-azure-region.md
printf '\n// a harmless change\n' >> $domain
out="$(hook)"; expect_status "lets a passing change through" 0 $? "$out"
cp $domain "$work/passing"
printf 'public static class Bad { public static DateTime T => DateTime.UtcNow; }\n' >> $domain
cp $domain "$work/failing"
out="$(hook)"; status=$?
expect_status "blocks a failing change" 2 "$status" "$out"
expect_output "gives Claude the check output" 'domain-purity' "$out"
out="$(hook)"; expect_status "reports the same failing state only once" 0 $? "$out"
rm -f .satt/state/last-reported
: > .satt/state/building
out="$(hook)"; expect_status "leaves a builder's half-built files alone" 0 $? "$out"
rm -f .satt/state/building
out="$(hook)"; expect_status "blocks again once the builder is done" 2 $? "$out"
cp "$work/passing" $domain
out="$(hook)"; expect_status "lets the fixed state through" 0 $? "$out"
git checkout -q -- $domain

# --- pre-commit hook ----------------------------------------------------------------------------
echo "pre-commit hook"
out="$(bash tools/setup-clone.sh 2>&1)"; expect_status "setup-clone succeeds" 0 $? "$out"
grep -qs "SaaSAllTheThings" "$(git rev-parse --git-path hooks)/pre-commit" && ok "installs the pre-commit hook" || bad "installs the pre-commit hook" "$out"
printf 'public static class Bad { public static Guid G => Guid.NewGuid(); }\n' >> $domain
git add $domain
out="$(git_q commit -qm "broken" 2>&1)"; expect_status "blocks a commit that fails the check" 1 $? "$out"
git reset -q HEAD -- $domain && git checkout -q -- $domain
printf '\n// a harmless change\n' >> $domain
git add $domain
out="$(git_q commit -qm "fine" 2>&1)"; expect_status "allows a commit that passes" 0 $? "$out"
printf '# notes\n' > notes.md && git add notes.md
out="$(git_q commit -qm "docs only" 2>&1)"; expect_status "allows a docs-only commit" 0 $? "$out"
expect_no_output "doesn't run the check for a docs-only commit" "running the project check" "$out"
# A research item changes no code: its note and the records commit without the check.
put product/research/2026-10-15-azure-region.md '# Norway East or West Europe
R1 · Informs: Q4 · Verified as of 2026-10-15 · Size: M'
git add product/research/2026-10-15-azure-region.md
out="$(git_q commit -qm "docs: research the Azure region (R1)" 2>&1)"; status=$?
expect_status "allows a commit with only a research note" 0 "$status" "$out"
expect_no_output "doesn't run the check for a research note" "running the project check" "$out"
printf '# ADR-3 · x\n\n- **Status:** proposed\n' > adr/ADR-3-x.md && git add adr/ADR-3-x.md
out="$(git_q commit -qm "an ADR" 2>&1)"; expect_output "runs the check for an ADR" "running the project check" "$out"
printf 'x\n' > tools/check.sh.satt-new
printf '\n// another change\n' >> $domain && git add $domain
out="$(git_q commit -qm "with satt-new" 2>&1)"; expect_status "refuses while a .satt-new file is unmerged" 1 $? "$out"
rm -f tools/check.sh.satt-new
git reset -q HEAD -- $domain && git checkout -q -- $domain

# A nested clone in an ignored folder is listed by ls-files as a directory. It doesn't block a
# commit, but a real upgrade file still does while the clone is there.
printf '/clones/\n' >> .git/info/exclude
mkdir -p clones/nested && (cd clones/nested && git init -q && git_q commit -q --allow-empty -m nested) >/dev/null 2>&1
out="$(git_q commit -q --allow-empty -m "with a nested clone" 2>&1)"
expect_status "a nested clone in an ignored folder doesn't block a commit" 0 $? "$out"
printf 'x\n' > tools/check.sh.satt-new
out="$(git_q commit -q --allow-empty -m "with a nested clone and satt-new" 2>&1)"
expect_status "a real upgrade file still blocks with a nested clone present" 1 $? "$out"
expect_no_output "names the upgrade file, not the nested clone" "clones/" "$out"
rm -f tools/check.sh.satt-new

# --- /ui-design -----------------------------------------------------------------------------------
echo "ui-design"
# Everything here runs in the installed example ($app). The reader and the capture checks need Node;
# the capture of the fixture web app (tests/ui-web) also needs Playwright and Chromium, found in
# tests/ui-web/node_modules (npm install there, then npx playwright install chromium) or in the
# node_modules folder $SATT_PLAYWRIGHT names. Without them those tests are skipped.
cd "$app" || exit 1
helpers="$work/ui-helpers"
mkdir -p "$helpers"
# compare <actual> <expected>: the same reading, apart from where it came from.
cat > "$helpers/compare.mjs" <<'EOF'
import { readFileSync } from "node:fs";
const load = (path) => { const value = JSON.parse(readFileSync(path, "utf8")); delete value.source; delete value.sha1; return value; };
const same = (a, b) => {
  if (typeof a === "number" && typeof b === "number") return a === b;
  if (Array.isArray(a) || Array.isArray(b)) return Array.isArray(a) && Array.isArray(b) && a.length === b.length && a.every((item, index) => same(item, b[index]));
  if (a && b && typeof a === "object" && typeof b === "object") {
    const keys = Object.keys(a).sort();
    return same(keys, Object.keys(b).sort()) && keys.every((key) => same(a[key], b[key]));
  }
  return a === b;
};
const [actual, expected] = [load(process.argv[2]), load(process.argv[3])];
console.log(same(actual, expected) ? "SAME" : "DIFFERENT\n" + JSON.stringify(actual) + "\n" + JSON.stringify(expected));
EOF
# validate <starter> <screen> <W> <H> <drawing.mjs>: valid Excalidraw (types.ts in excalidraw/excalidraw) that reads back empty.
cat > "$helpers/validate.mjs" <<'EOF'
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { pathToFileURL } from "node:url";
const [path, screen, width, height, reader] = process.argv.slice(2);
const { readDrawing } = await import(pathToFileURL(reader).href);
const TYPES = ["rectangle", "text", "image", "frame", "line", "arrow", "freedraw", "ellipse", "diamond"];
const problems = [];
const doc = JSON.parse(readFileSync(path, "utf8"));
if (doc.type !== "excalidraw" || doc.version !== 2) problems.push("type excalidraw, version 2");
if (!Array.isArray(doc.elements) || typeof doc.appState !== "object" || typeof doc.files !== "object") { console.log("elements, appState and files are required"); process.exit(1); }
for (const [key, file] of Object.entries(doc.files)) {
  if (file.id !== key || file.mimeType !== "image/png" || !String(file.dataURL).startsWith("data:image/png;base64,") || typeof file.created !== "number") problems.push("file " + key);
}
const ids = new Map();
const frames = [];
let previous = "";
for (const e of doc.elements) {
  if (!e.id || ids.has(e.id)) problems.push(`id '${e.id}' is empty or repeated`);
  ids.set(e.id, e);
  if (e.type === "frame") frames.push(e.id);
  if (!TYPES.includes(e.type)) problems.push(e.id + ": type");
  for (const key of ["x", "y", "width", "height", "angle", "strokeWidth", "roughness", "opacity", "updated"]) if (typeof e[key] !== "number") problems.push(`${e.id}: ${key} must be a number`);
  for (const key of ["seed", "version", "versionNonce"]) if (!Number.isInteger(e[key])) problems.push(`${e.id}: ${key} must be an integer`);
  for (const key of ["strokeColor", "backgroundColor", "index"]) if (typeof e[key] !== "string") problems.push(`${e.id}: ${key} must be a string`);
  if (!["hachure", "cross-hatch", "solid", "zigzag"].includes(e.fillStyle) || !["solid", "dashed", "dotted"].includes(e.strokeStyle)) problems.push(e.id + ": fillStyle or strokeStyle");
  if (!Array.isArray(e.groupIds) || typeof e.isDeleted !== "boolean" || typeof e.locked !== "boolean") problems.push(e.id + ": groupIds, isDeleted or locked");
  for (const key of ["frameId", "roundness", "boundElements", "link"]) if (!(key in e)) problems.push(`${e.id}: ${key} is missing (null is fine)`);
  if (!(String(e.index) > previous)) problems.push(e.id + ": index must grow with the array order");
  previous = String(e.index);
  if (e.type === "text" && (typeof e.text !== "string" || typeof e.originalText !== "string" || typeof e.fontSize !== "number" || typeof e.fontFamily !== "number"
      || typeof e.lineHeight !== "number" || typeof e.autoResize !== "boolean" || !["left", "center", "right"].includes(e.textAlign)
      || !["top", "middle", "bottom"].includes(e.verticalAlign) || !("containerId" in e))) problems.push(e.id + ": text fields");
  if (e.type === "image" && (!(e.fileId in doc.files) || e.status !== "saved" || !Array.isArray(e.scale) || e.scale.length !== 2 || !("crop" in e))) problems.push(e.id + ": fileId, status, scale or crop");
  if (e.type === "frame" && typeof e.name !== "string") problems.push(e.id + ": name");
}
if (frames.length !== 1) problems.push("one frame is expected");
else {
  const frame = ids.get(frames[0]);
  const background = ids.get("ddd-background") || {};
  if (frame.name !== screen || frame.width !== Number(width) || frame.height !== Number(height)) problems.push("the frame is named after the screen and is the size of the capture");
  if (background.type !== "image" || background.locked !== true || background.frameId !== frames[0] || background.width !== Number(width) || background.height !== Number(height)) problems.push("the screenshot is a locked image filling the frame");
  for (const [id, e] of ids) {
    if (e.type !== "frame" && e.frameId !== frames[0] && id !== "ddd-legend") problems.push(id + ": frameId");
    if (id.startsWith("ddd-existing") && (e.locked !== false || e.opacity !== 25 || JSON.stringify(e.groupIds) !== '["ddd-existing"]')) problems.push(id + ": the existing group is unlocked (it can be dragged), at 25% opacity");
  }
  if (ids.has("ddd-legend") && ids.get("ddd-legend").frameId !== null) problems.push("the legend is outside the frame");
}
const read = readDrawing(readFileSync(path, "utf8"), path, "", screen, join(dirname(path), "captures"));
if (read.error) problems.push("reading it back: " + read.error);
else {
  const back = read.drawing.frames[0];
  if (back.boxes.length || back.unparsed.length || back.notes.length || back.removed.length) problems.push("saving the starter unchanged and reading it back must give no boxes, notes or unparsed entries");
}
console.log(problems.length === 0 ? "VALID" : problems.join("\n"));
EOF

if ! command -v node >/dev/null 2>&1; then
  echo "  skip  /ui-design reader and capture tests (Node isn't installed)"
else
  # Drawings. The fixture drawing (tests/ui-drawing/, shared with Godot Director) has a green box with
  # bound text and click:, a blue box over an existing element, a red X over an element, an arrowed
  # comment, a box inside a box, a note outside the frame and a freehand squiggle; its expected
  # reading was worked out by hand. The scaled copy has the background image and everything over it
  # moved and scaled to 50% (the frame stays). The *.godot.drawing.json files are what Godot
  # Director's reader (tools/ui_drawing.gd) writes for them: the port must write the same text.
  drawings="$work/drawings"
  mkdir -p "$drawings/drawing_fixtures/read" "$drawings/drawing_fixtures/moved"
  cp "$src"/tests/ui-drawing/* "$drawings/drawing_fixtures/"
  for variant in fixture:read fixture-scaled:moved; do
    name="${variant%%:*}"; folder="${variant#*:}"
    cp "$src/tests/ui-drawing/fixture.elements.json" "$drawings/drawing_fixtures/$folder/hero_room@1000x500.elements.json"
    out="$(cd "$drawings" && node "$app/tools/ui/drawing.mjs" "drawing_fixtures/$name.excalidraw" "drawing_fixtures/$folder/hero_room.drawing.json" 2>&1)"
    expect_status "the reader reads $name.excalidraw" 0 $? "$out"
    out="$(node "$helpers/compare.mjs" "$drawings/drawing_fixtures/$folder/hero_room.drawing.json" "$src/tests/ui-drawing/fixture.expected.json" 2>&1)"
    case "$name" in
      fixture) expect_output "the fixture drawing gives exactly the expected boxes, intents, parent, comment, removal, note and one unparsed entry, to 0.1%" "^SAME" "$out" ;;
      *) expect_output "the same drawing with the background image moved and scaled 50% gives the same percentages" "^SAME" "$out" ;;
    esac
    cmp -s "$drawings/drawing_fixtures/$folder/hero_room.drawing.json" "$src/tests/ui-drawing/$name.godot.drawing.json" \
      && ok "and exactly the drawing.json Godot Director's reader writes for $name.excalidraw" \
      || bad "the reader writes the drawing.json Godot Director's reader writes for $name.excalidraw" \
        "$(diff "$drawings/drawing_fixtures/$folder/hero_room.drawing.json" "$src/tests/ui-drawing/$name.godot.drawing.json" | head -n 10)"
  done
  out="$(cd "$drawings" && node "$app/tools/ui/drawing.mjs" drawing_fixtures/fixture.excalidraw drawing_fixtures/read/hero_room.drawing.json 2>&1)"
  case "$out" in *claimed*) bad "the fixture has no claimed element" "$out" ;; *) ok "the fixture has no claimed element" ;; esac
  out="$(cd "$drawings" && node "$app/tools/ui/drawing.mjs" drawing_fixtures/fixture-conflict.excalidraw drawing_fixtures/read/conflict.drawing.json 2>&1)"
  expect_output "an element claimed by a moved grey box and a blue box is named in one note" "note: hero_room: element 4 \(GearList\) is claimed by a moved grey box and a blue box named after it" "$out"
  mkdir -p "$drawings/drawing_fixtures/nomap"
  out="$(cd "$drawings" && node "$app/tools/ui/drawing.mjs" drawing_fixtures/fixture.excalidraw drawing_fixtures/nomap/hero_room.drawing.json 2>&1)"
  expect_output "with no element map the moved grey boxes are skipped with one note per frame" "note: hero_room: no element map hero_room@1000x500.elements.json, so the moved grey boxes are ignored" "$out"
  [ "$(printf '%s
' "$out" | grep -c 'no element map')" = "1" ] && ok "and it is one note" || bad "and it is one note" "$out"
  out="$(node tools/ui/drawing.mjs "$drawings/nowhere.excalidraw" "$drawings/read.json" 2>&1)"; expect_status "the reader refuses a missing drawing" 1 $? "$out"
  printf '{ not json' > "$drawings/broken.excalidraw"
  out="$(node tools/ui/drawing.mjs "$drawings/broken.excalidraw" "$drawings/read.json" 2>&1)"; expect_status "the reader refuses invalid JSON" 1 $? "$out"
  expect_output "and says so" "isn't valid JSON" "$out"
  printf '{"type":"excalidraw","version":2,"elements":[],"files":{}}' > "$drawings/empty.excalidraw"
  out="$(node tools/ui/drawing.mjs "$drawings/empty.excalidraw" "$drawings/read.json" 2>&1)"; expect_status "the reader refuses a drawing with no frame" 1 $? "$out"
  expect_output "and says so" "has no frame" "$out"
  out="$(node tools/ui/drawing.mjs starter "$drawings/drawing_fixtures/fixture" "$drawings/hero_room.starter.excalidraw" 2>&1)"
  expect_status "the starter drawing is written from a capture's files" 0 $? "$out"
  cmp -s "$drawings/hero_room.starter.excalidraw" "$src/tests/ui-drawing/starter.expected.excalidraw" \
    && ok "the starter matches the hand-checked fixture that Godot Director's starter matches" \
    || bad "the starter matches the hand-checked fixture" "$(diff "$drawings/hero_room.starter.excalidraw" "$src/tests/ui-drawing/starter.expected.excalidraw" | head -n 10)"
  out="$(node "$helpers/validate.mjs" "$drawings/hero_room.starter.excalidraw" hero_room 1000 500 "$app/tools/ui/drawing.mjs" 2>&1)"
  expect_output "the starter is valid Excalidraw, and saved unchanged it reads back with no boxes and no unparsed entries" "^VALID" "$out"

  # What capture needs, and what it says without it. Nothing may be written when it can't run.
  cp tools/ui_capture.cfg "$work/saved-ui-cfg"; cp tools/ui/screens.mjs "$work/saved-catalog"; cp tools/check.cfg "$work/saved-check-cfg"
  rm -rf product/ui/captures
  out="$(bash tools/ui_capture.sh --list 2>&1)"; expect_status "lists the catalog with Node alone" 0 $? "$out"
  expect_output "a line per screen: id, title, states, route, drawing and spec" "home · Home · states: default · opens / · drawing: no · spec: no" "$out"
  printf 'export default { screens: [\n  { id: "a", title: "A", route: "/" },\n  { id: "a", title: "Again", route: "/again" },\n  { id: "b", title: "B", route: "b", scene: "x" },\n] };\n' > tools/ui/screens.mjs
  out="$(bash tools/ui_capture.sh --list 2>&1)"; expect_status "fails a catalog with broken entries" 1 $? "$out"
  expect_output "and names each problem" "the id 'a' is used twice" "$out"
  expect_output "and an unknown key and a route that isn't a path" "unknown key 'scene'.*route must be a path" "$out"
  cp "$work/saved-catalog" tools/ui/screens.mjs
  mkdir -p clients/web/src/screens
  printf 'export const HomeScreen = () => `<h1 data-testid="home-title">Home</h1>`;\n' > clients/web/src/screens/HomeScreen.ts
  out="$(bash tools/ui_capture.sh --missing 2>&1)"; expect_status "--missing never fails" 0 $? "$out"
  expect_output "it lists a screen file the catalog doesn't name as a source" "missing: clients/web/src/screens/HomeScreen.ts" "$out"
  out="$(bash tools/ui_capture.sh --all 2>&1)"; expect_status "exits 3 for a product with no web client to open" 3 $? "$out"
  expect_output "and says capture isn't available for its clients yet" "capture isn't available for this product's clients yet" "$out"
  printf '# Home\n\n## Layout (at 1280x720)\n| # | Element | Name | Where (x, y, w, h %%) | Shows | Does | Size |\n|---|---|---|---|---|---|---|\n| 1 | Title | home-title | 2, 2, 20, 5 | - | - | fit |\n| 2 | Menu | home-menu | 2, 10, 20, 5 | - | - | fit |\n' > product/ui/home.md
  out="$(bash tools/ui_capture.sh home --verify 2>&1)"; expect_status "verify without capture exits 3: unverified" 3 $? "$out"
  expect_output "but checks the spec's names in the source" "\| Title \| home-title \| clients/web/src/screens/HomeScreen.ts \|" "$out"
  expect_output "and names one that isn't there" "\| Menu \| home-menu \| not found \|" "$out"
  sed 's#^base_url =.*#base_url = https://example.com#' "$work/saved-ui-cfg" > tools/ui_capture.cfg
  out="$(bash tools/ui_capture.sh --all 2>&1)"; expect_status "refuses a host that isn't this machine (exit 3)" 3 $? "$out"
  expect_output "and says why" "refusing \[web\] base_url: example.com isn't this machine" "$out"
  sed 's#^base_url =.*#base_url = http://127.0.0.1:9#' "$work/saved-ui-cfg" > tools/ui_capture.cfg
  out="$(bash tools/ui_capture.sh --all 2>&1)"; expect_status "exits 3 without Playwright" 3 $? "$out"
  expect_output "and gives the command that installs it" "cd tools/ui && npm install && npx playwright install chromium" "$out"
  sed -e 's#^base_url =.*#base_url = https://orderdesk-dev.azurewebsites.net#' -e 's#^allow_hosts =.*#allow_hosts = orderdesk-dev.azurewebsites.net#' "$work/saved-ui-cfg" > tools/ui_capture.cfg
  out="$(bash tools/ui_capture.sh --all 2>&1)"; expect_status "refuses a deployed environment on Azure, even in allow_hosts (exit 3)" 3 $? "$out"
  expect_output "and says why" "orderdesk-dev.azurewebsites.net is a hosted environment on Azure and isn't \[web\] dev_url" "$out"

  # The dev environment, named in [web] dev_url, is the one hosted address capture opens.
  dev_cfg() { sed -e 's#^dev_url =.*#dev_url = https://orderdesk-dev.azurestaticapps.net#' "$@" "$work/saved-ui-cfg" > tools/ui_capture.cfg; }
  dev_cfg
  out="$(bash tools/ui_capture.sh --list --dev 2>&1)"; expect_status "lists the catalog for the dev environment" 0 $? "$out"
  expect_output "and says each screen opens in dev" "home · Home · states: default · opens / · drawing: no · spec: [a-z]+ · env: dev" "$out"
  out="$(bash tools/ui_capture.sh --all --dev 2>&1)"; expect_status "allows the dev host (it stops only for want of Playwright)" 3 $? "$out"
  expect_output "and says it captures dev" "capturing the dev environment \(orderdesk-dev.azurestaticapps.net\)" "$out"
  dev_cfg -e 's#^base_url =.*#base_url = https://orderdesk-prod.azurewebsites.net#'
  out="$(bash tools/ui_capture.sh --all 2>&1)"; expect_status "still refuses another Azure host with dev named" 3 $? "$out"
  expect_output "and says why" "orderdesk-prod.azurewebsites.net is a hosted environment on Azure and isn't \[web\] dev_url" "$out"
  dev_cfg -e 's#^base_url =.*#base_url = https://app.orderdesk.com#'
  out="$(bash tools/ui_capture.sh --all 2>&1)"; expect_status "and a production-looking host" 3 $? "$out"
  expect_output "and says it never opens prod" "app.orderdesk.com isn't this machine .* or the dev environment \(\[web\] dev_url\); capture never opens prod" "$out"
  sed -e 's#^base_url =.*#base_url = http://127.0.0.1:9#' -e 's#^allow_hosts =.*#allow_hosts = example.com#' "$work/saved-ui-cfg" > tools/ui_capture.cfg
  out="$(bash tools/ui_capture.sh --all 2>&1)"; expect_status "refuses an allow_hosts name that isn't this machine or a private address" 3 $? "$out"
  expect_output "and says allow_hosts is for this machine's names" "refusing \[web\] allow_hosts: example.com .*names for this machine only" "$out"
  cp "$work/saved-ui-cfg" tools/ui_capture.cfg
  out="$(bash tools/ui_capture.sh --all --dev 2>&1)"; expect_status "--dev without dev_url can't run" 3 $? "$out"
  expect_output "and says so" "\[web\] dev_url is empty" "$out"

  # A tenant's screen opens as a test user of a seeded test tenant: the catalog says which, and the
  # saved sign-in must be there before anything is opened.
  printf 'export default { screens: [\n  { id: "orders", title: "Orders", route: "/orders", tenant: "test-tenant-a" },\n  { id: "customers", title: "Customers", route: "/customers", tenant: "contoso", auth: "contoso-user" },\n] };\n' > tools/ui/screens.mjs
  sed 's#^tenants =.*#tenants = test-tenant-a test-tenant-b#' "$work/saved-ui-cfg" > tools/ui_capture.cfg
  out="$(bash tools/ui_capture.sh --list 2>&1)"; expect_status "fails a catalog entry with a tenant but no test user's sign-in, or a tenant that isn't seeded" 1 $? "$out"
  expect_output "a tenant goes with its test user's sign-in" "orders: a tenant's screen opens signed in as a test user of that tenant: give both tenant and auth" "$out"
  expect_output "and only seeded test tenants" "customers: tenant 'contoso' isn't in tools/ui_capture.cfg › \[web\] tenants \(test-tenant-a, test-tenant-b\): capture opens seeded test tenants only" "$out"
  printf 'export default { screens: [\n  { id: "orders", title: "Orders", route: "/orders", tenant: "test-tenant-a", auth: "tenant-a-user",\n    states: { default: null, other_tenant: { tenant: "test-tenant-b", auth: "tenant-b-user" } } },\n] };\n' > tools/ui/screens.mjs
  out="$(bash tools/ui_capture.sh --list 2>&1)"; expect_status "lists a screen per test tenant" 0 $? "$out"
  printf 'export default { screens: [\n  { id: "orders", title: "Orders", route: "/orders", tenant: "test-tenant-a", auth: "tenant-a-user",\n    states: { default: null, other_tenant: { tenant: "test-tenant-b" } } },\n] };\n' > tools/ui/screens.mjs
  out2="$(bash tools/ui_capture.sh --list 2>&1)"; expect_status "fails a state that names a tenant without its own sign-in" 1 $? "$out2"
  expect_output "a state never opens as one tenant with another's sign-in" "the state 'other_tenant': a tenant's screen opens signed in as a test user of that tenant: give both tenant and auth" "$out2"
  printf 'export default { screens: [\n  { id: "orders", title: "Orders", route: "/orders", tenant: "test-tenant-a", auth: "tenant-a-user",\n    states: { default: null, other_tenant: { tenant: "test-tenant-b", auth: "tenant-b-user" } } },\n] };\n' > tools/ui/screens.mjs
  expect_output "with the test tenant each state opens as" "orders · Orders · states: default \(tenant test-tenant-a\), other_tenant \(tenant test-tenant-b\) · opens /orders" "$out"
  sed -e 's#^base_url =.*#base_url = http://127.0.0.1:9#' -e 's#^tenants =.*#tenants = test-tenant-a test-tenant-b#' "$work/saved-ui-cfg" > tools/ui_capture.cfg
  out="$(bash tools/ui_capture.sh --all 2>&1)"; expect_status "exits 3 when a test user's sign-in isn't saved" 3 $? "$out"
  expect_output "and says what to set up" "a test user's sign-in isn't saved: tools/ui/.auth/tenant-a-user.json \(a test user of the test tenant test-tenant-a\), tools/ui/.auth/tenant-b-user.json .*npx playwright codegen --save-storage=.auth/tenant-a-user.json http://127.0.0.1:9.*never a real account or token" "$out"
  cp "$work/saved-catalog" tools/ui/screens.mjs
  sed 's#^base_url =.*#base_url = http://127.0.0.1:9#' "$work/saved-ui-cfg" > tools/ui_capture.cfg
  _no_node_path=""
  for _dir in $(printf '%s' "$PATH" | tr ':' '\n'); do
    [ -x "$_dir/node" ] || [ -x "$_dir/node.exe" ] || _no_node_path="${_no_node_path:+$_no_node_path:}$_dir"
  done
  out="$(PATH="$_no_node_path" bash tools/ui_capture.sh --all 2>&1)"; expect_status "exits 3 without Node" 3 $? "$out"
  expect_output "and says it needs Node 18" "needs Node 18 or newer" "$out"
  [ ! -e product/ui/captures ] && ok "writes nothing when it can't run" || bad "writes nothing when it can't run" "$(ls product/ui/captures)"
  out="$(PATH="$_no_node_path" bash tools/check.sh 2>&1)"; expect_status "the check passes without Node" 0 $? "$out"
  fingerprint="$(bash tools/check.sh --fingerprint)"
  mkdir -p product/ui/captures && printf '{}\n' > product/ui/captures/home@1280x720.elements.json && printf 'x' > product/ui/captures/home@1280x720.png
  [ "$(bash tools/check.sh --fingerprint)" = "$fingerprint" ] && ok "captures don't change the check's fingerprint (they're gitignored)" \
    || bad "captures don't change the check's fingerprint (they're gitignored)"
  rm -rf product/ui/captures product/ui/home.md

  # An upgrade from the release before /ui-design: an app without its files gets the stubs, the
  # .gitignore lines and the manifest entries, and keeps its own AGENTS.md and check.cfg.
  upgraded="$work/upgraded"
  new_repo "$upgraded"
  bash "$src/install.sh" "$upgraded" >/dev/null 2>&1
  (cd "$upgraded" && rm -rf .satt/procedures/ui-design.md .claude/skills/ui-design tools/ui_capture.sh tools/ui tools/ui_capture.cfg product/ui \
    && grep -v -e '/product/ui/captures/' -e '/tools/ui/' .gitignore > .gitignore.new && mv .gitignore.new .gitignore \
    && grep -v -e 'tools/ui' -e 'ui-design' .satt/manifest > manifest.new && mv manifest.new .satt/manifest \
    && printf '# My app\nOur own AGENTS.md\n' > AGENTS.md && printf '[project]\nstack = none\n[layers]\nclient = web/*\n' > tools/check.cfg \
    && mkdir -p web/admin/pages && printf 'export default () => "<main>Orders</main>";\n' > web/admin/pages/orders.tsx)
  out="$(bash "$src/install.sh" "$upgraded" 2>&1)"; expect_status "upgrades an app from before /ui-design" 0 $? "$out"
  if [ -f "$upgraded/tools/ui/screens.mjs" ] && [ -f "$upgraded/tools/ui_capture.cfg" ] && [ -f "$upgraded/product/ui/README.md" ] \
      && [ -x "$upgraded/tools/ui_capture.sh" ] && grep -qx '/product/ui/captures/' "$upgraded/.gitignore" && grep -qx '/tools/ui/node_modules/' "$upgraded/.gitignore" \
      && grep -q "$(printf '\t')tools/ui/capture.mjs$" "$upgraded/.satt/manifest" && grep -q "$(printf '\t').satt/procedures/ui-design.md$" "$upgraded/.satt/manifest"; then
    ok "it gets the catalog, the settings, the tools, the .gitignore lines and the manifest entries"
  else
    bad "the upgrade gets the catalog, the settings, the tools, the .gitignore lines and the manifest entries" "$out"
  fi
  grep -q "Our own AGENTS.md" "$upgraded/AGENTS.md" && grep -q "client = web/\*" "$upgraded/tools/check.cfg" \
    && ok "and keeps its own AGENTS.md and check.cfg" || bad "the upgrade keeps the app's own AGENTS.md and check.cfg"
  out="$(cd "$upgraded" && bash tools/ui_capture.sh --missing 2>&1)"; expect_status "align's screen check lists without failing" 0 $? "$out"
  expect_output "the app's screens the catalog doesn't cover yet" "missing: web/admin/pages/orders.tsx" "$out"

  # Capture of the fixture web app (tests/ui-web), served on this machine by its start_command.
  pw="${SATT_PLAYWRIGHT:-$src/tests/ui-web/node_modules}"
  chromium_ok=0
  if [ -d "$pw/playwright" ] && [ -d "$pw/playwright-core" ]; then
    mkdir -p tools/ui/node_modules && cp -R "$pw/playwright" "$pw/playwright-core" tools/ui/node_modules/
    (cd tools/ui && node --input-type=module -e 'import { chromium } from "playwright"; import { existsSync } from "node:fs"; process.exit(existsSync(chromium.executablePath()) ? 0 : 1);') >/dev/null 2>&1 && chromium_ok=1
  fi
  if [ "$chromium_ok" -eq 0 ]; then
    echo "  skip  capture of the fixture web app (no Playwright with Chromium in tests/ui-web/node_modules or \$SATT_PLAYWRIGHT)"
  else
    rm -rf uifixture && cp -R "$src/tests/ui-web" uifixture && rm -rf uifixture/node_modules
    port=$((40000 + $$ % 20000))
    sed -e "s#^base_url =.*#base_url = http://127.0.0.1:$port#" -e "s#^start_command =.*#start_command = node uifixture/serve.mjs $port#" \
      -e 's#^list = .*#list = 1280x720 800x600#' -e 's#^setup_timeout = .*#setup_timeout = 3#' \
      -e 's#^tenants =.*#tenants = test-tenant-a test-tenant-b#' "$work/saved-ui-cfg" > tools/ui_capture.cfg
    # The test users' saved sign-ins: empty, as the fixture app has no sign-in to keep.
    mkdir -p tools/ui/.auth && for user in tenant-a-user tenant-b-user; do printf '{"cookies":[],"origins":[]}\n' > "tools/ui/.auth/$user.json"; done
    cat > tools/ui/screens.mjs <<'EOF'
export default {
  screens: [
    { id: "clean", title: "Hero room", route: "/", source: "uifixture/site/index.html",
      states: {
        default: null,
        busy: async (page, api, screen) => { await screen.open(); await page.evaluate(() => { document.querySelector("h2").textContent = "Ada (busy)"; }); },
      } },
    { id: "lint", title: "Lint fixture", route: "/lint" },
    { id: "order", title: "Tab order", route: "/order" },
    { id: "broken", title: "Throws", route: "/broken" },
    { id: "gone", title: "Missing route", route: "/missing" },
    { id: "stuck", title: "A state that never finishes", route: "/", states: { default: () => new Promise(() => undefined) } },
    { id: "away", title: "Calls a hosted backend", route: "/away" },
    { id: "apiaway", title: "Seeds through a redirect off this machine", route: "/", states: { default: async (page, api) => { await api.get("/redirect-away"); } } },
    { id: "modal", title: "A modal dialog", route: "/modal" },
    { id: "reload", title: "Reloads when focused", route: "/reload" },
    { id: "bad", title: "A broken entry", route: "nope" },
    { id: "tenanted", title: "As a test tenant's user", route: "/order", tenant: "test-tenant-a", auth: "tenant-a-user",
      states: { default: null, other_tenant: { tenant: "test-tenant-b", auth: "tenant-b-user" } } },
    { id: "private", title: "Behind the sign-in", route: "/private" },
    { id: "signin", title: "Sent away to sign in", route: "/redirect-away" },
    { id: "msal", title: "Sent away to sign in by a script", route: "/signin" },
    { id: "denied", title: "Its API refuses without a sign-in", route: "/denied" },
  ],
};
EOF
    captures=product/ui/captures
    out="$(bash tools/ui_capture.sh --all 2>&1)"; status=$?
    expect_status "a screen that fails fails the run (exit 1), and the others are captured" 1 "$status" "$out"
    missing=""
    for base in clean clean.busy lint order away modal; do
      for size in 1280x720 800x600; do
        for ext in png elements.json map.png lint.txt; do [ -f "$captures/$base@$size.$ext" ] || missing="$missing $base@$size.$ext"; done
      done
    done
    [ -z "$missing" ] && ok "writes a PNG, element map, map image and lint file per screen, state and size" || bad "capture outputs missing:$missing" "$out"
    [ "$(od -An -tu1 -j16 -N8 "$captures/clean@800x600.png" | tr -s ' ' | sed 's/^ //;s/ $//')" = "0 0 3 32 0 0 2 88" ] \
      && ok "a capture has the requested size (800x600)" || bad "a capture has the requested size (800x600)"
    (cd "$captures" && ls -- *.starter.excalidraw 2>/dev/null | tr '\n' ' ') > "$work/starters"
    [ "$(cat "$work/starters")" = "away.starter.excalidraw broken.starter.excalidraw clean.starter.excalidraw lint.starter.excalidraw modal.starter.excalidraw order.starter.excalidraw tenanted.starter.excalidraw " ] \
      && ok "writes a starter drawing for the default state at the default size" || bad "writes a starter drawing for the default state at the default size" "$(cat "$work/starters")"
    grep -q '"schema": 1, "adapter": "playwright"' "$captures/clean@1280x720.elements.json" \
      && grep -q '"id":"change","stable":true,"path":"\[data-testid=\\"change\\"\]","kind":"button","name":"Change",' "$captures/clean@1280x720.elements.json" \
      && ok "the element map lists the data-testid elements with their role and name" || bad "the element map lists the data-testid elements with their role and name" "$(head -n 8 "$captures/clean@1280x720.elements.json")"
    grep -q 'Ada (busy)' "$captures/clean.busy@1280x720.elements.json" && ! grep -q 'Ada (busy)' "$captures/clean@1280x720.elements.json" \
      && ok "a state prepares the page after opening it" || bad "a state prepares the page after opening it"
    [ -z "$(cat "$captures"/clean@*.lint.txt "$captures"/clean.busy@*.lint.txt)" ] && ok "the clean page is lint-clean at every size" \
      || bad "the clean page is lint-clean at every size" "$(cat "$captures"/clean*.lint.txt)"
    lint="$(cat "$captures/lint@1280x720.lint.txt")"
    for rule in 'squeezed-text element [0-9]* \[data-testid="squeezed"\]' 'stretched-control element [0-9]* \[data-testid="stretched"\]' \
        'off-screen element [0-9]* \[data-testid="far"\]' 'overlap element [0-9]* \[data-testid="link-one"\]: element [0-9]* \(Two\)' \
        'unreachable element [0-9]* \[data-testid="skipped"\]' 'no-default-focus element [0-9]* \[data-testid="ok"\]' \
        'hard-coded-position element [0-9]* \[data-testid="pinned"\].*\(warning\)'; do
      expect_output "lint: ${rule%% *} on the element built to break it" "$rule" "$lint"
    done
    [ "$(printf '%s\n' "$lint" | grep -c .)" = "7" ] && ok "and nothing else on that page" || bad "the lint page has exactly seven findings" "$lint"
    order="$(node -e 'const m = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")); console.log(m.elements.map((e) => e.id + "=" + e.focus_order).join(" "));' "$captures/order@1280x720.elements.json")"
    [ "$order" = "first=3 third=2 second=1 trap=4 after=null" ] && ok "Tab order follows tabindex, and stops at the focus trap" || bad "Tab order follows tabindex, and stops at the focus trap" "$order"
    [ "$(cat "$captures/order@1280x720.lint.txt")" = 'unreachable element 5 [data-testid="after"]: Tab never reaches it from the default focus' ] \
      && ok "the element after the trap is the one unreachable element" || bad "the element after the trap is the one unreachable element" "$(cat "$captures/order@1280x720.lint.txt")"
    head -n 1 "$captures/broken@1280x720.lint.txt" | grep -q '^error: a page error: selftest page error' && [ -f "$captures/broken@1280x720.png" ] \
      && ok "a page error fails its screen, which is still captured, with the error at the top of its lint file" || bad "a page error fails its screen, with the error at the top of its lint file" "$out"
    grep -q '^error: /missing answered 404' "$captures/gone@1280x720.lint.txt" && [ ! -f "$captures/gone@1280x720.png" ] \
      && ok "a route that answers 404 fails its screen and leaves only the error" || bad "a route that answers 404 fails its screen and leaves only the error" "$out"
    expect_output "a state that doesn't finish fails only its screen" "FAIL: stuck@1280x720: the setup didn't finish within 3 seconds" "$out"
    expect_output "a broken catalog entry is named" "FAIL: bad: its route must be a path" "$out"
    grep -q '"tenant": "test-tenant-a"' "$captures/tenanted@1280x720.elements.json" && grep -q '"tenant": "test-tenant-b"' "$captures/tenanted.other_tenant@1280x720.elements.json" \
      && ! grep -q '"tenant"' "$captures/clean@1280x720.elements.json" \
      && ok "a tenant's screen opens as each state's test tenant, and its element map names the tenant" || bad "a tenant's screen opens as each state's test tenant, and its element map names the tenant" "$out"
    expect_output "a screen sent off this machine to sign in fails only its screen and says why" "FAIL: signin@1280x720: /redirect-away was sent off this machine to 203\.0\.113\.9, usually to sign in: it needs a sign-in" "$out"
    expect_output "a page sent to sign in by a script after it loaded fails only its screen" "FAIL: msal@1280x720: /signin was sent off this machine to 203\.0\.113\.9, usually to sign in: it needs a sign-in" "$out"
    [ ! -f "$captures/msal@1280x720.png" ] && [ ! -f "$captures/msal@1280x720.elements.json" ] && ok "and nothing of it is written but the error" \
      || bad "a screen sent to sign in leaves only its error"
    expect_output "a page whose API answers 401 fails only its screen" "FAIL: denied@1280x720: /denied: /api/private answered 401: it needs a sign-in" "$out"
    expect_output "a screen behind the sign-in, without a test user, fails only its screen and says why" "FAIL: private@1280x720: /private answered 401: it needs a sign-in: give the entry a seeded test tenant and its test user's saved sign-in" "$out"
    away="$(cat "$captures/away@1280x720.lint.txt")"
    expect_output "a request to a host that isn't this machine is blocked and noted" "note: blocked requests to 192\.0\.2\.1: not this machine" "$away"
    expect_output "so is a redirect off this machine, which capture doesn't follow" "note: blocked requests to 203\.0\.113\.9:" "$away"
    expect_output "and a WebSocket to another host" "note: blocked requests to 198\.51\.100\.7:" "$away"
    grep -q '"name":"local data"' "$captures/away@1280x720.elements.json" && ok "while the page's own requests to this machine go through" \
      || bad "the page's own requests to this machine go through" "$(head -n 8 "$captures/away@1280x720.elements.json")"
    expect_output "the api helper doesn't follow a redirect (it fails the state)" "FAIL: apiaway@1280x720: api: GET http://127\.0\.0\.1:$port/redirect-away answered 302" "$out"
    [ -z "$(cat "$captures/modal@1280x720.lint.txt")" ] && ok "behind an open modal dialog, nothing counts as unreachable" \
      || bad "behind an open modal dialog, nothing counts as unreachable" "$(cat "$captures/modal@1280x720.lint.txt")"
    expect_output "a page that reloads while it is mapped fails only its screen" "FAIL: reload@1280x720: the page changed while it was mapped" "$out"
    expect_output "capture starts the app with start_command" "starting the app: node uifixture/serve.mjs $port" "$out"
    node -e 'require("http").get(process.argv[1], () => process.exit(1)).on("error", () => process.exit(0));' "http://127.0.0.1:$port/" \
      && ok "and stops it afterwards" || bad "capture stops the app it started"
    cp "$captures/clean@1280x720.elements.json" "$work/first-map"; cp "$captures/clean@1280x720.png" "$work/first-png"
    out="$(bash tools/ui_capture.sh clean --state default --size 1280x720 2>&1)"; expect_status "captures one screen, state and size" 0 $? "$out"
    cmp -s "$captures/clean@1280x720.elements.json" "$work/first-map" && ok "a second capture gives the same element map" || bad "a second capture gives the same element map" "$out"
    cmp -s "$captures/clean@1280x720.png" "$work/first-png" && ok "and the same image" || bad "a second capture gives the same image"
    out="$(node "$helpers/validate.mjs" "$captures/clean.starter.excalidraw" clean 1280 720 "$app/tools/ui/drawing.mjs" 2>&1)"
    expect_output "a captured starter drawing is valid Excalidraw and reads back empty" "^VALID" "$out"

    # verify: a spec written from the capture matches it; moving one element 10% reports exactly it.
    node -e '
      const m = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
      const rows = m.elements.filter((e) => ["back", "hero-sheet", "gear-list", "change"].includes(e.id))
        .map((e, i) => `| ${i + 1} | ${e.id} | ${e.id} | ${e.rect_pct.join(", ")} | - | - | fit |`);
      require("fs").writeFileSync(process.argv[2], "# Hero room\n\n## Layout (at 1280x720)\n| # | Element | Name | Where (x, y, w, h %) | Shows | Does | Size |\n|---|---|---|---|---|---|---|\n" + rows.join("\n") + "\n");
    ' "$captures/clean@1280x720.elements.json" product/ui/clean.md
    mkdir -p "$work/director-ui" && cp "$captures/clean.starter.excalidraw" "$work/director-ui/clean.excalidraw"
    node tools/ui/drawing.mjs "$work/director-ui/clean.excalidraw" "$captures/clean.drawing.json" clean >/dev/null 2>&1
    out="$(bash tools/ui_capture.sh clean --verify --size 1280x720 2>&1)"; expect_status "verify passes a screen built as its spec says" 0 $? "$out"
    expect_output "with no deviations" "4 elements checked, 0 deviations" "$out"
    expect_output "a broken entry elsewhere in the catalog doesn't stop it" "note: another entry in tools/ui/screens.mjs has a problem: bad:" "$out"
    expect_output "it names the compare image" "compare image: product/ui/captures/clean.compare@1280x720.png" "$out"
    [ "$(od -An -tu1 -j16 -N8 "$captures/clean.compare@1280x720.png" 2>/dev/null | tr -s ' ' | sed 's/^ //;s/ $//')" = "0 0 10 8 0 0 2 208" ] \
      && ok "and writes it: the drawing's screenshot and the capture side by side (2568x720)" || bad "the compare image is the drawing's screenshot and the capture side by side (2568x720)" "$out"
    sed 's#<section class="panel" data-testid="hero-sheet">#<section class="panel" data-testid="hero-sheet" style="margin-left:128px">#' "$src/tests/ui-web/site/index.html" > uifixture/site/index.html
    out="$(bash tools/ui_capture.sh clean --verify --size 1280x720 2>&1)"; expect_status "verify fails a screen with an element moved 10%" 1 $? "$out"
    if [ "$(printf '%s\n' "$out" | grep -c '^ui_verify: | .* | moved: ')" = "1" ]; then
      expect_output "and reports exactly that element" "\| hero-sheet \| hero-sheet \| .* \| moved: left edge" "$out"
    else
      bad "verify reports exactly the moved element" "$out"
    fi
    cp "$src/tests/ui-web/site/index.html" uifixture/site/index.html

    # The dev environment: [web] dev_url names it (here this machine under another name, so the test
    # stays local). Capture neither starts nor stops it, and --list and the element map say env: dev.
    cp tools/ui_capture.cfg "$work/fixture-cfg-base"
    node uifixture/serve.mjs "$port" >/dev/null 2>&1 &
    dev_server=$!
    waited=0
    until node -e 'require("http").get(process.argv[1], () => process.exit(0)).on("error", () => process.exit(1));' "http://localhost:$port/"; do
      waited=$((waited + 1)); [ "$waited" -ge 30 ] && break; sleep 1
    done
    sed -e "s#^dev_url =.*#dev_url = http://localhost:$port#" -e 's#^list = .*#list = 1280x720#' "$work/saved-ui-cfg" > tools/ui_capture.cfg
    out="$(bash tools/ui_capture.sh clean --dev --state default 2>&1)"; expect_status "captures the dev environment" 0 $? "$out"
    expect_no_output "without starting anything" "starting the app" "$out"
    grep -q '"env": "dev"' "$captures/clean@1280x720.elements.json" && ok "its element map says env: dev"       || bad "a capture of dev says env: dev in its element map" "$(head -n 6 "$captures/clean@1280x720.elements.json")"
    out="$(bash tools/ui_capture.sh --list --dev 2>&1)"; expect_output "and --list says env: dev" "clean · Hero room · .* · env: dev" "$out"
    kill "$dev_server" 2>/dev/null; wait "$dev_server" 2>/dev/null
    cp "$work/fixture-cfg-base" tools/ui_capture.cfg

    # A capture killed mid-run leaves the app it started running; the next capture stops it first,
    # instead of taking it for an app the human started.
    answers() { node -e 'require("http").get(process.argv[1], () => process.exit(0)).on("error", () => process.exit(1));' "http://127.0.0.1:$port/"; }
    cp tools/ui_capture.cfg "$work/fixture-cfg"
    sed 's#^setup_timeout = .*#setup_timeout = 120#' "$work/fixture-cfg" > tools/ui_capture.cfg
    rm -f .satt/state/ui_app.pid
    bash tools/ui_capture.sh stuck > "$work/stuck.log" 2>&1 &
    waited=0
    until [ -f .satt/state/ui_app.pid ] && answers; do
      waited=$((waited + 1)); [ "$waited" -ge 60 ] && break; sleep 1
    done
    sleep 1
    capture_pid="$(cut -d' ' -f2 .satt/state/ui_app.pid 2>/dev/null)"
    case "$(uname -s)" in
      MINGW*|MSYS*|CYGWIN*) taskkill //PID "$capture_pid" //F >/dev/null 2>&1 ;;
      *) kill -9 "$capture_pid" 2>/dev/null ;;
    esac
    wait 2>/dev/null
    sleep 1
    if answers; then ok "a capture killed mid-run leaves the app it started running"; else bad "a capture killed mid-run leaves the app it started running" "$(cat "$work/stuck.log")"; fi
    cp "$work/fixture-cfg" tools/ui_capture.cfg
    out="$(bash tools/ui_capture.sh clean --state default --size 1280x720 2>&1)"; expect_status "the next capture runs" 0 $? "$out"
    expect_output "it stops the app the killed capture left running" "stopping the app an interrupted capture left running" "$out"
    expect_output "and starts its own" "starting the app: node uifixture/serve.mjs $port" "$out"
    if answers; then bad "and stops it afterwards: nothing is left running" "$out"; else ok "and stops it afterwards: nothing is left running"; fi
    [ ! -f .satt/state/ui_app.pid ] && ok "and clears its record of the app" || bad "capture clears its record of the app it started"

    sed -e "s#^base_url =.*#base_url = http://127.0.0.1:$((port + 1))#" -e 's#^start_command =.*#start_command = node -e "process.exit(4)"#' "$work/saved-ui-cfg" > tools/ui_capture.cfg
    out="$(bash tools/ui_capture.sh clean 2>&1)"; expect_status "exits 3 when the start command ends before the app answers" 3 $? "$out"
    expect_output "and says so, naming the app's output" "ended with exit 4 before the app answered at .* \(its output: \.satt/state/ui_app\.log\)" "$out"
  fi
  cp "$work/saved-ui-cfg" tools/ui_capture.cfg; cp "$work/saved-catalog" tools/ui/screens.mjs; cp "$work/saved-check-cfg" tools/check.cfg
  rm -rf product/ui/captures product/ui/clean.md uifixture tools/ui/node_modules tools/ui/.auth clients/web
fi

# --- .NET, where the SDK is installed -----------------------------------------------------------
if [ "$dotnet_sdk" -eq 1 ]; then
  echo ".NET"
  dotnet_app="$work/order-desk-dotnet"
  cp -R "$src/examples/order-desk" "$dotnet_app"
  (cd "$dotnet_app" && git init -q && git config core.autocrlf false && git add -A && git_q commit -qm example \
    && bash "$src/install.sh" . >/dev/null 2>&1 && git add -A && git_q commit -qm install) >/dev/null 2>&1
  cd "$dotnet_app" || exit 1
  out="$(bash tools/setup-clone.sh --skip-hook 2>&1)"; expect_status "setup-clone restores the example" 0 $? "$out"
  out="$(bash tools/check.sh 2>&1)"; status=$?
  expect_status "the example builds and its tests pass" 0 "$status" "$out"
  expect_output "runs the example's tests" "dotnet test passed" "$out"
else
  echo ".NET: skipped (no .NET SDK on this machine)"
fi

finish
