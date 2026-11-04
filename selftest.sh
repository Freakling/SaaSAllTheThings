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
other=" mapping.md contract.md prd.md director-brief.md decisions.md user-stories.md as-built.md interpretations.md prd-before.md postmortem.md README.md TEMPLATE.md ONBOARDING.md CHANGELOG.md AGENTS.md CLAUDE.md TASKS.md TASKS-archive.md adr.md integration-contract.md "
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
# User stories: the seed and the example's file have the header line, the sections and stories in the story
# format, whose roles are listed under Roles (and in the example, are personas of its PRD); the item format,
# the TASKS.md seed and the example carry Stories:; the check.cfg seeds have the cadence; the PRD links the
# file; and the rules, the procedures, the workshops, the assessment, the settings, the skills and the docs
# name them. tools/stories.sh --due is tested under "user stories".
stories_seed="$src/project/product/user-stories.md"
stories_example="$src/examples/order-desk/product/user-stories.md"
# stories_faults <file> [prd]: what a user stories file gets wrong, read in one pass with builtins; nothing when it holds.
stories_faults() {
  local line section="" next="" faults="" ids="|" roles="|" values="|" stories="" story id r found
  local header=0 value=0 rolesec=0
  local next_re='^[*][*]Next ID:[*][*] US-([0-9]+) · [*][*]Last validated:[*][*] never$'
  local role_re='^- [*][*]([^*:]+)[*][*]$'
  local value_re='^- [*][*]([^*:]+):[*][*] .+'
  local persona_re='^- [*][*]([^*:]+)[*][*] [(]'
  local row_re='^[|] US-([0-9]+) [|] As an? (.+ I [^|]+, so [^|]+[.]) [|] ([0-9]{4}-[0-9]{2}-[0-9]{2}|unconfirmed) [|]$'
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in
      '## The value in one paragraph per role') section=value; value=1; continue ;;
      '## Roles') section=roles; rolesec=1; continue ;;
      '## '*) section=table; continue ;;
      '| ID | Story | Confirmed |') header=1; continue ;;
    esac
    if [[ $line =~ $next_re ]]; then next="${BASH_REMATCH[1]}"
    elif [ "$section" = roles ] && [[ $line =~ $role_re ]]; then roles="$roles${BASH_REMATCH[1]}|"
    elif [ "$section" = value ] && [[ $line =~ $value_re ]]; then values="$values${BASH_REMATCH[1]}|"
    elif [[ $line =~ $row_re ]]; then
      id="${BASH_REMATCH[1]}"
      case "$ids" in *"|$id|"*) faults="$faults US-$id(twice)" ;; esac
      ids="$ids$id|"; stories="$stories${BASH_REMATCH[2]}"$'\n'
    else
      case "$line" in '| US-'*) faults="$faults row(not | US-<n> | As a <role> I ..., so ... | <date> or unconfirmed |)" ;; esac
    fi
  done < "$1"
  [ -n "$next" ] || faults="$faults Next-ID-and-Last-validated"
  [ "$value" -eq 1 ] && [ "$rolesec" -eq 1 ] && [ "$header" -eq 1 ] && [ -n "$stories" ] || faults="$faults sections"
  local IFS='|'
  for id in ${ids#|}; do [ -n "$next" ] && [ "$id" -lt "$next" ] || faults="$faults US-$id(not below Next ID)"; done
  for r in ${roles#|}; do case "$values" in *"|$r|"*) ;; *) faults="$faults role($r has no value paragraph)" ;; esac; done
  if [ -n "${2:-}" ]; then
    local personas="|" in_personas=0
    while IFS= read -r line || [ -n "$line" ]; do
      line="${line%$'\r'}"
      case "$line" in '## Personas and Roles') in_personas=1; continue ;; '## '*) in_personas=0; continue ;; esac
      [ "$in_personas" -eq 1 ] && [[ $line =~ $persona_re ]] && personas="$personas${BASH_REMATCH[1]}|"
    done < "$2"
    for r in ${roles#|}; do case "$personas" in *"|$r|"*) ;; *) faults="$faults role($r isn't a persona in the PRD)" ;; esac; done
  fi
  IFS=$'\n'
  shopt -s nocasematch
  for story in $stories; do
    found=0
    local IFS='|'
    for r in ${roles#|}; do [[ $story == "$r I "* ]] && { found=1; break; }; done
    IFS=$'\n'
    [ "$found" -eq 1 ] || faults="$faults story(its role isn't under Roles: ${story%% I *})"
  done
  shopt -u nocasematch
  printf '%s' "$faults"
}
wired=""
[ -f "$stories_seed" ] && [ -f "$stories_example" ] && [ -f "$src/framework/tools/stories.sh" ] || wired="$wired files"
grep -q '^# User stories: {{PROJECT_NAME}}$' "$stories_seed" || wired="$wired seed(title)"
grep -q '^# User stories: Order Desk$' "$stories_example" || wired="$wired example(title)"
faults="$(stories_faults "$stories_seed")"; [ -z "$faults" ] || wired="$wired seed:$faults"
faults="$(stories_faults "$stories_example" "$src/examples/order-desk/product/prd.md")"; [ -z "$faults" ] || wired="$wired example:$faults"
# The example: every agent item other than research has a Stories: line, every capability in its PRD names its
# stories, and every story ID an item or a capability names is in its file.
faults="$(awk '
  FNR == 1 { if (file == 2 && id != "" && agent && !st) print "item(" id " has no Stories:)"; st = 0; file++ }
  file == 1 { if ($0 ~ /^[|] US-[0-9]+ [|]/) { split($0, c, " "); have[c[2]] = 1 }; next }
  file == 2 && /^### / { if (id != "" && agent && !st) print "item(" id " has no Stories:)"; id = $2; st = 0
    agent = ($0 ~ / · agent$/ || $0 ~ / · agent · /) && id !~ /^R/ }
  file == 3 && /^## / { if (cap != "" && !st) print "capability(" cap " has no Stories:)"; cap = ""; caps = ($0 == "## Capabilities") }
  file == 3 && caps && /^### / { if (cap != "" && !st) print "capability(" cap " has no Stories:)"; cap = substr($0, 5); st = 0 }
  /^(- )?Stories: / { st = 1; n = split($0, w, /[ ,]+/)
    for (i = 1; i <= n; i++) if (w[i] ~ /^US-[0-9]+$/ && !(w[i] in have)) print FILENAME ": " w[i] " is not in the stories" }
  END { if (cap != "" && !st) print "capability(" cap " has no Stories:)" }
' "$stories_example" "$src/examples/order-desk/TASKS.md" "$src/examples/order-desk/product/prd.md")"
[ -z "$faults" ] || wired="$wired example($faults)"
grep -q '^- Stories: US-[0-9]' "$satt/tasks.md" && grep -q '^- \*\*`Stories:`\.\*\* .* or `none` for foundation, tooling and infrastructure' "$satt/tasks.md" || wired="$wired tasks.md"
grep -q '^- Stories: none$' "$src/project/TASKS.md" || wired="$wired project/TASKS.md"
for f in project/tools/check.cfg examples/order-desk/tools/check.cfg; do
  awk '/^\[stories\]$/ { s = 1; next } /^\[/ { s = 0 } s && /^every = 10$/ { found = 1 } END { exit !found }' "$src/$f" || wired="$wired $f"
done
grep -qF 'Each persona is a role in the user stories, by the same name' "$src/project/product/prd.md" \
  && grep -qF '[user stories](user-stories.md)' "$src/project/product/prd.md" && grep -qF '(Stories: US-1, US-3)' "$src/project/product/prd.md" \
  && grep -qF '[user stories](user-stories.md)' "$src/examples/order-desk/product/prd.md" || wired="$wired prd.md"
grep -q '^| Why each feature is built, for which persona | `product/user-stories\.md`: the value for each persona in PRD › Personas and Roles' "$satt/rules.md" \
  && grep -qF 'recorded in the PRD, the user stories, ADRs, contracts and TASKS.md' "$satt/rules.md" \
  && grep -q '^- \*\*Why it.s built\.\*\* A feature item names the user stories it serves' "$satt/rules.md" \
  && grep -qF '`product/user-stories.md` when a story was drafted for it' "$satt/rules.md" || wired="$wired rules.md"
grep -q '^## User stories$' "$satt/procedures/design.md" && grep -q '^### Validate the stories$' "$satt/procedures/design.md" \
  && grep -q 'bash tools/stories\.sh --due' "$satt/procedures/design.md" && grep -q 'its `Stories:`' "$satt/procedures/design.md" \
  && grep -q '^5\. \*\*`product/user-stories\.md`:\*\*' "$satt/procedures/design.md" || wired="$wired design.md"
grep -q 'bash tools/stories\.sh --due' "$satt/procedures/next-task.md" && grep -q '\[stories\] every' "$satt/procedures/next-task.md" \
  && grep -q 'A feature item (not a research item) with no story gets one before it is built' "$satt/procedures/next-task.md" \
  && grep -q 'with `product/user-stories\.md` when the claim drafted a story' "$satt/procedures/next-task.md" \
  && grep -q 'a security assessment or a stories validation if Pick step 4 found one due' "$satt/procedures/next-task.md" || wired="$wired next-task.md"
grep -qF -- '- [ ] Still right   - [ ] Needs a change' "$satt/procedures/acceptance.md" && grep -q '^4\. \*\*Stories\*\*' "$satt/procedures/acceptance.md" \
  && grep -qF 'take `Stories:` from the item it was found under' "$satt/procedures/acceptance.md" || wired="$wired acceptance.md"
grep -q 'stories no item serves' "$satt/procedures/align.md" && grep -q 'feature items with no story' "$satt/procedures/align.md" \
  && grep -q 'bugs with no story' "$satt/procedures/align.md" \
  && grep -q 'stories unconfirmed past the cadence' "$satt/procedures/align.md" \
  && grep -q 'were written from the code on <date>, before the app kept user stories\.' "$satt/procedures/align.md" || wired="$wired align.md"
grep -q 'the stories under `Stories:`' "$satt/procedures/build.md" || wired="$wired build.md"
for f in ui-design drift-reset roadmap; do grep -q '`Stories:`' "$satt/procedures/$f.md" || wired="$wired $f.md"; done
grep -q '^3\. \*\*User stories\.\*\* .*Every one is `unconfirmed`' "$satt/procedures/assess.md" \
  && grep -qF 'The stories under User stories go to `product/user-stories.md`' "$satt/procedures/assess.md" \
  && grep -q '^## User stories$' "$satt/templates/assessment.md" || wired="$wired assess.md/assessment.md"
grep -q '^## User stories$' "$satt/workshops/README.md" && grep -qF -- '- new US-? | changed US-<n> · As a <role>' "$satt/workshops/README.md" \
  && grep -q 'product/user-stories\.md' "$satt/workshops/capabilities.md" || wired="$wired workshops"
grep -qF '"Bash(bash tools/stories.sh --due)",' "$settings" && ! grep -qF '"Bash(bash tools/stories.sh*)"' "$settings" \
  && ! grep -qF '"Bash(bash tools/stories.sh *)"' "$settings" || wired="$wired settings.json"
grep -q 'validate the user stories' "$src/framework/.claude/skills/design/SKILL.md" && grep -q 'user stories' "$src/framework/.claude/skills/align/SKILL.md" \
  && grep -q 'user stories' "$src/framework/.claude/skills/assess/SKILL.md" && grep -q 'user stories' "$src/skills/saas-assessment/SKILL.md" \
  && grep -q 'under User stories' "$src/skills/saas-design-session/SKILL.md" || wired="$wired skills"
grep -q 'product/user-stories\.md' "$src/ONBOARDING.md" && grep -q '`\[stories\] every`' "$src/ONBOARDING.md" \
  && grep -q '^3\. \*\*Draft the first user stories\*\*' "$src/ONBOARDING.md" \
  && grep -q 'were written from the code on <date>, before the app kept user stories\.' "$src/ONBOARDING.md" || wired="$wired ONBOARDING.md"
grep -q 'product/user-stories\.md' "$src/README.md" && grep -q 'tools/stories\.sh' "$src/README.md" && grep -q '/design validate the stories' "$src/README.md" || wired="$wired README.md"
[ -z "$wired" ] && ok "the user stories seed and the example's have their header, sections and roles, and Stories:, the cadence, the PRD, the rules, the procedures, the workshops, the assessment, the settings, the skills and the docs name them" \
  || bad "the user stories aren't wired into:$wired"
# Prototypes: the procedure, the skill and tools/prototype.sh exist and are wired in. rules.md routes the
# procedure and says a prototype session is outside the loop, deploys nowhere and reaches main only through the
# harvest, the item format has Prototype:, the design procedure harvests one, sends what goes against the
# reference architecture to /architect and files nothing without the human, the settings allow the script, the
# hooks know proto/ branches, the guard keeps a prototype from Azure, and the docs name it. The script and the
# hooks run under "prototype".
_pp="$satt/procedures/prototype.md"
wired=""
for file in framework/.satt/procedures/prototype.md framework/.claude/skills/prototype/SKILL.md framework/tools/prototype.sh framework/.githooks/pre-push; do
  [ -f "$src/$file" ] || wired="$wired $file"
done
grep -q 'procedures/prototype\.md' "$src/framework/.claude/skills/prototype/SKILL.md" || wired="$wired SKILL.md"
grep -q '^## Start$' "$_pp" && grep -q '^## In a prototype session$' "$_pp" && grep -q '^## Harvest$' "$_pp" \
  && grep -qF 'bash tools/prototype.sh start <name>' "$_pp" && grep -qF 'bash tools/prototype.sh harvest <name>' "$_pp" \
  && grep -qF 'bash tools/prototype.sh remove <name>' "$_pp" && grep -qF 'bash tools/prototype.sh list' "$_pp" \
  && grep -qF 'git diff main...proto/<name>' "$_pp" && grep -qF 'Never push a `proto/` branch' "$_pp" \
  && grep -qF 'git branch -D proto/<name>' "$_pp" && grep -qF 'Never force it' "$_pp" \
  && grep -q 'Nothing is filed without the human.s answer' "$_pp" && grep -qF 'Commits need no approval' "$_pp" \
  && grep -qF '`ui-design.md` › capture' "$_pp" && grep -q 'Run `design\.md` on them' "$_pp" \
  && grep -qF 'git pull --ff-only' "$_pp" && grep -qF 'start <name> --as-is' "$_pp" \
  && grep -q "ask the human to stop the prototype's app and close its session" "$_pp" && grep -qF 'node_modules' "$_pp" \
  && grep -qF 'bash tools/check.sh --secrets' "$_pp" && grep -qF '`adr/`' "$_pp" && grep -qF '`tools/archcheck.awk`' "$_pp" \
  && [ "$(grep -c 'A capture opens whatever answers at `base_url`' "$_pp")" -ge 2 ] || wired="$wired prototype.md"
grep -qF '**Never deploys.** Not to dev, not to any other Azure environment' "$_pp" \
  && grep -qF 'no `az`, `azd`, `func azure` or `gh workflow run`, which the guard blocks in a prototype session' "$_pp" \
  && grep -qF 'an architecture call for `architect.md` with "comply" first, which ends in an ADR the human accepts' "$_pp" \
  && grep -qF 'to the reference architecture' "$_pp" \
  && grep -qF 'can still call `az` where no text guard sees it' "$_pp" \
  && grep -qF 'git checkout refs/heads/main -- <path>' "$_pp" && grep -qF '`.gitattributes` files' "$_pp" || wired="$wired prototype.md(deploys, architecture, scan files)"
grep -qF 'A prototype session never runs this, for dev either' "$satt/procedures/release.md" || wired="$wired release.md"
grep -qF 'Unlike Record step 5, a drafted story the human doesn' "$satt/procedures/design.md" || wired="$wired design.md(unanswered story)"
grep -qF '**prototype.md:**' "$satt/rules.md" && grep -q '^- \*\*Prototypes\.\*\*' "$satt/rules.md" \
  && grep -q 'That session is outside the loop' "$satt/rules.md" && grep -q 'reaches main only through the harvest' "$satt/rules.md" \
  && grep -qF 'nothing is deployed, to dev either' "$satt/rules.md" || wired="$wired rules.md"
grep -q '^- \*\*`Prototype:`\*\* (optional)\. `proto/<name>`' "$satt/tasks.md" || wired="$wired tasks.md"
grep -q '^## Harvest a prototype$' "$satt/procedures/design.md" && grep -q 'or harvest a prototype (Harvest a prototype, below)' "$satt/procedures/design.md" \
  && grep -qF -- '- Prototype: proto/<name>' "$satt/procedures/design.md" && grep -qF '(prototype: proto/<name>)' "$satt/procedures/design.md" \
  && grep -qF 'Each goes to `architect.md`, with "comply" first, and ends in an ADR that only the human accepts' "$satt/procedures/design.md" \
  && grep -q 'Nothing is filed without the human.s answer' "$satt/procedures/design.md" || wired="$wired design.md"
grep -qF '"Bash(bash tools/prototype.sh *)",' "$settings" || wired="$wired settings.json"
grep -qF 'bash tools/prototype.sh here' "$src/framework/.githooks/pre-commit" && grep -qF 'bash tools/prototype.sh here' "$src/framework/.claude/hooks/stop-check.sh" \
  && grep -qF 'refs/heads/proto/' "$src/framework/.githooks/pre-push" && grep -qF 'pre-commit pre-push' "$src/framework/tools/setup-clone.sh" \
  && grep -qF 'a prototype never deploys' "$src/framework/.claude/hooks/guard-commands.sh" || wired="$wired hooks"
grep -qF 'A session in a checkout that `bash tools/prototype.sh here` calls a prototype (a linked worktree on a `proto/` branch with `PROTOTYPE.md` at its root) is a prototype session: read `prototype.md` › In a prototype session before any work.' "$satt/rules.md" \
  && grep -qF 'git diff main...proto/<name> -- <path>' "$satt/procedures/build.md" || wired="$wired rules.md(prototype session) build.md"
grep -qF '`/prototype {name}`' "$src/README.md" && grep -qF 'tools/prototype.sh' "$src/README.md" && grep -qF '· prototype ·' "$src/README.md" \
  && grep -qF 'pre-push' "$src/README.md" || wired="$wired README.md"
grep -qF '`/prototype`' "$src/ONBOARDING.md" && grep -qF '.githooks/pre-push' "$src/ONBOARDING.md" || wired="$wired ONBOARDING.md"
grep -qF 'Prototypes (`prototype.md`, `/prototype`) aren' "$src/skills/saas-design-session/SKILL.md" && [ ! -e "$src/skills/saas-design-session/references/procedures/prototype.md" ] \
  || wired="$wired saas-design-session"
[ -z "$wired" ] && ok "prototypes: the procedure, the skill and tools/prototype.sh exist, and the rules, the item format, the design procedure, the release, the settings, the hooks and the docs name them" \
  || bad "prototypes aren't wired into:$wired"
# Nothing is written without the human's approval of a summary: rules.md › Who decides has the bullet right after
# the product-call bullet, and accepts an ADR only by the approval of the summary that lists it; design.md holds the
# answers in the conversation, has Summary and approval between For each question and Record each decision in one
# change, and Finish writes what the summary lists; and every procedure that records from a conversation carries the
# pointer: design.md's validation and harvest, research.md, next-task.md, architect.md, integrate.md, assess.md,
# acceptance.md, feedback.md, align.md, drift-reset.md, ui-design.md, roadmap.md, the workshop notes, the design-session skill
# and ONBOARDING.md (Director-Driven-Development T281).
wired=""
_ap_q="'"
_ap_tail='› Summary and approval); a chat message or an "Other" answer before then re-opens the options.'
_ap_ptr='Write nothing until the human approves a summary of all of it (`design.md` '"$_ap_tail"
_ap_ptr_d='Write nothing until the director approves a summary of all of it (`design.md` '"$_ap_tail"
_ap_ptr_o='Write nothing until the human approves a summary of all of it (`.satt/procedures/design.md` '"$_ap_tail"
_ap_ptr_s='Write nothing until the human (in a workshop, the room) approves a summary of all of it (`.satt/procedures/design.md` '"$_ap_tail"
_ap_room='A one-to-one session holds its decisions, stories, open questions, actions and ADR drafts in the conversation, shows them as the summary, and writes the notes file after the human approves it. In a live group workshop the scribe still confirms each decision aloud as the room moves on, and the read-back at the end is the summary the room approves; the notes file is written from it.'
_ap_adr='- **Only the director accepts an ADR.** An ADR is accepted only by the director'"$_ap_q"'s approval of the summary that lists it. The summary names each ADR with its status, and `architect.md` writes the ADR, its exceptions, the TASKS.md items, the AGENTS.md lines and the compliance mapping rows only after that approval. In Claude Code the hook still asks the director to confirm an edit that sets `Status: accepted`.'
_ap_rules="$satt/rules.md"
_ap_dm="$satt/procedures/design.md"
_ap_call="$(grep -n '^- \*\*A product call\*\* is anything a user or customer would notice' "$_ap_rules" | cut -d: -f1)"
_ap_rule="$(grep -n '^- \*\*Nothing is written without the human.s explicit approval\.\*\* While a session runs, the answers stay in the conversation\.' "$_ap_rules" | cut -d: -f1)"
[ -n "$_ap_call" ] && [ -n "$_ap_rule" ] && [ "$_ap_rule" -eq $((_ap_call + 1)) ] \
  && grep -qF 'is a scope change or a modification, not an answer to record: it re-opens the options it touches, and the session reassesses, then restarts or continues.' "$_ap_rules" \
  && grep -qF 'show a summary of every file, line, item, story and ADR status to be written (`design.md` › Summary and approval), and write and commit all of it in one change only after the human approves the summary.' "$_ap_rules" \
  || wired="$wired rules.md(the approval bullet after the product-call bullet)"
grep -qF -- "$_ap_adr" "$_ap_rules" && ! grep -qF 'only when the human has said so in this conversation' "$_ap_rules" || wired="$wired rules.md(the ADR sentence)"
_ap_each="$(grep -n '^## For each question$' "$_ap_dm" | cut -d: -f1)"
_ap_sum="$(grep -n '^## Summary and approval$' "$_ap_dm" | cut -d: -f1)"
_ap_rec="$(grep -n '^## Record each decision in one change$' "$_ap_dm" | cut -d: -f1)"
[ -n "$_ap_each" ] && [ -n "$_ap_sum" ] && [ -n "$_ap_rec" ] && [ "$_ap_each" -lt "$_ap_sum" ] && [ "$_ap_sum" -lt "$_ap_rec" ] \
  || wired="$wired design.md(Summary and approval between For each question and Record)"
grep -qF 'Hold the answer in the conversation: nothing is recorded yet, and an answered part is not recorded by itself.' "$_ap_dm" \
  && ! grep -qF 'record only that part' "$_ap_dm" || wired="$wired design.md(the wait holds the answers)"
grep -qF 'Nothing is written before the human approves it.' "$_ap_dm" && grep -qF 'Approve this summary, or tell me what to change?' "$_ap_dm" \
  && grep -qF 'Only a yes to the summary as shown approves it.' "$_ap_dm" \
  && grep -qF 'each user story with its ID and its Confirmed date, or `unconfirmed`;' "$_ap_dm" \
  && grep -qF 'each ADR with the status it will be written with;' "$_ap_dm" || wired="$wired design.md(the summary's list)"
grep -qF 'Write everything the approved summary lists and commit it as one change, `docs: <summary>`' "$_ap_dm" \
  && grep -qF 'The approval of the summary is the approval to commit (`rules.md` › Git and Azure).' "$_ap_dm" || wired="$wired design.md(Finish)"
[ "$(grep -cF "$_ap_ptr" "$_ap_dm")" -ge 2 ] && grep -qF 'each ADR the architecture step leads to' "$_ap_dm" \
  || wired="$wired design.md(pointers in the validation and the harvest)"
for _ap_f in research.md next-task.md architect.md integrate.md assess.md acceptance.md feedback.md align.md roadmap.md; do
  grep -qF "$_ap_ptr" "$satt/procedures/$_ap_f" || wired="$wired $_ap_f(pointer)"
done
for _ap_f in ui-design.md drift-reset.md; do
  grep -qF "$_ap_ptr_d" "$satt/procedures/$_ap_f" || wired="$wired $_ap_f(pointer)"
done
grep -qF 'Hold the note and the item in the conversation.' "$satt/procedures/research.md" || wired="$wired research.md(holds the note and the item)"
grep -qF 'A product decision: the summary lists its records, as `design.md` lists them.' "$satt/procedures/next-task.md" \
  && grep -qF 'its summary (`architect.md` › Summary and approval)' "$satt/procedures/next-task.md" || wired="$wired next-task.md(blocked)"
_ap_ar="$satt/procedures/architect.md"
_ap_prop="$(grep -n '^## Propose$' "$_ap_ar" | cut -d: -f1)"
_ap_sum="$(grep -n '^## Summary and approval$' "$_ap_ar" | cut -d: -f1)"
_ap_rec="$(grep -n '^## Record$' "$_ap_ar" | cut -d: -f1)"
[ -n "$_ap_prop" ] && [ -n "$_ap_sum" ] && [ -n "$_ap_rec" ] && [ "$_ap_prop" -lt "$_ap_sum" ] && [ "$_ap_sum" -lt "$_ap_rec" ] \
  && grep -qF 'The summary lists the ADR with its status' "$_ap_ar" \
  && grep -qF "An ADR is accepted only by the human${_ap_q}s approval of the summary that lists it." "$_ap_ar" \
  && grep -qF 'In Claude Code the hook still asks the human to confirm an edit that sets `Status: accepted`.' "$_ap_ar" \
  && ! grep -qF 'until the human has said in this conversation' "$_ap_ar" || wired="$wired architect.md(Summary and approval, the ADR sentence)"
grep -qF "Hold each round${_ap_q}s answers in the conversation" "$satt/procedures/integrate.md" \
  && grep -qF -- '- **Summary and approval.** Show one summary of everything this session will write' "$satt/procedures/integrate.md" || wired="$wired integrate.md(the rounds and the summary)"
grep -qF 'the ADR drafts with the status each will be written with' "$satt/procedures/assess.md" \
  || wired="$wired assess.md(the summary's list)"
! grep -qF 'straight away' "$satt/procedures/feedback.md" || wired="$wired feedback.md(straight away)"
grep -qF 'Inside a session the fixes join its summary; during onboarding they are approved at `ONBOARDING.md` › 10' "$satt/procedures/align.md"   && ! grep -qF 'If any are missing, rerun the installer.' "$satt/procedures/align.md" || wired="$wired align.md(the fixes join the summary)"
[ "$(grep -cF "$_ap_ptr_d" "$satt/procedures/drift-reset.md")" -ge 2 ] && grep -q '^## Summary and approval$' "$satt/procedures/drift-reset.md" \
  && grep -qF 'the design diff' "$satt/procedures/drift-reset.md" \
  && grep -qF 'Commit the reset folder and the records as one change, `docs: drift reset YYYY-MM-DD`' "$satt/procedures/drift-reset.md" \
  || wired="$wired drift-reset.md(the summary, the postmortem's and one commit)"
grep -qF 'The summary lists the spec,' "$satt/procedures/ui-design.md" || wired="$wired ui-design.md(the summary's list)"
grep -qF "$_ap_room" "$satt/workshops/README.md" && ! grep -qF 'scribes live into the notes file' "$satt/workshops/README.md" \
  || wired="$wired workshops/README.md(the workshop sentence)"
grep -qF "$_ap_room" "$src/skills/saas-design-session/SKILL.md" && grep -qF "$_ap_ptr_s" "$src/skills/saas-design-session/SKILL.md" \
  && grep -qF 'That read-back is the summary the room approves' "$src/skills/saas-design-session/SKILL.md" || wired="$wired saas-design-session(the workshop sentence and pointer)"
_ap_both="$(grep -n '^### Both$' "$src/ONBOARDING.md" | cut -d: -f1)"
_ap_sum="$(grep -n '^### Summary and approval$' "$src/ONBOARDING.md" | cut -d: -f1)"
[ "$(grep -cF "$_ap_ptr_o" "$src/ONBOARDING.md")" -ge 2 ] && [ -n "$_ap_both" ] && [ -n "$_ap_sum" ] && [ "$_ap_both" -lt "$_ap_sum" ] \
  && grep -qF "An ADR is accepted only by the human${_ap_q}s approval of the summary that lists it, so ADR-1 is accepted by the approval of this summary." "$src/ONBOARDING.md" \
  && ! grep -qF 'since the human just decided' "$src/ONBOARDING.md" || wired="$wired ONBOARDING.md(pointers, Both before Summary and approval, ADR-1)"
grep -q 'once the director approves a summary of them' "$src/framework/.claude/skills/design/SKILL.md" || wired="$wired skills/design/SKILL.md(description)"
[ -z "$wired" ] && ok "nothing is written until the human approves a summary: the rule, the ADR sentence, design.md's Summary and approval, and the pointer in each procedure that records from a conversation" \
  || bad "the approval of a summary isn't wired into:$wired"
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
pw_tool="$(_pw_range "$src/framework/tools/ui/package.json")"
pw_test="$(_pw_range "$src/tests/ui-web/package.json")"
[ "$pw_tool" = "$pw_test" ] \
  && ok "the selftest's Playwright is the version capture asks for" \
  || bad "framework/tools/ui/package.json and tests/ui-web/package.json ask for different Playwright versions"
# One exact version, not a range: no lock file ships, so the pin is what fixes the installed tree (framework/tools/ui/.npmrc).
pw_exact='^[0-9]+\.[0-9]+\.[0-9]+$'
[[ $pw_tool =~ $pw_exact && $pw_test =~ $pw_exact ]] \
  && ok "Playwright is pinned to one exact version in both package.json files (no ^ or ~)" \
  || bad "Playwright is a range in framework/tools/ui/package.json or tests/ui-web/package.json (pin one exact version: no lock file ships)"
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
[ -f .claude/hooks/session-touched.sh ] && grep -q "$(printf '\t').claude/hooks/session-touched.sh$" .satt/manifest \
  && git check-ignore -q .satt/state/sessions/design.touched && git check-ignore -q .satt/state/sessions/design.before \
  && ok "installs the session record hook, and git ignores the records it keeps" || bad "installs the session record hook, and git ignores the records it keeps" "$(cat .gitignore)"
[ -f .claude/hooks/release-check.sh ] && grep -q "$(printf '\t').claude/hooks/release-check.sh$" .satt/manifest && git check-ignore -q .satt/state/latest-release \
  && ok "installs the release check hook, and git ignores the answer it keeps" || bad "installs the release check hook, and git ignores the answer it keeps" "$(cat .gitignore)"
[ -x .claude/hooks/orphan-report.sh ] && grep -q "$(printf '\t').claude/hooks/orphan-report.sh$" .satt/manifest \
  && ok "installs the orphan report hook" || bad "installs the orphan report hook"
grep -q "$(printf '\t')tools/ui/capture.mjs$" .satt/manifest && ! grep -q "$(printf '\t')tools/ui/screens.mjs$" .satt/manifest \
  && ok "the manifest lists the capture tools, not the app's own catalog" || bad "the manifest lists the capture tools, not the app's own catalog"
grep -q "Order Desk" AGENTS.md && ok "keeps the project's own files" || bad "keeps the project's own files"
[ -x tools/stories.sh ] && grep -q "$(printf '\t')tools/stories.sh$" .satt/manifest && grep -q '^# User stories: Order Desk$' product/user-stories.md \
  && ok "installs tools/stories.sh and keeps the app's own user stories" || bad "installs tools/stories.sh and keeps the app's own user stories" "$out"
[ -f .satt/procedures/prototype.md ] && [ -f .claude/skills/prototype/SKILL.md ] && [ -x tools/prototype.sh ] && [ -x .githooks/pre-push ] \
  && grep -q "$(printf '\t')tools/prototype.sh$" .satt/manifest && grep -q "$(printf '\t').githooks/pre-push$" .satt/manifest \
  && ok "installs prototypes: the procedure, the skill, tools/prototype.sh and the pre-push hook" \
  || bad "installs prototypes: the procedure, the skill, tools/prototype.sh and the pre-push hook" "$out"
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
[ -x "$core_only/tools/stories.sh" ] && cmp -s "$core_only/product/user-stories.md" "$stories_seed" \
  && ok "a new app gets tools/stories.sh and the user stories seed, even with --tools none" \
  || bad "a new app gets tools/stories.sh and the user stories seed, even with --tools none" "$out"
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
# The wildcard git rules take any flag, and some git flags write a file (--output), read a file
# outside the repository (--no-index, commit -F and --file) or run a configured command
# (--ext-diff, grep -O and --open-files-in-pager), none of which should run without the human (the
# docs repo's security assessment, product/security/2026-10-29.md, F1, and its item B14). A template
# that allows a wildcard git rule has to carry its deny rules (four for diff, log, show, stash and
# commit; two for grep); the hook's cases (below) cover the rest.
git_deny_missing() { # git_deny_missing <settings file>: the deny rules it lacks, for the wildcard git rules it allows
  local rule allow deny
  allow="$(sed -n '/"allow": *\[/,/\]/p' "$1")"
  deny="$(sed -n '/"deny": *\[/,/\]/p' "$1")"
  if printf '%s\n' "$allow" | grep -qE '"Bash\(git (diff|log|show|stash|commit) \*\)"'; then
    for rule in 'Bash(git *--output*)' 'Bash(git *--no-index*)' 'Bash(git *--ext-diff*)' 'Bash(git commit *--file*)'; do
      printf '%s\n' "$deny" | grep -qF "\"$rule\"" || printf '%s\n' "$rule"
    done
  fi
  if printf '%s\n' "$allow" | grep -qF '"Bash(git grep *)"'; then
    for rule in 'Bash(git grep *--open*)' 'Bash(git grep *-O*)'; do
      printf '%s\n' "$deny" | grep -qF "\"$rule\"" || printf '%s\n' "$rule"
    done
  fi
}
# The credential stores and the secret files: the Read tool may not open the gh CLI's token file, git's
# credentials, ~/.ssh, or a .env, *.pem or *.key file, nor a .env.<suffix> file that holds values (the docs
# repo's item T253 adds the twelve .env.<suffix> rules, which name the common suffixes). Each of these Read
# rules has to be in the deny list, named exactly.
read_deny_missing() { # read_deny_missing <settings file>: the Read rules it doesn't deny
  local rule deny
  deny="$(sed -n '/"deny": *\[/,/\]/p' "$1")"
  for rule in 'Read(~/.ssh/**)' 'Read(~/.git-credentials)' 'Read(~/.config/git/credentials)' \
      'Read(~/.config/gh/**)' 'Read(~/AppData/Roaming/GitHub CLI/**)' \
      'Read(.env)' 'Read(**/.env)' 'Read(*.pem)' 'Read(**/*.pem)' 'Read(*.key)' 'Read(**/*.key)' \
      'Read(.env.local)' 'Read(**/.env.local)' 'Read(.env.*.local)' 'Read(**/.env.*.local)' \
      'Read(.env.development)' 'Read(**/.env.development)' 'Read(.env.production)' 'Read(**/.env.production)' \
      'Read(.env.staging)' 'Read(**/.env.staging)' 'Read(.env.test)' 'Read(**/.env.test)'; do
    printf '%s\n' "$deny" | grep -qF "\"$rule\"" || printf '%s\n' "$rule"
  done
}
if [ ! -f "$settings" ]; then
  bad "the settings template is missing, so its git deny rules can't be checked"
elif [ -n "$(git_deny_missing "$settings")" ]; then
  bad "the settings template allows a wildcard git rule but doesn't deny these (git flags that write or read any file, or run a command):" "$(git_deny_missing "$settings")"
else
  ok "the settings template denies git's file-writing, file-reading and external-command flags next to its wildcard git rules"
fi
if [ ! -f "$settings" ]; then
  bad "the settings template is missing, so its credential-store and secret-file Read rules can't be checked"
elif [ -n "$(read_deny_missing "$settings")" ]; then
  bad "the settings template lets the Read tool open the credential stores (the gh CLI's, git's credentials, ~/.ssh) or the secret files (.env, the .env.<suffix> files with values, *.pem, *.key):" "$(read_deny_missing "$settings")"
else
  ok "the settings template denies the Read tool the gh CLI's, git's and SSH credential stores, and the .env, .env.<suffix>, *.pem and *.key files"
fi
# The check is tested on planted settings, so a change that stops it flagging a missing rule fails here.
git_planted=""
printf '{\n  "permissions": {\n    "allow": [\n      "Bash(git diff *)"\n    ],\n    "deny": [\n      "Read(.env)"\n    ]\n  }\n}\n' > "$work/git-deny-none.json"
[ "$(git_deny_missing "$work/git-deny-none.json" | wc -l | tr -d ' ')" = 4 ] || git_planted="$git_planted none"
for git_rule in 'git log' 'git show' 'git stash' 'git commit'; do
  printf '{\n  "permissions": {\n    "allow": [\n      "Bash(%s *)"\n    ],\n    "deny": [\n      "Bash(git *--output*)"\n    ]\n  }\n}\n' \
    "$git_rule" > "$work/git-deny-one.json"
  [ "$(git_deny_missing "$work/git-deny-one.json" | wc -l | tr -d ' ')" = 3 ] || git_planted="$git_planted $git_rule"
done
printf '{\n  "permissions": {\n    "allow": [\n      "Bash(git status)",\n      "Bash(git add *)"\n    ]\n  }\n}\n' > "$work/git-deny-no-wildcard.json"
[ -z "$(git_deny_missing "$work/git-deny-no-wildcard.json")" ] || git_planted="$git_planted no-wildcard"
printf '{\n  "permissions": {\n    "allow": [\n      "Bash(git grep *)"\n    ],\n    "deny": [\n      "Bash(git *--output*)"\n    ]\n  }\n}\n' > "$work/git-deny-grep.json"
[ "$(git_deny_missing "$work/git-deny-grep.json" | wc -l | tr -d ' ')" = 2 ] || git_planted="$git_planted grep"
printf '{\n  "permissions": {\n    "allow": [\n      "Bash(git grep *)"\n    ],\n    "deny": [\n      "Bash(git grep *--open*)"\n    ]\n  }\n}\n' > "$work/git-deny-grep-one.json"
[ "$(git_deny_missing "$work/git-deny-grep-one.json")" = 'Bash(git grep *-O*)' ] || git_planted="$git_planted grep-one"
printf '{\n  "permissions": {\n    "allow": [\n      "Bash(git grep *)"\n    ],\n    "deny": [\n      "Bash(git grep *--open*)",\n      "Bash(git grep *-O*)"\n    ]\n  }\n}\n' > "$work/git-deny-grep-all.json"
[ -z "$(git_deny_missing "$work/git-deny-grep-all.json")" ] || git_planted="$git_planted grep-all"
[ -z "$git_planted" ] && ok "the git deny check flags each missing deny rule, and passes settings with no wildcard git rule" \
  || bad "the git deny check misses a planted case:$git_planted"
# The same for the Read rules, on planted settings.
read_planted=""
printf '{\n  "permissions": {\n    "allow": [\n      "Bash(git status)"\n    ]\n  }\n}\n' > "$work/read-deny-none.json"
[ "$(read_deny_missing "$work/read-deny-none.json" | wc -l | tr -d ' ')" = 23 ] || read_planted="$read_planted none"
printf '{\n  "permissions": {\n    "deny": [\n      "Read(~/.ssh/**)",\n      "Read(~/.git-credentials)",\n      "Read(~/.config/git/credentials)",\n      "Read(~/.config/gh/**)",\n      "Read(.env)",\n      "Read(**/.env)",\n      "Read(.env.local)",\n      "Read(**/.env.local)",\n      "Read(.env.*.local)",\n      "Read(**/.env.*.local)",\n      "Read(.env.development)",\n      "Read(**/.env.development)",\n      "Read(.env.production)",\n      "Read(**/.env.production)",\n      "Read(.env.staging)",\n      "Read(**/.env.staging)",\n      "Read(.env.test)",\n      "Read(**/.env.test)",\n      "Read(*.pem)",\n      "Read(**/*.pem)",\n      "Read(*.key)",\n      "Read(**/*.key)"\n    ]\n  }\n}\n' > "$work/read-deny-four.json"
[ "$(read_deny_missing "$work/read-deny-four.json")" = 'Read(~/AppData/Roaming/GitHub CLI/**)' ] || read_planted="$read_planted four"
printf '{\n  "permissions": {\n    "deny": [\n      "Read(~/.ssh/**)",\n      "Read(~/.git-credentials)",\n      "Read(~/.config/git/credentials)",\n      "Read(~/.config/gh/**)",\n      "Read(~/AppData/Roaming/GitHub CLI/**)",\n      "Read(.env)",\n      "Read(**/.env)",\n      "Read(.env.local)",\n      "Read(**/.env.local)",\n      "Read(.env.*.local)",\n      "Read(**/.env.*.local)",\n      "Read(.env.development)",\n      "Read(**/.env.development)",\n      "Read(.env.production)",\n      "Read(**/.env.production)",\n      "Read(.env.staging)",\n      "Read(**/.env.staging)",\n      "Read(.env.test)",\n      "Read(**/.env.test)",\n      "Read(*.pem)",\n      "Read(**/*.pem)",\n      "Read(*.key)",\n      "Read(**/*.key)"\n    ]\n  }\n}\n' > "$work/read-deny-all.json"
[ -z "$(read_deny_missing "$work/read-deny-all.json")" ] || read_planted="$read_planted all"
# A secret file written in a shorter form doesn't count: this one lacks Read(**/*.pem) and nothing else.
printf '{\n  "permissions": {\n    "deny": [\n      "Read(~/.ssh/**)",\n      "Read(~/.git-credentials)",\n      "Read(~/.config/git/credentials)",\n      "Read(~/.config/gh/**)",\n      "Read(~/AppData/Roaming/GitHub CLI/**)",\n      "Read(.env)",\n      "Read(**/.env)",\n      "Read(.env.local)",\n      "Read(**/.env.local)",\n      "Read(.env.*.local)",\n      "Read(**/.env.*.local)",\n      "Read(.env.development)",\n      "Read(**/.env.development)",\n      "Read(.env.production)",\n      "Read(**/.env.production)",\n      "Read(.env.staging)",\n      "Read(**/.env.staging)",\n      "Read(.env.test)",\n      "Read(**/.env.test)",\n      "Read(*.pem)",\n      "Read(*.key)",\n      "Read(**/*.key)"\n    ]\n  }\n}\n' > "$work/read-deny-no-recursive-pem.json"
[ "$(read_deny_missing "$work/read-deny-no-recursive-pem.json")" = 'Read(**/*.pem)' ] || read_planted="$read_planted recursive-pem"
[ -z "$read_planted" ] && ok "the Read deny check flags each missing credential-store and secret-file rule, and passes settings that deny all twenty-three" \
  || bad "the Read deny check misses a planted case:$read_planted"
guard_dir="$work/guard-cases"; mkdir -p "$guard_dir"
git_fail=""
guard_report() { # guard_report <failed cases> <what is wrong> <what holds>: one line for a block of cases, and the failed ones under it
  if [ -n "$1" ]; then
    bad "$2"
    printf '%s\n' "${1#$'\n'}" | sed 's/^/          /'
  else ok "$3"; fi
  git_fail=""
}
# json_str <text>: sets JSON_STR to the text as the inside of a JSON string, with \, ", a line break, a tab and a return escaped. (A ${//}
# replacement left a backslash single and turned a line break into n, so a newline case reached the guard as a joined word.)
json_str() {
  local s="$1" out="" i c
  for ((i = 0; i < ${#s}; i++)); do
    c="${s:i:1}"
    case $c in
      '\') out+='\\' ;;
      '"') out+='\"' ;;
      $'\n') out+='\n' ;;
      $'\t') out+='\t' ;;
      $'\r') out+='\r' ;;
      *) out+="$c" ;;
    esac
  done
  JSON_STR="$out"
}
# The guard cases (Director-Driven-Development B41). guard queues a case: its JSON payload goes to a file, and its expected
# exit code, tool and text are kept. guard_run runs the queued cases, guard_jobs at a time, each as its own run of the hook
# with its own payload, then checks every exit code against that case's expected one, in the order the cases were queued,
# so a failure names its case and why. Each block of cases ends with guard_run and guard_report. A case may name a word its
# message must hold (the fourth argument, matched in any case), so a block that exits 2 is shown to be blocked by its own rule.
guard_jobs=$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4); [ "$guard_jobs" -le 8 ] || guard_jobs=8
guard_cmds=(); guard_exps=(); guard_tools=(); guard_pats=()
guard() { # guard <expected-exit> <command> [tool name: Bash by default, or PowerShell] [a word the hook's message must hold]
  local n=${#guard_cmds[@]} tool="${3:-Bash}"
  json_str "$2"
  printf '{"session_id":"s","tool_name":"%s","tool_input":{"command":"%s","description":"run"}}' "$tool" "$JSON_STR" > "$guard_dir/$n.json"
  guard_cmds+=("$2"); guard_exps+=("$1"); guard_tools+=("$tool"); guard_pats+=("${4:-}")
}
guard_run() {
  local n=${#guard_cmds[@]} first i k
  local -a pid=() rc=()
  for ((first = 0; first < n; first += guard_jobs)); do
    for ((k = 0; k < guard_jobs && first + k < n; k++)); do
      bash .claude/hooks/guard-commands.sh < "$guard_dir/$((first + k)).json" >/dev/null 2>"$guard_dir/$((first + k)).err" &
      pid[k]=$!
    done
    for ((k = 0; k < guard_jobs && first + k < n; k++)); do
      wait "${pid[k]}"; rc[first + k]=$?
    done
  done
  for ((i = 0; i < n; i++)); do
    if [ "${rc[i]}" -ne "${guard_exps[i]}" ]; then
      git_fail="$git_fail"$'\n'"  guard exited ${rc[i]}, expected ${guard_exps[i]} (${guard_tools[i]}): ${guard_cmds[i]//$'\n'/ NL }"
    elif [ -n "${guard_pats[i]}" ] && ! grep -qi -- "${guard_pats[i]}" "$guard_dir/$i.err"; then
      git_fail="$git_fail"$'\n'"  guard's message doesn't name ${guard_pats[i]} (${guard_tools[i]}): ${guard_cmds[i]//$'\n'/ NL }"
    fi
  done
  guard_cmds=(); guard_exps=(); guard_tools=(); guard_pats=()
  rm -f "$guard_dir"/*.json "$guard_dir"/*.err
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
guard_run
guard_report "$git_fail" "the guard hook doesn't block every destructive git command, Azure delete, complete-mode deployment, Key Vault secret read and client secret, or it blocks a plain form" "the guard hook blocks a destructive git command, an Azure delete, a complete-mode deployment, a Key Vault secret read and a client secret, and passes the plain forms"
# The wildcard git allow rules (`git diff *`, `git log *`, `git show *`, `git commit *`, `git grep *`)
# take any flag, and some flags write a file (--output), read a file outside the repository
# (--no-index, commit -F and --file, a `git diff` of a path outside it) or run a configured command
# (--ext-diff; grep -O, which runs its argument as the pager), with no prompt. The hook reads the
# command as the shell hands it to git, so a flag that is quoted, escaped, attached to a short option
# or hidden behind another command is still seen, and a flag named inside a commit message or a
# heredoc body is not. The deny rules in settings.json cover the plain forms; the hook covers the
# rest: commit -F, where a rule can't tell `-F <path>` from `-F -`, and grep's pager flag in its short,
# combined and abbreviated spellings (the docs repo's security assessment,
# product/security/2026-10-29.md, F1, and its item B14).
for cmd in \
    'git log -1 --format=probe --output=/tmp/probe.txt' \
    'git log --output /tmp/probe.txt' \
    'git show --output /tmp/probe.txt HEAD' \
    'git diff --output=probe.txt' \
    'git stash show --output=/tmp/probe.txt' \
    "git log '--output=/tmp/probe.txt'" \
    'git log "--no-index"' \
    'git log --out\put=/tmp/probe.txt' \
    'git log --output="/tmp/my probe.txt"' \
    'git diff --no-index a b' \
    'git diff --no-index /dev/null /etc/hosts' \
    'git log -p --ext-diff' \
    'git diff --ext-diff' \
    'git diff /etc/hosts README.md' \
    'git diff ../other.txt README.md' \
    'git commit -F /tmp/msg.txt' \
    'git commit -F/tmp/msg.txt' \
    'git commit -aF /tmp/msg.txt' \
    'git commit -F "/tmp/my msg.txt"' \
    'git commit --file /tmp/msg.txt' \
    'git commit --file=/tmp/msg.txt' \
    'git commit -F - -F /tmp/msg.txt' \
    'git add -A && git commit -F /tmp/msg.txt' \
    'git -C work/SaaSAllTheThings log --output=/tmp/probe.txt' \
    $'git commit -q -F - <<\'EOF\'\nmsg\nEOF\ngit log --output=/tmp/probe.txt' \
    'git grep -O foo' \
    'git grep -Oecho foo' \
    'git grep -n -Ovim foo' \
    'git grep -iO foo' \
    'git grep -nOvim foo' \
    'git grep -e foo -Oecho' \
    'git grep -A 1 -Oecho foo' \
    'git grep --open-files-in-pager foo' \
    'git grep --open-files-in-pager=echo foo' \
    'git grep --open=echo foo' \
    'git grep --op foo' \
    'git grep "-Obj"' \
    "git grep '-Oecho' foo" \
    'git grep -nO"echo hi" foo' \
    'git grep --"open-files-in-pager"=echo foo' \
    'git -C work/SaaSAllTheThings grep -Oecho foo' \
    'git add . && git grep -Oecho foo'; do
  guard 2 "$cmd"
done
for cmd in \
    'git log --oneline -5' \
    'git diff HEAD' \
    'git diff --cached --stat' \
    'git diff origin/main..HEAD -- docs/index.md' \
    'git show HEAD:README.md' \
    'git commit -m "fix the --output handling"' \
    'git commit -F -' \
    'git commit --file=-' \
    $'git commit -q -F - <<\'EOF\'\nfix the --output and --no-index handling, not -F /tmp/x\nEOF' \
    'git stash list' \
    'git worktree list' \
    'git grep -n foo' \
    "git grep -i -e x -- '*.md'" \
    'git grep -ie -O' \
    'git grep -e -Oecho' \
    'git grep -n "an -Obj pattern"' \
    'git grep -c --no-open-files-in-pager foo' \
    'git grep --only-matching foo' \
    'git log --grep -O'; do
  guard 0 "$cmd"
done
guard_run
guard_report "$git_fail" "the guard hook doesn't block every git flag that writes a file, reads outside the repository or runs a configured command, or it blocks a plain form" "the guard hook blocks the git flags that write a file, read outside the repository or run a configured command, and passes the plain forms"
# The credential stores: ~/.ssh, git's credentials files and the gh CLI's hosts.yml, read by the shell
# in any spelling of the path (the Read tool is denied them in settings.json), and the commands that
# print a stored credential (the docs repo's item B15).
for cmd in \
    'cat ~/.ssh/id_ed25519' \
    'head "$HOME/.git-credentials"' \
    'cat ~/.config/gh/hosts.yml' \
    'less "/c/Users/V/AppData/Roaming/GitHub CLI/hosts.yml"' \
    'cat "C:\Users\V\.ssh\id_rsa"' \
    'tail -n 5 ${HOME}/.config/git/credentials' \
    'cd ~ && strings .ssh/known_hosts' \
    'gh auth token' \
    'gh auth status -t' \
    'gh auth status --show-token' \
    "printf 'protocol=https\\nhost=github.com\\n' | git credential fill" \
    "printf 'protocol=https\\nhost=github.com\\n' | git credential get"; do
  guard 2 "$cmd"
done
for cmd in \
    'cat README.md' \
    'cat docs/how-to/where.md' \
    'grep -n ssh docs/how-to/trouble.md' \
    'git log --oneline -3' \
    'ls ~/.ssh' \
    'gh auth status' \
    'git commit -m "docs: gh auth token prints the stored token"'; do
  guard 0 "$cmd"
done
# The secret files: .env, *.pem and *.key read by the shell, relative, from a folder or quoted (the docs
# repo's item T248, as App-Director's guard blocks them). Names that only look like one pass. The .env.<suffix>
# files that hold values are blocked too (the docs repo's item T253), and the committed templates pass.
for cmd in \
    'cat .env' \
    'head ./.env' \
    'cat "certs/server.pem"' \
    'less deploy.key' \
    "head '.env'" \
    'tail -n 5 config/.env' \
    'cat "deploy keys/prod.key"' \
    'strings "C:\certs\server.pem"' \
    'cat .env.local' \
    'head ./.env.production' \
    'cat "config/.env.staging"' \
    'less .env.development.local' \
    "tail '.env.test'" \
    'tail -n 20 .env.local' \
    'cat .env.example .env.local' \
    'cat .env.example; cat .env.local'; do
  guard 2 "$cmd"
done
for cmd in \
    'cat .env.example' \
    'cat README.md' \
    'cat docs/keys.md' \
    'ls .env' \
    'cat x.env' \
    'cat config/.env.sample' \
    'head .env.template' \
    'cat .env.dist' \
    'ls .env.local'; do
  guard 0 "$cmd"
done
guard_run
guard_report "$git_fail" "the guard hook doesn't block every shell read of a credential store or a secret file, or it blocks an ordinary read" "the guard hook blocks shell reads of the credential stores and the secret files, and the commands that print a stored credential, and passes the templates and ordinary reads"

# A quoted or split no-verify (the docs repo's item B26, as App-Director's guard blocks them): the test runs on the words
# after their quotes are resolved, so '-n', "-n", -""n and --no-ve''rify skip the check as -n and --no-verify do. The
# -- that ends the options stops it, so a -n after it is a pathspec and passes.
for cmd in "git commit '-n' -m x" 'git commit "-n" -m x' 'git commit -""n -m x' "git commit --no-ve''rify -m x" \
    "git commit --no-'verify' -m x" 'git commit -m x --no-ve"rify"' "git commit -'n' -m x" \
    "git commit '-nm' x" 'git commit -m x "-n"'; do
  guard 2 "$cmd"
done
for cmd in "git commit -m x -- '-n'" "git commit -m 'fix: the -n flag' -- a.cs"; do
  guard 0 "$cmd"
done

# Prototypes (.satt/procedures/prototype.md): the harvest removes a worktree, never forced, and leaves deleting
# the branch to the human, so the guard blocks every spelling of what discards a worktree's changes or a
# branch's commits, or overwrites a branch: worktree remove with a force (-f, a cluster with f, --force from its
# first three characters), worktree add -B, -f and --force, branch -D, -d with a force, -M, -C, and -m or -c with
# a force. An unquoted brace expansion or $IFS in a git command could spell such a flag past it, so they are
# blocked too, while git's own @{...} passes; the global options that take a value are read past.
for cmd in \
    'git branch -D proto/quick-add' \
    'git worktree remove --force ../app-proto-quick-add' \
    'git worktree remove --forc ../x' \
    'git worktree remove --f ../x' \
    "git worktree remove '--force' ../x" \
    'git worktree remove ../app-proto-quick-add -f' \
    'git worktree remove -ff ../x' \
    'git -C ../app worktree remove --fo ../x' \
    'git branch -d -f proto/quick-add' \
    'git branch --delete --force proto/quick-add' \
    'git branch --del --forc proto/quick-add' \
    'git branch -df proto/quick-add' \
    'git branch -qD proto/quick-add' \
    'git worktree remove --{force,} x' \
    'git worktree remove -{f,f} x' \
    'git worktree remove x$IFS--force' \
    'git worktree remove x${IFS}--force' \
    'git branch -{D,} x' \
    'git branch -{d..f} x' \
    'git --git-dir .git worktree remove --forc x' \
    'git --work-tree . branch -df x' \
    'git --config-env x=Y worktree remove -f x' \
    'git branch -M a b' \
    'git branch -C a b' \
    'git branch -m -f a b' \
    'git branch --move --force a b' \
    'git branch -cf a b' \
    'git worktree add -B proto/x ../x main' \
    'git worktree add -f ../x proto/x' \
    'git worktree add --forc ../x proto/x'; do
  guard 2 "$cmd"
done
for cmd in \
    'git worktree add --no-track -b proto/quick-add ../app-proto-quick-add main' \
    'git worktree remove ../app-proto-quick-add' \
    'git worktree list' \
    'git branch -d proto/quick-add' \
    'git branch -f topic main' \
    'git branch -uorigin/feature-dev' \
    'git commit -m "git branch -d -f x"' \
    'git log HEAD@{1}' \
    'git log --oneline @{u}..HEAD' \
    'git diff stash@{0}' \
    'git branch -m old new' \
    'git branch -c old new' \
    'git commit -m "a {b,c} message"' \
    'bash tools/prototype.sh start quick-add' \
    'bash tools/prototype.sh remove quick-add'; do
  guard 0 "$cmd"
done
# A command that starts a later line, tab-indented or not, is a command of its own. The command arrives
# JSON-escaped, so its first letter follows the n or t of \n or \t, and a rule that wants a word boundary before
# git, az or azd must read the line break as a separator (the first line must not hide it).
for cmd in \
    $'cd x\ngit branch -D y' \
    $'cd x\n\tgit branch -D y' \
    $'echo hi\ngit push origin main --force' \
    $'echo hi\n\tgit commit -m x --no-verify' \
    $'cd x\ngit worktree remove --force y' \
    $'cd x\ngit log --output=/tmp/probe.txt' \
    $'cd x\nazd down --purge' \
    $'cd x\n\taz group delete -n rg --yes' \
    $'cd x\n\naz keyvault secret show --vault-name kv --name db' \
    '/usr/bin/git branch -D y'; do
  guard 2 "$cmd"
done
for cmd in \
    $'cd x\ngit branch -d y' \
    $'cd x\n\tgit status' \
    $'git add a.md\ngit commit -m "docs: a note" -- a.md' \
    $'cd x\nls' \
    $'cd x\naz account show'; do
  guard 0 "$cmd"
done
guard_run
guard_report "$git_fail" "the guard hook doesn't block every quoted no-verify, prototype branch rule or command on a later line, or it blocks a plain form" "the guard hook blocks a quoted or split no-verify, the prototype branch and worktree rules, and a command on a later line, and passes the plain forms"

# Hangs: Python that reads its script from a heredoc (T309: with a body or without), a polling loop without a limit, a lone long sleep.
nlc=$'\n'
for cmd in "python3 - <<'EOF' 2>/dev/null || echo \"no python\"${nlc}EOF" "python3 - <<EOF${nlc}EOF" \
    "py.exe - <<'PY'${nlc}PY" "python3 - <<'EOF' 2>/dev/null || python - <<'EOF2'${nlc}EOF${nlc}x${nlc}EOF2" \
    "cd x && /usr/bin/python3 - <<'EOF'${nlc}EOF" "python3 - <<'EOF'${nlc}EOF${nlc}echo after" \
    "python - <<-'EOF'${nlc}${nlc}EOF" "python3 - <<'EOF'${nlc}print(1)${nlc}EOF" "python3 - <<EOF 2>/dev/null || echo no${nlc}import sys${nlc}EOF"; do
  guard 2 "$cmd" Bash python
  guard 2 "$cmd" PowerShell python
done
for cmd in \
    'until grep -q "^exit" /tmp/t/tasks/b1.output; do sleep 5; done' 'while true; do sleep 10; done' \
    'until [ -f done.flag ]; do sleep 2; done' 'timeout 900 bash -c "until [ -f f ]; do sleep 2; done"' \
    "timeout 300 bash -c 'until [ -f f ]; do sleep 2; done'" 'timeout 5m bash -c "while sleep 1; do :; done"' \
    'timeout 0 bash -c "until [ -f f ]; do sleep 2; done"' 'while ! grep -q ok /tmp/t/tasks/b1.output; do sleep 3; done' \
    'sleep 300' 'sleep 5m' 'echo hi && sleep 1h' 'sleep 281'; do
  guard 2 "$cmd"
done
for cmd in 'python3 --version' \
    "python3 -c 'print(1)'" 'timeout 240 bash -c "until [ -f f ]; do sleep 2; done"' \
    "(timeout 240s bash -c 'while [ ! -f f ]; do sleep 2; done')" 'cd x && timeout 4m bash -c "until [ -f f ]; do sleep 2; done"' \
    'timeout -k 5 280 bash -c "until [ -f f ]; do sleep 2; done"' \
    'until grep -q "exited with code" /tmp/t/tasks/b1.output; do sleep 5; done' \
    'until grep -qE "exited with code|\[killed\]" /tmp/t/tasks/b1.output; do sleep 5; done' \
    'sleep 5' 'sleep 280' 'sleep 4m' 'sleep 0.5' 'echo "wait: sleep 600"' 'git commit -m "no until loop with sleep" -- a.md' \
    'while read -r l; do echo "$l"; done < f'; do
  guard 0 "$cmd"
done
guard_run
guard_report "$git_fail" "the guard hook doesn't block every hang, or it blocks a bounded wait" "the guard hook blocks Python reading its script from a heredoc, a polling loop without a limit and a long sleep, and passes the bounded forms"
grep -q 'run_in_background' .satt/rules.md && grep -q 'Never feed Python its script from a heredoc' .satt/rules.md && grep -q 'time limit under five minutes' .satt/rules.md \
  && ok "rules.md names the time limit, run_in_background and the Python heredoc" || bad "rules.md says: time limits, run_in_background, never feed Python its script from a heredoc"

# The hook runs under macOS's bash 3.2 too (.claude/CLAUDE.md > Scripts), so it holds no bash 4 form: case conversion (${x,,}, ${x^^}),
# an associative array, mapfile or readarray, coproc, |&, or a negative substring offset (${x: -1}). Comment lines are skipped.
bash4=$(grep -nE '^[^#]*(\$\{[A-Za-z_0-9]+(\[[^]]*\])?(,,|\^\^)\}|(declare|local|typeset) +-[a-zA-Z]*A|(^|[;&| ])(mapfile|readarray) +|(^|[;&| ])coproc +[A-Za-z]|[[:space:]]\|&[[:space:]]|\$\{[A-Za-z_0-9@*]+(\[[^]]*\])?: -[0-9])' .claude/hooks/guard-commands.sh || true)
if [ -z "$bash4" ]; then ok "the guard hook uses no bash 4 form, so it runs under bash 3.2"
else bad "the guard hook uses a bash 4 form (bash 3.2 on macOS has none)" "$bash4"; fi
# bash 3.2 keeps the quotes of a quoted replacement string (${t//x/"$y"}), so the hook replaces text with str_swap, which quotes none.
bash43=$(grep -nE '^[^#]*\$\{[A-Za-z_0-9]+(\[[^]]*\])?//?("[^"]*"|[^/"}]+)/"' .claude/hooks/guard-commands.sh || true)
if [ -z "$bash43" ]; then ok "the guard hook quotes no replacement string, which bash 3.2 would keep"
else bad "the guard hook quotes a replacement string (bash 3.2 keeps the quotes)" "$bash43"; fi

# The guard starts no other process (it runs on every Bash, Monitor and PowerShell call, and a process start is slow on Windows). With no
# PATH only a builtin can run, so "command not found" in its output names a process it tried to start. A spread of the cases that
# reach most of its rules (credential reads, wrappers, substitutions, loops, heredocs, git flags, Azure) is run that way.
nopath_fail=""
for cmd in \
    'git push origin main --force' 'git commit -m x --no-verify' $'git commit -q -F - <<\'EOF\'\nmsg\nEOF' 'git log --output=/tmp/x' \
    'git -c core.pager=x log' 'git branch -df x' 'git worktree remove --force x' 'GIT=git; $GIT push --force' \
    'cat .env.local' 'cat ~/.ssh/id_rsa' 'Get-Content .env' 'gh auth token' 'bash -c "git push --force"' 'eval "cat .env"' \
    'echo $(git push --force)' 'git push "$(echo --force)"' $'git commit \\\n-n -m x' $'# note\\\ngit push --force' \
    'until test -f x; do sleep 1; done' 'sleep 300' 'for ((i=0;i<9;i++)); do sleep 1; done' $'python3 - <<\'EOF\'\nEOF' \
    'until [ -f done ]; do sleep 5; done' 'sleep 600.5' $'$gd = @\'\nx\n\'@\nSet-Content x.gd -Value $gd' \
    'azd down' 'az group delete -n rg' 'az keyvault secret show --name x' 'bash -c "az group delete -n rg"' 'echo $(az ad sp credential reset --id 1)' \
    'Invoke-Expression "git push --force"' 'bash tools/../x.sh' $'cat <<EOF | bash\ngit push --force\nEOF' 'git status' 'ls'; do
  json_str "$cmd"
  for tool in Bash PowerShell; do
    printf '{"session_id":"s","tool_name":"%s","tool_input":{"command":"%s","description":"run"}}' "$tool" "$JSON_STR" > "$guard_dir/nopath.json"
    err=$(PATH=/nonexistent "$BASH" .claude/hooks/guard-commands.sh < "$guard_dir/nopath.json" 2>&1 >/dev/null)
    case $err in *"command not found"*) nopath_fail="$nopath_fail"$'\n'"  ($tool) ${cmd//$'\n'/ NL }: ${err//$'\n'/ | }" ;; esac
  done
done
rm -f "$guard_dir/nopath.json"
guard_report "$nopath_fail" "the guard starts another process" "the guard starts no other process"

# The guard's reading of a command, case by case (Director-Driven-Development T276; the B numbers are its bug IDs): the PowerShell
# tool, the readers of credential files, continuations (a backslash in Bash, a backtick in PowerShell, and the comments
# that end in one), tabs, command substitutions, variables, shell wrappers, wait loops, heredoc bodies, git configuration
# and program flags, quoted and capitalised names, and Invoke-Expression.
if [ ! -f .claude/settings.json ]; then
  bad ".claude/settings.json is missing, so the guard's wiring can't be checked"
else
  git_fail=""
  perm_allow=$(sed -n '/"allow": *\[/,/\]/p' .claude/settings.json)
  if [ ! -f .claude/hooks/guard-commands.sh ]; then
    git_fail="$git_fail"$'\n'"  .claude/hooks/guard-commands.sh is missing"
  else
    for cmd in \
        'git log -1 --format=probe --output=/tmp/probe.txt' \
        'git log --output /tmp/probe.txt' \
        'git show --output /tmp/probe.txt HEAD' \
        'git diff --output=probe.txt' \
        'git stash show --output=/tmp/probe.txt' \
        "git log '--output=/tmp/probe.txt'" \
        'git log "--no-index"' \
        'git log --out\put=/tmp/probe.txt' \
        'git log --output="/tmp/my probe.txt"' \
        'git diff --no-index a b' \
        'git diff --no-index /dev/null /etc/hosts' \
        'git log -p --ext-diff' \
        'git diff --ext-diff' \
        'git diff /etc/hosts README.md' \
        'git diff ../other.txt README.md' \
        'git commit -F /tmp/msg.txt' \
        'git commit -F/tmp/msg.txt' \
        'git commit -aF /tmp/msg.txt' \
        'git commit -F "/tmp/my msg.txt"' \
        'git commit --file /tmp/msg.txt' \
        'git commit --file=/tmp/msg.txt' \
        'git commit -F - -F /tmp/msg.txt' \
        'git add -A && git commit -F /tmp/msg.txt' \
        'git -C work/SaaSAllTheThings log --output=/tmp/probe.txt' \
        $'git commit -q -F - <<\'EOF\'\nmsg\nEOF\ngit log --output=/tmp/probe.txt' \
        'git grep -O foo' \
        'git grep -Oecho foo' \
        'git grep -n -Ovim foo' \
        'git grep -iO foo' \
        'git grep -nOvim foo' \
        'git grep -e foo -Oecho' \
        'git grep -A 1 -Oecho foo' \
        'git grep --open-files-in-pager foo' \
        'git grep --open-files-in-pager=echo foo' \
        'git grep --open=echo foo' \
        'git grep --op foo' \
        'git grep "-Obj"' \
        "git grep '-Oecho' foo" \
        'git grep -nO"echo hi" foo' \
        'git grep --"open-files-in-pager"=echo foo' \
        'git -C work/SaaSAllTheThings grep -Oecho foo' \
        'git add . && git grep -Oecho foo' \
        'git tag -F /tmp/msg.txt v1' \
        'git tag -aF /tmp/msg.txt v1' \
        'git tag -a v1 -F/tmp/msg.txt' \
        'git tag -a v1 --file=/tmp/msg.txt' \
        'git tag --file /tmp/msg.txt v1' \
        'git tag --fi=/tmp/msg.txt v1' \
        'bash tools/stacks/../../x.sh' \
        'bash -x tools/stacks/../x.sh' \
        'bash tools/stacks/.\./x.sh' \
        'bash tools/stacks/".."/x.sh' \
        'sh ./tools/../x.sh' \
        '/bin/bash tools/stacks/../x.sh' \
        'cat ~/.ssh/id_ed25519' \
        'head "$HOME/.git-credentials"' \
        'cat ~/.config/gh/hosts.yml' \
        'less "/c/Users/V/AppData/Roaming/GitHub CLI/hosts.yml"' \
        'cat "C:\Users\V\.ssh\id_rsa"' \
        'cat "certs/server.pem"' \
        "head '.env'" \
        'cat .env.local' \
        'head ./.env.production' \
        'cat "config/.env.staging"' \
        'less .env.development.local' \
        "tail '.env.test'" \
        'tail -n 20 .env.local' \
        'cat .env.example; cat .env.local' \
        'cat README.md .env.local' \
        'tail -n 20 .env' \
        'head -5 certs/server.pem' \
        'cat docs/a.md "deploy.key"' \
        'less -R .env.production' \
        'gh auth token' \
        'gh auth status -t' \
        "printf 'protocol=https\\nhost=github.com\\n' | git credential fill" \
        "printf 'protocol=https\\nhost=github.com\\n' | git credential get" \
        $'cd x\ngit branch -D y' \
        $'cd x\ngit commit --no-verify -m x' \
        $'cd x\n\tgit log --output=/tmp/x' \
        $'echo a\ngit push --force' \
        $'cd x\ngit commit -F /tmp/msg.txt' \
        $'cd x\ngit credential fill' \
        $'echo x\nbash tools/stacks/../x.sh' \
        "git commit '-n' -m x" \
        'git commit "-n" -m x' \
        'git commit -""n -m x' \
        "git commit --no-ve''rify -m x" \
        "git commit -m -- '-n'" \
        $'git commit \\\n-n -m x' \
        $'git push \\\n--force' \
        $'git push origin \\\n+main' \
        $'git reset \\\n--hard' \
        $'git credential \\\nfill' \
        $'git log \\\n--output=/tmp/probe.txt' \
        $'cat \\\n.env.local' \
        $'cat README.md \\\n.env.local' \
        $'cat\t.env.local' \
        $'head\t-n\t20\t.env' \
        $'git\tpush --force' \
        $'git\tcommit -n -m x' \
        $'git\tlog --output=/tmp/probe.txt' \
        $'echo a\\\\\ngit push --force' \
        $'echo a\\\\\ngit commit -F /tmp/msg.txt' \
        $'sleep \\\n300'; do
      guard 2 "$cmd"
    done
    for cmd in \
        'git log --oneline -5' \
        'git diff HEAD' \
        'git diff --cached --stat' \
        'git diff origin/main..HEAD -- docs/index.md' \
        'git show HEAD:README.md' \
        'git commit -m "fix the --output handling"' \
        'git commit -m x -- docs/index.md' \
        "git commit -m x -- '-n'" \
        'git commit -F -' \
        'git commit --file=-' \
        $'git commit -q -F - <<\'EOF\'\nfix the --output and --no-index handling, not -F /tmp/x\nEOF' \
        'git stash list' \
        'git worktree list' \
        'git grep -n foo' \
        "git grep -i -e x -- '*.md'" \
        'git grep -ie -O' \
        'git grep -e -Oecho' \
        'git grep -n "an -Obj pattern"' \
        'git grep -c --no-open-files-in-pager foo' \
        'git grep --only-matching foo' \
        'git log --grep -O' \
        'git tag -a v1 -m x' \
        'git tag -a v1 -m "see --file and -F"' \
        'git tag -n' \
        'git tag -a v1 -F -' \
        'git tag --file=- -a v1' \
        'bash tools/check.sh' \
        'bash tools/prototype.sh start quick-add' \
        'bash tools/stacks/dotnet.sh --since HEAD~3..HEAD' \
        'bash tools/check.sh && git log origin/main..HEAD' \
        'bash ../x.sh' \
        'cd tools && bash ../x.sh' \
        'cat README.md' \
        'cat docs/how-to/where.md' \
        'cat .env.example' \
        'cat config/.env.sample' \
        'head .env.template' \
        'cat .env.dist' \
        'cat README.md docs/x.md' \
        'tail -n 20 .env.example' \
        'head -5 notes.txt' \
        'cat .env.example .env.sample' \
        'grep -n ssh docs/how-to/trouble.md' \
        'git log --oneline -3' \
        'ls ~/.ssh' \
        'gh auth status' \
        $'git status\ngit log --oneline -3' \
        $'git status\ngit commit -q -F - <<\'EOF\'\nfix the --output and --no-index handling, not -F /tmp/x\nEOF' \
        $'git commit -q -F - <<\'EOF\'\nfix the -n flag, not a flag\nEOF' \
        'echo x\\ngit branch -D y' \
        $'git log \\\n--oneline -3' \
        $'git status \\\n-s' \
        $'git diff \\\nHEAD' \
        $'echo a\\\\\nls' \
        $'cat README.md \\\ndocs/x.md' \
        $'cat\tREADME.md' \
        $'git\tstatus'; do
      guard 0 "$cmd"
    done
    # PowerShell (B24): its input carries the command as tool_input.command, like Bash's, so the hook must
    # exit the same way on a PowerShell payload. These are the git flags the deny rules and the guard block.
    for cmd in \
        'git push --force' \
        'git commit --no-verify -m x' \
        'git reset --hard HEAD~1' \
        'git log --output=/tmp/probe.txt' \
        'git diff --no-index a b' \
        'git commit -F /tmp/msg.txt' \
        'git grep -Oecho foo' \
        'git tag -F /tmp/msg.txt v1' \
        'bash tools/stacks/../../x.sh' \
        'cat .env.local'; do
      guard 2 "$cmd" PowerShell
    done
    for cmd in 'git status' 'git log --oneline -5' 'git diff HEAD'; do
      guard 0 "$cmd" PowerShell
    done
  fi
  guard_run
  guard_report "$git_fail" "git's file-writing, file-reading and external-command flags, and script paths outside tools/, are not all blocked" "the wildcard rules deny, and the guard hook blocks, git's file-writing, file-reading and external-command flags and script paths outside tools/"

  # The PowerShell readers of credential files (B27): Get-Content and its aliases gc and type, Select-String
  # and sls, and [IO.File]::ReadAll... block a credential file in any case, as cat does, and so does a reader
  # inside a -Command or -c string. The same readers of ordinary files pass, and the checks run for the Bash
  # tool too, since the hook reads every tool's command the same way.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for reader in 'Get-Content' 'gc' 'type' 'GET-CONTENT' 'Select-String -Pattern x' 'sls x' \
        'Get-Content -Path' 'Get-Content -LiteralPath'; do
      for target in '.env.local' '.env' '.env*' 'certs/server.pem' '~/.ssh/id_ed25519' \
          '$HOME\.ssh\id_rsa' '~/.config/gh/hosts.yml' '"$env:APPDATA\GitHub CLI\hosts.yml"'; do
        guard 2 "$reader $target" PowerShell
      done
    done
    for cmd in \
        "[IO.File]::ReadAllText('.env.local')" \
        '[System.IO.File]::ReadAllLines(".env")' \
        '[io.file]::readallbytes("certs/server.pem")' \
        '[IO.File]::ReadLines("$HOME\.ssh\id_rsa")' \
        'Get-Content .env.example; Get-Content .env.local' \
        'powershell -NoProfile -Command "Get-Content .env.local"' \
        'powershell -c "gc .env"' \
        'cmd /c "type .env.local"' \
        "bash -c 'cat .env.local'" \
        'bash -c "cat .env.local"' \
        'cat .env*' \
        '\cat .env.local' \
        'echo `cat .env.local`' \
        'type .env.local' \
        'gc .env.local'; do
      guard 2 "$cmd"
    done
    for cmd in \
        'Get-Content README.md' \
        'gc docs/index.md' \
        'Get-Content -Path docs/index.md' \
        'Get-Content -LiteralPath README.md' \
        'Select-String -Path docs/index.md -Pattern title' \
        'Get-Content .env.example' \
        'gc config/.env.sample' \
        '[IO.File]::ReadAllText("docs/index.md")' \
        'Get-ChildItem ~/.ssh' \
        'powershell -NoProfile -Command "Get-Content README.md"' \
        'type git'; do
      guard 0 "$cmd" PowerShell
    done
    guard 0 'type git'
    guard 0 'type README.md'
  fi
  guard_run
  guard_report "$git_fail" "the guard hook doesn't block every read of a credential file, or blocks a read of an ordinary file (B27)" "the guard hook blocks the PowerShell and Bash readers of credential files, in any case, and passes the readers of ordinary files and templates"

  # PowerShell's backtick (B28): a backtick that ends a line continues it, so a flag or a read it splits is
  # blocked as the plain form is, and a benign continuation passes. An escaped backtick (``) and a backtick
  # followed by spaces don't continue. In Bash a backtick is command substitution, so the same text passes
  # there. A comment that ends in a backtick still shows the next line, which the joined text would hide.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        $'git push `\n--force' \
        $'git commit `\n-n -m x' \
        $'cat `\n.env.local' \
        $'cat README.md `\n.env.local' \
        $'git push `\r\n--force' \
        $'git push `\r--force' \
        $'git log `\n--output=/tmp/probe.txt' \
        $'git pu`\nsh --force' \
        $'cat .en`\nv.local' \
        $'# note`\ngit push --force'; do
      guard 2 "$cmd" PowerShell
    done
    for cmd in \
        $'git log `\n--oneline -3' \
        $'git status `\n-s' \
        $'cat ``\n.env.local' \
        $'git push ``\n--force' \
        $'git push ` \n--force'; do
      guard 0 "$cmd" PowerShell
    done
    guard 0 $'cat README.md `\n.env.local'
  fi
  guard_run
  guard_report "$git_fail" "the guard hook doesn't treat a PowerShell backtick at a line's end as a continuation, or treats a Bash or an escaped one as one (B28)" "the guard hook blocks a flag or a read that a PowerShell backtick continuation splits, and passes the benign continuations and the escaped and Bash backticks (B28)"

  # A Bash comment that ends in a backslash (B31): Bash ends the comment at the line break, so the line after it is a
  # command of its own, and the guard reads it as written. A continued command after such a comment is read from its
  # own line on. A # inside a word (a#b) is no comment, so its continuation is joined, as Bash joins it. The hang
  # check reads a heredoc header joined to its delimiter (B29): python3 with - <<'EOF' on the next line, with a body or without.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        $'# note\\\ngit push --force' \
        $'# note\\\ngit commit --no-verify -m x' \
        $'git status # note\\\ngit push --force' \
        $'# a\\\ngit commit \\\n-F /tmp/msg.txt' \
        $'# a\\\ngit push \\\n--force' \
        $'# a\\\n# b\\\ngit push \\\n--force' \
        $'git push origin main#\\\n  --force' \
        $'python3 \\\n- <<\'EOF\'\nEOF' \
        $'python3 \\\n- <<\'EOF\'\nprint(1)\nEOF'; do
      guard 2 "$cmd"
    done
    for cmd in \
        $'# note\\\ngit status' \
        $'git status # note\\\n-s' \
        $'echo a#b\\\n--force' \
        $'python3 \\\ntool.py <<\'EOF\'\ndata\nEOF'; do
      guard 0 "$cmd"
    done
  fi
  guard_run
  guard_report "$git_fail" "the guard hook reads a command after a Bash comment that ends in a backslash as hidden, or blocks a benign one (B31, B29)" "the guard hook reads the line after a Bash comment that ends in a backslash, and the command continued after it, as Bash does (B31, B29)"

  # A PowerShell comment that ends in a backtick (B35): PowerShell ends the comment at the line break too, so the line after it
  # is a command of its own, and a continued command after it is read from its own line on, as for a Bash comment (B31). A CRLF
  # break is the same. A comment that ends in a backtick, followed by a plain command, passes.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        $'# note`\ngit commit `\n-F x' \
        $'# note`\r\ngit commit `\r\n-F x'; do
      guard 2 "$cmd" PowerShell
    done
    guard 0 $'# note`\ngit status' PowerShell
  fi
  guard_run
  guard_report "$git_fail" "the guard hook doesn't read a command after a PowerShell comment that ends in a backtick, or blocks a plain one (B35)" "the guard hook reads the command after a PowerShell comment that ends in a backtick, and the command continued after it, as PowerShell does (B35)"

  # A quoted or path-qualified reader, a backtick inside a word and a StreamReader (B30): the call operator with a
  # quoted name (& 'Get-Content' .env.local), a reader by its path (/bin/cat, cat.exe, the Management module's
  # Get-Content), a backtick escape that leaves a letter or a dot in a reader or a name (Get-Con`tent, .en`v.local),
  # and the StreamReader constructors are read as the plain forms are. A reader in a string with a backtick-escaped
  # quote, a template and an ordinary file pass. In PowerShell the escape also reaches the git flag rules (--fo`rce).
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        "& 'Get-Content' .env.local" \
        '& "gc" .env.local' \
        ". 'type' .env.local" \
        "& 'Get-Content' -Path '.env.local'" \
        "Get-Content '.env.local'" \
        'Get-Con`tent .env.local' \
        'gc .en`v.local' \
        'type `.env.local' \
        'C:\Git\usr\bin\cat.exe .env.local' \
        'Microsoft.PowerShell.Management\Get-Content .env.local' \
        '[System.IO.StreamReader]::new(".env.local")' \
        "[IO.StreamReader]::new('.env')" \
        "New-Object System.IO.StreamReader('.env.local')" \
        'New-Object -TypeName System.IO.StreamReader -ArgumentList .env.local' \
        'git push --fo`rce' \
        'Write-Output x; & "gc" .env'; do
      guard 2 "$cmd" PowerShell
    done
    for cmd in \
        '/bin/cat .env.local' \
        '/usr/bin/head -n 5 .env' \
        "'/bin/cat' .env.local" \
        '/usr/bin/tail -n 20 .env.production'; do
      guard 2 "$cmd"
    done
    for cmd in \
        "& 'Get-Content' README.md" \
        "& 'Get-Content' '.env.example'" \
        'Write-Output "say `"hi`" now"' \
        'Write-Output "run `"gc README.md`" next"' \
        "[System.IO.StreamReader]::new('docs/index.md')" \
        "New-Object System.IO.StreamReader('README.md')" \
        'Get-Con`tent README.md' \
        'cat.exe README.md'; do
      guard 0 "$cmd" PowerShell
    done
    for cmd in \
        '/bin/cat README.md' \
        '/usr/bin/head -n 5 .env.example' \
        "'/bin/cat' README.md"; do
      guard 0 "$cmd"
    done
  fi
  guard_run
  guard_report "$git_fail" "the guard hook misses a quoted or path-qualified reader, a backtick inside a word or a StreamReader of a credential file (B30)" "the guard hook blocks a quoted or path-qualified reader, a backtick-escaped word and a StreamReader of a credential file, and passes the same readers of ordinary files (B30)"

  # The common file readers (B36): grep, sed, awk, sort, base64, xxd and the rest of the list in the hook print a
  # credential file as cat does, in Bash and in a PowerShell payload; a reader or a name split by quotes (ca''t, c"a"t)
  # is read as the shell runs it; [IO.File]::OpenText, OpenRead and Open read one. A pattern is an argument as well
  # (B27), so grep "\.env" and git grep .env are blocked, and the templates and ordinary files pass. A commit message
  # that names a reader, with no credential file after it, passes.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        'grep x .env.local' \
        'awk 1 .env' \
        'sed -n p .env.local' \
        'base64 .env.local' \
        'xxd .env.local' \
        'egrep x .env' \
        'fgrep -i x .env.production' \
        'rg x .env.local' \
        'gawk "{print}" .env.staging' \
        'sort .env.local' \
        'uniq .env' \
        'cut -d= -f2 .env.local' \
        'nl .env' \
        'tac .env.local' \
        'rev .env' \
        'od -c .env' \
        'hexdump -C .env.local' \
        'diff .env.local .env.example' \
        'cmp .env .env.example' \
        '/usr/bin/grep x .env.local' \
        'grep -rn "\.env" docs/' \
        'git grep .env' \
        "ca''t .env.local" \
        'c"a"t .env.local' \
        "'ca'\"t\" .env" \
        'g""rep x .env' \
        'ba"se"64 .env.local' \
        'cat .en'"''"'v.local' \
        'c'"'"'a'"'"'t .env.local'; do
      guard 2 "$cmd"
    done
    for cmd in \
        "[System.IO.File]::OpenText('.env.local')" \
        '[IO.File]::OpenRead(".env")' \
        "[System.IO.File]::Open('.env.local', 'Open', 'Read')" \
        '[io.file]::opentext("certs/server.pem")' \
        '[IO.File]::OpenRead("$HOME\.ssh\id_rsa")' \
        '& "Get-Content" .env.local' \
        'Select-String -Path .env -Pattern x'; do
      guard 2 "$cmd" PowerShell
    done
    for cmd in \
        'grep x .env.example' \
        'sed -n p .env.sample' \
        'awk 1 .env.template' \
        'base64 .env.dist' \
        'xxd .env.example' \
        'ca""t .env.example' \
        'c"a"t config/.env.sample' \
        'grep -n "DATABASE_URL" src/' \
        'sed -n 1,5p docs/index.md' \
        'awk 1 docs/index.md' \
        'sort README.md' \
        'cut -c1-3 README.md' \
        'diff README.md docs/index.md' \
        'git grep TODO' \
        'git diff README.md' \
        'git commit -m "fix: sort the docs and grep notes"' \
        'git commit -m "docs: sed, awk and diff notes" -- docs/index.md' \
        'rev-parse --show-toplevel'; do
      guard 0 "$cmd"
    done
    for cmd in \
        "[System.IO.File]::OpenText('docs/index.md')" \
        '[IO.File]::OpenRead("README.md")' \
        "[System.IO.File]::Open('docs/index.md', 'Open')" \
        "[IO.File]::OpenText('.env.example')"; do
      guard 0 "$cmd" PowerShell
    done
  fi
  guard_run
  guard_report "$git_fail" "the guard hook misses a common file reader, a reader or a name split by quotes, or an IO.File Open method of a credential file, or blocks an ordinary read (B36)" "the guard hook blocks grep, sed, awk, sort, base64, xxd and the other common readers, a reader or name split by quotes, and [IO.File]::OpenText, OpenRead and Open of a credential file, and passes the same readers of templates and ordinary files (B36)"

  # A backslash that escapes an ordinary character in a Bash command is removed by the shell (B44): c\at is cat, and .en\v.local
  # is .env.local, so the reader and the name are read as the shell runs them. An escaped backslash (\\) is one backslash, and a
  # backslash before a space stays, as the shell keeps the name one word. Windows paths and the templates pass, and PowerShell's
  # escape is the backtick (B30), so a backslash in a PowerShell payload is a path separator, not an escape.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        'c\at .env.local' \
        'he\ad .env' \
        'cat .en\v.local' \
        'cat .env\.local' \
        'cat .e\nv.local' \
        'c\a\t .env.local' \
        'ca\t .en\v.local' \
        'sed -n p .en\v.local' \
        'C\AT .env.local' \
        'c\at "config/.en\v.local"' \
        'cat ~/.s\sh/id_rsa' \
        'cat C:\Users\V\.env' \
        'cat .\pem'; do
      guard 2 "$cmd"
    done
    for cmd in \
        'c\\at .env.local' \
        'cat .en\\v.local' \
        'cat .en\v.example' \
        'cat .en\v.sample' \
        'cat .env\ .example' \
        'c\at README.md' \
        'cat C:\Users\V\README.md' \
        'cat C:\Users\V\docs\index.md' \
        'cat C:\repo\.env.example' \
        'git commit -m "docs: c\at notes"'; do
      guard 0 "$cmd"
    done
    guard 0 'c\at .env.local' PowerShell
    guard 0 "bash -c 'c\at README.md'" PowerShell
    guard 0 "powershell -c \"c\at .env.local\"" PowerShell
    guard 2 "bash -c 'c\at .env.local'" PowerShell
    guard 2 'bash -c "cat .en\v.local"' PowerShell
    guard 2 'type C:\x\.env' PowerShell
  fi
  guard_run
  guard_report "$git_fail" "the guard hook misses a backslash that escapes a character in a Bash credential read, or blocks an ordinary read or a PowerShell backslash (B44)" "the guard hook blocks a Bash credential read whose reader or name has a backslash that escapes a character (c\\at, .en\\v.local), and passes the templates, Windows paths and a PowerShell backslash (B44)"

  # The credential-read check (B52): an escaped space in a store path (GitHub\ CLI is the gh CLI's folder, and the backslash-space is
  # the space in it); an ANSI-C string ($'...') in a reader's or a file's name, which is read as the shell reads it (\xHH, \NNN and the
  # common escapes), with an escape the guard can't decode (\u, \0) blocked as unjudgeable; and a PowerShell command's $(...), read as
  # a command of its own, so a Bash command in it that reads through a backslash (c\at) is blocked. A backslash-space in a name
  # (.env\ .example) is one word, not .env, and passes. PowerShell's backslash is no escape (its escape is the backtick), so its store
  # path passes as written (B44).
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        'cat ~/AppData/Roaming/GitHub\ CLI/hosts.yml' \
        'cat ~/AppData/Roaming/GitHub\ CLI' \
        'cat "~/AppData/Roaming/GitHub\ CLI/hosts.yml"' \
        'cat ~/AppData/Roaming/Git\Hub\ CLI/hosts.yml' \
        "\$'\\x63at' .env.local" \
        "\$'\\143at' .env.local" \
        "cat \$'.en\\x76.local'" \
        "cat \$'\\x2eenv.local'" \
        "cat \$'\\x2e\\x65nv\\x2elocal'" \
        "cat \$'\\x2eenv'\$'.local'" \
        "cat \$'.env\\x2elocal' docs/index.md" \
        "cat \$'\\x2eenv' .example" \
        "cat \$'\\u0063at' .env.local" \
        "cat \$'\\0' README.md" \
        "echo \$(bash -c \$'c\\x61t .env.local')" \
        "echo \$(bash -c 'c\\at .env.local')" \
        "git log \$(bash -c 'c\\at .env.local')"; do
      guard 2 "$cmd"
    done
    for cmd in \
        "echo \$(bash -c 'c\\at .env.local')" \
        "echo \"\$(bash -c 'c\\at .env.local')\"" \
        "Write-Output \$(bash -c \"c\\at ~/.ssh/id_rsa\")"; do
      guard 2 "$cmd" PowerShell
    done
    for cmd in \
        'cat .env\ .example' \
        'cat README.md docs/index.md' \
        "printf '%s' \$'\\e[31mred\\e[0m'" \
        "tr -d \$'\\r' < docs/index.md" \
        "cat \$'README\\56md'" \
        "cat \$'\\101\\x42C.md'" \
        "cat \$'.env.example'" \
        "cat \$'\\x2eenv.template'" \
        "echo \"\$(bash -c 'c\\at README.md')\"" \
        "echo \$(bash -c 'echo hi')"; do
      guard 0 "$cmd"
    done
    for cmd in \
        'cat ~/AppData/Roaming/GitHub\ CLI/hosts.yml' \
        'Write-Output "$(Get-Content .env.example)"' \
        'Write-Output "$(Get-Content README.md)"' \
        "Write-Output \"\$(bash -c 'c\\at README.md')\""; do
      guard 0 "$cmd" PowerShell
    done
  fi
  guard_run
  guard_report "$git_fail" "the guard hook misses an escaped space in a store path, an ANSI-C string in a reader's or a file's name, or a PowerShell command's substitution that reads a credential file, or blocks an ordinary read (B52)" "the guard hook blocks a credential read through an escaped space in a store path, an ANSI-C string in a name, and a PowerShell command's substitution, and passes an ANSI-C string that names no credential and the substitutions that read none (B52)"

  # A command substitution in a git command's words (B32): what it prints can be a flag, and the text it runs is a command
  # the guard can't see. The repro (git push $(echo --force) and its backtick form) is blocked as the plain flag is, in Bash
  # and PowerShell, and so is a substitution as the command name, or one that runs a non-reading command. A double-quoted
  # value that starts with fixed text, a commit's or tag's -m value and a read (git, date, cat, echo, printf) pass, as the
  # procedures use them. The text of a substitution is judged as a command of its own.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        'git push $(echo --force)' \
        'git push `echo --force`' \
        'git push "$(echo --force)"' \
        'git log $(echo --output=/tmp/x)' \
        'git log "$(echo --output=/tmp/x)"' \
        'git log "--output=$(echo /tmp/x)"' \
        'git log "--since=$(rm -rf x)"' \
        'git log -1 "$(date +%F)"' \
        'git log "x$(git push --force)"' \
        'git push $(git push --force)' \
        'git status && echo $(git push --force)' \
        'echo "$(git push --force)"' \
        'git log > >(git push --force)' \
        '$(echo git) push --force' \
        'git log $(echo git) push' \
        'git commit -m x "$(cat x)"' \
        'git commit -m "$(echo $(rm -rf x))"' \
        $'git commit -c -m "$(cat <<\'EOF\'\n--file=/tmp/x\nEOF\n)"' \
        $'git commit -m -m "$(cat <<\'EOF\'\n--file=/tmp/x\nEOF\n)"' \
        $'git commit -m "$(cat <<EOF\n$(git push --force)\nEOF\n)"' \
        $'git commit -m "$(cat x; git push --force)"' \
        $'git log \\\n$(echo --output=/tmp/x)' \
        'git push "--force"$(echo x)'; do
      guard 2 "$cmd"
    done
    for cmd in \
        'git push $(echo --force)' \
        'git push `echo --force`' \
        'git push "$(echo --force)"' \
        'git push (echo --force)' \
        'git push @(echo --force)' \
        '$(echo git) push --force' \
        'git log -- $(echo --output=/tmp/x)' \
        'git log "$(git push --force)"'; do
      guard 2 "$cmd" PowerShell
    done
    for cmd in \
        $'git commit -m "$(cat <<\'EOF\'\nfix the --output handling, and -F /tmp/x\nEOF\n)"' \
        $'git commit -a -m "$(cat <<\'EOF\'\nmsg one\n\nBody with `ticks` and $(vars) text\nEOF\n)" -- docs/index.md' \
        $'git commit -m "$(cat <<\'EOF\'\nmsg `git push --force` in a quoted heredoc\nEOF\n)" -- x' \
        $'git commit -m "$(cat <<EOF\nplain body\nEOF\n)"' \
        'git commit -m "$(git log -1 --format=%s)"' \
        'git commit -m "$(echo --file=/tmp/x)"' \
        'git tag -a "v$(cat VERSION)" -m "release"' \
        'git checkout -q -b "ddd/bundle-$(date +%F)" origin/main' \
        'git ls-remote --heads origin "ddd/bundle-$(date +%F)*"' \
        "git log --since=\"\$(date -d '7 days ago' +%F)\" --oneline" \
        'git log --format=%h -n 1 -- "docs/$(echo index).md"' \
        'test -z "$(git status --porcelain)"' \
        'echo "$r $(git -C work/$r describe --tags)"' \
        'for f in $(git diff --name-only); do echo "$f"; done' \
        'K=$(git rev-parse HEAD); echo $K' \
        'cd "$(git rev-parse --show-toplevel)" && git status' \
        'git status; echo $(date)' \
        'git log -1 --format=%h \$(echo --output)' \
        'echo `date`'; do
      guard 0 "$cmd"
    done
    guard 0 'Write-Output "$(git status)"' PowerShell
    guard 0 $'git commit -m "$(cat <<\'EOF\'\nmsg\nEOF\n)" && git push origin main' PowerShell
  fi
  guard_run
  guard_report "$git_fail" "the guard hook reads a command substitution in a git command's words, or as its name, as harmless, or blocks a plain read (B32)" "the guard hook blocks a command substitution that can print a git flag or run a command the guard can't read, in git's words or as a command name, and passes the quoted values, messages and reads the procedures use (B32)"

  # A Bash comment holds no substitution and opens no quoted string (B43): a backtick, $( or quote in it is text, so the
  # command after the comment is read as Bash reads it. A substitution after a comment, a tab, ; or & is still read, and so is
  # one after a # inside a word (a#b) or after an escaped blank, since neither starts a comment. A ) in a comment doesn't close a
  # substitution, so its text runs to the next line and is blocked. A blank before a # inside ${...} is part of the expansion,
  # not a comment. An unquoted heredoc body's substitutions are read whole, as the shell expands them, so a comment in one is
  # read too; a quoted body is text.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        $'git push # x\n`echo --force`' \
        $'git push # x\ngit push `echo --force`' \
        $'git status # note\ngit push $(echo --force)' \
        $'# it\'s\ngit push `echo --force`' \
        $'git status a#b `echo --force`' \
        $'git status a\\ #`echo --force`' \
        $'git status ${x:- #a} $(echo --force)' \
        $'git push origin ":${y:- #}$(echo main)"' \
        $'git push `# x`' \
        $'git push `echo --force` # x' \
        $'git push $(echo --force) # `' \
        $'git status $(echo a # `)' \
        $'git log "--format=$(echo a # )\nprintf x)"' \
        $'git commit -q -F - <<EOF\n# note `\nmsg\nEOF' \
        $'git log <<EOF\n# $(git push --force)\nEOF' \
        $'git status <<EOF\n# `git push --force`\nEOF' \
        $'# note `\\\ngit push `echo --force`'; do
      guard 2 "$cmd"
    done
    for cmd in \
        $'# note `\ngit status' \
        $'# note `echo --force`\ngit status' \
        $'# note $(echo --force)\ngit status' \
        $'git status\t# note `\ngit log -1' \
        $'git status;# note `\ngit log -1' \
        $'# it\'s\ngit status' \
        $'git status # $(echo --force)' \
        $'git status # `echo --force`' \
        $'git status ${x:-y} # $(echo --force)' \
        $'# note `\\\ngit status' \
        $'git commit -q -F - <<\'EOF\'\n# note `echo --force`\nmsg\nEOF'; do
      guard 0 "$cmd"
    done
  fi
  guard_run
  guard_report "$git_fail" "the guard hook reads a backtick, \$( or quote in a Bash comment as a substitution or a string, or misses a substitution after one (B43)" "the guard hook reads a Bash comment as text, so a backtick, \$( or quote in it starts no substitution or string, and a substitution after a comment, an escaped blank or a # in a word is still read (B43)"

  # The word decoder (B51) reads a comment on its own line: a quote in it pairs with nothing after the line break, so the
  # quoted flag, refspec or credential command after it is seen, in Bash, in a heredoc body a shell runs and in PowerShell
  # (whose # starts a comment the same way). A quote in a comment that never closes is text, so the flags it names pass,
  # and a quoted command in a comment passes as it did; a # inside a quoted string, an escaped #, ${#x} or $# starts no
  # comment, so a flag after one is blocked.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        $'# it\'s\ngit push origin \':main\'' \
        $'# it\'s\ngit push "--force" \'x\'' \
        $'# say "hi\ngit push "--force" "x"' \
        $'# it\'s\ngit commit -q "-n" -m \'x\'' \
        $'# it\'s\ngit push origin "+main" \'x\'' \
        $'# say "hi\ngit push origin \':main\'' \
        $'# say "hi\ngit commit -q "-n" -m "x"' \
        $'git status\n# it\'s\ngit push "--force" \'x\'' \
        $'echo \'a\'  # it\'s\ngit push "--force" \'x\'' \
        $'# it\'s\n# don\'t\ngit push origin \':main\' \'x\'' \
        $'bash <<\'EOF\'\n# it\'s\ngit push origin \':main\'\nEOF' \
        $'bash <<\'EOF\'\n# it\'s\ngit push "--force" \'x\'\nEOF' \
        $'# it\'s\ngit credential fill \'x\'' \
        $'# note\\\ngit push --force' \
        $'echo a\\ #b ; git push --force' \
        $'echo "#" ; git push --force' \
        $'git status ${x:- #} ; git push --force' \
        $'echo "$(echo "a #") # b" ; git push --force'; do
      guard 2 "$cmd"
    done
    for cmd in \
        $'# it\'s\ngit status' \
        $'# it\'s --force\ngit status' \
        $'# it\'s "--force" -n :main\ngit status' \
        $'# it\'s \':main\'\ngit log -1' \
        $'# it\'s "git push --force"\ngit status' \
        $'# say "--force" and "-n" and ":main"\ngit status' \
        $'git status # it\'s --force\ngit log -1' \
        $'git status\n# it\'s\ngit log --oneline -3' \
        $'# it\'s -n\ngit push origin main' \
        $'git commit -q -F - <<\'EOF\'\n# it\'s git push origin \':main\'\nEOF' \
        $'bash <<\'EOF\'\n# it\'s --force\necho done\nEOF' \
        $'git commit -m "fix #12 it\'s" -m "x"' \
        $'git status "#" \'it\'' \
        $'echo ;#x'; do
      guard 0 "$cmd"
    done
    for cmd in \
        $'# it\'s\ngit push "--force" \'x\'' \
        $'# it\'s\ngit commit -q "-n" -m \'x\'' \
        $'echo "a""b # " ; git push --force' \
        'git push `#x --force'; do
      guard 2 "$cmd" PowerShell
    done
    guard 0 $'# it\'s --force\ngit status' PowerShell
    guard 0 $'# it\'s\ngit log -1' PowerShell
  fi
  guard_run
  guard_report "$git_fail" "the guard hook reads a quote in a comment as pairing with a quote after its line break, or blocks a comment that names a flag or quotes a command (B51)" "the guard hook reads a quote in a Bash or PowerShell comment as pairing with nothing after its line break, so a quoted flag, refspec or credential command after it is blocked, and a comment that names a flag or quotes a command passes (B51)"

  # A destructive git rule (B33) reads the words as the shell hands them over: a quoted flag, refspec or path is seen, a flag
  # ends at ; & | ) or a line break as it does at a space, and a heredoc body a shell runs is read too. The rules are a force
  # push, a +refspec, reset --hard, clean -f, checkout or switch -f, checkout or restore of ".", stash drop or clear, and
  # branch -D. A quoted message that names one passes, and so does a quoted word that isn't a flag.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
      $'git push --force\necho done' \
      'git push --force;echo done' \
      'git push --force&&echo done' \
      'git push --force|cat' \
      '(git push --force)' \
      'git push "--force"' \
      "git push '--force'" \
      'git push "--force-with-lease=origin/main"' \
      'git push --fo"rce"' \
      'git push -f;echo done' \
      'git push origin "+main"' \
      "git push origin '+main'" \
      'git pu"sh" --force' \
      'git status && git push --force' \
      $'git status\ngit push "--force"' \
      'git checkout "."' \
      'git checkout -- "."' \
      'git restore "."' \
      'git checkout .;echo done' \
      'git checkout -f;echo done' \
      'git checkout "-f" main' \
      'git checkout -qf main' \
      'git switch "--discard-changes" main' \
      'git reset "--hard"' \
      'git reset --hard;echo done' \
      'git clean "-f"' \
      'git stash "drop"' \
      'git stash drop;echo done' \
      'git branch "-D" x' \
      'git branch -D x;echo done' \
      'git branch -vD x' \
      'git commit -n;echo done' \
      'git commit -m "-x;y" -F /tmp/msg.txt' \
      'git diff "/etc/passwd"' \
      'bash "tools/../x.sh"' \
      $'bash <<\'EOF\'\ngit push --force\nEOF' \
      $'bash <<\'EOF\'\ngit push "--force"\nEOF' \
      $'bash <<\'EOF\'\ngit push origin "+main"\nEOF' \
      $'bash <<\'EOF\'\ngit checkout "."\nEOF' \
      $'bash <<\'EOF\'\ngit commit -n -m x\nEOF' \
      $'sh <<EOF\ngit reset --hard\nEOF'; do
      guard 2 "$cmd"
    done
    for cmd in \
      'git push origin main' \
      'git push origin "HEAD:refs/heads/main"' \
      'git push "origin" main' \
      'git push origin main;git status' \
      'git push -u origin "ddd/bundle-$(date +%F)"' \
      'git commit -m "stop git push --force;"' \
      'git commit -m "reset --hard" -m "checkout ."' \
      'git commit -m "stash drop"' \
      'git commit -m "-x" -F -' \
      'git checkout -b "feature/x"' \
      'git checkout "main"' \
      'git branch -d x' \
      'git branch -vv' \
      'git log --grep "push --force"' \
      'git log --oneline "--grep=push"' \
      'git stash show "drop"' \
      'git tag -a v1 -m "push --force note"' \
      'echo "git push --force"' \
      'git status && echo "reset --hard"' \
      $'git status\ngit log --oneline -3' \
      $'git commit -q -F - <<\'EOF\'\nStop "git push --force" in the hook, and "git reset --hard".\nEOF' \
      $'git commit -q -F - <<\'EOF\'\nfix the --output and --no-index handling, not -F /tmp/x\nEOF'; do
      guard 0 "$cmd"
    done
    for cmd in 'git push "--force"' 'git push origin "+main"' 'git checkout "."' 'git push --force;echo done' 'git reset "--hard"'; do
      guard 2 "$cmd" PowerShell
    done
    guard 0 'Write-Output "git push --force"' PowerShell
    guard 0 'git push origin "HEAD:main"' PowerShell
  fi
  guard_run
  guard_report "$git_fail" "the guard hook doesn't read a destructive git rule's flag, refspec or path as the shell does, or blocks a message that names one (B33)" "the guard hook blocks a force push, a +refspec, reset, clean, checkout, stash drop and branch -D that a quote, a line break, ; & | ) or a heredoc body hides, and passes the quoted messages (B33)"

  # A script a shell or an interpreter runs is a command of its own (B34): a quoted string given to bash -c, sh -c or
  # zsh -c (with options before -c), eval, powershell -Command, pwsh -c or cmd /c is read by the same rules, to four levels
  # of nesting, whatever the name is quoted or prefixed with. A comment, a heredoc body or a message in quotes that names
  # one is text, and a read or a benign script passes. A command whose quoting the guard can't close, and PowerShell's
  # -EncodedCommand, whose text is hidden, are blocked.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        "bash -c 'git push --force'" \
        'sh -c "git commit --no-verify -m x"' \
        "eval 'git log --output=x'" \
        'sh -c "git push $(echo --force)"' \
        "sh -c 'git commit -n -m x'" \
        "zsh -c 'git branch -D x'" \
        "bash -lc 'git reset --hard'" \
        "bash -o pipefail -c 'git push --force'" \
        'eval "git push" --force' \
        "bash -c \"git push '--force'\"" \
        "timeout 240 bash -c 'git push --force'" \
        "bash -c 'bash -c \"git push --force\"'" \
        'sh -c "git commit -m \"x\" -n"' \
        'powershell -NoProfile -Command "git push --force"' \
        'cmd /c "git push --force"' \
        '"bash" -c "git push --force"' \
        "ba''sh -c 'git push --force'" \
        "nice -n 5 bash -c 'git push --force'" \
        "sudo sh -c 'git push --force'" \
        "eval 'bash -c \"git push --force\"'" \
        "bash -c \"\$(echo git push --force)\"" \
        "bash -c 'git checkout .'" \
        'bash -c "git push origin +main"' \
        "/bin/bash -c 'git push --force'" \
        "bash -c \$'git push --force'" \
        "bash -c 'git commit -F /tmp/msg.txt'" \
        "bash -c 'bash tools/stacks/../x.sh'" \
        "bash -c 'sleep 300'" \
        'sh -c "git status' \
        'powershell -EncodedCommand ZwBpAHQAIABwAHUAcwBoAA==' \
        $'# don\'t\nbash -c \'git push --force\'' \
        $'cat <<\'EOF\'\nit\'s\nEOF\nbash -c \'git push --force\'' \
        $'bash -c \'echo hi\' ; sh -c "git status\nbash -c \'git push --force\'"'; do
      guard 2 "$cmd"
    done
    # Four wrappers nested (bash -c inside sh -c inside zsh -c inside bash -c) reach the git inside; a fifth is blocked.
    wrap_esc() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '%s' "$s"; }
    nest="bash -c 'git push --force'"
    for _ in 1 2 3; do nest="sh -c \"$(wrap_esc "$nest")\""; done
    guard 2 "$nest"
    nest="bash -c 'echo hi'"
    for _ in 1 2 3; do nest="sh -c \"$(wrap_esc "$nest")\""; done
    guard 0 "$nest"
    nest="sh -c \"$(wrap_esc "$nest")\""
    guard 2 "$nest"
    for cmd in \
        "bash -c 'git status'" \
        'sh -c "echo hi"' \
        "bash -c 'git log --oneline -3'" \
        "sh -c \"git commit -m 'fix the --output handling'\"" \
        'echo "bash -c '"'"'git push --force'"'"'"' \
        'git commit -m "fix: sh -c '"'"'git push --force'"'"' now blocked"' \
        $'git commit -q -F - <<\'EOF\'\nthe sh -c \'git push --force\' guard\nEOF' \
        "timeout 240 bash -c 'until test -f x; do sleep 5; done'" \
        '(timeout 4m bash -c "while true; do sleep 1; done")' \
        'bash -c "echo $(date)"' \
        'powershell -NoProfile -Command "Write-Output '"'"'hi'"'"'"' \
        "bash -c 'cat README.md'" \
        'eval "echo hi"' \
        'git log --grep "bash -c git push --force"' \
        "bash -c 'echo hi' git status" \
        'echo sh -c' \
        'git commit -m "run cmd /c later"' \
        $'bash -c "git commit -F - <<\'EOF\'\nmsg\nEOF"' \
        $'git commit -m "$(cat <<\'EOF\'\nmsg with sh -c \'git push --force\'\nEOF\n)"' \
        'bash tools/check.sh'; do
      guard 0 "$cmd"
    done
    # PowerShell (B34): the same wrappers in the PowerShell tool's payload, and a backtick that joins a flag.
    for cmd in \
        "pwsh -c 'git reset --hard'" \
        'powershell -Command "git push --force"' \
        'bash -c "git push --force"' \
        'cmd /c "git push --force"' \
        'powershell -EncodedCommand ZwBpAHQAIABwAHUAcwBoAA==' \
        'powershell -c "git push --fo`rce"'; do
      guard 2 "$cmd" PowerShell
    done
    for cmd in \
        "pwsh -c 'git status'" \
        'powershell -NoProfile -Command "Write-Output '"'"'hi'"'"'"' \
        'cmd /c "echo hi"' \
        'powershell -File tools/x.ps1 "git push --force"' \
        'pwsh -c "Get-ChildItem | Select-Object Name"'; do
      guard 0 "$cmd" PowerShell
    done
  fi
  guard_run
  guard_report "$git_fail" "the guard hook doesn't read a script a shell or an interpreter runs as a command of its own, or blocks a message that names one (B34)" "the guard hook reads a script given to bash -c, sh -c, zsh -c, eval, powershell -Command, pwsh -c or cmd /c as a command, to four levels, and passes the messages, heredocs and reads that name one (B34)"

  # A wait loop in a script a shell or an interpreter runs (B42): the hang check reads each such script as it reads the command,
  # so an until, while true or while : loop with sleep is blocked under eval, bash -c, sh -c, powershell -Command and cmd /c.
  # A timeout of 280 seconds or less above the wrapper bounds the whole script, as it bounds a loop the command runs itself,
  # and a loop with no sleep, or in a message that names one, passes.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        "eval 'until false; do sleep 1; done'" \
        "eval 'while true; do sleep 1; done'" \
        "eval 'while :; do sleep 1; done'" \
        "sh -c 'until false; do sleep 1; done'" \
        "eval \"until false; do sleep 1; done\"" \
        "eval 'bash -c \"until false; do sleep 1; done\"'" \
        "eval 'eval \"while true; do sleep 1; done\"'" \
        "sh -c \"eval 'while : ; do sleep 1; done'\"" \
        "timeout 9999 eval 'until false; do sleep 1; done'" \
        "timeout 0 eval 'until false; do sleep 1; done'" \
        "timeout 5m eval 'until false; do sleep 1; done'" \
        'cmd /c "until false; do sleep 1; done"' \
        'cmd /c "while true; do sleep 1; done"' \
        'powershell -Command "while ($true) { Start-Sleep 1 }"' \
        'powershell -NoProfile -Command "while ($true) { sleep 1 }"'; do
      guard 2 "$cmd"
    done
    for cmd in \
        'while ($true) { Start-Sleep 1 }' \
        'While ($true) { Start-Sleep -Seconds 5 }' \
        'WHILE ($true) { start-sleep 2 }'; do
      guard 2 "$cmd" PowerShell
    done
    for cmd in \
        "timeout 60 eval 'until false; do sleep 1; done'" \
        "timeout 4m eval 'until false; do sleep 1; done'" \
        "timeout 240s eval 'until false; do sleep 1; done'" \
        'timeout 60 cmd /c "until false; do sleep 1; done"' \
        "timeout 60 bash -c \"eval 'until false; do sleep 1; done'\"" \
        "sh -c \"timeout 60 eval 'until false; do sleep 1; done'\"" \
        "eval 'timeout 60 bash -c \"until false; do sleep 1; done\"'" \
        "eval 'until false; do echo hi; done'" \
        "eval 'sleep 1'" \
        "eval 'git commit -m \"until false; do sleep 1; done\"'" \
        'cmd /c "echo until"' \
        'powershell -Command "Write-Output (Get-Date)"'; do
      guard 0 "$cmd"
    done
    for cmd in \
        'while ($true) { Get-Date }' \
        'timeout 60 powershell -Command "while ($true) { Start-Sleep 1 }"'; do
      guard 0 "$cmd" PowerShell
    done
  fi
  guard_run
  guard_report "$git_fail" "the guard hook doesn't block a wait loop in a script a shell or an interpreter runs, or blocks one a timeout bounds (B42)" "the guard hook blocks an until or while loop with sleep in a script given to eval, bash -c, sh -c, powershell -Command or cmd /c, and passes one under a timeout of 280 seconds or less (B42)"

  # The hang check's other forms (B49): a C-style for (( loop with sleep and no time limit; a PowerShell do { } while or until with a
  # sleep in its body; Start-Sleep and its alias sleep with -Seconds, -s or -Milliseconds over 280 seconds; cmd's timeout /t N over 280
  # seconds, or -1, which waits for a key press for ever (cmd's timeout is a wait, not a time limit); and a Bash substitution, which
  # runs before a timeout above it starts, so the timeout doesn't bound it. A substitution in single quotes, or escaped, is the
  # script's own, so a timeout above a script bounds it. A message that names one of these passes (the quoted text is blanked).
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        'for ((;;)); do sleep 1; done' \
        'for (( ; ; )); do sleep 1; done' \
        'for ((i = 0; i < 3; i++)); do sleep 1; done' \
        'timeout 60 echo "$(until false; do sleep 1; done)"' \
        'timeout 60 echo $(until false; do sleep 1; done)' \
        'timeout 60 bash -c "echo $(until false; do sleep 1; done)"' \
        'timeout 60 echo "$(bash -c "until false; do sleep 1; done")"' \
        'echo "$(sleep 600)"' \
        'echo "$(cmd /c "timeout /t 600")"' \
        'powershell -Command "Start-Sleep -Seconds 600"' \
        'powershell -Command "Start-Sleep -Milliseconds 300001"' \
        'cmd /c "timeout /t 300"' \
        'cmd /c "timeout /t -1"' \
        'timeout 60 cmd /c "timeout /t 600"' \
        'timeout 60 echo $(cat <<'"'"'EOF'"'"'
x
EOF
) ; while true; do sleep 1; done'; do
      guard 2 "$cmd"
    done
    for cmd in \
        'do { Start-Sleep 1 } while ($true)' \
        'do { Start-Sleep 1 } until ($false)' \
        'DO { START-SLEEP -S 600 } WHILE ($true)' \
        'Start-Sleep -Seconds 600' \
        'Start-Sleep -s 600' \
        'Start-Sleep -Milliseconds 280001' \
        'sleep -Seconds 300' \
        'timeout 60 Write-Output $(while ($true) { Start-Sleep 1 })' \
        'powershell -Command "do { Start-Sleep 1 } while ($true)"'; do
      guard 2 "$cmd" PowerShell
    done
    for cmd in \
        "timeout 60 bash -c 'echo \$(until false; do sleep 1; done)'" \
        'timeout 240 bash -c "echo \$(until test -f x; do sleep 5; done)"' \
        "timeout 240 bash -c 'for ((i = 0; i < 3; i++)); do sleep 1; done'" \
        'echo "$(date +%s)"' \
        'echo $(sleep 280)' \
        'bash -c "echo $(date)"' \
        'timeout 60 cmd /c "timeout /t 60"' \
        'cmd /c "timeout /t 280"' \
        "echo '\$(until false; do sleep 1; done)'" \
        'git commit -m "wait: Start-Sleep 600 and for ((;;)) and do { x } while (y)"' \
        'git log --format="%h $(date +%F)" -3' \
        'echo "$(git log --oneline -3)"' \
        'for i in 1 2 3; do echo $i; done' \
        'for ((i = 0; i < 3; i++)); do echo $i; done'; do
      guard 0 "$cmd"
    done
    for cmd in \
        'timeout 60 powershell -Command "do { Start-Sleep 1 } while ($true)"' \
        'timeout 240 powershell -Command "Start-Sleep -Seconds 240"' \
        'Start-Sleep -Seconds 280' \
        'Start-Sleep -Milliseconds 280000' \
        'Start-Sleep 5' \
        'do { Get-Date } while ($false)' \
        "Write-Output 'do { Start-Sleep 1 } while (\$true)'"; do
      guard 0 "$cmd" PowerShell
    done
  fi
  guard_run
  guard_report "$git_fail" "the guard hook doesn't block a for (( loop, a do ... while, Start-Sleep or timeout /t over 280 seconds, or a substitution before a timeout, or blocks a message or a bounded script that names one (B49)" "the guard hook blocks a for (( loop with sleep, a do ... while with sleep, Start-Sleep and timeout /t over 280 seconds, and a substitution that runs before a timeout, and passes a bounded script and a message that names them (B49)"

  # The hang check reads the command without the bodies no shell runs (B50): a commit's, tag's or gh message, and a cat or tee body
  # nothing runs (the classification's reading, B40 and B48). So a message can name a loop, a pause or a timed wait, as plain text,
  # in a C-style or a PowerShell loop, with a pause or a wait over five minutes. A body a shell, an interpreter or a runner executes
  # is still read, and so is a Python heredoc (T309) and a command after a message. An unquoted message's substitution is run, so it
  # is read; a quoted one is text, and so are its backticks.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        $'git commit -q -F - -- a <<\'EOF\'\nPowerShell\'s While loop with Start-Sleep is now seen.\nEOF' \
        $'gh pr edit 5 --body-file - <<\'EOF\'\nPowerShell\'s While loop with Start-Sleep is now seen.\nEOF' \
        $'git commit -q -F - <<\'EOF\'\nfix: for ((i = 0; i < 3; i++)); do sleep 600; done\nEOF' \
        $'git commit -q -F - <<\'EOF\'\nwait: Start-Sleep -Seconds 600 before retry\nEOF' \
        $'gh pr create --body-file - <<\'EOF\'\nUse cmd\'s timeout /t 600 to wait\nEOF' \
        $'gh pr create --body-file - <<\'EOF\'\ndo { Start-Sleep 600 } while ($true)\nEOF' \
        $'gh pr create --body-file - <<\'EOF\'\nuse `sleep 600` and `timeout /t 600` as examples\nEOF' \
        $'gh pr create --body-file - <<\'EOF\'\n$(until false; do sleep 1; done)\nEOF' \
        $'git commit -q -F - <<EOF\nwhile you wait, Start-Sleep 600 $(date +%F)\nEOF' \
        $'git tag -a v1 -F - <<\'EOF\'\nwhile true; do sleep 600; done\nEOF' \
        $'gh issue comment 5 -F - <<\'EOF\'\nfor ((;;)); do sleep 1; done\nEOF' \
        $'gh release create v1 --notes-file - <<\'EOF\'\ndo { Start-Sleep 600 } until ($false)\nEOF' \
        $'git commit -q -F - <<\'EOF\'\nfix: sleep 600\nEOF\ngit status' \
        $'cat > notes.md <<\'EOF\'\nuntil false; do sleep 600; done\nEOF' \
        $'cat > notes.md <<EOF\nuntil false; do sleep 600; done\nEOF' \
        $'tee notes.md <<\'EOF\'\nStart-Sleep -Seconds 600\nEOF'; do
      guard 0 "$cmd"
    done
    guard 0 'git commit -q -m "wait: Start-Sleep -Seconds 600"' PowerShell
    for cmd in \
        $'python3 - <<\'EOF\'\nEOF' \
        $'bash <<\'EOF\'\nuntil false; do sleep 600; done\nEOF' \
        $'cat > x.sh <<\'EOF\'\nwhile true; do sleep 1; done\nEOF\nbash x.sh' \
        $'cat > x.sh <<\'EOF\'\nStart-Sleep -Seconds 600\nEOF\nsh x.sh' \
        $'cat > x.sh <<\'EOF\'\nuntil false; do sleep 1; done\nEOF\n. ./x.sh' \
        $'echo start; cat > x.sh <<\'EOF\'\nuntil false; do sleep 1; done\nEOF\nbash x.sh' \
        $'git commit -q -F - <<\'EOF\'\nmsg\nEOF\nwhile true; do sleep 1; done' \
        $'gh pr create --body-file - <<\'EOF\'\nmsg\nEOF\nsleep 600' \
        $'git commit -q -F - <<EOF\n$(until false; do sleep 1; done)\nEOF' \
        $'gh pr create --body-file - <<EOF\n$(sleep 600)\nEOF' \
        $'git commit -q -F - <<EOF\n`until false; do sleep 1; done`\nEOF' \
        $'cat > notes.md <<\'EOF\'\nmsg\nEOF\nbash -c "until false; do sleep 600; done"'; do
      guard 2 "$cmd"
    done
  fi
  guard_run
  guard_report "$git_fail" "the guard hook blocks a message or an unrun cat body that names a loop, a pause or a timed wait, or passes a body a shell, an interpreter or a runner executes (B50)" "the guard hook passes a commit's, tag's or gh message, and a cat or tee body nothing runs, that names a loop, a pause or a timed wait, and blocks a body a shell, an interpreter or a runner executes (B50)"

  # The hang check's loops and pauses (T39, as Godot-Director's T278 has them). A wait loop ends at the done that closes it as a command,
  # not at a done in its condition or in a quoted word, and the do and done of a loop nested in it are counted, so each loop below runs
  # to its own done. A pause with a fraction is judged as its whole part is (sleep 600.5, sleep 4.7m, Start-Sleep -Seconds 280.5).
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        'until [ -f done ]; do sleep 5; done' \
        'while [ "$x" = done ]; do sleep 5; done' \
        'while true; do for f in a b; do :; done; sleep 5; done' \
        'while true; do while read l; do :; done < f; sleep 5; done' \
        $'until false\ndo\n  for f in a; do echo $f; done\n  sleep 5\ndone' \
        'for ((;;)); do until true; do :; done; sleep 1; done' \
        'while true; do for f in a; do :; done;sleep 9;done' \
        'until [ -f done ]; do echo x; for f in a; do :; done; sleep 5; done' \
        'while true; do echo "done"; sleep 5; done' \
        "while true; do echo '; done'; sleep 5; done" \
        'sleep 600.5' 'sleep 280.5' 'echo x; sleep 300.0' 'sleep 4.7m'; do
      guard 2 "$cmd"
    done
    for cmd in \
        'while read l; do for f in a; do :; done; done < x; sleep 5' \
        'for f in a b; do while read l; do :; done < f; done' \
        'while true; do for f in a; do :; done; done; sleep 5' \
        'until [ -f x ]; do echo done; done' \
        'timeout 240 bash -c "while true; do for f in a; do :; done; sleep 5; done"' \
        'sleep 0.5' 'sleep 280.0' 'sleep 4.5m' 'sleep 1.'; do
      guard 0 "$cmd"
    done
    for cmd in 'Start-Sleep -Seconds 600.5' 'Start-Sleep 280.5' 'Start-Sleep -Milliseconds 280000.5'; do guard 2 "$cmd" PowerShell; done
    for cmd in 'Start-Sleep -Seconds 0.5' 'Start-Sleep -Milliseconds 280000.0' 'Start-Sleep -Milliseconds 279999.5'; do guard 0 "$cmd" PowerShell; done
  fi
  guard_run
  guard_report "$git_fail" "the guard hook doesn't end a wait loop at the done that closes it, doesn't read a pause with a fraction as its whole part, or blocks a loop a timeout bounds or a plain pause" "the guard hook reads each wait loop to its own done, judges a pause with a fraction as its whole part is, and passes the bounded and the short forms"

  # The view flags start empty (T39): a variable of the same name in the hook's environment changes nothing, so an exported vhang=1
  # doesn't skip the git rules, and the other per-view names (vcov, vdep, vpx, vps, cn_all, hsubb) change nothing either.
  env_fail=""
  printf '%s' '{"session_id":"s","tool_name":"Bash","tool_input":{"command":"git push --force origin main","description":"run"}}' > "$guard_dir/env.json"
  for v in vhang vcov vdep vpx vps cn_all hsubb; do
    env "$v=1" bash .claude/hooks/guard-commands.sh < "$guard_dir/env.json" >/dev/null 2>&1
    [ $? -eq 2 ] || env_fail="$env_fail"$'\n'"  with $v=1 in the environment the guard passes git push --force"
  done
  rm -f "$guard_dir/env.json"
  guard_report "$env_fail" "a variable in the hook's environment named like a per-view flag changes what the guard blocks" "a variable in the hook's environment named like a per-view flag changes nothing"

  # The credential-print rules read the text without a commit's, tag's or gh message, or a cat body nothing runs (T39): a message may
  # name gh auth token or git credential fill. A body a shell runs, a substitution in a message and a command after a message still block.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in 'git commit -q -m "docs: gh auth token is blocked"' \
        $'git commit -q -F - <<\'EOF\'\nfix: gh auth token is blocked\nEOF' \
        $'git commit -q -F - <<\'EOF\'\ndocs: git credential fill prints a token\nEOF' \
        $'gh pr edit 5 --body-file - <<\'EOF\'\nThe guard blocks gh auth token and git credential get.\nEOF' \
        $'cat > notes.md <<\'EOF\'\ngh auth token\nEOF'; do
      guard 0 "$cmd"
    done
    for cmd in 'gh auth token' \
        $'bash <<\'EOF\'\ngh auth token\nEOF' \
        $'git commit -q -F - <<EOF\n$(gh auth token)\nEOF' \
        $'git commit -q -F - <<\'EOF\'\nmsg\nEOF\ngh auth token' \
        $'cat > x.sh <<\'EOF\'\ngit credential fill\nEOF\nbash x.sh'; do
      guard 2 "$cmd"
    done
  fi
  guard_run
  guard_report "$git_fail" "the guard hook blocks a message or a cat body that names a credential print and runs nothing, or doesn't block one that runs" "the guard hook passes a message that names gh auth token or git credential fill, and blocks the commands that print a credential, a body a shell runs, and a substitution in a message"

  # The guard judges a 30 KB body in time (the hook's timeout is 10 seconds): 900 GDScript-like lines of $AnimationPlayer.play("walk_N"),
  # written by a Bash heredoc into cat > and by a PowerShell here-string assigned and written with Set-Content. Each runs under a UTF-8
  # locale, where the per-character walks cost the most, and must exit 0 in under 5 seconds (bash's time keyword starts no process).
  # The third case is a here-string whose lines all name py (T309), so the Python heredoc check opens its gate and reads each line.
  gd_body=""; py_body=""
  for ((gi = 1; gi <= 900; gi++)); do gd_body+="\$AnimationPlayer.play(\"walk_$gi\")"$'\n'; py_body+="\$copy_$gi = python3 -c \"print($gi)\""$'\n'; done
  slow_cmds=("cat > scripts/hero.gd <<'EOF'"$'\n'"$gd_body""EOF" "\$gd = @'"$'\n'"$gd_body""'@"$'\n'"Set-Content -Path scripts/hero.gd -Value \$gd" \
    "\$gd = @'"$'\n'"$py_body""'@"$'\n'"Set-Content -Path scripts/hero.py -Value \$gd")
  slow_tools=(Bash PowerShell PowerShell); slow_fail=""; slow_times=""
  TIMEFORMAT=%R
  for ((si = 0; si < ${#slow_cmds[@]}; si++)); do
    json_str "${slow_cmds[si]}"
    printf '{"session_id":"s","tool_name":"%s","tool_input":{"command":"%s","description":"run"}}' "${slow_tools[si]}" "$JSON_STR" > "$guard_dir/slow.json"
    { time LC_ALL=C.UTF-8 bash .claude/hooks/guard-commands.sh < "$guard_dir/slow.json" >/dev/null 2>&1; } 2>"$guard_dir/slow.time"
    slow_rc=$?
    slow_s="$(cat "$guard_dir/slow.time")"
    slow_times="$slow_times ${slow_tools[si]} ${slow_s}s"
    [ "$slow_rc" = 0 ] || slow_fail="$slow_fail"$'\n'"  (${slow_tools[si]}) the guard exited $slow_rc on a 30 KB body, expected 0"
    [ "${slow_s%%.*}" -lt 5 ] 2>/dev/null || slow_fail="$slow_fail"$'\n'"  (${slow_tools[si]}) the guard took ${slow_s}s on a 30 KB body, over 5 seconds"
  done
  unset TIMEFORMAT
  rm -f "$guard_dir/slow.json" "$guard_dir/slow.time"
  guard_report "$slow_fail" "the guard is too slow on a 30 KB body, or it exits non-zero on one" "the guard reads a 30 KB heredoc and here-string in under 5 seconds each:$slow_times"

  # A variable in a git command's words (B37): the guard can't read what it holds. A variable that the command assigns once,
  # to a plain value, is read as that value, so FLAG=--force; git push $FLAG is the force push it is. Any other unquoted
  # variable in the words of a git subcommand the rules read is blocked, and so is a quoted one that a flag or a path could
  # be, a fixed text that starts a flag (--$X), a variable as the subcommand, and a variable as a command's name followed by
  # -c or -Command. The everyday forms pass: a quoted variable as the value of -m, -e, -b or -C, after --, after fixed text
  # that doesn't start a flag, as a push's branch after its remote, and in a subcommand the rules don't read (git status).
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        'FLAG=--force; git push $FLAG' \
        'FLAG=-f; git push ${FLAG} origin' \
        'export ST=-f && git push $ST origin' \
        'FLAG=--force; git push "$FLAG"' \
        'FLAG=ok; FLAG=--force; git push $FLAG' \
        'FLAG=ok; read FLAG; git push $FLAG' \
        'NV=--no-verify; git commit $NV -m x' \
        'git commit $NV -m x' \
        "git commit \"\$NV\" -m x" \
        'git push $FLAG' \
        'git push "$FLAG"' \
        'git push origin $BR' \
        'git push --$X' \
        'git push "--$X"' \
        'git push -$F origin' \
        'git log $X' \
        'git log --output="$X"' \
        'git diff "$f"' \
        'git -C $d log' \
        'git $CMD --force' \
        'git commit -nm"$x" -- a' \
        'git commit -m$msg' \
        'git checkout -b $name' \
        'git reset --hard $REF' \
        'git branch -D "$b"' \
        'git grep "$p"' \
        $'bash <<\'EOF\'\ngit push $FLAG\nEOF' \
        "\$X -c 'git push --force'" \
        '"$SHELL" -c "git push --force"' \
        'sudo "$X" -c "git push --force"' \
        'env FOO=1 $X -c x' \
        'timeout 240 "$X" -c x' \
        'echo ok && $X -c x' \
        '"$EDITOR" -c x'; do
      guard 2 "$cmd"
    done
    for cmd in 'git commit $NV -m x' 'git push "$FLAG"' 'git push -u origin $BR' '$X -c "git push --force"' \
        '& $X -c "git push --force"'; do
      guard 2 "$cmd" PowerShell
    done
    for cmd in \
        'for r in A B C; do git -C work/$r status --short; done' \
        'git -C "work/$r" log --oneline -1' \
        'git -C "$repo" fetch' \
        'git -C $d status' \
        'git status $X' \
        'git add $FILE' \
        'git log --since="$since"' \
        'git commit -m "$msg" -- a' \
        'git commit -m"$msg" -- a' \
        'git commit -am "$msg"' \
        'git commit -C "$c"' \
        'git push -u origin "$branch"' \
        'git push origin "$a" "$b"' \
        'git checkout -b "ddd/bundle-$day"' \
        'git checkout -b "ddd/bundle-$day" origin/main' \
        'git switch -c "$b"' \
        'git grep -e "$p"' \
        'git tag -a "v$VER" -m "release"' \
        'git log --format="%h $X"' \
        'git log -- $X' \
        'git commit -m "$msg" -- $X' \
        'git log > "$out"' \
        'git log >"$out" --oneline' \
        'FLAG=ok; git push $FLAG' \
        'FLAG=--force; echo $FLAG' \
        'MSG=--force; git commit -m "$MSG"' \
        'a=1; git push $a' \
        'echo $X -c x' \
        'echo -n $X -c x' \
        'echo "$X -c y"' \
        '"$EDITOR" notes.txt' \
        'git commit -m "& $X -c y" -- a' \
        $'git commit -q -F - <<\'EOF\'\nfix the $X handling\nEOF'; do
      guard 0 "$cmd"
    done
    guard 0 'git push -u origin "$branch"' PowerShell
    guard 0 'git commit -m "$msg" -- a' PowerShell
  fi
  guard_run
  guard_report "$git_fail" "the guard hook reads a variable in a git command's words as a value it can't see, or blocks a plain form (B37)" "the guard hook reads a variable a git command assigns once as its value, blocks an unquoted or flag-capable variable in a git command's words, a variable as a subcommand or as a shell's name followed by -c, and passes the everyday forms (B37)"

  # A variable as a command's name, and a variable a shell's script or a script path holds (B45): the name a command assigns is
  # the name it runs (G=git; $G push --force is git), and an unresolved name that the command sets another way, or that a git
  # subcommand or a destructive flag follows, is blocked. A variable a shell's script (bash -c, eval, -Command) holds, or that a
  # script path under tools/ holds, is blocked too. The everyday forms pass: "$PY" -I script.py, a loop that runs "$PY" "$f", a
  # variable as an argument, and a single-quoted script's own variable (its shell reads it, and it can't name a command here).
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        'G=git; $G push --force' \
        '$G push --force' \
        '"$G" push --force' \
        'G=git; ${G} push --force' \
        'G=git; "$G" push --force' \
        '$G --force' \
        'if true; then $G push --force; fi' \
        'for f in x; do $G push --force; done' \
        '{ $G push --force; }' \
        'xargs $G push --force' \
        'find . -exec $G push --force \;' \
        'if true; then "$X" -c x; fi' \
        'CMD="git push --force"; $CMD' \
        'read CMD <<< "git push --force"; $CMD' \
        'FOO=$(echo git); $FOO push --force' \
        'X=../../evil.sh; bash tools/stacks/$X' \
        'bash tools/stacks/$X.sh' \
        'bash "tools/$X"' \
        'bash -c "$CMD"' \
        'eval "$CMD"' \
        'eval $CMD' \
        "bash -c '\$CMD'" \
        'CMD="git push --force" bash -c '"'"'$CMD'"'"'' \
        'sh -c "echo $HOME"' \
        $'G=git; bash <<\'EOF\'\n$G push --force\nEOF' \
        $'bash <<\'EOF\'\n$G push --force\nEOF' \
        $'CMD="git push --force" bash <<\'EOF\'\n$CMD\nEOF'; do
      guard 2 "$cmd"
    done
    for cmd in "\$G = 'git'; & \$G push --force" '& $G push --force'; do
      guard 2 "$cmd" PowerShell
    done
    guard 2 'powershell -Command "$P"' PowerShell
    for cmd in \
        'G=git; $G status' \
        'G=ls; $G push --force' \
        'echo $G push --force' \
        '"$PY" -I script.py' \
        'PY=python3; "$PY" -I script.py' \
        'FOO="a b" "$PY" -I x.py' \
        'for f in tools/*.py; do "$PY" "$f"; done' \
        'for f in a b; do echo "$f"; done' \
        'if true; then "$PY" -I x.py; fi' \
        'find . -name x -exec "$PY" -I y {} \;' \
        'xargs -I{} echo {}' \
        '"$PY" tools/usage.py status' \
        'bash "$script"' \
        'bash tools/check.sh "$X"' \
        'cd "$dir" && git status' \
        'bash -c "echo \$HOME"' \
        "bash -c 'echo \$HOME'" \
        $'git commit -q -F - <<\'EOF\'\n$G push --force\nEOF'; do
      guard 0 "$cmd"
    done
    guard 0 "powershell -Command 'Get-ChildItem | % { \$_.Name }'" PowerShell
  fi
  guard_run
  guard_report "$git_fail" "the guard hook doesn't read a variable as a command's name, or a script or script path that a variable holds, or blocks an everyday form (B45)" "the guard hook reads a variable as a command's name as the value it assigns, blocks an unresolved one that the command sets another way or a git subcommand follows, blocks a shell's script, eval or -Command that a variable holds and a tools/ script path with a variable, and passes the everyday forms (B45)"

  # An assignment is not a command, so it isn't read as a variable command name (B55): a PowerShell $x = 1, $x += 1 or $env:X = 'y',
  # and a PowerShell constant or automatic value that no call operator runs ($true, $null, $args), pass in a PowerShell payload and in
  # a PowerShell script a shell runs. A Bash NAME+=value is an assignment prefix, as NAME=value is. A call operator still runs
  # what its name holds, and a git subcommand after any name is still read: & $x, & $args[0], $args push --force and $G push
  # --force block, and so does out+=x $G push --force.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        '$x = 1' \
        '$files = Get-ChildItem docs' \
        '$x=1' \
        '$x += 1' \
        '$x ??= 1' \
        "\$env:X = 'y'" \
        '$x[0] = 1' \
        '$null = Get-Date' \
        '$true' \
        '$false' \
        '$null' \
        'while ($true) { Get-Date }' \
        '$args' \
        '$_.Name' \
        '$input | Out-Null'; do
      guard 0 "$cmd" PowerShell
    done
    for cmd in \
        "\$x = 1; & \$x" \
        "\$x = 'git'; & \$x push --force" \
        '$args push --force' \
        '& $args[0] push --force' \
        '$input | ForEach-Object { & $_ push --force }' \
        '& $env:COMSPEC push --force'; do
      guard 2 "$cmd" PowerShell
    done
    for cmd in \
        "powershell -Command 'while (\$true) { Get-Date }'" \
        "powershell -Command '\$x = 1'" \
        'c="${x:0:1}"; out+="$c"; echo hi' \
        'out+=x; echo hi'; do
      guard 0 "$cmd"
    done
    for cmd in \
        'out+=x $G push --force' \
        'out+=x; $G push --force' \
        'c+=y; "$c" push --force' \
        "powershell -Command '\$args push --force'" \
        "powershell -Command '\$G = \"git\"; & \$G status'"; do
      guard 2 "$cmd"
    done
  fi
  guard_run
  guard_report "$git_fail" "the guard hook reads an assignment or a constant as a variable command name, or passes a call operator or a NAME+=value prefix that runs a git command (B55)" "the guard hook passes a PowerShell assignment, a constant and an automatic value that runs nothing, and a Bash NAME+=value assignment, and blocks a call operator or a prefixed variable that runs git (B55)"

  # PowerShell's Invoke-Expression and iex (B60) run their one string argument as a script, as eval does. A literal argument is read as
  # a script of its own, and a variable the command assigns once to a plain literal before the call is read as its value. A pipeline into
  # the call, no argument, an argument that isn't one string (a concatenation, a second argument, a double-quoted $( the caller expands),
  # and a variable that can't be resolved (one set another way, in a branch, or after the call) are blocked. The benign forms pass.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        "iex 'git push --force'" \
        "Invoke-Expression 'git push --force'" \
        "Invoke-Expression -Command 'git push --force'" \
        "iex -Command:'git push --force'" \
        "IEX \"git push --force\"" \
        "iex 'git push --force' -Verbose" \
        "iex -Verbose 'git push --force'" \
        "iex '-Verbose git push --force'" \
        "Microsoft.PowerShell.Utility\\Invoke-Expression 'git push --force'" \
        "& iex 'git push --force'" \
        "ForEach-Object { iex 'git push --force' }" \
        "ForEach-Object {iex 'git push --force'}" \
        "\$x = 'git push --force'; iex \$x" \
        "\$x='git push --force'; iex \$x" \
        "\$x = 'git push --force'; Invoke-Expression \$x" \
        "\$x = 'git push --force'; iex \"\$x\"" \
        "\$x = \"git push --force\"; iex \$x" \
        "\$x = 'git push --force'; iex \${x}" \
        "\$x = 'git push --force'; iex \$x -Verbose" \
        "\$x = 'git push --force'; iex \$x | Out-Null" \
        "\$x = 'git'; iex \"\$x push --force\"" \
        "iex \$x" \
        "iex \"\$x\"" \
        "iex" \
        "iex \$x; \$x = 'git push --force'" \
        "\$x = 'git push --force' | Out-Null; iex \$x" \
        "\$x = 'ls'; iex \"\$x\" \"--force\"" \
        "\$x = 'ls'; iex \"\$x\"-f ''" \
        "\$x = 'ls'; iex \$x \$y" \
        "\$x = 'ls'; Set-Variable x 'git push --force'; iex \$x" \
        "\$x = 'ls'; . ./evil.ps1; iex \$x" \
        "\$x = 'ls'; Import-Module ./m.psm1; iex \$x" \
        "if (\$true) { \$x = 'ls' }; iex \$x" \
        "\$x = 'git push --force'; iex \$x[0]" \
        "\$x = 'ls'; \$x[0] = 'git push --force'; iex \$x" \
        "\$x = 'ls'; \$x += 'git push --force'; iex \$x" \
        "\$y = '\$x = ''git push --force'''; iex \$y; iex \$x" \
        "\$x = 'ls'; \$y = '\$x = ''git push --force'''; iex \$y; iex \$x" \
        "\$x = 'git push --force'; \$y = \$x; iex \$y" \
        "iex \"\$(Get-Content x.txt)\"" \
        "iex @args" \
        "\$x = 'Get-Date'; iex @x" \
        "iex ('git push' + ' --force')" \
        "iex 'git pu' + 'sh --force'" \
        "iex \"git push\" + \" --force\"" \
        "'git push --force' | iex" \
        "Get-Content x.ps1 | iex"; do
      guard 2 "$cmd" PowerShell
    done
    guard 2 "powershell -Command \"iex 'git push --force'\"" PowerShell
    for cmd in \
        "\$x = 'Get-Date'; iex \$x" \
        "\$x = 'Get-Date'; iex \"\$x\"" \
        "\$x = 'git status'; iex \$x" \
        "\$x = 'Get-Date'; \$y = 'git status'; iex \$x; iex \$y" \
        "\$x = 'git push --force'" \
        "\$x = 'git push --force'; iex 'Get-Date'" \
        "iex 'Get-Date'" \
        "iex 'Get-Date' -Verbose" \
        "Invoke-Expression -Command 'Get-Date' -Verbose" \
        "iex 'Write-Output \$x'" \
        "iex '\$x = 1'" \
        "iex \$true" \
        "iex 'Get-Date' | Out-Null" \
        "ForEach-Object { iex 'Get-Date' }" \
        "Get-Help Invoke-Expression" \
        "Get-Command iex" \
        "Write-Output 'iex git push --force'"; do
      guard 0 "$cmd" PowerShell
    done
  fi
  guard_run
  guard_report "$git_fail" "the guard hook doesn't read an Invoke-Expression or iex script as a command, or passes one it can't read (B60)" "the guard hook reads the string argument of Invoke-Expression and iex as a script, resolves a variable the command assigns once to a plain literal, blocks a pipeline into it, an argument that isn't one string and an unresolved variable, and passes the benign forms (B60)"

  # A git command name in another case (B46): PowerShell finds a command case-insensitively, and Windows finds GIT too, so GIT and
  # Git are git in every git rule. Only the name is matched so: git's subcommands and flags stay case-sensitive, as git reads them.
  # The git rules, the credential prints, a substitution in the words and a shell body that runs GIT block as their lowercase
  # forms do, and the everyday forms and a quoted or heredoc message that names git in another case pass.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        'GIT push --force origin main' \
        'Git commit --no-verify -m x' \
        'GIT reset --hard HEAD~1' \
        'GIT log --output=/tmp/probe.txt' \
        'Git diff --no-index a b' \
        'GIT commit -F /tmp/msg.txt' \
        'GIT grep -Oecho foo' \
        'GIT push origin :main' \
        'GIT branch -D x' \
        'GIT credential fill' \
        'Git credential get' \
        'GIT -c core.pager=calc log' \
        'Git push "$(echo --force)" origin main' \
        $'bash <<\'EOF\'\nGIT push --force\nEOF'; do
      guard 2 "$cmd" PowerShell
    done
    for cmd in 'GIT push --force origin main' 'Git commit --no-verify -m x'; do
      guard 2 "$cmd"
    done
    for cmd in \
        'GIT status' \
        'Git log --oneline -5' \
        'GIT diff HEAD' \
        'GIT grep -n foo' \
        'GIT tag -a v1 -m "see --force and -F"' \
        'echo "Git push --force is blocked"' \
        'echo "Git credential fill is blocked"' \
        $'Git commit -q -F - <<\'EOF\'\nfix the --output and --no-index handling, not -F /tmp/x\nEOF'; do
      guard 0 "$cmd" PowerShell
    done
    guard 0 'GIT status'
  fi
  guard_run
  guard_report "$git_fail" "the guard hook passes a git command name in another case, or blocks a message that names git in another case (B46)" "the guard hook blocks a git command name in any case (GIT, Git) as it blocks git, and passes the everyday forms and the messages that name git in another case (B46)"

  # A shell's name in a bash script path under tools/ (B47): a quoted name is the same shell as the bare one, and so is one in another
  # case (PowerShell and Windows find a command case-insensitively). So "bash", 'sh' and BASH lead a path that leaves tools/ as bash
  # and sh do, and a quoted or split path, and a wrapper's script that names the shell in any case, are read too. The everyday forms
  # pass, and so does a message or an echo that names a shell with its path.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        '"bash" tools/../x.sh' \
        "'sh' tools/stacks/../../x.sh" \
        'BASH tools/stacks/../../x.sh' \
        'Bash tools/../x.sh' \
        '"bash" "tools/../x.sh"' \
        'sh -x "tools/stacks/../x.sh"' \
        'BASH -x tools/stacks/../x.sh' \
        '"/bin/bash" tools/../x.sh' \
        'bash tools/".."/x.sh' \
        "bash 'tools/../x.sh'" \
        'env "bash" tools/../x.sh' \
        '"bash" ./tools/../x.sh' \
        '"BASH" -c "BASH tools/../x.sh"' \
        "sh -c 'BASH tools/../x.sh'" \
        '"bash" tools/stacks/$X.sh' \
        $'echo x\n"bash" tools/../x.sh'; do
      guard 2 "$cmd"
    done
    for cmd in '"bash" tools/../x.sh' 'BASH tools/stacks/../../x.sh'; do
      guard 2 "$cmd" PowerShell
    done
    for cmd in \
        'bash tools/check.sh' \
        '"bash" tools/check.sh' \
        'BASH tools/check.sh' \
        "'sh' tools/stacks/dotnet.sh --since HEAD~3..HEAD" \
        'echo "bash" tools/../x.sh' \
        'echo "BASH tools/../x.sh"' \
        'git commit -m "bash tools/../x.sh"' \
        'cat "sh" tools/../x.sh' \
        'git status'; do
      guard 0 "$cmd"
    done
    guard 0 '"bash" tools/check.sh' PowerShell
  fi
  guard_run
  guard_report "$git_fail" "the guard hook passes a bash script path that leaves tools/ when its shell's name is quoted or in another case (B47)" "the guard hook blocks a script path under tools/ that leaves it, when bash or sh is quoted or in any case, and passes the everyday forms and the messages that name a shell (B47)"

  # Git's configuration keys and program flags (B38). A -c key, or --config-env, that names a program git runs (an alias that
  # starts with !, the pager, the editor, the ssh command, a diff or credential helper, an include) is blocked, and so is a key a
  # variable holds; the keys that run nothing pass (core.quotepath, color.*, advice.*, log.*, user.name, pager.<cmd>=false). The
  # flags that name a program for a remote (--upload-pack, --receive-pack, --exec, and clone's -u), abbreviations included, are
  # blocked on fetch, pull, push, clone, ls-remote and archive, and a plain fetch, push -u and clone -b pass. A variable that names
  # a program git runs (GIT_CONFIG_*, GIT_SSH_COMMAND, GIT_PAGER, GIT_EDITOR, EDITOR) set on a git command is blocked too.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        'git -c alias.x="!echo hi" x' \
        "git -c 'alias.x=!echo hi' x" \
        'git -c "alias.x=!echo hi" x' \
        'git -c core.pager="sh -c x" log' \
        'git -c core.sshCommand=x fetch' \
        'git -c diff.external=x diff' \
        'git -c "$k=v" log' \
        'git -c Alias.X=y x' \
        'git -c core.quotepath=false -c alias.x=y x' \
        'git -c color.ui=always -c core.pager=x log' \
        'git -c sequence.editor=x rebase -i HEAD~2' \
        "git -c credential.helper='!x' fetch origin" \
        'git -c protocol.ext.allow=always fetch origin' \
        'git -c include.path=/tmp/x log' \
        'git -c "core.$(echo pager)=x" log' \
        'git -c pager.log=less log' \
        'git --config-env=core.pager=PAGER_VAR log' \
        'git --git-dir .git -c alias.x=y x' \
        "git -c \$'alias.x=!echo hi' x" \
        "git -c 'alias.x=y' x" \
        'git -c "alias.x" x' \
        'git -c "a""lias.x=!echo" x' \
        'git -c "core.pager"=sh x' \
        'k=core.pager; git -c "$k=sh" log' \
        $'git \\\n-c core.pager=x log' \
        'git clone -c core.sshCommand=x https://example.com/r.git d' \
        'git clone --config=alias.x=y https://example.com/r.git d' \
        'git clone --config alias.x=y https://example.com/r.git d' \
        'git clone -c alias.x=y https://example.com/r.git d' \
        'git clone -u "sh -c x" https://example.com/r.git d' \
        'git clone --upload-pack="sh -c x" https://example.com/r.git d' \
        'git clone -qu "sh -c x" https://example.com/r.git d' \
        'git fetch --upload-pack x origin' \
        'git fetch --upl=x origin' \
        'git fetch --upload-pack="$(echo x)" origin' \
        'git fetch "--$(echo upload-pack)=x" origin' \
        'git pull --upload-pack=x' \
        'git push --receive-pack=x origin main' \
        'git push --receive-pack x origin main' \
        'git push --exec=x origin main' \
        'git push origin main --receive=x' \
        'git ls-remote --upload-pack=x origin' \
        'git archive --remote=origin --exec=x HEAD' \
        'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.pager GIT_CONFIG_VALUE_0=x git log' \
        'GIT_SSH_COMMAND=x git fetch' \
        'GIT_PAGER=x git log' \
        'GIT_EXTERNAL_DIFF=x git log -p' \
        'env GIT_EDITOR=x git commit' \
        'export GIT_PAGER=x; git log' \
        'EDITOR=x git commit -a'; do
      guard 2 "$cmd"
    done
    for cmd in 'git -c core.pager=x log' 'git -c "$k=v" log' 'git fetch --upload-pack=x' 'git -c alias.x=!echo x' \
        '$env:GIT_PAGER="x"; git log'; do
      guard 2 "$cmd" PowerShell
    done
    for cmd in \
        'git -c core.quotePath=false status --porcelain --untracked-files=all' \
        'git -c core.quotepath=off log --oneline -3' \
        'git -c color.ui=never log --oneline' \
        'git -c user.name=selftest -c user.email=selftest@localhost commit -m x' \
        "git -c 'user.name=A B' commit -m x" \
        'git -c advice.detachedHead=false checkout HEAD~1' \
        'git -c log.showSignature=false log -1' \
        'git -c pager.log=false log --oneline' \
        'git -c "color.ui=always" diff --stat' \
        'k=color.ui; git -c "$k=always" log --oneline' \
        'git -C work/SaaSAllTheThings fetch' \
        'git -c core.quotepath=false -C work/SaaSAllTheThings status' \
        'git clone -b main https://example.com/r.git d' \
        'git clone -q --depth 1 https://example.com/r.git d' \
        'git clone -c core.quotepath=false https://example.com/r.git d' \
        'git fetch origin' \
        'git fetch --unshallow origin' \
        'git push -u origin "$branch"' \
        'git push origin main' \
        'git push --recurse-submodules=check origin main' \
        'git ls-remote origin' \
        'git archive --format=tar HEAD' \
        'git pull --rebase origin main' \
        'git log -c' \
        'git commit -c HEAD' \
        'git commit -m "--upload-pack=x fix"' \
        'git commit -m "alias.x=!echo hi"' \
        'git tag -a v1 -m "-c alias.x=y"' \
        'git commit -m "set EDITOR=vim and GIT_PAGER=x"' \
        'GIT_AUTHOR_NAME=x git commit -m y' \
        'FOO=1 git status' \
        'EDITORCONFIG=x git status' \
        $'git commit -q -F - <<\'EOF\'\nGIT_PAGER=x and EDITOR=vim in a message\nEOF' \
        $'git \\\n-c core.quotepath=false status'; do
      guard 0 "$cmd"
    done
    guard 0 'git -c user.email=a@b.c commit -m x' PowerShell
    guard 0 'git -c color.ui=always status' PowerShell
    guard 0 'git push -u origin main' PowerShell
  fi
  guard_run
  guard_report "$git_fail" "the guard hook passes a git -c key or a program flag that runs a command, or a variable that names one, or blocks a plain form (B38)" "the guard hook blocks a git -c key that names a program (an alias, the pager, the ssh command, a diff or credential helper), a key a variable holds, a program flag for a remote (--upload-pack, --receive-pack, --exec, clone's -u), and a GIT_CONFIG_*, GIT_PAGER or EDITOR variable on a git command; the keys that run nothing and the plain forms pass (B38)"

  # A quoted git name, a heredoc body a shell runs, the long forms and a credential subcommand in quotes (B39). The git name is
  # read as the shell reads it, quotes removed, so "git", 'git' and g"it" are git. A heredoc body a shell runs (any body but a
  # commit's or tag's message) is read by the file-writing flag rules, and a backtick ends a flag in it. git branch with --delete
  # and --force (-d -f, -df, --del --forc), git push --mirror, --delete and -d (abbreviations too) and a :ref refspec are blocked,
  # as their plain forms are, and the credential-print rules read the decoded words. A message that names them, and a read that
  # names none, pass: a commit's or tag's message is text no shell runs.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        '"git" push --force' \
        "'git' push --force" \
        'g"it" push --force' \
        '"git" log --output=/tmp/x' \
        $'bash <<\'EOF\'\ngit log --output=/tmp/x\nEOF' \
        $'sh <<EOF\ngit diff --no-index a b\nEOF' \
        $'bash <<\'EOF\'\ngit commit -F /tmp/msg.txt\nEOF' \
        $'bash <<\'EOF\'\ngit grep -Oecho foo\nEOF' \
        $'cat <<\'EOF\' | bash\ngit log --output=/tmp/x\nEOF' \
        $'bash <<\'EOF\'\ngit branch --delete --force x\nEOF' \
        $'bash <<\'EOF\'\ngit push --mirror\nEOF' \
        $'bash <<\'EOF\'\ngit credential "fill"\nEOF' \
        $'bash <<\'EOF\'\ngit push `echo --force`\nEOF' \
        $'bash <<\'EOF\'\ngit push --force`echo x`\nEOF' \
        $'ssh host <<\'EOF\'\ngit push `echo --force`\nEOF' \
        $'git status && bash <<\'EOF\'\ngit push `echo --force`\nEOF' \
        $'"bash" <<\'EOF\'\ngit push --mirror\nEOF' \
        $'git commit -m "$(source /dev/stdin <<\'EOF\'\ngit push `echo --force`\nEOF\n)"' \
        'sh -c "git push --mirror"' \
        'git branch --delete --force x' \
        'git branch --delete -f x' \
        'git branch -d -f x' \
        'git branch -df x' \
        'git branch -fd x' \
        'git branch --del --forc x' \
        'git push --mirror' \
        'git push --mirror origin' \
        'git push --mi origin' \
        'git push --delete origin x' \
        'git push --de origin x' \
        'git push -d origin x' \
        'git push -fd origin x' \
        'git push origin :x' \
        'git push origin ":x"' \
        'git push origin :refs/heads/x' \
        'git credential "fill"' \
        "git credential 'get'" \
        'git credential fi"ll"' \
        'gh "auth" "token"' \
        'g"h" auth token'; do
      guard 2 "$cmd"
    done
    for cmd in \
        'git branch -d x' \
        'git branch -vv' \
        'git branch -m old new' \
        'git branch --list "*f*"' \
        'git push origin main:main' \
        'git push origin HEAD:refs/heads/x' \
        'git push --dry-run origin main' \
        'git push --set-upstream origin x' \
        'echo "git push --mirror"' \
        'echo "git credential fill"' \
        'git log --grep "push --mirror"' \
        'git status && echo "git credential fill"' \
        $'git commit -q -F - <<\'EOF\'\nfix: git push --mirror and git branch -d x\nEOF' \
        $'git commit -q -F - <<\'EOF\'\nfix: git log --output=x in the docs\nEOF' \
        $'git commit -q -F - <<\'EOF\'\nmsg with `git push --force` in it\nEOF' \
        $'git tag -a v1 -F - <<\'EOF\'\nfix: git push --delete origin x\nEOF' \
        $'git commit -q -F - <<\'EOF\'\nfix the --mirror and --delete flags, not -d\nEOF' \
        $'bash <<\'EOF\'\necho hi\nEOF' \
        $'bash <<\'EOF\'\ngit status\nEOF' \
        $'bash <<\'EOF\'\ngit branch -d x\nEOF' \
        $'git status && bash <<\'EOF\'\necho x\nEOF'; do
      guard 0 "$cmd"
    done
    for cmd in '"git" push --force' 'git branch --delete --force x' 'git push --mirror' 'git push origin :x' \
        'git credential "fill"' 'gh "auth" "token"'; do
      guard 2 "$cmd" PowerShell
    done
    for cmd in 'git branch -d x' 'git push origin main'; do
      guard 0 "$cmd" PowerShell
    done
  fi
  guard_run
  guard_report "$git_fail" "the guard hook doesn't read a quoted git name, a heredoc body a shell runs, a long-form branch or push flag, a push refspec that deletes, or a quoted credential subcommand as the shell does, or blocks a message that names a plain form (B39)" "the guard hook blocks a quoted git name, a heredoc body a shell runs with a file-writing flag, a backtick flag or a destructive command, git branch --delete --force, git push --mirror, --delete or a :ref refspec, and a quoted credential subcommand, and passes the messages and reads that name them (B39)"

  # A heredoc body no shell runs is text (B40): a commit's or tag's message, and a cat or tee body that the command doesn't run (no
  # shell, interpreter, ssh, chmod, make, a ./ path, a dot-source or the .git folder). The destructive rules and the file-writing flag
  # rules skip such a body, so a message or a written file that names a destructive git command passes, and its substitutions are
  # still read. A body written to a file and run in the same command (cat > x.sh, then bash x.sh, ./x.sh or . x.sh) is a script a
  # shell runs, and is read as before. The guard reads command text, so a file written by an earlier command isn't judged.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        $'git commit -q -F - <<\'EOF\'\nfix: git push --force; done\nEOF' \
        $'git tag -a v1 -F - <<\'EOF\'\nfix: git push --delete origin x\nEOF' \
        $'git commit -q -F - <<\'EOF\'\nmsg with `git push --force` in it\nEOF' \
        $'git commit -m "$(cat <<\'EOF\'\nfix: git reset --hard\nEOF\n)"' \
        $'git commit -q -F - <<\'EOF\'\nfix: git log --output=x in the docs\nEOF\nbash x.sh' \
        $'cat > notes.md <<\'EOF\'\nsee git log --output=x\nEOF' \
        $'cat > notes.md <<\'EOF\'\na backticked `git push --force` here\nEOF' \
        $'tee notes.md <<\'EOF\'\ngit push --mirror\nEOF' \
        $'cat <<\'EOF\' > notes.md\ngit reset --hard\nEOF' \
        $'cat >> notes.md <<\'EOF\'\ngit branch -D x\nEOF' \
        $'cat > notes.md <<\'EOF\'\ngit push --force\nEOF\ngit add notes.md && git status' \
        $'cat > ./notes.md <<\'EOF\'\ngit grep -Oecho foo\nEOF' \
        $'cat > notes.md <<\'EOF\'\nbash -c \'git push --force\'\nEOF' \
        $'cat > notes.md <<EOF\nplain text, no git here\nEOF' \
        $'cat > notes.md <<\'EOF\'\ngit push --force\nEOF\necho "run bash later"' \
        $'cat > notes.md <<\'EOF\'\ngit push --force\nEOF\ngit commit -q -F - <<\'EOF2\'\nfix: git push --force\nEOF2'; do
      guard 0 "$cmd"
    done
    for cmd in \
        $'cat > x.sh <<EOF\ngit push --force\nEOF\nbash x.sh' \
        $'cat > x.sh <<\'EOF\'\ngit push --force\nEOF\nbash x.sh' \
        $'cat > x.sh <<\'EOF\'\ngit push --force\nEOF\nchmod +x x.sh && ./x.sh' \
        $'cat > x.sh <<\'EOF\'\ngit reset --hard\nEOF && sh x.sh' \
        $'cat > x.sh <<\'EOF\'\ngit log --output=/tmp/x\nEOF\nbash x.sh' \
        $'cat > x.sh <<\'EOF\'\ngit push --force\nEOF\nsource x.sh' \
        $'tee x.sh <<\'EOF\'\ngit push --force\nEOF\n. ./x.sh' \
        $'cat > x.sh <<\'EOF\'\ngit push --force\nEOF\n"bash" x.sh' \
        $'cat > x.sh <<\'EOF\'\ngit push --force\nEOF\npython3 x.sh' \
        $'cat > x.sh <<\'EOF\'\ngit push --force\nEOF\nenv bash x.sh' \
        $'cat > Makefile <<\'EOF\'\npush:\n\tgit push --force\nEOF\nmake push' \
        $'cat > .git/hooks/pre-commit <<\'EOF\'\ngit push --force\nEOF\ngit commit -q -m x' \
        $'cat > notes.md <<EOF\n$(git push --force)\nEOF' \
        $'cat > notes.md <<EOF\n`git push --force`\nEOF' \
        $'git commit -q -F - <<EOF\nfix `git push --force`\nEOF' \
        $'cat <<\'EOF\' | bash\ngit push --force\nEOF' \
        $'bash <<\'EOF\'\ngit push --force\nEOF'; do
      guard 2 "$cmd"
    done
    guard 2 $'cat > x.ps1 <<\'EOF\'\ngit push --force\nEOF\n& ./x.ps1' PowerShell
  fi
  guard_run
  guard_report "$git_fail" "the guard hook reads a commit's or tag's message, or a cat or tee body that nothing in the command runs, as a script (B40), or passes a body a shell runs" "the guard hook passes a commit's or tag's message and a cat or tee body that the command doesn't run, and blocks a body written to a file and run in the same command (B40)"

  # A gh message with a quoted delimiter (B48): gh pr create and edit, issue create, edit and comment, and release create and edit
  # take the body from stdin (--body-file -, -F -, --notes-file -) or from a $(cat <<'EOF') given to --body, -b, --notes or -n. That
  # body is text no shell runs, as a commit's message is (B40), so the destructive rules skip it, and the variable rules (B37)
  # skip it and a cat body nothing runs. A body a shell runs, an unquoted body with a substitution, a git command that goes on past
  # the body, or a body piped to a shell is still read.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        $'gh pr edit 5 --body-file - <<\'EOF\'\nfix: git push --force; done\nEOF' \
        $'gh pr create --body "$(cat <<\'EOF\'\nfix: git push --force\nEOF\n)"' \
        $'gh pr create --title t --body-file - <<\'EOF\'\nDo not run git push --force\nEOF' \
        $'gh issue comment 5 -F - <<\'EOF\'\ngit reset --hard\nEOF' \
        $'gh issue create -b "$(cat <<\'EOF\'\ngit branch -D x\nEOF\n)"' \
        $'gh release create v1 --notes-file - <<\'EOF\'\ngit push --mirror\nEOF' \
        $'gh release edit v1 -n "$(cat <<\'EOF\'\ngit push --delete origin x\nEOF\n)"' \
        $'gh pr create --body-file=- <<\'EOF\'\ngit push --force\nEOF' \
        $'GH pr create -F- <<\'EOF\'\ngit push --force\nEOF' \
        $'gh pr create --body="$(cat <<\'EOF\'\ngit push --force\nEOF\n)"' \
        $'gh pr edit 5 --body-file - <<\'EOF\'\ngit push --force\nEOF' \
        $'gh pr create --body-file - <<\'EOF\'\nbash -c \'git push --force\'\nEOF' \
        $'gh pr create --body-file - <<\'EOF\'\necho cmd /c "git push --force"\nEOF' \
        $'gh pr edit 5 --body-file - <<\'EOF\'\nfix: git push $X handling\nEOF' \
        $'git commit -q -F - <<\'EOF\'\nfix: git push $X handling\nEOF' \
        $'git tag -a v1 -F - <<\'EOF\'\nfix: git push $X handling\nEOF' \
        $'cat > notes.md <<\'EOF\'\nfix: git push $X handling\nEOF'; do
      guard 0 "$cmd"
    done
    for cmd in \
        $'gh pr edit 5 --body-file - <<\'EOF\' && git push --force\nmsg\nEOF' \
        $'gh pr create --body-file - <<\'EOF\'\nmsg\nEOF\ngit push --force' \
        $'gh pr create --body-file - <<\'EOF\' | bash\ngit push --force\nEOF' \
        $'gh pr create --body-file - <<EOF\nfix: git push --force\nEOF' \
        $'gh pr create --body "$(cat <<EOF\n$(git push --force)\nEOF\n)"' \
        $'gh pr create --body "$(cat <<\'EOF\'\nmsg\nEOF\n)" --title "$(git push --force)"' \
        $'bash <<\'EOF\'\ngit push $X\nEOF' \
        $'cat > x.sh <<\'EOF\'\ngit push $X\nEOF\nbash x.sh'; do
      guard 2 "$cmd"
    done
    # A shell or PowerShell name right after a word that only prints its words (echo, printf, Write-Output, Write-Host, write) is
    # text (B48). Anywhere else it may run a script, so a launcher's argument stays read: ssh, find -exec, docker exec, Start-Process.
    for cmd in \
        "echo PowerShell 'bash tools/../x.sh'" \
        "echo pwsh 'bash tools/../x.sh'" \
        "echo bash -c 'git push --force'" \
        'echo sh -c "git push --force"' \
        $'printf sh -c \'git push --force\'' \
        $'echo eval \'git push --force\'' \
        'echo PowerShell -Command "git push --force"'; do
      guard 0 "$cmd"
    done
    for cmd in \
        'ssh host pwsh -c "git push --force"' \
        'find . -exec pwsh -c "git push --force" \;' \
        'docker exec ctr pwsh -c "git push --force"' \
        'ssh host sh -c "git push --force"' \
        'find . -exec sh -c "git push --force" \;' \
        $'docker exec ctr bash -c \'git push --force\''; do
      guard 2 "$cmd"
    done
    for cmd in \
        'Write-Output PowerShell -Command "git push --force"' \
        "Write-Output powershell 'bash tools/../x.sh'" \
        "echo pwsh 'bash tools/../x.sh'" \
        "Write-Host Pwsh.exe 'bash tools/../x.sh'"; do
      guard 0 "$cmd" PowerShell
    done
    for cmd in \
        "Start-Process powershell -ArgumentList 'git push --force'" \
        'ssh host pwsh -c "git push --force"' \
        'timeout 60 powershell -c "git push --force"'; do
      guard 2 "$cmd" PowerShell
    done
  fi
  guard_run
  guard_report "$git_fail" "the guard hook reads a gh message's body, or a variable in a message or a cat body nothing runs, as a command, passes a body a shell runs, or reads a word after echo, printf, Write-Output, Write-Host or write, or a launcher's argument, wrongly (B48)" "the guard hook passes a gh pr, issue or release message with a quoted delimiter, and a variable in a message or in a cat body nothing runs, and blocks a git command after a message, an unquoted message, a message piped to a shell, and a variable in a body a shell runs; a shell or PowerShell name after echo, printf, Write-Output, Write-Host or write is text, and one that a launcher passes a script to is read (B48)"

  # SaaSAllTheThings' own rules, read as the git rules are: deleting Azure resources (azd down, az ... delete), a complete-mode
  # deployment, a Key Vault secret read (show, download, backup) and az ad app or sp credential reset (a client secret) are the
  # human's. The az and azd names are read in any case and with .cmd, .exe or .bat, after a path or with quotes around the name
  # or a word; a continuation, a tab, a comment, a wrapper (bash -c, eval, powershell -Command, cmd /c), a substitution and a
  # heredoc body a shell runs are read like the plain command. Both tools get the same cases. A message that names a command is text.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        'azd down --purge' \
        'azd down' \
        'azd down;echo done' \
        'az group delete -n rg-orderdesk-dev --yes' \
        'az cosmosdb delete -n x -g y' \
        'az servicebus namespace delete -n x -g y' \
        'az deployment group create -g rg --template-file main.bicep --mode Complete' \
        'az deployment group create -g rg --template-file main.bicep --mode=complete' \
        'az deployment group create -g rg --template-file main.bicep --mode "Complete"' \
        'az keyvault secret show --vault-name kv --name db' \
        'az keyvault secret download --vault-name kv --name db --file f' \
        'az keyvault secret backup --vault-name kv --name db --file f' \
        'az ad app credential reset --id 123' \
        'az ad sp credential reset --id 123 --append' \
        'AZ group delete -n rg' \
        'AZD down' \
        'az.cmd group delete -n rg' \
        'az.exe group delete -n rg' \
        'azd.exe down' \
        '/usr/bin/az group delete -n rg' \
        '"az" group delete -n rg' \
        "'azd' down" \
        'a"z" group delete -n rg' \
        'az group "delete" -n rg' \
        'az "group" delete -n rg' \
        'az keyvault secret "show" --name x' \
        'cd infra && az group delete -n rg --yes' \
        'az account show && az group delete -n rg' \
        'true | az group delete -n rg' \
        'FLAG=1 az group delete -n rg' \
        'env az group delete -n rg' \
        'timeout 60 azd down' \
        $'cd x\naz group delete -n rg' \
        $'cd x\n\taz group delete -n rg' \
        $'az\tgroup\tdelete -n rg' \
        $'az group delete\necho done' \
        $'# note\\\naz group delete -n rg' \
        $'az account show # note\\\naz group delete -n rg' \
        'bash -c "az group delete -n rg --yes"' \
        "sh -c 'azd down'" \
        'eval "az group delete -n rg"' \
        'powershell -Command "az group delete -n rg --yes"' \
        'pwsh -c "azd down"' \
        'cmd /c "az group delete -n rg"' \
        'timeout 30 bash -c "az keyvault secret show --name x"' \
        'echo $(az group delete -n rg --yes)' \
        'echo "$(az keyvault secret show --name x --query value)"' \
        'x=$(az ad sp credential reset --id 1)' \
        'echo `az group delete -n rg`' \
        $'bash <<\'EOF\'\naz group delete -n rg\nEOF' \
        $'cat > x.sh <<\'EOF\'\nazd down\nEOF\nbash x.sh'; do
      guard 2 "$cmd"
      guard 2 "$cmd" PowerShell
    done
    # Bash's backslash escapes a quote, so a script nested in a script is read through both (PowerShell's escape is the backtick).
    guard 2 'bash -c "bash -c \"az group delete -n rg\""'
    # A backslash at a line's end continues a Bash command, so the lines are one command. In PowerShell it is a path separator,
    # no continuation (its escape is the backtick, below), so the second line is a command of its own and the first runs nothing.
    for cmd in \
        $'az group \\\ndelete -n rg' \
        $'a\\\nz group delete -n rg' \
        $'az keyvault secret \\\nshow --name x'; do
      guard 2 "$cmd"
      guard 0 "$cmd" PowerShell
    done
    for cmd in \
        '& az group delete -n rg' \
        '& "az" group delete -n rg' \
        '& az.cmd group delete -n rg' \
        $'az group `\ndelete -n rg' \
        $'a`\nz group delete -n rg' \
        $'# note`\naz group delete -n rg' \
        'az account show; az group delete -n rg' \
        'Invoke-Expression "az group delete -n rg"' \
        'iex "azd down"' \
        'powershell -c "& az group delete -n rg"' \
        'az group delete -n rg 2>&1 | Out-Null'; do
      guard 2 "$cmd" PowerShell
    done
    for cmd in \
        'az account show' \
        'az group list -o table' \
        'az group show -n rg' \
        'az deployment group what-if -g rg --template-file infra/main.bicep' \
        'az deployment group create -g rg --template-file main.bicep --mode Incremental' \
        'az keyvault secret list --vault-name kv' \
        'az keyvault secret set --vault-name kv --name x --value y' \
        'az ad app federated-credential create --id 1 --parameters fc.json' \
        'az ad app show --id 1' \
        'az bicep build --file infra/main.bicep' \
        'az storage blob upload --name delete.txt -f a.txt' \
        'azd up' \
        'azd env list' \
        'azd provision --preview' \
        'bash tools/check.sh && az account show' \
        'lazy delete' \
        'grep -n delete docs/index.md' \
        'echo "az group delete is for the human"' \
        "echo 'azd down'" \
        'git commit -m "docs: az group delete and azd down are for the human" -- a.md' \
        "git commit -m 'fix: keyvault secret show is blocked' -- a.cs" \
        $'git commit -q -F - <<\'EOF\'\nazd down, az group delete and az keyvault secret show are the human\'s\nEOF' \
        $'cat > notes.md <<\'EOF\'\naz group delete -n rg\nEOF\ngit add notes.md' \
        'bash -c "az account show"' \
        'echo $(az account show)' \
        $'cd x\naz account show'; do
      guard 0 "$cmd"
      guard 0 "$cmd" PowerShell
    done
  fi
  guard_run
  guard_report "$git_fail" "the guard hook doesn't read an az or azd command that deletes a resource, a complete-mode deployment, a Key Vault secret read or a client secret reset as the shell does, or blocks a plain Azure command or a message that names one" "the guard hook blocks azd down, az ... delete, a complete-mode deployment, a Key Vault secret read and az ad app or sp credential reset in the Bash and the PowerShell tool, with the name in any case, quoted, with .cmd or .exe or after a path, on a continued line, after a comment, in a tab-separated command, in a wrapper's script, a substitution or a heredoc body a shell runs, and passes the plain Azure commands and the messages that name them"

  # SaaSAllTheThings' Az PowerShell module: a Remove-Az cmdlet deletes Azure resources as az ... delete does, so the guard reads it the
  # same way. The name is blocked in any case, after a module or a path (Az.Resources\Remove-AzResourceGroup, .\Remove-AzResource), in
  # each reading the az rule takes: a continued line, a comment, a wrapper's script, a substitution, a PowerShell backtick, a
  # heredoc body a shell runs. The Get-Az reads pass, and so does a message that only names a cmdlet: a commit's or tag's -m value
  # (one word or more) and a heredoc body nothing runs. Both tools get the same cases, except the ones that depend on a line break.
  git_fail=""
  if [ -f .claude/hooks/guard-commands.sh ]; then
    for cmd in \
        'Remove-AzResourceGroup -Name rg -Force' \
        'remove-azresourcegroup -Name rg' \
        'REMOVE-AZRESOURCE -ResourceId x' \
        'Remove-AzStorageAccount -Name x -ResourceGroupName rg' \
        'Remove-AzureRmResourceGroup -Name rg' \
        'Remove-AzContext -Force' \
        'Az.Resources\Remove-AzResourceGroup -Name rg' \
        'Az.Resources\remove-azresourcegroup -Name rg' \
        'Microsoft.PowerShell.Management\Remove-AzResource -ResourceId x' \
        '.\Remove-AzResourceGroup -Name rg' \
        'C:\Modules\Az\Remove-AzResource -ResourceId x' \
        "'Remove-AzResourceGroup' -Name rg" \
        '"Remove-AzResourceGroup" -Name rg' \
        "& 'Az.Resources\\Remove-AzResourceGroup' -Name rg" \
        'Get-AzResourceGroup -Name rg | Remove-AzResourceGroup -Force' \
        'Get-AzResourceGroup -Name rg; Remove-AzResourceGroup -Name rg' \
        'bash tools/check.sh && Remove-AzResourceGroup -Name rg' \
        'git commit -m "Remove-AzResourceGroup" && Remove-AzResourceGroup -Name rg' \
        'git commit -m Remove-AzResourceGroup; Remove-AzResourceGroup -Name rg' \
        'echo $(Remove-AzResourceGroup -Name rg)' \
        'echo "$(Remove-AzResourceGroup -Name rg)"' \
        'powershell -Command "Remove-AzResourceGroup -Name rg -Force"' \
        "pwsh -c 'Remove-AzResourceGroup -Name rg'" \
        'bash -c "Remove-AzResourceGroup -Name rg"' \
        'timeout 60 Remove-AzResourceGroup -Name rg' \
        'Start-Job { Remove-AzResourceGroup -Name rg }' \
        "Start-Process powershell -ArgumentList 'Remove-AzResourceGroup -Name rg'" \
        $'Get-AzResource -Name x\nRemove-AzResource -ResourceId y' \
        $'# note\\\nRemove-AzResourceGroup -Name rg' \
        $'bash <<\'EOF\'\nRemove-AzResourceGroup -Name rg\nEOF'; do
      guard 2 "$cmd"
      guard 2 "$cmd" PowerShell
    done
    # A line break that a shell joins (a backslash in Bash) joins the name, and a PowerShell backtick does; PowerShell's backslash is a
    # path separator, so the same split name passes there, as it does for az group delete above.
    guard 2 $'Remove-Az\\\nResourceGroup -Name rg'
    guard 0 $'Remove-Az\\\nResourceGroup -Name rg' PowerShell
    guard 2 $'Remove-Az`\nResourceGroup -Name rg' PowerShell
    guard 2 'Remo`ve-AzResourceGroup -Name rg' PowerShell
    guard 2 'Invoke-Expression "Remove-AzResourceGroup -Name rg"' PowerShell
    guard 2 'iex "Remove-AzResource -ResourceId x"' PowerShell
    for cmd in \
        'Get-AzResourceGroup -Name rg' \
        'Get-AzResource -Name x | Select-Object Name' \
        'Remove-Item -Path x' \
        'git commit -m "Remove-AzResourceGroup"' \
        'git commit -m "docs: Remove-AzResourceGroup is for the human" -- a.md' \
        'git commit -am Remove-AzResourceGroup' \
        'git commit --message=Remove-AzResourceGroup -- a.md' \
        'git tag -a v1 -m Remove-AzResource' \
        'echo "Remove-AzResourceGroup is for the human"' \
        'Write-Output "Remove-AzResourceGroup is for the human"' \
        $'git commit -q -F - <<\'EOF\'\nRemove-AzResourceGroup is for the human\nEOF' \
        $'cat > notes.md <<\'EOF\'\nRemove-AzResourceGroup -Name rg\nEOF\ngit add notes.md'; do
      guard 0 "$cmd"
      guard 0 "$cmd" PowerShell
    done
  fi
  guard_run
  guard_report "$git_fail" "the guard hook doesn't read a Remove-Az cmdlet (the Az PowerShell module's delete) as it reads az ... delete, or blocks a Get-Az read or a message that names a cmdlet" "the guard hook blocks a Remove-Az cmdlet in any case, after a module or a path, quoted, joined, after a comment, in a wrapper's script, a substitution, Invoke-Expression or a heredoc body a shell runs, in the Bash and the PowerShell tool, and passes the Get-Az reads and the messages that name a cmdlet"

  # A command's name written as a path (B61): a quoted command with a space in its path, or a backslash path, is read as its last part
  # (git.exe, az.cmd, Remove-AzResourceGroup) in the Bash and the PowerShell tool, after a prefix, a separator or a call operator. A path
  # that is an argument, a message or a heredoc body nothing runs is text, and an escaped name (g\it) is still the shell's name.
  for cmd in \
      '"C:\Program Files\Git\bin\git.exe" push --force' \
      '& "C:\Program Files\Git\cmd\git.exe" push --force' \
      '& '"'"'C:\Program Files\Az\Remove-AzResourceGroup'"'"' -Name rg' \
      '"C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd" group delete -n rg' \
      '"C:\Program Files\Azure CLI\az.cmd" group delete -n rg' \
      'C:\bin\az.cmd group delete -n rg' \
      '.\az.cmd group delete -n rg' \
      '..\tools\az.cmd group delete -n rg' \
      'C:\Git\bin\git.exe push --force' \
      '"C:\Git\bin\git.exe" push --force' \
      'FOO=1 "C:\Program Files\Git\bin\git.exe" push --force' \
      'env "C:\Program Files\Git\bin\git.exe" push --force' \
      'cd x && "C:\Program Files\Git\bin\git.exe" push --force' \
      'true; "C:\Program Files\Git\bin\git.exe" push --force' \
      '"/usr/bin/git" push --force' \
      'echo $("C:\Program Files\Git\bin\git.exe" push --force)' \
      "bash -c '\"C:\\Program Files\\Git\\bin\\git.exe\" push --force'" \
      "powershell -Command \"& 'C:\\Program Files\\Az\\Remove-AzResourceGroup' -Name rg\"" \
      $'bash <<\'EOF\'\n"C:\\Program Files\\Git\\bin\\git.exe" push --force\nEOF'; do
    guard 2 "$cmd"
    guard 2 "$cmd" PowerShell
  done
  guard 2 'g\it push --force' # Bash only: in PowerShell a backslash is a path, so g\it is not git there
  for cmd in \
      'git commit -q -m "docs: C:\Program Files\Git\bin\git.exe push --force is blocked"' \
      'echo "C:\Program Files\Az"' \
      "& 'C:\\Program Files\\Git\\bin\\git.exe' status" \
      '"C:\Program Files\Git\bin\git.exe" log -1' \
      '"C:\Program Files\Git\bin\git.exe" push origin main' \
      'git log "C:\Program Files\Git\bin\git.exe"' \
      'cp "C:\x y\git.exe" backup' \
      'echo C:\bin\az.cmd group delete' \
      "bash -c '\"C:\\Program Files\\Git\\bin\\git.exe\" log -1'" \
      $'cat > notes.md <<\'EOF\'\n"C:\\Program Files\\Git\\bin\\git.exe" push --force\nEOF\ngit add notes.md' \
      'Write-Output "C:\Program Files\Az\Remove-AzResourceGroup"' \
      'Get-AzResource -Name "C:\x y\Remove-AzResourceGroup"' \
      '& "C:\Program Files\Az\Get-AzResourceGroup" -Name rg'; do
    guard 0 "$cmd"
    guard 0 "$cmd" PowerShell
  done
  guard_run
  guard_report "$git_fail" "the guard hook doesn't read a quoted command's path, or a backslash path, as the command's name, so git, az or a Remove-Az cmdlet passes behind it, or it blocks a path that is an argument, a message or a body nothing runs" "the guard hook blocks git, az and Remove-Az behind a quoted path with a space, a backslash path, a prefix, a separator, a call operator, a wrapper and a heredoc body a shell runs, in the Bash and the PowerShell tool, and passes the paths that are arguments, messages and bodies nothing runs, and an escaped name"

  # Python that reads its script from a heredoc (T309), whatever the body is. The interpreter is python, python3, python3.13, pythonw or py,
  # with or without .exe, bare or behind a path with / or \, quoted or not; with - or without it, with options before it (-u, -X utf8,
  # py's -3); from a heredoc in each of its forms (<<E, <<'E', <<"E", <<\E, <<-E) or a here-string; behind a wrapper or in a chain; piped
  # in from a heredoc (cat <<'E' | python -) and, in PowerShell, from a here-string; split by a continuation; in a heredoc body a shell
  # runs; and as the first half of the node fallback form (B64). Each is blocked in the Bash and the PowerShell tool and the message names
  # python. A script file fed data from a heredoc, -c, -m, --version and a message, echo, grep or unrun cat body that names the form pass.
  for cmd in \
      $'python - <<\'E\'\nprint(1)\nE' \
      $'python <<\'E\'\nprint(1)\nE' \
      $'python3 - <<\'E\'\nprint(1)\nE' \
      $'python3 <<E\nprint(1)\nE' \
      $'python3.13 - <<\'E\'\nprint(1)\nE' \
      $'pythonw - <<\'E\'\nprint(1)\nE' \
      $'py - <<\'E\'\nprint(1)\nE' \
      $'python.exe - <<\'E\'\nprint(1)\nE' \
      $'py.exe - <<\'E\'\nprint(1)\nE' \
      $'/usr/bin/python3 - <<\'E\'\nprint(1)\nE' \
      $'"C:/Program Files/Python313/python.exe" - <<\'E\'\nprint(1)\nE' \
      $'"C:\\Program Files\\Python313\\python.exe" - <<\'E\'\nprint(1)\nE' \
      $'C:\\Python313\\python.exe - <<\'E\'\nprint(1)\nE' \
      $'"python3" - <<\'E\'\nprint(1)\nE' \
      $'python3 -u - <<E\nprint(1)\nE' \
      $'python3 -X utf8 - <<E\nprint(1)\nE' \
      $'py -3 - <<E\nprint(1)\nE' \
      $'python3 -u <<E\nprint(1)\nE' \
      $'python3 - <<E\nprint(1)\nE' \
      $'python3 - <<"E"\nprint(1)\nE' \
      $'python3 - <<\\E\nprint(1)\nE' \
      $'python3 - <<-E\n\tprint(1)\n\tE' \
      $'python3 - <<EOF\nEOF' \
      $'python - <<<\'print(1)\'' \
      $'python <<<"print(1)"' \
      $'timeout 60 python - <<E\nprint(1)\nE' \
      $'env X=1 python - <<E\nprint(1)\nE' \
      $'cd x && python - <<E\nprint(1)\nE' \
      $'python3 - <<E 2>/dev/null || true\nprint(1)\nE' \
      $'cat <<\'E\' | python -\nprint(1)\nE' \
      $'cat <<E | python3\nprint(1)\nE' \
      $'@\'\nprint(1)\n\'@ | python -' \
      $'@"\nprint(1)\n"@ | python' \
      $'bash <<\'X\'\npython3 - <<\'E\'\nprint(1)\nE\nX' \
      $'# it\'s\npython3 - <<\'E\'\nprint(1)\nE'; do
    guard 2 "$cmd" Bash python
    guard 2 "$cmd" PowerShell python
  done
  # B64: the form with a node fallback. Its quoted string closes on the second line, so the shell starts the heredoc's body after it, and
  # the body is empty; the quoted string may hold anything.
  for cmd in \
      $'python3 - <<\'E\' 2>/dev/null || node -e "\nx()"\nE' \
      $'python3 - <<\'E\' 2>/dev/null || node -e "\nconsole.log(\'a\')"\nE' \
      $'python3 - <<\'E\' 2>/dev/null || node -e \'\nx()\'\nE'; do
    guard 2 "$cmd" Bash python
    guard 2 "$cmd" PowerShell python
  done
  guard 2 $'python3 \\\n- <<\'EOF\'\nprint(1)\nEOF' Bash python   # Bash only: a backslash joins a line in Bash, not in PowerShell
  guard 2 $'python3 `\n- <<\'EOF\'\nprint(1)\nEOF' PowerShell python
  for cmd in \
      $'python tool.py <<\'E\'\ndata\nE' \
      $'python3 tool.py --flag <<E\ndata\nE' \
      $'python3 -u tool.py <<E\ndata\nE' \
      $'py -3 tool.py <<E\ndata\nE' \
      $'/usr/bin/python3 tool.py <<\'E\'\ndata\nE' \
      $'python3 -c "print(1)"' \
      $'python -c "print(1)" <<\'E\'\ndata\nE' \
      $'python -m json.tool <<\'E\'\n{"a":1}\nE' \
      $'python3 -m mod' \
      $'python3 --version' \
      $'python3 tool.py' \
      $'python3 - < script.py' \
      $'cat <<E | python3 tool.py\ndata\nE' \
      $'git commit -q -F - <<\'E\'\nfix: python3 - <<\'X\' is blocked\nE' \
      $'git commit -q -m "docs: python3 - <<\'E\' hangs"' \
      $'git commit -q -m "x; python3 - <<\'E\'"' \
      $'git tag -a v1 -F - <<\'E\'\npython3 - <<\'X\'\nprint(1)\nX\nE' \
      $'gh pr create --body-file - <<\'E\'\npython3 - <<\'X\'\nprint(1)\nX\nE' \
      $'echo "python3 - <<\'E\'"' \
      $'echo "never run python3 - <<\'E\'"' \
      $'grep -n "python3 - <<\'EOF\'" docs.md' \
      $'cat > notes.md <<\'E\'\npython3 - <<\'X\'\nprint(1)\nX\nE'; do
    guard 0 "$cmd"
    guard 0 "$cmd" PowerShell
  done
  guard_run
  guard_report "$git_fail" "the guard hook doesn't block a Python that reads its script from a heredoc, a here-string or a heredoc piped into it, whatever the body is, or it blocks a script file fed data from a heredoc, -c, -m or a message that names the form (T309, B64)" "the guard hook blocks python, python3, python3.13, pythonw and py, path-qualified or quoted, reading a script from a heredoc in every form, a here-string, a pipe from a heredoc or a PowerShell here-string, behind a wrapper, in a chain, after a continuation, in a heredoc body a shell runs and before a node fallback, in the Bash and the PowerShell tool, and passes a script file fed data, -c, -m, --version and the messages that name the form (T309, B64)"

  # Python with nothing to run (Director-Driven-Development B66): python3 -, python or py -3 with no script, no -c, no -m and nothing
  # fed to it waits for input that never comes, so it is blocked bare, with options, behind a path, a quote or a wrapper, in a chain,
  # with a time limit above it or a redirect after it, in the Bash and the PowerShell tool, and the refusal names it. A file fed to it
  # (python3 - < x.py), a pipe into it, a script file, -c, -m, --version and the like, and text that names Python (command -v python3,
  # pip install python, a quoted message) pass.
  bare_msg='python with no script'
  for cmd in \
    'python3 -' \
    'python' \
    'py -3' \
    'python3 2>/dev/null || true' \
    'python3 - 2>/dev/null; sed -n 1p x' \
    'python -' \
    'python3' \
    'pythonw' \
    'python3.13 -' \
    'python.exe' \
    'py' \
    'py -3.13' \
    'PYTHON3' \
    'Python.EXE -' \
    '/usr/bin/python3 -' \
    'C:/Python313/python.exe -' \
    'C:\Python313\python.exe' \
    '"C:/Program Files/Python313/python.exe" -' \
    $'\'/usr/bin/python3\' -' \
    'python3 -u' \
    'python3 -u -' \
    'python3 -X utf8' \
    'python3 -Xutf8 -' \
    'python -W ignore -' \
    'python3 -B -E' \
    'cd x && python3 -' \
    'cd x; python3 -' \
    'false || python3 -' \
    'python3 - && echo ok' \
    'python3 - | tee log' \
    'python3 2>&1 | head' \
    'python3 - &' \
    'python3 >out.txt' \
    'python3 > out.txt 2>&1' \
    'python3 &> out.txt' \
    'timeout 60 python3 -' \
    'timeout -k 5 60 python3 -' \
    'timeout 2m python' \
    'env python3 -' \
    '/usr/bin/env python3 -' \
    'env X=1 python3 -' \
    'X=1 python3 -' \
    'PYTHONPATH="a b" python3 -' \
    'sudo python3 -' \
    'nohup python3 -' \
    'nice -n 5 python3 -' \
    'time python3 -' \
    'exec python3 -' \
    'command python3 -' \
    'winpty python' \
    'uv run python' \
    'poetry run python3 -' \
    'if python3 -; then echo x; fi' \
    'x=$(python3 -)' \
    '(python3 -)' \
    '{ python3 -; }' \
    '! python3 -' \
    'echo "a"; python3 -; echo "b"' \
    $'echo \'a\'; python3 -; echo \'b\'' \
    $'cd x\npython3 -\necho done' \
    'python3 -c "print(1)"; python3 -' \
    'cat x | head; python3 -' \
    'bash -c "python3 -"' \
    'eval "python3 -"' \
    $'python3 \\\n  -' \
    $'python3 \\\n  -u \\\n  -' \
    $'timeout 60 \\\n  python3 -' \
    $'# note \\\npython3 -' \
    $'cat <<E | head\nx\nE\npython3' \
    $'bash <<\'X\'\npython3 -\nX'; do
    guard 2 "$cmd" Bash "$bare_msg"
  done
  for cmd in \
    'python -' \
    'python' \
    'python | Out-Null' \
    'python 2>$null' \
    'python *> $null' \
    '& python -' \
    '& python.exe' \
    'py -3' \
    'Set-Location x; python -' \
    $'python `\n  -' \
    $'echo \'a\'; python -; echo \'b\''; do
    guard 2 "$cmd" PowerShell "$bare_msg"
  done
  for cmd in \
    'python3 - < x.py' \
    'python3 < x.py' \
    'python3 -u - < x.py' \
    'python3 - </dev/null' \
    'cat x.py | python3 -' \
    'cat x.py | python3' \
    'cat x | timeout 60 python3 -' \
    'git show HEAD:x.py | python3 -' \
    'cat x |& python3 -' \
    'python3 --version' \
    'python --version 2>&1' \
    'python3 -V' \
    'python3 -VV' \
    'python3 -h' \
    'python3 --help' \
    'python3 --help-env' \
    'python -?' \
    'py --list' \
    'py --list-paths' \
    'py -0' \
    'py -0p' \
    'py -V:3.13 x.py' \
    'python3 -c "print(1)"' \
    'python3 -c print' \
    'python -m pytest' \
    'python3 -mpytest' \
    'python3 -um pip list' \
    'python3 -Bc "x"' \
    'python3 x.py' \
    'python3 tool.py --flag' \
    'python -I script.py' \
    'python3 -u x.py' \
    'python3 -X utf8 x.py' \
    'python3 -Xdev x.py' \
    'python -W ignore x.py' \
    'py -3 x.py' \
    'py -3 -c "x"' \
    'py install 3.13' \
    'python3 "$f"' \
    'python3 $f' \
    'python3 "x y.py"' \
    'python3 $(ls x.py)' \
    'if python3 --version; then echo x; fi' \
    'command -v python' \
    'command -V python3' \
    'command -v python3 >/dev/null || echo no' \
    'which python3' \
    'where python' \
    'where.exe python' \
    'type python' \
    'type -p python3' \
    'hash python' \
    'pip install python' \
    'winget install python' \
    'brew install python' \
    'apt install python3' \
    'choco install python' \
    'echo python' \
    'echo python3 -' \
    'printf "%s" python' \
    'grep -rn python .' \
    'rg python' \
    'ls python' \
    'cd python' \
    'mkdir py' \
    'cat py' \
    'git add python' \
    'git log --grep python' \
    'case "$x" in python) echo y ;; esac' \
    'PY=python3' \
    'PY="python3"' \
    'PY=python3; $PY x.py' \
    'export PY=python3' \
    'export PY="python3"' \
    'x=$(command -v python3)' \
    '[ -x python ]' \
    'test -f python' \
    'git commit -m "python3 -"' \
    $'git commit -m \'run python\'' \
    'echo "a; python3 -; b"' \
    'gh pr view 1 --json body -q .body' \
    'find . -name "*.py" -exec python3 {} \;' \
    'ls *.py | xargs python3' \
    'xargs python3' \
    'python3 <(cat x.py)' \
    'sed -n "/python/p" x' \
    'node -e "python"' \
    $'git commit -m "a\npython\nb"' \
    $'echo \'x\npython3 -\ny\'' \
    $'cat > x.sh <<\'E\'\npython3 -\nE' \
    $'git commit -F - <<\'E\'\npython\nE' \
    $'python3 \\\n  tool.py' \
    $'python3 \\\n  tool.py --flag \\\n  --other' \
    $'python3 \\\n  -c "print(1)"' \
    $'python3 -u \\\n  x.py' \
    $'timeout 60 \\\n  python3 tool.py' \
    $'python3 \\\n  - < x.py' \
    $'cat x.py | \\\n  python3 -' \
    $'cat x.py |\n  python3 -' \
    $'# note \\\npython3 tool.py' \
    $'python3 tool.py <<\'PY\'\ndata\nPY' \
    $'python3 tool.py <<PY\ndata\nPY' \
    $'node x.js <<-PY\n\tdata\n\tPY' \
    $'ruby x.rb <<"python"\ndata\npython' \
    $'gh pr create --title t --body-file - <<\'E\'\npython3 -\nE'; do
    guard 0 "$cmd"
  done
  for cmd in \
    'Get-Content x.py -Raw | python -' \
    'Get-Command python' \
    '(Get-Command python).Source' \
    'gcm python' \
    'Write-Output python' \
    'Write-Host python' \
    'python --version' \
    $'python -c \'print(1)\'' \
    'python x.py' \
    'Start-Process python' \
    $'python `\n  x.py' \
    $'python `\n  -c \'print(1)\'' \
    $'Get-Content x.py -Raw |\n  python -' \
    'if (Get-Command python -ErrorAction SilentlyContinue) { python --version }'; do
    guard 0 "$cmd" PowerShell
  done
  # Each quoted string is blanked on its own: a command between two of them is still read (a long sleep between two echoes).
  guard 2 'echo "a"; sleep 999; echo "b"' Bash 'sleep 999'
  guard_run
  guard_report "$git_fail" "the guard hook passes a Python with no script, no -c, no -m and nothing fed to it, or blocks one that has a script, a file or a pipe fed to it, or text that names Python (B66)" "the guard hook blocks a Python with nothing to run, bare, behind a path, a quote or a wrapper, in a chain, in the Bash and the PowerShell tool, and passes one that has a script, a file or a pipe fed to it, and text that names Python (B66)"

  # The PowerShell tool (B24) has its own name. The guard runs for it only when the hook's matcher names it,
  # and a Bash(...) deny or ask rule stops the same command in PowerShell only through its PowerShell(...)
  # twin, in the same list. The allow list names no PowerShell command, so nothing PowerShell runs is allowed
  # without a prompt. Read(...) rules are the Read tool's; PowerShell's own file reads are not covered here.
  ps_fail=""
  guard_matcher=$(awk -F'"' '/"matcher"/ { m = $4 } /guard-commands\.sh/ { print m; exit }' .claude/settings.json)
  for tool in Bash Monitor PowerShell; do
    case "|$guard_matcher|" in
      *"|$tool|"*) ;;
      *) ps_fail="$ps_fail"$'\n'"  the guard hook's matcher \"$guard_matcher\" doesn't name $tool" ;;
    esac
  done
  for list in deny ask; do
    arr=$(sed -n "/\"$list\": *\[/,/\]/p" .claude/settings.json)
    while IFS= read -r rule; do
      [ -n "$rule" ] || continue
      twin="PowerShell(${rule#Bash(}"
      printf '%s\n' "$arr" | grep -qF "\"$twin\"" \
        || ps_fail="$ps_fail"$'\n'"  settings.json's $list rules have $rule but no $twin"
    done <<< "$(printf '%s\n' "$arr" | grep -oE '"Bash\([^"]*\)"' | tr -d '"')"
  done
  printf '%s\n' "$perm_allow" | grep -q 'PowerShell(' \
    && ps_fail="$ps_fail"$'\n'"  settings.json's allow list names a PowerShell command, so PowerShell would run it without a prompt"
  # The Az PowerShell module's delete (the Remove-Az rule): the PowerShell tool denies every Remove-Az cmdlet, as it denies az group delete.
  sed -n '/"deny": *\[/,/\]/p' .claude/settings.json | grep -qF '"PowerShell(Remove-Az*)"' \
    || ps_fail="$ps_fail"$'\n'"  settings.json's deny list lacks PowerShell(Remove-Az*), so the PowerShell tool would run a Remove-Az cmdlet without a prompt"
  guard_report "$ps_fail" "the PowerShell tool isn't wired to the guard and the deny rules (B24), or its deny list lacks the Remove-Az cmdlets" "the guard hook's matcher names PowerShell, every Bash deny rule has a PowerShell twin, the allow list names no PowerShell command, and the deny list denies PowerShell(Remove-Az*)"
fi

# --- guard-protected hook -------------------------------------------------------------------------


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
authority ask "an edit to the prototype script" '{"tool_name":"Edit","tool_input":{"file_path":"/home/u/app/tools/prototype.sh","old_string":"a","new_string":"b"}}'
authority ask "an edit to the pre-push hook" '{"tool_name":"Edit","tool_input":{"file_path":"/home/u/app/.githooks/pre-push","old_string":"a","new_string":"b"}}'

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

# The compliance questions: one set, used by onboarding, assess and the two workshops.
cq="$src/framework/.satt/reference/compliance-questions.md"
{ [ -f "$cq" ] && grep -q 'Security framework' "$cq" && grep -q 'Regulations' "$cq" && grep -q 'Audit and evidence' "$cq"   && grep -q 'never assume' "$cq" && grep -q 'never from the agent.s memory' "$cq" && grep -q 'controls: to add' "$cq" && grep -q 'marks nothing met' "$cq"; }   && ok "reference/compliance-questions.md asks the security framework, regulations, auditor and evidence, and never takes controls from memory" || bad "reference/compliance-questions.md lacks a question or the no-memory rule"
missing=""
for f in ONBOARDING.md framework/.satt/procedures/assess.md framework/.satt/workshops/vision.md framework/.satt/workshops/tenancy-identity.md; do
  grep -q 'compliance-questions.md' "$src/$f" || missing="$missing $f"
done
[ -z "$missing" ] && ok "onboarding, assess and the vision and tenancy-identity workshops point at the compliance questions" || bad "not pointing at compliance-questions.md:$missing"

# OWASP is a non-negotiable baseline.
grep -q 'OWASP is the baseline' "$src/framework/.satt/rules.md" && grep -q 'OWASP API Security Top 10' "$src/framework/.satt/rules.md"   && grep -q 'no project setting' "$src/framework/.satt/rules.md" && grep -q 'An accepted ADR may deviate from a single item' "$src/framework/.satt/rules.md"   && ok "rules.md states the OWASP baseline as framework-owned, with an ADR as the only way to deviate from an item" || bad "rules.md lacks the OWASP baseline rule"
n=$(grep -c '^| OWASP A[01][0-9] .*(baseline: keep) |' "$map"); [ "$n" = 10 ] && ok "the seed mapping has the ten OWASP baseline rows" || bad "the seed mapping has $n OWASP baseline rows, expected 10"
for i in 01 02 03 04 05 06 07 08 09 10; do grep -q "^| OWASP A$i " "$map" || bad "the seed mapping lacks OWASP A$i"; done
grep '^| OWASP' "$map" | grep -q '| direct |' && bad "an OWASP baseline row says direct" || ok "no OWASP baseline row says direct"
missing=""
for p in architect review align; do grep -q 'OWASP' "$src/framework/.satt/procedures/$p.md" || missing="$missing $p"; done
[ -z "$missing" ] && ok "architect, review and align name the OWASP baseline" || bad "procedures that don't name the OWASP baseline:$missing"
grep -q 'removed baseline row' "$src/framework/.satt/procedures/align.md" && ok "align reports a removed baseline row" || bad "align lacks the removed baseline row report"
grep -q 'OWASP' "$src/ONBOARDING.md" && ok "onboarding names the OWASP baseline" || bad "ONBOARDING.md doesn't name the OWASP baseline"

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

# --- Stop hook, per session ---------------------------------------------------------------------
# Two sessions can share one working folder (a design session and a build session, no worktree). The Stop hook runs the
# check only for a session that wrote or edited a source file itself: session-touched.sh keeps that record by the
# session_id in the hook input (a file tool's PostToolUse; for Bash and PowerShell the git status before and after the
# command). So a design session that edits only Markdown never waits for, or is blocked by, another session's
# uncommitted code. A throwaway repository holds it, with a stand-in check that records that it ran and fails while
# .satt/state/fail exists, and scripted hook inputs.
echo "stop hook, per session"
sr="$work/session-stop"; new_repo "$sr"
sr_hooks="$src/framework/.claude/hooks"
mkdir -p "$sr/tools" "$sr/src"
cat > "$sr/tools/check.sh" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in --fingerprint) cat src/*.cs 2>/dev/null | git hash-object --stdin; exit 0 ;; esac
: > .satt/state/check-ran
if [ -f .satt/state/fail ]; then echo "domain-purity: src/Billing.cs reads the clock"; exit 1; fi
exit 0
EOF
printf '/.satt/state/\n' > "$sr/.gitignore"
git -C "$sr" add -A >/dev/null 2>&1; git_q -C "$sr" commit -qm "a stand-in check" >/dev/null 2>&1
sr_state="$sr/.satt/state"
sr_nl=$'\n'
_sr_wrote() { # _sr_wrote <session> <tool> <path> [path key] [event]: a file tool's PostToolUse input, through the tracker
  printf '{"session_id":"%s","cwd":"%s","hook_event_name":"%s","tool_name":"%s","tool_input":{"%s":"%s","content":"x"},"tool_response":{"success":true}}' \
    "$1" "$sr" "${5:-PostToolUse}" "$2" "${4:-file_path}" "$3" | CLAUDE_PROJECT_DIR="$sr" bash "$sr_hooks/session-touched.sh" after 2>&1
}
_sr_cmd() { # _sr_cmd <session> before|after <tool> [event]: a Bash or PowerShell command's PreToolUse or PostToolUse input
  printf '{"session_id":"%s","cwd":"%s","hook_event_name":"%s","tool_name":"%s","tool_input":{"command":"make"}}' \
    "$1" "$sr" "${4:-PostToolUse}" "$3" | CLAUDE_PROJECT_DIR="$sr" bash "$sr_hooks/session-touched.sh" "$2" 2>&1
}
_sr_stop() { # _sr_stop <hook input>: the Stop hook's output; the exit status is the hook's
  printf '%s' "$1" | CLAUDE_PROJECT_DIR="$sr" bash "$sr_hooks/stop-check.sh" 2>&1
}
_sr_stop_as() { _sr_stop "{\"session_id\":\"$1\",\"transcript_path\":\"/x/y.jsonl\",\"hook_event_name\":\"Stop\",\"stop_hook_active\":false}"; }
_sr_rec() { cat "$sr_state/sessions/$1.touched" 2>/dev/null; }
_sr_ran() { [ -e "$sr_state/check-ran" ]; }

# 1. A design session that edits only Markdown, while a build session has uncommitted source in the same folder.
put "$sr/src/Billing.cs" 'class Billing {}'
_sr_wrote build Write "$sr/src/Billing.cs" >/dev/null
_sr_wrote design Write "$sr/docs/notes.md" >/dev/null
_sr_wrote design Edit "$sr/TASKS.md" >/dev/null
_sr_wrote design MultiEdit "$sr/product/prd.md" >/dev/null
out="$(_sr_rec build)"; expect_output "records the source file a session wrote, from the project root" '^src/Billing\.cs$' "$out"
if [ ! -e "$sr_state/sessions/design.touched" ]; then ok "records nothing for a session that edited only Markdown"; else bad "records nothing for a session that edited only Markdown" "$(_sr_rec design)"; fi
: > "$sr_state/fail"   # a check that would fail, as the other session's unfinished code makes it
out="$(_sr_stop_as design)"; status=$?
expect_status "the Stop hook exits 0 for a design session while another session has uncommitted source in the folder" 0 "$status" "$out"
if _sr_ran; then bad "the check doesn't run for the session that edited only Markdown"; else ok "the check doesn't run for the session that edited only Markdown"; fi
_sr_wrote kinds Write "$sr/adr/ADR-9-x.md" >/dev/null
_sr_wrote kinds NotebookEdit "$sr/analysis/model.ipynb" notebook_path >/dev/null
_sr_wrote kinds Write "$sr/.satt/state/building" >/dev/null
_sr_wrote kinds Write "/elsewhere/Outside.cs" >/dev/null
_sr_wrote kinds Write "$sr/README.md" >/dev/null
out="$(_sr_rec kinds)"
[ "$out" = "adr/ADR-9-x.md${sr_nl}analysis/model.ipynb" ] && ok "records an ADR and a notebook as source, and skips Markdown, the state folder and a file outside the project" \
  || bad "records an ADR and a notebook as source, and skips Markdown, the state folder and a file outside the project" "$out"

# 2. The build session that wrote source gets the check, is blocked once for a failure, and not twice for the same one.
: > "$sr_state/fail"
out="$(_sr_stop_as build)"; status=$?
expect_status "the session that wrote source gets the check, and is blocked when it fails" 2 "$status" "$out"
expect_output "and is given the check's output" 'domain-purity' "$out"
if _sr_ran; then ok "the check ran for it"; else bad "the check ran for it"; fi
rm -f "$sr_state/check-ran"
out="$(_sr_stop_as build)"; status=$?
expect_status "the same failure isn't reported twice" 0 "$status" "$out"
if _sr_ran; then bad "and the check isn't run again for it"; else ok "and the check isn't run again for it"; fi

# 3. A Bash or PowerShell command is read from git's list of changed files before and after it.
_sr_cmd shell before Bash >/dev/null
sleep 1
put "$sr/src/Made.cs" 'class Made {}'
put "$sr/notes.md" '# notes'
_sr_cmd shell after Bash >/dev/null
out="$(_sr_rec shell)"
[ "$out" = "src/Made.cs" ] && ok "a Bash command that creates a source file is recorded, and a Markdown file and a file already changed before it are not" \
  || bad "a Bash command that creates a source file is recorded, and a Markdown file and a file already changed before it are not" "$out"
_sr_cmd shell2 before PowerShell PreToolUse >/dev/null
sleep 1
printf '// edited by a command\n' >> "$sr/src/Billing.cs"
_sr_cmd shell2 after PowerShell PostToolUseFailure >/dev/null
out="$(_sr_rec shell2)"
[ "$out" = "src/Billing.cs" ] && ok "a PowerShell command that modifies a file changed before it is recorded, one that fails too" \
  || bad "a PowerShell command that modifies a file changed before it is recorded, one that fails too" "$out"
_sr_cmd shell3 before Bash >/dev/null; _sr_cmd shell3 after Bash >/dev/null
if [ ! -e "$sr_state/sessions/shell3.touched" ]; then ok "a command that changes nothing records nothing"; else bad "a command that changes nothing records nothing" "$(_sr_rec shell3)"; fi
_sr_cmd shell4 after Bash >/dev/null
if [ ! -e "$sr_state/sessions/shell4.touched" ]; then ok "a command with no snapshot before it records nothing"; else bad "a command with no snapshot before it records nothing" "$(_sr_rec shell4)"; fi

# 4. A passing check removes the session's record, and not another session's.
rm -f "$sr_state/fail" "$sr_state/check-ran"
_sr_cmd build before Bash >/dev/null
printf '// the fix\n' >> "$sr/src/Billing.cs"
out="$(_sr_stop_as build)"; status=$?
expect_status "a session whose code passes the check ends its turn" 0 "$status" "$out"
if _sr_ran; then ok "the check ran for it"; else bad "the check ran for it"; fi
if [ ! -e "$sr_state/sessions/build.touched" ] && [ ! -e "$sr_state/sessions/build.before" ]; then ok "a passing check removes the session's record"; else bad "a passing check removes the session's record" "$(ls "$sr_state/sessions")"; fi
if [ -s "$sr_state/sessions/shell.touched" ]; then ok "and leaves another session's"; else bad "and leaves another session's"; fi

# 5. A record older than a day is ignored, and deleted with any other session's that old.
: > "$sr_state/fail"; rm -f "$sr_state/check-ran" "$sr_state/last-reported"
_sr_wrote old Write "$sr/src/Billing.cs" >/dev/null
_sr_wrote stale Write "$sr/src/Billing.cs" >/dev/null
touch -t 202001010000 "$sr_state/sessions/old.touched" "$sr_state/sessions/stale.touched"
out="$(_sr_stop_as old)"; status=$?
expect_status "a record older than a day is ignored" 0 "$status" "$out"
if _sr_ran; then bad "and the check doesn't run for it"; else ok "and the check doesn't run for it"; fi
if [ ! -e "$sr_state/sessions/old.touched" ] && [ ! -e "$sr_state/sessions/stale.touched" ]; then ok "and it is deleted, as is another session's that old"; else bad "and it is deleted, as is another session's that old" "$(ls "$sr_state/sessions")"; fi

# 6. No session_id, or one that can't be a file name, behaves as before: uncommitted source runs the check once.
out="$(_sr_stop '{"hook_event_name":"Stop"}')"; status=$?
expect_status "with no session_id the hook decides from git alone: uncommitted source runs the check, and a failure blocks" 2 "$status" "$out"
if _sr_ran; then ok "and the check ran"; else bad "and the check ran"; fi
out="$(_sr_stop '{"hook_event_name":"Stop"}')"; expect_status "and the same failure isn't reported twice" 0 $? "$out"
printf '// another change\n' >> "$sr/src/Billing.cs"; rm -f "$sr_state/check-ran"
out="$(_sr_stop_as '../../escape')"; status=$?
expect_status "a session_id that isn't a plain name behaves the same" 2 "$status" "$out"
printf '// and another\n' >> "$sr/src/Billing.cs"
out="$(_sr_stop '{"session_id":"","hook_event_name":"Stop"}')"; expect_status "so does an empty one" 2 $? "$out"

# 7. What stays as it was: the builder marker, SATT_STOP_CHECK=0 and a project with no tools/check.sh.
printf '// once more\n' >> "$sr/src/Billing.cs"; rm -f "$sr_state/check-ran"
_sr_wrote marked Write "$sr/src/Billing.cs" >/dev/null
: > "$sr_state/building"
out="$(_sr_stop_as marked)"; status=$?
expect_status "a session with a record leaves a builder's half-built files alone" 0 "$status" "$out"
rm -f "$sr_state/building"
out="$(SATT_STOP_CHECK=0 _sr_stop_as marked)"; expect_status "SATT_STOP_CHECK=0 turns the Stop hook off for it" 0 $? "$out"
SATT_STOP_CHECK=0 _sr_wrote off Write "$sr/src/Billing.cs" >/dev/null
if [ ! -e "$sr_state/sessions/off.touched" ]; then ok "and the record with it"; else bad "and the record with it"; fi
mv "$sr/tools/check.sh" "$sr/tools/check.sh.away"
out="$(_sr_stop_as marked)"; expect_status "a project with no tools/check.sh ends the turn" 0 $? "$out"
mv "$sr/tools/check.sh.away" "$sr/tools/check.sh"
if _sr_ran; then bad "the check isn't run while the builder marker, the switch or a missing script excuses it"; else ok "the check isn't run while the builder marker, the switch or a missing script excuses it"; fi
out="$(_sr_stop_as marked)"; expect_status "and the record still blocks once those are gone" 2 $? "$out"

# 8. Work that is committed ends the record: the check passed in the commit, and what differs later is another's.
rm -f "$sr_state/fail" "$sr_state/check-ran"
git -C "$sr" add -A >/dev/null 2>&1; git_q -C "$sr" commit -qm "the build session's work" >/dev/null 2>&1
out="$(_sr_stop_as marked)"; status=$?
expect_status "a session whose source is all committed ends its turn" 0 "$status" "$out"
if [ ! -e "$sr_state/sessions/marked.touched" ] && ! _sr_ran; then ok "and its record is removed without running the check"; else bad "and its record is removed without running the check" "$(ls "$sr_state/sessions")"; fi
put "$sr/docs/more.md" '# more'
out="$(_sr_stop '{"hook_event_name":"Stop"}')"; expect_status "with no session_id, a Markdown-only change ends the turn, as before" 0 $? "$out"

# The hooks are wired in settings.json: the snapshot before a command, the record after a file tool or a command
# (a failing one too), and the hook runs under macOS's bash 3.2 and BSD tools, so it holds none of the forms they lack.
wiring="$(awk '/^    "[A-Za-z]+": \[/ { ev = $1; gsub(/[":]/, "", ev) } /"matcher"/ { split($0, a, "\""); m = a[4] }
  /session-touched\.sh/ { print ev ";" m ";" ($0 ~ / before"/ ? "before" : "after") }' "$src/framework/.claude/settings.json")"
[ "$wiring" = "PreToolUse;Bash|PowerShell;before${sr_nl}PostToolUse;Edit|Write|MultiEdit|NotebookEdit;after${sr_nl}PostToolUse;Bash|PowerShell;after${sr_nl}PostToolUseFailure;Bash|PowerShell;after" ] \
  && ok "settings.json runs the record hook before Bash and PowerShell, after them (a failing one too) and after Edit, Write, MultiEdit and NotebookEdit" \
  || bad "settings.json runs the record hook before Bash and PowerShell, after them (a failing one too) and after Edit, Write, MultiEdit and NotebookEdit" "$wiring"
bash4=$(grep -nE '^[^#]*(\$\{[A-Za-z_0-9]+(\[[^]]*\])?(,,|\^\^)\}|(declare|local|typeset) +-[a-zA-Z]*A|(^|[;&| ])(mapfile|readarray) +|(^|[;&| ])coproc +[A-Za-z]|[[:space:]]\|&[[:space:]]|\$\{[A-Za-z_0-9@*]+(\[[^]]*\])?: -[0-9]|stat +-c|date +-d|sed +-i|readlink +-f|-printf|-delete)' \
  "$sr_hooks/session-touched.sh" "$sr_hooks/stop-check.sh" "$sr_hooks/release-check.sh" "$sr_hooks/orphan-report.sh" || true)
if [ -z "$bash4" ]; then ok "the Stop hook, the record hook, the release check and the orphan report use no bash 4 form and no GNU-only tool flag"
else bad "the Stop hook, the record hook, the release check and the orphan report use no bash 4 form and no GNU-only tool flag" "$bash4"; fi

# --- Release check hook -------------------------------------------------------------------------
# A SessionStart hook says when the installed version is older than the latest release tag on GitHub. The tests run it
# in a throwaway project with stubs first on PATH: a git that records its calls and prints a scripted tag list, and a
# timeout that records its arguments. No request leaves the machine.
echo "release check hook"
rc_hook="$src/framework/.claude/hooks/release-check.sh"
rc="$work/release-check"; rc_proj="$rc/proj"; rc_state="$rc_proj/.satt/state"
mkdir -p "$rc_proj/.satt" "$rc/bin" "$rc/bin_nt" "$rc/bin_none"
put "$rc/bin/git" '#!/bin/bash
printf "%s\n" "git $* prompt=${GIT_TERMINAL_PROMPT:-unset}" >> "$RC_LOG"
if [ -n "${RC_GIT_FAIL:-}" ]; then exit "$RC_GIT_FAIL"; fi
while IFS= read -r l; do printf "%s\n" "$l"; done < "$RC_TAGS"'
put "$rc/bin/timeout" '#!/bin/bash
printf "%s\n" "timeout $*" >> "$RC_LOG"
shift
exec "$@"'
cp "$rc/bin/git" "$rc/bin_nt/git"
chmod +x "$rc/bin/git" "$rc/bin/timeout" "$rc/bin_nt/git"
rc_tags() { # rc_tags <tag>…: what the stub git lists, each as a line of git ls-remote
  : > "$rc/tags"
  for t in "$@"; do printf '8cb76061505469ebdd9a3488e9892e4e36f398ba\trefs/tags/%s\n' "$t" >> "$rc/tags"; done
}
rc_project() { # rc_project <manifest version line text>: a fresh project, with no cache and no recorded calls
  rm -rf "$rc_state" "$rc/calls"
  printf '# saasallthethings %s\n# source abc1234\n# tools claude\n0000\t.satt/rules.md\n' "$1" > "$rc_proj/.satt/manifest"
}
rc_run() { # rc_run [VAR=value…]: the hook from outside the project (CLAUDE_PROJECT_DIR names it), stubs first on PATH
  (cd "$rc" && printf '{"hook_event_name":"SessionStart","source":"startup"}' \
    | env CLAUDE_PROJECT_DIR="$rc_proj" PATH="$rc/bin:$PATH" RC_LOG="$rc/calls" RC_TAGS="$rc/tags" "$@" "$BASH" "$rc_hook" 2>&1)
}
rc_git_calls() { local n; n="$(grep -c '^git ' "$rc/calls" 2>/dev/null)"; echo "${n:-0}"; }
rc_says() { # rc_says <installed> <latest>: the hook's one line of JSON
  local t="SaaSAllTheThings $1 is installed, and the latest release is $2. Ask the agent to upgrade it when it suits you."
  printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s Tell the human this once, in your first reply."}}' "$t" "$t"
}
rc_expect_silent() { # rc_expect_silent <what> <output> <status>
  if [ -z "$2" ] && [ "$3" -eq 0 ]; then ok "$1"; else bad "$1 (exit $3)" "$2"; fi
  return 0
}

rc_tags v0.14.0 v0.15.0 v0.16.0
rc_project "0.15.0"
out="$(rc_run)"; status=$?
[ "$out" = "$(rc_says 0.15.0 0.16.0)" ] && [ "$status" -eq 0 ] && ok "a project behind the latest release is told so, as one line of JSON for the human and for Claude" \
  || bad "a project behind the latest release is told so, as one line of JSON for the human and for Claude (exit $status)" "$out"
if command -v node >/dev/null 2>&1; then
  if printf '%s' "$out" | node -e 'const j = JSON.parse(require("fs").readFileSync(0, "utf8")); process.exit(j.systemMessage.indexOf("0.15.0") > 0 && j.systemMessage.indexOf("0.16.0") > 0 && j.hookSpecificOutput.hookEventName === "SessionStart" && j.hookSpecificOutput.additionalContext.indexOf(j.systemMessage) === 0 ? 0 : 1)' 2>/dev/null; then
    ok "and the line parses as JSON, with the installed and the latest version in the message and the instruction in Claude's text"
  else bad "and the line parses as JSON, with the installed and the latest version in the message and the instruction in Claude's text" "$out"; fi
fi
expect_output "the instruction to Claude is to say it once, in the first reply" 'additionalContext":"[^"]* Tell the human this once, in your first reply\."' "$out"
[ -s "$rc_state/latest-release" ] && [ "$(cat "$rc_state/latest-release")" = "0.16.0" ] && ok "the version found is kept in .satt/state/latest-release" \
  || bad "the version found is kept in .satt/state/latest-release" "$(cat "$rc_state/latest-release" 2>/dev/null)"
expect_output "the lookup is git ls-remote of the release tags, with no prompt, under timeout 5" \
  '^timeout 5 git ls-remote --tags --refs https://github.com/Freakling/SaaSAllTheThings.git refs/tags/v\*'$'\n''git ls-remote --tags --refs https://github.com/Freakling/SaaSAllTheThings.git refs/tags/v\* prompt=0$' "$(cat "$rc/calls")"

rc_tags v1.14.0; rc_project "1.9.0"
out="$(rc_run)"; [ "$out" = "$(rc_says 1.9.0 1.14.0)" ] && ok "1.9.0 is below 1.14.0: the versions are compared as numbers" || bad "1.9.0 is below 1.14.0: the versions are compared as numbers" "$out"
rc_tags v1.9.0; rc_project "1.14.0"
out="$(rc_run)"; status=$?; rc_expect_silent "1.14.0 is not below 1.9.0" "$out" "$status"
rc_tags v0.9.0 v0.9.1 v0.10.0 v0.2.0; rc_project "0.9.1"
out="$(rc_run)"; [ "$out" = "$(rc_says 0.9.1 0.10.0)" ] && ok "the highest tag is chosen by numeric fields: v0.10.0 is above v0.9.1" || bad "the highest tag is chosen by numeric fields: v0.10.0 is above v0.9.1" "$out"

rc_tags v0.15.0 v0.16.0; rc_project "0.16.0"
out="$(rc_run)"; status=$?; rc_expect_silent "an install at the latest release is silent" "$out" "$status"
rc_project "0.17.0"
out="$(rc_run)"; status=$?; rc_expect_silent "an install newer than the latest release is silent" "$out" "$status"
rc_project "0.15.0 + unreleased (abc1234)"
out="$(rc_run)"; [ "$out" = "$(rc_says 0.15.0 0.16.0)" ] && ok "' + unreleased (abc)' is read as its version" || bad "' + unreleased (abc)' is read as its version" "$out"
rc_project "0.16.0 + unreleased (abc1234)"
out="$(rc_run)"; status=$?; rc_expect_silent "an unreleased install of the latest version is silent" "$out" "$status"
printf '# saasallthethings 0.15.0\r\n# tools claude\r\n' > "$rc_proj/.satt/manifest"; rm -rf "$rc_state"
out="$(rc_run)"; [ "$out" = "$(rc_says 0.15.0 0.16.0)" ] && ok "a manifest with CRLF line ends is read" || bad "a manifest with CRLF line ends is read" "$out"

# The answer is looked up at most once a day.
rc_project "0.15.0"; mkdir -p "$rc_state"; printf '0.16.0\n' > "$rc_state/latest-release"
out="$(rc_run)"; status=$?
[ "$out" = "$(rc_says 0.15.0 0.16.0)" ] && [ "$(rc_git_calls)" -eq 0 ] && ok "a cache less than a day old answers without calling git" \
  || bad "a cache less than a day old answers without calling git (exit $status, $(rc_git_calls) calls)" "$out"
touch -t 202001010000 "$rc_state/latest-release"; rc_tags v0.15.0 v0.17.0
out="$(rc_run)"
[ "$out" = "$(rc_says 0.15.0 0.17.0)" ] && [ "$(rc_git_calls)" -eq 1 ] && ok "a cache a day old calls git once and takes the new answer" \
  || bad "a cache a day old calls git once and takes the new answer ($(rc_git_calls) calls)" "$out"
out="$(rc_run)"
[ "$out" = "$(rc_says 0.15.0 0.17.0)" ] && [ "$(rc_git_calls)" -eq 1 ] && ok "and the next session that day calls it no more" \
  || bad "and the next session that day calls it no more ($(rc_git_calls) calls)" "$out"
rc_project "0.15.0"; mkdir -p "$rc_state"; printf 'rubbish\n' > "$rc_state/latest-release"
out="$(rc_run)"; status=$?; rc_expect_silent "a cache that holds no version is silent" "$out" "$status"
[ "$(rc_git_calls)" -eq 0 ] && ok "and is not looked up again that day" || bad "and is not looked up again that day ($(rc_git_calls) calls)"

# A lookup that fails prints nothing, exits 0 and is not tried again that day.
rc_project "0.15.0"
out="$(rc_run RC_GIT_FAIL=128)"; status=$?
rc_expect_silent "a failed git prints nothing and exits 0" "$out" "$status"
[ -f "$rc_state/latest-release" ] && [ ! -s "$rc_state/latest-release" ] && ok "and leaves an empty cache, so the next try is tomorrow" || bad "and leaves an empty cache, so the next try is tomorrow"
out="$(rc_run RC_GIT_FAIL=128)"; status=$?
[ "$(rc_git_calls)" -eq 1 ] && rc_expect_silent "and git isn't called again that day" "$out" "$status" || bad "and git isn't called again that day ($(rc_git_calls) calls)"
rc_project "0.15.0"
out="$(rc_run RC_GIT_FAIL=124)"; status=$?; rc_expect_silent "a git that times out prints nothing and exits 0" "$out" "$status"
rc_project "0.15.0"; mkdir -p "$rc_state"; printf '0.16.0\n' > "$rc_state/latest-release"; touch -t 202001010000 "$rc_state/latest-release"
out="$(rc_run RC_GIT_FAIL=128)"
[ "$out" = "$(rc_says 0.15.0 0.16.0)" ] && [ "$(cat "$rc_state/latest-release")" = "0.16.0" ] && ok "a failed lookup keeps the old value" || bad "a failed lookup keeps the old value" "$out"
out="$(rc_run RC_GIT_FAIL=128)"
[ "$(rc_git_calls)" -eq 1 ] && ok "and touches the file, so the next try is tomorrow" || bad "and touches the file, so the next try is tomorrow ($(rc_git_calls) calls)"
rc_project "0.15.0"; mkdir -p "$rc_state"   # the state folder exists, as PATH holds no mkdir below
out="$(cd "$rc" && printf '{}' | env CLAUDE_PROJECT_DIR="$rc_proj" PATH="$rc/bin_none" "$BASH" "$rc_hook" 2>&1)"; status=$?
rc_expect_silent "no git on the machine prints nothing and exits 0" "$out" "$status"
[ -f "$rc_state/latest-release" ] && [ ! -s "$rc_state/latest-release" ] && ok "and leaves an empty cache" || bad "and leaves an empty cache"
rc_tags v0.16.0; rc_project "0.15.0"; mkdir -p "$rc_state"
out="$(cd "$rc" && printf '{}' | env CLAUDE_PROJECT_DIR="$rc_proj" PATH="$rc/bin_nt" RC_LOG="$rc/calls" RC_TAGS="$rc/tags" "$BASH" "$rc_hook" 2>&1)"
[ "$out" = "$(rc_says 0.15.0 0.16.0)" ] && ok "without timeout on the machine the lookup still runs" || bad "without timeout on the machine the lookup still runs" "$out"

# Tags of another shape are ignored.
rc_tags v2.0.0-rc1 latest v1.0 v1.2.3.4 v3.0.0x vv4.0.0 'v9.9.9^{}' v0.16.0 v0.15.0
rc_project "0.15.0"
out="$(rc_run)"; [ "$out" = "$(rc_says 0.15.0 0.16.0)" ] && ok "tags such as v2.0.0-rc1, latest and v1.0 are ignored" || bad "tags such as v2.0.0-rc1, latest and v1.0 are ignored" "$out"
rc_tags v2.0.0-rc1 latest v1.0
rc_project "0.15.0"
out="$(rc_run)"; status=$?
rc_expect_silent "a list with no v<major>.<minor>.<patch> tag is silent" "$out" "$status"
[ -f "$rc_state/latest-release" ] && [ ! -s "$rc_state/latest-release" ] && ok "and keeps no version" || bad "and keeps no version" "$(cat "$rc_state/latest-release" 2>/dev/null)"

# The switch, a missing manifest, and a manifest with no version.
rc_tags v0.16.0
rc_project "0.15.0"
out="$(rc_run SATT_RELEASE_CHECK=0)"; status=$?
if [ ! -e "$rc/calls" ] && [ ! -e "$rc_state" ]; then rc_expect_silent "SATT_RELEASE_CHECK=0 turns it off: silent, no request and no state" "$out" "$status"
else bad "SATT_RELEASE_CHECK=0 turns it off: silent, no request and no state" "$(cat "$rc/calls" 2>/dev/null)"; fi
rc_project "0.15.0"; rm -f "$rc_proj/.satt/manifest"
out="$(rc_run)"; status=$?
[ ! -e "$rc/calls" ] && rc_expect_silent "no .satt/manifest is silent and makes no request" "$out" "$status" || bad "no .satt/manifest is silent and makes no request"
printf '# tools claude\n0000\t.satt/rules.md\n' > "$rc_proj/.satt/manifest"
out="$(rc_run)"; status=$?
[ ! -e "$rc/calls" ] && rc_expect_silent "a manifest with no version line is silent and makes no request" "$out" "$status" || bad "a manifest with no version line is silent and makes no request"
rc_project "dev"
out="$(rc_run)"; status=$?
[ ! -e "$rc/calls" ] && rc_expect_silent "a version line that isn't a version is silent and makes no request" "$out" "$status" || bad "a version line that isn't a version is silent and makes no request"
out="$(cd "$rc" && printf '{}' | env CLAUDE_PROJECT_DIR="$rc/nowhere" PATH="$rc/bin:$PATH" RC_LOG="$rc/calls" RC_TAGS="$rc/tags" "$BASH" "$rc_hook" 2>&1)"; status=$?
rc_expect_silent "a project folder that doesn't exist is silent" "$out" "$status"

# The hook is not part of the check, so a warning can't fail it; it is wired at session start, and installed.
if grep -rqF 'release-check' "$src/framework/tools" "$src/framework/.githooks" "$src/framework/.claude/hooks/stop-check.sh"; then
  bad "the check, the git hooks and the Stop hook don't run the release check, so a warning never fails them"
else ok "the check, the git hooks and the Stop hook don't run the release check, so a warning never fails them"; fi
wiring="$(awk '/^    "[A-Za-z]+": \[/ { ev = $1; gsub(/[":]/, "", ev) } /"matcher"/ { split($0, a, "\""); m = a[4] }
  /release-check\.sh/ { hit = 1 } hit && /"timeout"/ { t = $0; gsub(/[^0-9]/, "", t); print ev ";" m ";" t; hit = 0 }' "$src/framework/.claude/settings.json")"
[ "$wiring" = "SessionStart;startup|resume;10" ] && ok "settings.json runs the release check at SessionStart, on startup and resume, with a 10 second timeout" \
  || bad "settings.json runs the release check at SessionStart, on startup and resume, with a 10 second timeout" "$wiring"
expect_output "the hook says what it is in the header the other hooks use" '^# SaaSAllTheThings release check · Claude Code hook · framework-owned: replaced on upgrade\.' "$(sed -n 2p "$rc_hook")"
expect_output "and how to turn it off" 'SATT_RELEASE_CHECK=0 turns it off' "$(cat "$rc_hook")"
grep -qF 'release check' "$src/PRIVACY.md" && grep -qF 'SATT_RELEASE_CHECK=0' "$src/PRIVACY.md" && grep -qF 'apart from the release check below' "$src/PRIVACY.md" \
  && ok "PRIVACY.md says what the release check reads, and how to turn it off" || bad "PRIVACY.md says what the release check reads, and how to turn it off"

# --- Orphan report hook -------------------------------------------------------------------------
# A SessionStart hook lists long-running processes whose parent is gone. The tests run it with stubs first on PATH: a
# uname that names the system, a ps and a powershell.exe that print scripted process rows, a timeout that records its
# first argument, and a kill, a taskkill and a pkill that record any call (there must be none). No real process list is
# read, and nothing is stopped.
echo "orphan report hook"
op_hook="$src/framework/.claude/hooks/orphan-report.sh"
op="$work/orphan-report"; op_cwd="$op/cwd"
mkdir -p "$op/bin" "$op/bin_nt" "$op/bin_nops" "$op/bin_none" "$op_cwd"
put "$op/bin/uname" '#!/bin/bash
printf "%s\n" "uname $*" >> "$OP_LOG"
printf "%s\n" "$OP_UNAME"'
put "$op/bin/ps" '#!/bin/bash
printf "%s\n" "ps $*" >> "$OP_LOG"
while IFS= read -r l; do printf "%s\n" "$l"; done < "$OP_ROWS"
exit "${OP_EXIT:-0}"'
put "$op/bin/powershell.exe" '#!/bin/bash
printf "%s\n" "powershell.exe $*" >> "$OP_LOG"
while IFS= read -r l; do printf "%s\r\n" "$l"; done < "$OP_ROWS"
exit "${OP_EXIT:-0}"'
put "$op/bin/timeout" '#!/bin/bash
printf "%s\n" "timeout $1" >> "$OP_LOG"
if [ -n "${OP_TIMED_OUT:-}" ]; then exit 124; fi
shift
exec "$@"'
for s in kill taskkill pkill; do put "$op/bin/$s" '#!/bin/bash
printf "%s\n" "$0 $*" >> "$OP_SIGNALS"'; done
cp "$op/bin/uname" "$op/bin_nt/uname"; cp "$op/bin/powershell.exe" "$op/bin_nt/powershell.exe"; cp "$op/bin/uname" "$op/bin_nops/uname"
chmod +x "$op/bin/"* "$op/bin_nt/"* "$op/bin_nops/"*
op_rows() { # op_rows <row>…: the process list the stubs print
  : > "$op/rows"
  local l; for l in "$@"; do printf '%s\n' "$l" >> "$op/rows"; done
}
op_run() { # op_run <win|ps> [VAR=value…]: the hook from an empty folder, stubs first on PATH
  local u=Linux; [ "$1" = win ] && u="MINGW64_NT-10.0-26300"; shift
  rm -f "$op/calls"
  (cd "$op_cwd" && printf '{"hook_event_name":"SessionStart","source":"startup"}' \
    | env PATH="$op/bin:$PATH" OP_LOG="$op/calls" OP_ROWS="$op/rows" OP_UNAME="$u" OP_SIGNALS="$op/signals" "$@" "$BASH" "$op_hook" 2>&1)
}
op_says() { # op_says <list>: the hook's one line of JSON for that list of processes
  local t="Processes that outlived the shell that started them (parent gone, over an hour old): $1. They may be left over from an ended session. Stopping them is your call."
  printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s Tell the human this once, in your first reply, and don'"'"'t stop them unless the human asks."}}' "$t" "$t"
}
op_expect_silent() { # op_expect_silent <what> <output> <status>
  if [ -z "$2" ] && [ "$3" -eq 0 ]; then ok "$1"; else bad "$1 (exit $3)" "$2"; fi
  return 0
}

# Windows: the rows are pid, ppid, age in seconds and name, as the PowerShell script prints them (CRLF line ends).
op_rows "4 0 90000 System" "35660 8000 50400 python3.13.exe" "100 4 999999 Registry"
out="$(op_run win)"; status=$?
[ "$out" = "$(op_says 'pid 35660 python3.13 (14 h)')" ] && [ "$status" -eq 0 ] && ok "an hour-old python3.13.exe whose parent row is gone is listed, as one line of JSON for the human and for Claude" \
  || bad "an hour-old python3.13.exe whose parent row is gone is listed, as one line of JSON for the human and for Claude (exit $status)" "$out"
expect_output "on Windows the list is read with PowerShell's Get-CimInstance Win32_Process, under timeout 8" \
  '^uname -s'$'\n''timeout 8'$'\n''powershell.exe -NoProfile -NonInteractive -Command [^'$'\n'']*Get-CimInstance Win32_Process[^'$'\n'']*CreationDate' "$(cat "$op/calls")"
op_rows "500 4 90000 explorer.exe" "35660 500 50400 python3.13.exe"
out="$(op_run win)"; status=$?; op_expect_silent "a process whose parent is alive and older is not listed" "$out" "$status"
op_rows "35660 8000 3540 python3.13.exe"
out="$(op_run win)"; status=$?; op_expect_silent "one that is 59 minutes old is not listed" "$out" "$status"
op_rows "35660 8000 3600 python3.13.exe"
out="$(op_run win)"; [ "$out" = "$(op_says 'pid 35660 python3.13 (1 h)')" ] && ok "and one an hour old is" || bad "and one an hour old is" "$out"
op_rows "500 4 600 cmd.exe" "35660 500 50400 python3.13.exe"
out="$(op_run win)"; [ "$out" = "$(op_says 'pid 35660 python3.13 (14 h)')" ] && ok "a process whose parent row is younger than it (a reused id) is listed" || bad "a process whose parent row is younger than it (a reused id) is listed" "$out"
op_rows "700 0 7200 node.exe"
out="$(op_run win)"; [ "$out" = "$(op_says 'pid 700 node (2 h)')" ] && ok "a ppid of 0 counts as a parent that is gone" || bad "a ppid of 0 counts as a parent that is gone" "$out"
op_rows "21 9 90000 notepad.exe" "22 9 90000 explorer.exe" "23 9 90000 pythonista.exe" "24 9 90000 python2.exe" "25 9 90000 nodemon.exe" "26 9 90000 shell.exe" "27 9 90000 godo.exe" "28 9 90000 python3.x.exe" "29 9 90000 chrome.exe"
out="$(op_run win)"; status=$?; op_expect_silent "notepad.exe, explorer.exe and names that only look like a listed one (pythonista, python2, nodemon, shell, godo, chrome) are not listed" "$out" "$status"
op_rows "31 9 72060 PYTHON.EXE" "32 9 68460 pythonw.exe" "33 9 64860 py.exe" "34 9 61260 Node.exe" "35 9 57660 bash.exe" "36 9 54060 sh.exe" \
  "37 9 50460 Godot_v4.5-stable_win64.exe" "38 9 46860 chrome-headless-shell.exe" "39 9 43260 python3.9.exe" "40 9 39660 python3.exe"
out="$(op_run win)"
[ "$out" = "$(op_says 'pid 31 PYTHON (20 h), pid 32 pythonw (19 h), pid 33 py (18 h), pid 34 Node (17 h), pid 35 bash (16 h), pid 36 sh (15 h), pid 37 Godot_v4.5-stable_win64 (14 h), pid 38 chrome-headless-shell (13 h), pid 39 python3.9 (12 h), pid 40 python3 (11 h)')" ] \
  && ok "python, pythonw, py, node, bash, sh, godot*, chrome-headless-shell, python3 and python3.<n> are listed, in any case and without .exe" \
  || bad "python, pythonw, py, node, bash, sh, godot*, chrome-headless-shell, python3 and python3.<n> are listed, in any case and without .exe" "$out"

# Eleven orphans print the oldest ten, oldest first, and how many more there are.
op_list=(); op_want=""; i=0
while [ $i -le 10 ]; do op_list+=("$((31 + i)) 9 $(((3 + i) * 3600 + 60)) node.exe"); i=$((i + 1)); done
i=10; while [ $i -ge 1 ]; do op_want="${op_want:+$op_want, }pid $((31 + i)) node ($((3 + i)) h)"; i=$((i - 1)); done
op_rows "${op_list[@]}"
out="$(op_run win)"
[ "$out" = "$(op_says "$op_want, and 1 more")" ] && ok "eleven orphans print the oldest ten, oldest first, and \"and 1 more\"" || bad "eleven orphans print the oldest ten, oldest first, and \"and 1 more\"" "$out"
op_rows "${op_list[@]}" "50 9 7200 node.exe" "51 9 7200 node.exe"
out="$(op_run win)"
[ "$out" = "$(op_says "$op_want, and 3 more")" ] && ok "and with thirteen, \"and 3 more\"" || bad "and with thirteen, \"and 3 more\"" "$out"
op_rows "41 9 172800 node.exe" "42 9 176400 node.exe" "43 9 259200 node.exe" "44 9 3599 node.exe"
out="$(op_run win)"
[ "$out" = "$(op_says 'pid 43 node (3 d), pid 42 node (2 d), pid 41 node (48 h)')" ] && ok "ages read as hours up to 48 and as days after" || bad "ages read as hours up to 48 and as days after" "$out"

# A name with odd characters is reduced to [A-Za-z0-9._-] and can't break the JSON.
op_rows '777 8000 7200 Godot"}],"a":"\x'$'\x01''.exe' '778 8000 7300 no"de'
out="$(op_run win)"
[ "$out" = "$(op_says 'pid 778 node (2 h), pid 777 Godotax (2 h)')" ] && ok "a name with quotes, brackets, a backslash and a control character is reduced to its safe characters" \
  || bad "a name with quotes, brackets, a backslash and a control character is reduced to its safe characters" "$out"
if command -v node >/dev/null 2>&1; then
  if printf '%s' "$out" | node -e 'const j = JSON.parse(require("fs").readFileSync(0, "utf8")); process.exit(j.systemMessage.indexOf("Godotax") > 0 && j.hookSpecificOutput.hookEventName === "SessionStart" && j.hookSpecificOutput.additionalContext.indexOf(j.systemMessage) === 0 ? 0 : 1)' 2>/dev/null; then
    ok "and the line parses as JSON, with the same text for the human and for Claude"
  else bad "and the line parses as JSON, with the same text for the human and for Claude" "$out"; fi
fi

# Elsewhere: ps -A -o pid=,ppid=,etime=,comm=, with [[dd-]hh:]mm:ss read into seconds and comm reduced to its base name.
op_rows "  35660     1 14:00:00 python3.13" "  25748     1 2-03:00:00 node" "   4000     1    59:59 bash" "   4001     1 1-00:00:00 sh" \
  "   4002     1 02:00:00 /usr/bin/python3" "   4003     1 2-00:00:00 /Applications/Godot.app/Contents/MacOS/Godot" \
  "   4004     1 2-01:00:00 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome" "   4005     1 03:00:00 sshd" "   4006     1 2-01:00:00 python"
out="$(op_run ps)"; status=$?
[ "$out" = "$(op_says 'pid 25748 node (2 d), pid 4006 python (2 d), pid 4003 Godot (48 h), pid 4001 sh (24 h), pid 35660 python3.13 (14 h), pid 4002 python3 (2 h)')" ] && [ "$status" -eq 0 ] \
  && ok "ps rows are read: dd-hh:mm:ss, hh:mm:ss and mm:ss (59:59 is under the hour), a path in comm is cut to its base name, sshd and a browser are not listed" \
  || bad "ps rows are read: dd-hh:mm:ss, hh:mm:ss and mm:ss (59:59 is under the hour), a path in comm is cut to its base name, sshd and a browser are not listed (exit $status)" "$out"
expect_output "elsewhere the list is read with ps -A -o pid=,ppid=,etime=,comm=" '^uname -s'$'\n''ps -A -o pid=,ppid=,etime=,comm=$' "$(cat "$op/calls")"
op_rows "  100     1 10-00:00:00 launchd" "  200   100       05:00 zsh" "  201   200 03:00:00 python3" "  300   100 10:00:00 bash" "  301   300 09:00:00 node" "  302   999 08:00:00 py"
out="$(op_run ps)"
[ "$out" = "$(op_says 'pid 302 py (8 h), pid 201 python3 (3 h)')" ] && ok "with ps: a live older parent keeps its child out, a younger parent row and a missing one put it in" \
  || bad "with ps: a live older parent keeps its child out, a younger parent row and a missing one put it in" "$out"

# Silent, and exit 0: the off switch, a list that is empty or garbled, a tool that fails or times out, or is missing.
op_rows "35660 8000 50400 python3.13.exe"
out="$(op_run win SATT_ORPHAN_REPORT=0)"; status=$?
if [ ! -e "$op/calls" ]; then op_expect_silent "SATT_ORPHAN_REPORT=0 turns it off: silent, and the process list isn't read" "$out" "$status"
else bad "SATT_ORPHAN_REPORT=0 turns it off: silent, and the process list isn't read" "$(cat "$op/calls")"; fi
op_rows "35660 8000 50400 python3.13.exe"
out="$(op_run win OP_EXIT=1)"; status=$?; op_expect_silent "a PowerShell that fails prints nothing and exits 0, whatever it printed" "$out" "$status"
out="$(op_run ps OP_EXIT=1)"; status=$?; op_expect_silent "a ps that fails prints nothing and exits 0" "$out" "$status"
out="$(op_run win OP_TIMED_OUT=1)"; status=$?; op_expect_silent "a PowerShell that times out prints nothing and exits 0" "$out" "$status"
op_rows
out="$(op_run win)"; status=$?; op_expect_silent "an empty list is silent" "$out" "$status"
op_rows "not a process list" "x y z" "1 2 notatime python3" "-5 1 99999 node.exe"
out="$(op_run ps)"; status=$?; op_expect_silent "rows that aren't rows are skipped" "$out" "$status"
op_rows "35660 8000 50400 python3.13.exe"
out="$(cd "$op_cwd" && printf '{}' | env PATH="$op/bin_nops" OP_LOG="$op/calls" OP_UNAME=MINGW64_NT-10.0-26300 "$BASH" "$op_hook" 2>&1)"; status=$?
op_expect_silent "no powershell.exe on a Windows machine is silent, and exits 0" "$out" "$status"
out="$(cd "$op_cwd" && printf '{}' | env PATH="$op/bin_nops" OP_LOG="$op/calls" OP_UNAME=Linux "$BASH" "$op_hook" 2>&1)"; status=$?
op_expect_silent "no ps elsewhere is silent, and exits 0" "$out" "$status"
out="$(cd "$op_cwd" && printf '{}' | env PATH="$op/bin_none" "$BASH" "$op_hook" 2>&1)"; status=$?
op_expect_silent "no uname, no ps and no PowerShell is silent, and exits 0" "$out" "$status"
out="$(cd "$op_cwd" && printf '{}' | env PATH="$op/bin_nt" OP_LOG="$op/calls" OP_ROWS="$op/rows" OP_UNAME=MINGW64_NT-10.0-26300 "$BASH" "$op_hook" 2>&1)"
[ "$out" = "$(op_says 'pid 35660 python3.13 (14 h)')" ] && ok "without timeout on the machine the list is still read" || bad "without timeout on the machine the list is still read" "$out"

# It stops nothing and writes nothing.
[ ! -e "$op/signals" ] && ok "a stub kill, taskkill and pkill on PATH are never called" || bad "a stub kill, taskkill and pkill on PATH are never called" "$(cat "$op/signals")"
if [ -z "$(ls -A "$op_cwd")" ]; then ok "the hook writes no file in the folder it runs from"; else bad "the hook writes no file in the folder it runs from" "$(ls -A "$op_cwd")"; fi
sig="$(grep -vE '^[[:space:]]*#' "$op_hook" | grep -iE '(^|[^A-Za-z_-])(kill|taskkill|pkill|killall|Stop-Process|Set-Process|wmic)([^A-Za-z_-]|$)')"
[ -z "$sig" ] && ok "the hook's code names no command that stops or changes a process" || bad "the hook's code names no command that stops or changes a process" "$sig"

# The hook is not part of the check, so a report can't fail it; it is wired at session start, and installed.
if grep -rqF 'orphan-report' "$src/framework/tools" "$src/framework/.githooks" "$src/framework/.claude/hooks/stop-check.sh"; then
  bad "the check, the git hooks and the Stop hook don't run the orphan report, so it never fails them"
else ok "the check, the git hooks and the Stop hook don't run the orphan report, so it never fails them"; fi
wiring="$(awk '/^    "[A-Za-z]+": \[/ { ev = $1; gsub(/[":]/, "", ev) } /"matcher"/ { split($0, a, "\""); m = a[4] }
  /orphan-report\.sh/ { hit = 1 } hit && /"timeout"/ { t = $0; gsub(/[^0-9]/, "", t); print ev ";" m ";" t; hit = 0 }' "$src/framework/.claude/settings.json")"
[ "$wiring" = "SessionStart;startup|resume;10" ] && ok "settings.json runs the orphan report at SessionStart, on startup and resume, with a 10 second timeout" \
  || bad "settings.json runs the orphan report at SessionStart, on startup and resume, with a 10 second timeout" "$wiring"
wiring="$(awk '/^    "SessionStart": \[/ { on = 1 } on && /"matcher"/ { n++ } on && /\.claude\/hooks\// { h++ } on && /^    \],?$/ { print n ";" h; on = 0 }' "$src/framework/.claude/settings.json")"
[ "$wiring" = "1;2" ] && ok "and it shares the release check's session-start entry: one matcher, two hooks" || bad "and it shares the release check's session-start entry: one matcher, two hooks" "$wiring"
expect_output "the hook says what it is in the header the other hooks use" '^# SaaSAllTheThings orphan report · Claude Code hook · framework-owned: replaced on upgrade\.' "$(sed -n 2p "$op_hook")"
expect_output "and how to turn it off" 'SATT_ORPHAN_REPORT=0' "$(cat "$op_hook")"
grep -qF 'names, ids and ages of the processes' "$src/PRIVACY.md" && grep -qF 'SATT_ORPHAN_REPORT=0' "$src/PRIVACY.md" && ! grep -qF "Only your app's repository" "$src/PRIVACY.md" \
  && ok "PRIVACY.md says the hook reads process names, ids and ages, stores and sends nothing, and how to turn it off" \
  || bad "PRIVACY.md says the hook reads process names, ids and ages, stores and sends nothing, and how to turn it off"

# --- pre-commit hook ----------------------------------------------------------------------------
echo "pre-commit hook"
out="$(bash tools/setup-clone.sh 2>&1)"; expect_status "setup-clone succeeds" 0 $? "$out"
grep -qs "SaaSAllTheThings" "$(git rev-parse --git-path hooks)/pre-commit" && ok "installs the pre-commit hook" || bad "installs the pre-commit hook" "$out"
grep -qs "SaaSAllTheThings" "$(git rev-parse --git-path hooks)/pre-push" && ok "installs the pre-push hook" || bad "installs the pre-push hook" "$out"
expect_output "setup-clone says it installed both hooks" "setup: pre-push hook installed" "$out"
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

# The secrets scan (the check's secrets rule alone: tools/check.sh --secrets) runs on every commit,
# whatever is staged, while the whole check runs only when a commit stages more than documentation. So a
# token pasted into a Markdown page is caught before it enters history, and the whole check isn't run
# for it. A throwaway repository holds it: the framework installed and the hook shim setup-clone.sh
# installed in $app above. The secret is assembled at run time ($fake_key) and never written into a
# file of this repository.
sec_repo="$work/secret-commit"; new_repo "$sec_repo"
bash "$src/install.sh" "$sec_repo" >/dev/null 2>&1
(cd "$sec_repo" && git add -A >/dev/null 2>&1 && git_q commit -qm "install" >/dev/null 2>&1)
cp "$app/.git/hooks/pre-commit" "$sec_repo/.git/hooks/pre-commit"
cd "$sec_repo" || exit 1
sec_commits="$(git rev-list --count HEAD)"
put docs/setup.md "# Setup
Storage: $fake_key"
git add docs/setup.md
out="$(git_q commit -qm "docs: setup" 2>&1)"; status=$?
expect_status "blocks a Markdown-only commit that holds a secret" 1 "$status" "$out"
expect_output "names the file and line of the secret" '\[secrets\] docs/setup\.md:2' "$out"
expect_output "says a secret blocked the commit" 'a secret was found; commit blocked' "$out"
expect_no_output "doesn't run the whole check for a Markdown-only commit" "running the project check" "$out"
expect_no_output "never prints the secret itself" "q2Vh4dN0k3sRm7" "$out"
[ "$(git rev-list --count HEAD)" = "$sec_commits" ] && ok "the blocked commit is not made" || bad "the blocked commit is not made"
out="$(bash tools/check.sh --secrets 2>&1)"; status=$?
expect_status "check.sh --secrets fails on the same secret" 1 "$status" "$out"
# An accepted ADR excuses it, as it does in the whole check.
put adr/ADR-9-fixture.md '# ADR-9 · A fixture page holds an example key

- **Status:** accepted
- Exception: secrets docs/setup.md'
out="$(bash tools/check.sh --secrets 2>&1)"; expect_status "an accepted ADR exception excuses it, as in the whole check" 0 $? "$out"
rm -f adr/ADR-9-fixture.md
put docs/setup.md "# Setup
Storage: Account""Key=<from Key Vault>"
git add docs/setup.md
out="$(git_q commit -qm "docs: setup" 2>&1)"; status=$?
expect_status "allows a Markdown-only commit without a secret" 0 "$status" "$out"
expect_output "scans for secrets on every commit" "scanning for secrets" "$out"
expect_no_output "and still doesn't run the whole check for it" "running the project check" "$out"
# A scan that can't run blocks the commit, a Markdown-only one too: with the check's rules file missing, awk
# can't run them.
mv tools/archcheck.awk "$work/archcheck.saved"
put docs/other.md "# Other"
git add docs/other.md
out="$(git_q commit -qm "docs: other" 2>&1)"; status=$?
expect_status "blocks a Markdown-only commit while the secrets scan can't run" 1 "$status" "$out"
expect_output "and says the scan couldn't run" "the secrets scan couldn't run; commit blocked" "$out"
mv "$work/archcheck.saved" tools/archcheck.awk
git reset -q -- docs/other.md && rm -f docs/other.md
# The scan reads the index too: a secret that is staged and then edited out of the file on disk is still in the
# commit that would carry it.
put docs/staged.md "# Staged
Storage: $fake_key"
git add docs/staged.md
put docs/staged.md "# Staged
Storage: <from Key Vault>"
out="$(bash tools/check.sh --secrets 2>&1)"; status=$?
expect_status "check.sh --secrets finds a secret that is staged but edited out on disk" 1 "$status" "$out"
expect_output "and names the file and line" '\[secrets\] docs/staged\.md:2' "$out"
out="$(git_q commit -qm "docs: staged" 2>&1)"; status=$?
expect_status "the pre-commit hook blocks the commit that would carry it" 1 "$status" "$out"
expect_no_output "and never prints the secret" "q2Vh4dN0k3sRm7" "$out"
git reset -q -- docs/staged.md && rm -f docs/staged.md
out="$(bash tools/check.sh --secrets 2>&1)"; expect_status "and passes once it is unstaged" 0 $? "$out"
# A git grep that fails didn't look: --secrets exits 3, never 0 (here the index is unreadable).
_gg="$work/grep-fails"; new_repo "$_gg"; bash "$src/install.sh" "$_gg" >/dev/null 2>&1
(cd "$_gg" && git add -A >/dev/null 2>&1 && git_q commit -qm "install" >/dev/null 2>&1)
printf 'junk' > "$_gg/.git/index"
out="$(cd "$_gg" && bash tools/check.sh --secrets 2>&1)"; status=$?
expect_status "check.sh --secrets exits 3 when git grep fails" 3 "$status" "$out"
expect_output "and says nothing was checked" "git grep couldn't scan the files, so nothing was checked" "$out"
# setup-clone installs both hooks even when the stack has no profile (exit 3): neither needs the toolchain, and
# the pre-commit hook still blocks a secret there.
_sc="$work/setup-exit3"; new_repo "$_sc"; bash "$src/install.sh" "$_sc" >/dev/null 2>&1
sed 's/^stack = dotnet$/stack = cobol/' "$_sc/tools/check.cfg" > "$work/cfg-cobol" && cp "$work/cfg-cobol" "$_sc/tools/check.cfg"
out="$(cd "$_sc" && bash tools/setup-clone.sh 2>&1)"; status=$?
expect_status "setup-clone exits 3 when the stack has no profile" 3 "$status" "$out"
grep -qs "SaaSAllTheThings" "$_sc/.git/hooks/pre-commit" && grep -qs "SaaSAllTheThings" "$_sc/.git/hooks/pre-push" \
  && ok "and still installs the pre-commit and pre-push hooks" || bad "setup-clone installs the hooks even when it exits 3" "$out"
(cd "$_sc" && git add -A >/dev/null 2>&1 && git_q commit -qm "install" --no-verify >/dev/null 2>&1 && put docs/setup.md "# Setup
Storage: $fake_key" && git add docs/setup.md)
out="$(cd "$_sc" && git_q commit -qm "docs: setup" 2>&1)"; status=$?
expect_status "the hooks block a secret there" 1 "$status" "$out"
expect_output "and name the file" '\[secrets\] docs/setup\.md:2' "$out"
cd "$app" || exit 1

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
  expect_output "and says it needs Node 20" "needs Node 20 or newer" "$out"
  # The floor is Node 20, the lowest that Playwright 1.64.1 declares: a Node 19 is refused, not run.
  mkdir -p "$work/node19" && printf '#!/bin/sh\ncase "$1" in -p) echo 19 ;; --version) echo v19.9.0 ;; esac\n' > "$work/node19/node" && chmod +x "$work/node19/node"
  out="$(PATH="$work/node19:$PATH" bash tools/ui_capture.sh --all 2>&1)"; expect_status "exits 3 on Node 19, below the floor" 3 $? "$out"
  expect_output "and says it needs Node 20 or newer, and which Node it found" "needs Node 20 or newer; this is v19.9.0" "$out"
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

# --- security assessment ---------------------------------------------------------------------------
echo "security assessment"
sec="$satt/procedures/security.md"; owasp="$satt/reference/owasp.md"; map="$src/project/compliance/mapping.md"
missing=""
for file in framework/.satt/procedures/security.md framework/.satt/reference/owasp.md framework/.claude/skills/security/SKILL.md \
    tests/security/README.md tests/security/vulnerable/tools/check.cfg tests/security/clean/tools/check.cfg \
    tests/security/vulnerable/src/Shop.Functions/Shop.Functions.csproj.fixture tests/security/clean/src/Shop.Functions/Shop.Functions.csproj.fixture \
    tests/security/vulnerable/clients/web/package-lock.fixture.json tests/security/clean/clients/web/package-lock.fixture.json \
    tests/security/vulnerable/clients/web/package.fixture.json tests/security/clean/clients/web/package.fixture.json; do
  [ -f "$src/$file" ] || missing="$missing $file"
done
[ -z "$missing" ] && ok "the security assessment's files exist" || bad "security assessment files missing:$missing"
manifests="$(cd "$src/tests/security" && git ls-files -co --exclude-standard -- '*package.json' '*package-lock.json' '*.csproj')"
[ -z "$manifests" ] && ok "the fixture's manifests carry .fixture names, so the repository's dependency graph doesn't read them" \
  || bad "real manifest names under tests/security:" "$manifests"
# The checklist: each Top 10 category under the name of its baseline row, each API Security Top 10 category under
# the row it belongs to, every check marked code, config or people, the tools table and the severity rubric.
wired=""
for i in 01 02 03 04 05 06 07 08 09 10; do
  name="$(sed -n "s/^### A$i \(.*\)$/\1/p" "$owasp")"
  [ -n "$name" ] && grep -qF "| OWASP A$i $name (baseline: keep) |" "$map" || wired="$wired A$i"
done
for i in 1 2 3 4 5 6 7 8 9 10; do grep -q "^### API$i .* (row A[01][0-9])$" "$owasp" || wired="$wired API$i"; done
unmarked="$(awk '/^## OWASP Top 10 \(2025\)$/ { on = 1 } /^## Severity$/ { on = 0 } on && /^- / && !/^- `(code|config|people)` / { n++ } END { print n + 0 }' "$owasp")"
[ "$unmarked" = 0 ] || wired="$wired $unmarked-unmarked-checks"
for s in 'access reviews' 'incident response' 'on call' 'rotation' 'ASVS' 'nothing here is copied' 'A tool passing never verifies a check on its own'; do
  grep -qi "$s" "$owasp" || wired="$wired owasp.md($s)"
done
grep -qF '| `secrets` (the check) | A04 |' "$owasp" && grep -qF '| `tenant-source` (the check) | A01, API1 |' "$owasp" \
  && grep -qF '| `network-public` (the check) | A02, API8 |' "$owasp" \
  && grep -qF '| `dotnet list package --vulnerable --include-transitive`, `npm audit --omit=dev`, `pip-audit` | A03 |' "$owasp" \
  || wired="$wired owasp.md(tools table)"
grep -q 'a tenant isolation break (always high)' "$owasp" || wired="$wired owasp.md(severity)"
for s in '### A03 Software Supply Chain Failures' '### A10 Mishandling of Exceptional Conditions' 'dead-letter' 'fail closed' 'Lockfiles are committed' 'local files under `infra/modules/`' 'Server-side request forgery'; do
  grep -qF -- "$s" "$owasp" || wired="$wired owasp.md(2025: $s)"
done
grep -q '^## OWASP API Security Top 10 (2023)$' "$owasp" && grep -q 'OWASP Top 10 (2025)' "$satt/rules.md" || wired="$wired editions"
for s in 'Where the tenant comes from' 'partition key starts with the `TenantId`' "registry's active tenants" 'cache keys start with the `TenantId`' "tenant's stamp"; do
  grep -qF "$s" "$owasp" || wired="$wired owasp.md(A01: $s)"
done
[ -z "$wired" ] && ok "reference/owasp.md covers the ten Top 10 rows by name and the API Security Top 10, marks every check, files each tool under its OWASP item and has the severity rubric" \
  || bad "reference/owasp.md is missing:$wired"
# The procedure: tools first (never installed without asking), a fresh-context reviewer, findings as bug items, the
# director's list, the dated report, never met from a tool alone, and the mapping update.
wired=""
for s in 'Never install a tool without asking' 'skipped' 'bash tools/check.sh --architecture' 'dotnet list <target> package --vulnerable --include-transitive' \
    'npm audit --omit=dev' 'pip-audit' 'p/owasp-top-ten' 'gh run' 'fresh context' 'read and search tools only' 'file:line' \
    'a tenant isolation break is always high' 'proposed fix' 'Found in: assessment/security/YYYY-MM-DD.md' 'High first' \
    'what to do, and why' 'never add one without asking' 'Commit:' 'Skipped:' 'verified / findings' 'not checkable here' \
    'not applicable' 'A tool passing never marks a category met' "What a clean run doesn't prove" 'compliance/mapping.md' \
    'Never `direct` from a tool alone' "customer's own framework" 'OWASP A01` to `OWASP A10' \
    'pip-audit --disable-pip --no-deps -r requirements.txt' 'pinned with `==`' 'COREPACK_ENABLE_NETWORK=0 COREPACK_ENABLE_DOWNLOAD_PROMPT=0' \
    "couldn't run" 'path:line:col:rule id' '--emacs-output=.satt/state/semgrep.txt' 'Never print, read or quote the two files otherwise' \
    'the target the check builds' 'never blindly in the root' 'A tool is clean only when it exits 0' 'A timeout (exit 124)' \
    'Never quote a secret' 'only `file:line` and the kind of secret' 'Never delete a row' 'Keep an existing Met by entry' \
    "customer's own framework** stay unchanged" '(medium is `med` in the heading)' 'skipping `node_modules/`' 'report its audit as information' \
    'where `timeout` is available'; do
  grep -qF -- "$s" "$sec" || wired="$wired [$s]"
done
grep -q 'security\.md' "$satt/procedures/release.md" \
  && grep -q 'Whether or not it runs, an open `high` bug that names an OWASP item blocks the release' "$satt/procedures/release.md" \
  && grep -q 'unless an accepted ADR deviates from that item' "$satt/procedures/release.md" || wired="$wired release.md"
grep -q 'security\.md' "$satt/procedures/next-task.md" && grep -qF '`[security] every`' "$satt/procedures/next-task.md" \
  && grep -q '10 when the key is absent' "$satt/procedures/next-task.md" \
  && grep -qF 'With no report in `assessment/security/` yet, the assessment is due' "$satt/procedures/next-task.md" \
  && grep -q 'is-shallow-repository' "$satt/procedures/next-task.md" || wired="$wired next-task.md"
# The count next-task.md gives counts item commits, squash-merged ones too, and nothing else.
count_re="$(sed -n "s/.*grep -cE '\([^']*\)'.*/\1/p" "$satt/procedures/next-task.md" | head -n 1)"
n="$(printf '%s\n' 'feat: a (T12)' 'fix: b (B3) (#34)' 'docs: c (R2)' 'chore: d' 'feat: e (T7) extra' | grep -cE "$count_re")"
{ [ -n "$count_re" ] && [ "$n" = 2 ]; } || wired="$wired next-task.md(count: $n)"
grep -q '^- \*\*security\.md:\*\*' "$satt/rules.md" && grep -q 'assessment/security/' "$satt/rules.md" || wired="$wired rules.md"
grep -q '^| `owasp\.md` |' "$satt/reference/README.md" || wired="$wired reference/README.md"
grep -q 'reference/owasp\.md' "$satt/procedures/review.md" || wired="$wired review.md"
grep -q 'a security assessment report in `assessment/security/`' "$satt/tasks.md" || wired="$wired tasks.md"
grep -q 'and the security assessment (`.satt/procedures/security.md`) does, for the OWASP rows' "$map" || wired="$wired mapping.md"
grep -q 'on main at the release commit (never on a detached tag)' "$satt/procedures/release.md" || wired="$wired release.md(main)"
grep -q 'procedures/security\.md' "$src/framework/.claude/skills/security/SKILL.md" \
  && ! grep -q 'disable-model-invocation' "$src/framework/.claude/skills/security/SKILL.md" || wired="$wired SKILL.md"
for f in project/tools/check.cfg examples/order-desk/tools/check.cfg; do
  awk '/^\[security\]$/ { s = 1; next } /^\[/ { s = 0 } s && /^every = 10$/ { found = 1 } END { exit !found }' "$src/$f" || wired="$wired $f"
done
grep -q '/security' "$src/ONBOARDING.md" && grep -qF '[security] every' "$src/ONBOARDING.md" && grep -q '/security' "$src/README.md" \
  || wired="$wired ONBOARDING.md/README.md"
[ -f "$src/skills/saas-design-session/references/reference/owasp.md" ] && [ ! -e "$src/skills/saas-design-session/references/procedures/security.md" ] \
  && grep -q 'security\.md' "$src/skills/saas-design-session/SKILL.md" || wired="$wired saas-design-session"
[ -z "$wired" ] && ok "/security is wired into the procedure, release, next-task, the rules, the reference, the skill, the setting and the docs" \
  || bad "/security isn't wired into:$wired"
# The tool step on the fixture: the check's rules fire on the seeded faults and not on the clean twin.
for v in vulnerable clean; do
  d="$work/security-$v"; rm -rf "$d"; cp -R "$src/tests/security/$v" "$d"
  cp "$src/framework/tools/check.sh" "$src/framework/tools/archcheck.awk" "$src/framework/tools/cfg.sh" "$d/tools/"
  mv "$d/clients/web/package.fixture.json" "$d/clients/web/package.json"
  mv "$d/clients/web/package-lock.fixture.json" "$d/clients/web/package-lock.json"
  mv "$d/src/Shop.Functions/Shop.Functions.csproj.fixture" "$d/src/Shop.Functions/Shop.Functions.csproj"
done
fake_key="Account""Key=q2Vh4dN0k3sRm7Yy1PzT8wLx6Jc9Bf5Ga0Hu2Ie4Kd7Ms="
settings_json="$work/security-vulnerable/src/Shop.Functions/appsettings.json"
sed "s|SEEDED_ACCOUNT_KEY|$fake_key|" "$settings_json" > "$work/security-settings" && cp "$work/security-settings" "$settings_json"
for v in vulnerable clean; do (cd "$work/security-$v" && git init -q && git config core.autocrlf false && git add -A) >/dev/null 2>&1; done
out="$(cd "$work/security-vulnerable" && bash tools/check.sh --architecture 2>&1)"
expect_status "the check fails the vulnerable fixture" 1 $? "$out"
expect_output "secrets (A04) finds the seeded key" '\[secrets\] src/Shop\.Functions/appsettings\.json:2' "$out"
expect_no_output "and never prints it" "q2Vh4dN0k3sRm7" "$out"
expect_output "tenant-source (A01, API1) finds the tenant read from a header" '\[tenant-source\] src/Shop\.Functions/Orders/ListOrdersFunction\.cs:16' "$out"
expect_output "network-public (A02) finds the public Service Bus" '\[network-public\] infra/modules/bus\.bicep' "$out"
out="$(cd "$work/security-clean" && bash tools/check.sh --architecture 2>&1)"
expect_status "the check passes the clean twin" 0 $? "$out"
expect_no_output "and reports none of the seeded faults" '\[(secrets|tenant-source|network-public)\]' "$out"
# The dependency audits, where the tool is installed and the advisory database answers.
offline='ENOTFOUND|ETIMEDOUT|EAI_AGAIN|ECONNREFUSED|ECONNRESET|audit endpoint returned an error|Unable to load the service index|NU1301|No such host'
if command -v npm >/dev/null 2>&1; then
  out="$(cd "$work/security-vulnerable/clients/web" && COREPACK_ENABLE_NETWORK=0 COREPACK_ENABLE_DOWNLOAD_PROMPT=0 npm audit --omit=dev 2>&1 </dev/null)"; status=$?
  if [[ $out =~ $offline ]]; then
    echo "  note  npm audit skipped: the advisory database didn't answer"
  else
    expect_status "npm audit (A03) fails the vulnerable fixture" 1 "$status" "$out"
    expect_output "and names the seeded package" 'lodash' "$out"
    out="$(cd "$work/security-clean/clients/web" && COREPACK_ENABLE_NETWORK=0 COREPACK_ENABLE_DOWNLOAD_PROMPT=0 npm audit --omit=dev 2>&1 </dev/null)"
    expect_status "npm audit passes the clean twin" 0 $? "$out"
  fi
else
  echo "  note  npm audit skipped: npm isn't installed"
fi
if [ "$dotnet_sdk" -eq 1 ]; then
  vuln_proj="$work/security-vulnerable/src/Shop.Functions/Shop.Functions.csproj"
  clean_proj="$work/security-clean/src/Shop.Functions/Shop.Functions.csproj"
  if ! dotnet restore "$vuln_proj" >/dev/null 2>&1 </dev/null || ! dotnet restore "$clean_proj" >/dev/null 2>&1 </dev/null; then
    echo "  note  dotnet list package --vulnerable skipped: restore failed (no network?)"
  else
    out="$(dotnet list "$vuln_proj" package --vulnerable --include-transitive 2>&1 </dev/null)"
    if [[ $out =~ $offline ]]; then
      echo "  note  dotnet list package --vulnerable skipped: the advisory source didn't answer"
    else
      expect_output "dotnet list package --vulnerable (A03) names the seeded package" 'Newtonsoft\.Json' "$out"
      out="$(dotnet list "$clean_proj" package --vulnerable --include-transitive 2>&1 </dev/null)"
      expect_output "and finds nothing in the clean twin" 'has no vulnerable packages' "$out"
    fi
  fi
else
  echo "  note  dotnet list package --vulnerable skipped: no .NET SDK on this machine"
fi

# --- user stories ----------------------------------------------------------------------------------
echo "user stories"
# tools/stories.sh --due counts built items as next-task.md counts them for the security assessment, from the
# commit on the stories file's Last validated line (by its date when that commit isn't in the history), and
# is due when the stories were never validated. The seed stands in for an app's file.
_st="$work/stories"; new_repo "$_st"; mkdir -p "$_st/tools" "$_st/product"
cp "$src/framework/tools/stories.sh" "$_st/tools/"
out="$(cd "$_st" && bash tools/stories.sh --due 2>&1)"; status=$?
expect_status "stories --due exits 0 without a stories file" 0 "$status" "$out"
expect_output "stories --due: not due without a stories file" "^stories: not due: no stories yet \(no product/user-stories\.md\), \[stories\] every = 10$" "$out"
printf '# User stories: x\n\n**Next ID:** US-1 · **Last validated:** never\n\n## Roles\n' > "$_st/product/user-stories.md"
out="$(cd "$_st" && bash tools/stories.sh --due 2>&1)"
expect_output "stories --due: not due while the file has no stories" "^stories: not due: no stories yet in product/user-stories\.md" "$out"
cp "$stories_seed" "$_st/product/user-stories.md"
_st_total="$(grep -c '^| US-' "$stories_seed")"; _st_unc="$(grep -c '| unconfirmed |$' "$stories_seed")"
out="$(cd "$_st" && bash tools/stories.sh --due 2>&1)"
expect_output "stories --due: due when never validated, counting the stories and the unconfirmed ones" \
  "^stories: due: never validated \(Last validated: never\), $_st_total stories, $_st_unc unconfirmed, \[stories\] every = 10$" "$out"
(cd "$_st" && for i in 1 2 3; do git_q commit -q --allow-empty -m "feat: item (T$i)"; done && git_q commit -q --allow-empty -m "docs: note (R1)")
printf '[stories]\n; a comment line\nevery = 3\n' > "$_st/tools/check.cfg"
_st_validated() { # <the Last validated value>
  sed "s/\*\*Last validated:\*\* never/**Last validated:** $1/" "$stories_seed" > "$_st/product/user-stories.md"
}
_st_validated "2026-01-01 at \`$(cd "$_st" && git rev-parse --short HEAD~2)\`"
out="$(cd "$_st" && bash tools/stories.sh --due 2>&1)"
expect_output "stories --due counts from the Last validated commit, research items left out" \
  "^stories: not due: built items since the last validation \(2026-01-01, commit [0-9a-f]+\): 1, \[stories\] every = 3; $_st_total stories, $_st_unc unconfirmed$" "$out"
(cd "$_st" && git_q commit -q --allow-empty -m "feat: squashed item (T4) (#12)" && git_q commit -q --allow-empty -m "fix: squashed bug (B2) (#13)")
out="$(cd "$_st" && bash tools/stories.sh --due 2>&1)"
expect_output "stories --due counts squash-merge subjects and is due at [stories] every = 3" "^stories: due: built items since the last validation \(2026-01-01, commit [0-9a-f]+\): 3, \[stories\] every = 3" "$out"
(cd "$_st" && git_q commit -q --allow-empty -m "fix: B5 is mentioned (B5) but not at the end")
out="$(cd "$_st" && bash tools/stories.sh --due 2>&1)"
expect_output "stories --due ignores an item ID that doesn't end the subject" ": 3, \[stories\] every = 3" "$out"
_st_validated "2000-01-01 at \`0000000\`"
out="$(cd "$_st" && bash tools/stories.sh --due 2>&1)"
expect_output "stories --due counts by the date when the commit isn't in this history" \
  "^stories: due: built items since the last validation \(2000-01-01, by its date: its commit isn't in this history\): 5, \[stories\] every = 3" "$out"
_st_validated "2000-01-01"
out="$(cd "$_st" && bash tools/stories.sh --due 2>&1)"
expect_output "stories --due counts by the date when the line names no commit" \
  "^stories: due: built items since the last validation \(2000-01-01, by its date: the line names no commit\): 5, \[stories\] every = 3" "$out"
grep -v '^\*\*Next ID:\*\*' "$stories_seed" > "$_st/product/user-stories.md"
out="$(cd "$_st" && bash tools/stories.sh --due 2>&1)"
expect_output "stories --due is due, and says why, when the file has no Last validated line" \
  "^stories: due: never validated \(product/user-stories\.md has no Last validated line\), $_st_total stories" "$out"
printf '[stories]\nevery = often\n' > "$_st/tools/check.cfg"
out="$(cd "$_st" && bash tools/stories.sh --due 2>&1)"
expect_output "stories --due notes a setting that isn't a whole number above 0 and uses 10" "^stories: note: \[stories\] every = often isn't a whole number above 0; using 10" "$out"
printf '[stories]\nevery = 0\n' > "$_st/tools/check.cfg"
out="$(cd "$_st" && bash tools/stories.sh --due 2>&1)"
expect_output "stories --due treats every = 0 the same way" "^stories: note: \[stories\] every = 0 isn't a whole number above 0; using 10" "$out"
out="$(cd "$_st" && bash tools/stories.sh 2>&1)"; status=$?
expect_status "stories.sh without --due exits 3" 3 "$status" "$out"
# Outside a git repository (git isn't allowed to look above $work for one) it can't count, and says so.
_st_nogit="$work/stories-nogit"; mkdir -p "$_st_nogit/tools" "$_st_nogit/product"
cp "$src/framework/tools/stories.sh" "$_st_nogit/tools/"; cp "$stories_seed" "$_st_nogit/product/"
out="$(cd "$_st_nogit" && GIT_CEILING_DIRECTORIES="$work" bash tools/stories.sh --due 2>&1)"; status=$?
expect_status "stories --due exits 3 outside a git repository" 3 "$status" "$out"
expect_output "and says it couldn't count" "^stories: couldn't count: not a git repository$" "$out"

# --- prototypes -----------------------------------------------------------------------------------
echo "prototype"
# tools/prototype.sh on a throwaway app with an origin: start stops while origin/main is ahead, creates the
# worktree beside the project, the branch from main with no upstream and the committed PROTOTYPE.md, and refuses
# an existing name or an invalid one. Only a prototype (a linked worktree on a proto/ branch with PROTOTYPE.md at
# its root) skips the check: the pre-commit hook still scans every commit for secrets there, and blocks a commit
# while what the scan reads (adr/, tools/check.cfg, tools/check.sh, tools/archcheck.awk) differs from main's,
# and runs the check everywhere else, the Stop hook likewise, the pre-push hook refuses a proto/ branch, and
# the guard keeps a prototype session from Azure. harvest prints what the harvest reads and changes nothing;
# remove never forces and keeps the branch. The app's project check always fails (tools/check.local.sh), so a
# commit that goes through shows the check was skipped. A token is assembled at run time ($fake_key), never
# kept in a tracked file.
_proto_repo() { # _proto_repo <folder> <origin>: an app with the framework installed, a failing project check and an origin
  new_repo "$1" >/dev/null 2>&1
  bash "$src/install.sh" "$1" >/dev/null 2>&1
  sed 's/^stack = dotnet$/stack = none/' "$1/tools/check.cfg" > "$work/proto-cfg" && cp "$work/proto-cfg" "$1/tools/check.cfg"
  printf 'exit 1\n' > "$1/tools/check.local.sh"
  git init -q --bare "$2"
  (cd "$1" && git config user.name selftest && git config user.email selftest@localhost && git branch -M main \
    && git config branch.autoSetupMerge always \
    && git add -A && git commit -q --no-verify -m "install, with a failing project check" && git remote add origin "$2" \
    && git push -q origin main && bash tools/setup-clone.sh) >/dev/null 2>&1
}
_pa="$work/proto-app"; _pw="$work/proto-app-proto-quick-add"; _po="$work/proto-origin.git"
_proto_repo "$_pa" "$_po"
proto() { (cd "$_pa" && bash tools/prototype.sh "$@" 2>&1); }
commit_in() { (cd "$1" && git commit -qm "$2" 2>&1); }   # commit_in <folder> <message>
_pa_none() { [ ! -e "$_pw" ] && [ -z "$(git -C "$_pa" for-each-ref refs/heads/proto/)" ]; }   # no prototype yet
guard_in() { # guard_in <what> <project dir> <expected exit> <command> [tool name: Bash by default, or PowerShell]: the guard as a session in that folder
  local tool="${5:-Bash}" escaped="${4//\\/\\\\}"
  escaped="${escaped//\"/\\\"}"
  escaped="${escaped//$'\n'/\\n}"; escaped="${escaped//$'\t'/\\t}"   # as a real command line carries them
  printf '{"session_id":"s","tool_name":"%s","tool_input":{"command":"%s","description":"run"}}' "$tool" "$escaped" \
    | CLAUDE_PROJECT_DIR="$2" bash "$src/framework/.claude/hooks/guard-commands.sh" >/dev/null 2>&1
  local got=$?
  local shown="${4//$'\n'/\\n}"; shown="${shown//$'\t'/\\t}"
  [ "$tool" = Bash ] || shown="($tool) $shown"
  if [ "$got" -eq "$3" ]; then ok "$([ "$3" -eq 2 ] && echo blocks || echo allows) in $1: $shown"; else bad "guard exit $got, expected $3 in $1: $shown"; fi
}

[ -x "$_pa/tools/prototype.sh" ] && [ -x "$_pa/.githooks/pre-push" ] && ok "the throwaway app has the installed prototype tools" \
  || bad "the throwaway app has the installed prototype tools"
out="$(proto list)"
expect_output "list says so when there are no prototypes" "^prototype: no prototypes \(no proto/ branches\)$" "$out"

# A prototype's only gates are its hooks and the secrets scan, so start refuses, creating nothing, without them.
_pa_hooks="$(git -C "$_pa" rev-parse --git-path hooks)"
[ "${_pa_hooks#/}" = "$_pa_hooks" ] && [ "${_pa_hooks#?:}" = "$_pa_hooks" ] && _pa_hooks="$_pa/$_pa_hooks"
mv "$_pa_hooks/pre-push" "$work/pre-push.saved"
out="$(proto start quick-add)"; status=$?
{ [ "$status" -eq 1 ] && printf '%s' "$out" | grep -q "this clone has no SaaSAllTheThings pre-push hook: run bash tools/setup-clone.sh here first" && _pa_none; } \
  && ok "start refuses, creating nothing, while this clone has no pre-push hook" || bad "start refuses while this clone has no pre-push hook (exit $status)" "$out"
mv "$work/pre-push.saved" "$_pa_hooks/pre-push"
mv "$_pa/tools/archcheck.awk" "$work/archcheck.saved"
out="$(proto start quick-add)"; status=$?
{ [ "$status" -eq 1 ] && printf '%s' "$out" | grep -q "the secrets scan can't run here" && _pa_none; } \
  && ok "start refuses, creating nothing, while the secrets scan can't run here" || bad "start refuses while the secrets scan can't run here (exit $status)" "$out"
mv "$work/archcheck.saved" "$_pa/tools/archcheck.awk"
_pm="$work/proto-old-main"; _proto_repo "$_pm" "$work/proto-old-origin.git"
(cd "$_pm" && git rm -q .githooks/pre-push tools/archcheck.awk && git commit -q --no-verify -m "a main without the hook and the scan's rules") >/dev/null 2>&1
out="$(cd "$_pm" && bash tools/prototype.sh start quick-add 2>&1)"; status=$?
{ [ "$status" -eq 1 ] && printf '%s' "$out" | grep -q "main has no committed .githooks/pre-push tools/archcheck.awk" && [ ! -e "$work/proto-old-main-proto-quick-add" ]; } \
  && ok "start refuses, creating nothing, when main has no committed pre-push hook or scan rules" || bad "start refuses when main lacks the hook and the scan rules (exit $status)" "$out"

# origin/main ahead of main (as last fetched): start creates nothing and says how to go on.
_pa_ahead="$(cd "$_pa" && git commit-tree -p main -m "a commit only origin has" "main^{tree}")"
git -C "$_pa" update-ref refs/remotes/origin/main "$_pa_ahead"
out="$(proto start quick-add)"; status=$?
expect_status "start stops when origin/main is ahead of main (exit 5)" 5 "$status" "$out"
expect_output "and offers to bring main up to date or to start as it is" "git pull --ff-only.*start quick-add --as-is" "$out"
[ ! -e "$_pw" ] && ! git -C "$_pa" show-ref --verify --quiet refs/heads/proto/quick-add \
  && ok "and creates no branch and no worktree" || bad "start created a prototype while origin/main was ahead"
out="$(proto start quick-add --as-is)"; status=$?
git -C "$_pa" update-ref refs/remotes/origin/main main
expect_status "start --as-is creates a prototype from main as it is" 0 "$status" "$out"
[ -d "$_pw" ] && [ "$(git -C "$_pw" symbolic-ref --short HEAD 2>/dev/null)" = "proto/quick-add" ] \
  && ok "start creates the worktree beside the project, named after it, on the new branch proto/quick-add" \
  || bad "start creates the worktree beside the project, named after it, on the new branch proto/quick-add" "$out"
[ "$(git -C "$_pa" merge-base main proto/quick-add 2>/dev/null)" = "$(git -C "$_pa" rev-parse main)" ] \
  && ok "the prototype's branch starts from local main" || bad "the prototype's branch starts from local main"
[ -z "$(git -C "$_pa" config --get branch.proto/quick-add.merge)" ] \
  && ok "the prototype's branch has no upstream, even with branch.autoSetupMerge = always" \
  || bad "the prototype's branch has an upstream: $(git -C "$_pa" config --get branch.proto/quick-add.merge)"
expect_output "start runs setup-clone in the worktree, which installs the pre-commit hook" "setup: pre-commit hook installed" "$out"
expect_output "and the pre-push hook" "setup: pre-push hook installed" "$out"
grep -q "^## What we're trying$" "$_pw/PROTOTYPE.md" && grep -q '^## How it felt$' "$_pw/PROTOTYPE.md" \
  && grep -q '^## What to keep$' "$_pw/PROTOTYPE.md" \
  && grep -qF 'A session in a checkout that `bash tools/prototype.sh here` calls a prototype (a linked worktree on a `proto/` branch with this file at its root) is a prototype session: read `.satt/procedures/prototype.md` › In a prototype session before any work.' "$_pw/PROTOTYPE.md" \
  && grep -qF 'it deploys nowhere, dev included' "$_pw/PROTOTYPE.md" \
  && [ -z "$(git -C "$_pw" status --porcelain)" ] && [ "$(git -C "$_pa" rev-list --count main..proto/quick-add)" = 1 ] \
  && ok "start writes PROTOTYPE.md from its template (what we're trying, how it felt, what to keep) and commits it" \
  || bad "start writes PROTOTYPE.md from its template and commits it" "$(cat "$_pw/PROTOTYPE.md" 2>&1)"

out="$(proto start quick-add)"; status=$?
expect_status "start refuses a name whose branch exists" 1 "$status" "$out"
expect_output "and says the branch exists" "the branch proto/quick-add already exists" "$out"
mkdir -p "$work/proto-app-proto-taken"
out="$(proto start taken)"; status=$?
expect_status "start refuses a name whose folder exists" 1 "$status" "$out"
expect_output "and says the folder exists" "the folder .*proto-app-proto-taken already exists" "$out"
_proto_bad=""
for _pn in Quick quick_add -x x- a/b .. 'two words' list harvest remove here ''; do
  out="$(proto start "$_pn")"; status=$?
  { [ "$status" -eq 1 ] && printf '%s' "$out" | grep -q "isn't a prototype name"; } || _proto_bad="$_proto_bad '$_pn'"
done
[ -z "$_proto_bad" ] && ok "start refuses an invalid name: capitals, an underscore, a dash at either end, a slash, dots, a space, a command word, none" \
  || bad "start doesn't refuse these names:$_proto_bad"
[ "$(git -C "$_pa" for-each-ref refs/heads/proto/ | wc -l | tr -d ' ')" = 1 ] && [ "$(git -C "$_pa" worktree list | wc -l | tr -d ' ')" = 2 ] \
  && ok "a refused start creates no branch and no worktree" || bad "a refused start creates no branch and no worktree" "$(git -C "$_pa" worktree list)"
out="$(cd "$_pw" && bash tools/prototype.sh start other 2>&1)"; status=$?
expect_status "start refuses to run in a prototype session" 1 "$status" "$out"
out="$(cd "$_pw" && bash tools/prototype.sh here 2>&1)"; status=$?
expect_status "here: the worktree is a prototype" 0 "$status" "$out"
out="$(cd "$_pa" && bash tools/prototype.sh here 2>&1)"; status=$?
expect_status "here: the main checkout isn't" 1 "$status" "$out"
out="$(proto list)"
expect_output "list shows the prototype, its worktree and its commits since main" "^proto/quick-add · .*proto-app-proto-quick-add · 1 commit\(s\) since main$" "$out"

# The pre-commit hook in the prototype: no project check, but the secrets scan on every commit.
(cd "$_pw" && printf 'export const tried = 1;\n' > tried.ts && git add tried.ts)
out="$(commit_in "$_pw" "proto: try it")"; status=$?
expect_status "pre-commit lets a source commit through in a prototype while the check fails" 0 "$status" "$out"
expect_output "and says the check is skipped in a prototype" "this checkout is a prototype, so the project check is skipped" "$out"
expect_output "and that the secrets scan still ran" "scanning for secrets" "$out"
expect_no_output "and doesn't run the check there" "running the project check|check.local" "$out"
(cd "$_pw" && printf 'export const key = "%s";\n' "$fake_key" > leak.ts && git add leak.ts)
_pt_commits="$(git -C "$_pw" rev-list --count HEAD)"
out="$(commit_in "$_pw" "proto: a secret")"; status=$?
expect_status "pre-commit still blocks a staged secret in a prototype" 1 "$status" "$out"
expect_output "and names the file and line" '\[secrets\] leak\.ts:1' "$out"
expect_output "and says a secret blocked the commit" 'a secret was found; commit blocked' "$out"
expect_no_output "and never prints the secret" "q2Vh4dN0k3sRm7" "$out"
[ "$(git -C "$_pw" rev-list --count HEAD)" = "$_pt_commits" ] && ok "the blocked commit in the prototype is not made" || bad "the blocked commit in the prototype is not made"
(cd "$_pw" && git reset -q -- leak.ts && rm -f leak.ts)
# The files the scan reads to excuse a finding or to find one must be main's, on disk and staged: excusing a secret
# needs the human, and a prototype has no review to catch it. Each of these blocks a commit that is otherwise fine.
(cd "$_pw" && printf 'export const ok = 3;\n' >> tried.ts && git add tried.ts)
_proto_blocked() { # _proto_blocked <what>: the commit in the prototype is blocked because the scan's files differ from main's
  out="$(commit_in "$_pw" "proto: $1")"; status=$?
  { [ "$status" -eq 1 ] && printf '%s' "$out" | grep -q "what the secrets scan reads differs from main's in this prototype; commit blocked"; } \
    && ok "pre-commit blocks a prototype commit while $1" || bad "pre-commit blocks a prototype commit while $1 (exit $status)" "$out"
}
(cd "$_pw" && put adr/ADR-9-excuse.md '# ADR-9 · Excuse a finding

- **Status:** accepted
- Exception: secrets leak.ts')
_proto_blocked "an ADR that excuses a secret is on disk, untracked"
expect_output "and names the file" "adr/ADR-9-excuse\.md" "$out"
(cd "$_pw" && git add adr/ADR-9-excuse.md)
_proto_blocked "an ADR is staged"
(cd "$_pw" && git rm -q -f --cached adr/ADR-9-excuse.md && rm -f adr/ADR-9-excuse.md)
printf '\n[scan]\nskip = leak.ts\n' >> "$_pw/tools/check.cfg"
_proto_blocked "tools/check.cfg on disk differs from main's"
(cd "$_pw" && git checkout -q -- tools/check.cfg)
rm -f "$_pw/tools/archcheck.awk"
_proto_blocked "the scan's rules (tools/archcheck.awk) are missing"
(cd "$_pw" && git checkout -q -- tools/archcheck.awk)
rm -f "$_pw/tools/check.sh"
_proto_blocked "the scan (tools/check.sh) is missing"
(cd "$_pw" && git checkout -q -- tools/check.sh)
out="$(commit_in "$_pw" "proto: more")"; status=$?
expect_status "and the same commit goes through once the scan's files are main's again" 0 "$status" "$out"
# Main moves on in a file the scan reads: the prototype's commits compare the index and the disk with main, not
# the commit they are made on, so they are blocked until the prototype takes main's copy, and then they go through
# although HEAD still holds the old one.
(cd "$_pa" && printf '; main moved on\n' >> tools/check.cfg && git commit -q --no-verify -am "chore: main changes the check settings") >/dev/null 2>&1
(cd "$_pw" && printf 'export const synced = 4;\n' >> tried.ts && git add tried.ts)
_proto_blocked "main changed tools/check.cfg and the prototype has not taken it"
expect_output "and says how to take main's copy" "git checkout refs/heads/main -- <path>" "$out"
(cd "$_pw" && git checkout -q refs/heads/main -- tools/check.cfg)
out="$(commit_in "$_pw" "proto: take main's check settings")"; status=$?
expect_status "and goes through once the prototype has taken main's copy, though HEAD held the old one" 0 "$status" "$out"
[ "$(git -C "$_pw" show HEAD:tools/check.cfg | tail -n 1)" = "; main moved on" ] \
  && ok "the commit carries main's tools/check.cfg" || bad "the commit carries main's tools/check.cfg"
# .gitattributes can make git grep skip a file as binary, so the root one and any in a folder must be main's too.
(cd "$_pw" && printf 'export const attr = 5;\n' >> tried.ts && git add tried.ts && printf '*.ts -text\n' >> .gitattributes)
_proto_blocked "the root .gitattributes on disk differs from main's"
(cd "$_pw" && git checkout -q -- .gitattributes && mkdir -p sub && printf '* binary\n' > sub/.gitattributes)
_proto_blocked "a .gitattributes in a folder is untracked"
expect_output "and names it" "sub/\.gitattributes" "$out"
(cd "$_pw" && git add sub/.gitattributes)
_proto_blocked "a .gitattributes in a folder is staged"
(cd "$_pw" && git rm -q -f --cached sub/.gitattributes && rm -rf sub && git reset -q -- tried.ts && git checkout -q -- tried.ts)

# Everywhere else the check runs: the prototype's worktree without PROTOTYPE.md or on a detached HEAD, a proto/
# branch in the main checkout (with or without PROTOTYPE.md: it isn't a linked worktree), main, and protoish.
# None of them is a prototype for the pre-commit hook. The guard is stricter: it fails closed, so a PROTOTYPE.md
# beside a .git file (a linked worktree) is a prototype whatever branch it is on, and lets Azure through only
# where one of the two is missing.
_proto_runs() { # _proto_runs <what> <folder> <guard exit for az there>: a staged file's commit there runs the failing check
  (cd "$2" && printf 'export const x = 1;\n' > runs.ts && git add runs.ts)
  out="$(commit_in "$2" "feat: runs")"; status=$?
  { [ "$status" -eq 1 ] && printf '%s' "$out" | grep -q "running the project check"; } \
    && ok "pre-commit runs the check in $1" || bad "pre-commit runs the check in $1 (exit $status)" "$out"
  (cd "$2" && git reset -q -- runs.ts && rm -f runs.ts)
  guard_in "$1" "$2" "$3" 'az deployment group what-if -g rg --template-file infra/main.bicep'
}
mv "$_pw/PROTOTYPE.md" "$work/PROTOTYPE.md.saved"
_proto_runs "a worktree on a proto/ branch without PROTOTYPE.md" "$_pw" 0
mv "$work/PROTOTYPE.md.saved" "$_pw/PROTOTYPE.md"
git -C "$_pw" checkout -q --detach
_proto_runs "a detached HEAD, in the prototype's worktree" "$_pw" 2
git -C "$_pw" switch -q proto/quick-add
git -C "$_pa" switch -q -c proto/fake
_proto_runs "a proto/ branch in the main checkout" "$_pa" 0
printf '# Prototype: fake\n' > "$_pa/PROTOTYPE.md"
_proto_runs "a proto/ branch in the main checkout, with a PROTOTYPE.md (not a linked worktree)" "$_pa" 0
rm -f "$_pa/PROTOTYPE.md"
git -C "$_pa" switch -q main && git -C "$_pa" branch -q -d proto/fake
_proto_runs "main" "$_pa" 0
git -C "$_pa" switch -q -c protoish
_proto_runs "a branch whose name only starts like one (protoish)" "$_pa" 0
git -C "$_pa" switch -q main && git -C "$_pa" branch -q -d protoish
(cd "$_pw" && git reset -q -- tried.ts && git checkout -q -- tried.ts)

# The Stop hook runs the check when files differ from the last commit, but not in a prototype.
_stop_in() { printf '{}' | CLAUDE_PROJECT_DIR="$1" bash "$src/framework/.claude/hooks/stop-check.sh" 2>&1; }
printf 'export const wip = 1;\n' > "$_pw/wip.ts"
out="$(_stop_in "$_pw")"; expect_status "the Stop hook doesn't run the check in a prototype" 0 $? "$out"
printf 'export const wip = 1;\n' > "$_pa/wip.ts"
out="$(_stop_in "$_pa")"; expect_status "the Stop hook runs the check on main, and blocks on a failure" 2 $? "$out"
rm -f "$_pa/wip.ts" "$_pa/.satt/state/last-reported"

# A prototype session never deploys: the guard blocks az, azd, func azure and gh workflow run there, in either
# way the session can be told (CLAUDE_PROJECT_DIR, or the folder it runs in), and keeps working locally. It reads
# the command as the shell does: a command on a later line (tab-indented or not), a path before the word, .exe,
# .cmd or .bat after it, the func subcommands that reach Azure (azure*, kubernetes) and the npm packages that
# hold func (azure-functions-core-tools, azfun, azurefunctions); and the quoted text too when the line names a shell
# with -c (any flags before it), PowerShell, cmd /c, python -c, node -e or eval, or holds a command
# substitution, where a false block beats a miss.
for cmd in \
    'az account show' \
    'az deployment group create -g rg --template-file infra/main.bicep' \
    'az deployment group what-if -g rg --template-file infra/main.bicep' \
    'az functionapp deployment source config-zip -g rg -n orders --src a.zip' \
    'azd up' \
    'azd deploy' \
    'azd provision' \
    'func azure functionapp publish orders-func' \
    'gh workflow run deploy.yml' \
    'bash tools/check.sh && azd up' \
    'cd src && az bicep build --file x.bicep' \
    'bash -c "az group list"' \
    $'cd src\naz account show' \
    $'cd src\n\taz account show' \
    $'dotnet build\n\n\tazd deploy' \
    $'cd src\\\naz account show' \
    $'bash <<\'EOF\'\naz account show\nEOF' \
    '/usr/bin/az account show' \
    './node_modules/.bin/func azure functionapp publish orders-func' \
    'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd account show' \
    'az.cmd account show' \
    'az.exe login' \
    'azd.exe up' \
    'func.exe azure functionapp publish orders-func' \
    'gh.exe workflow run deploy.yml' \
    'bash -e -c "az account show"' \
    'bash -ec "az account show"' \
    'sh -lc "azd up"' \
    'bash --noprofile --norc -c "az account show"' \
    'pwsh -Command "az account show"' \
    'powershell -NoProfile -c "az login"' \
    'cmd /c az account show' \
    'cmd /c "az account show"' \
    "python3 -c \"import os; os.system('az account show')\"" \
    'node -e "require(\"child_process\").execSync(\"az login\")"' \
    'eval "az account show"' \
    'echo "$(az account show)"' \
    'npx azure-functions-core-tools azure functionapp publish orders-func' \
    'npx -y azure-functions-core-tools@4 start' \
    'func azurecontainerapps deploy' \
    'func kubernetes deploy' \
    'func --verbose azure functionapp publish orders-func' \
    'azfun deploy' \
    'azurefunctions publish' \
    'AZ ACCOUNT SHOW' \
    'env az account show' \
    'cd x && (az login)' \
    '"az" account show' \
    "'azd' up" \
    'a"z" account show' \
    '"func" azure functionapp publish orders-func' \
    'bash -c "\"az\" account show"' \
    'echo ok; "gh" workflow run deploy.yml'; do
  guard_in "a prototype" "$_pw" 2 "$cmd"
done
# The PowerShell tool reaches the same rule: its commands are read as the shell's are, and Invoke-Expression and iex run a script.
for cmd in \
    'az account show' \
    '& az account show' \
    '& "az" account show' \
    'az.cmd account show' \
    'AZ account show' \
    'azd up' \
    'func azure functionapp publish orders-func' \
    'gh workflow run deploy.yml' \
    $'cd src\naz account show' \
    'dotnet build; az login' \
    'powershell -NoProfile -Command "az login"' \
    'Invoke-Expression "azd up"' \
    "iex 'az account show'"; do
  guard_in "a prototype" "$_pw" 2 "$cmd" PowerShell
done
for cmd in \
    'Get-Content README.md' \
    'dotnet test' \
    'git status --short' \
    'Write-Output "az account show is not for a prototype"' \
    'git commit -m "proto: az deployment and azd up are not for a prototype"' \
    "Invoke-Expression 'dotnet build'" \
    'bash tools/prototype.sh here'; do
  guard_in "a prototype" "$_pw" 0 "$cmd" PowerShell
done
guard_in "the main checkout" "$_pa" 0 'az account show' PowerShell
for cmd in \
    'func start' \
    'func new --name Orders --template "HTTP trigger"' \
    'bash tools/check.sh' \
    'dotnet test' \
    'git status --short' \
    'git commit -m "proto: az deployment and azd up are not for a prototype"' \
    $'git commit -q -F - <<\'EOF\'\nproto: try the order screen\nEOF' \
    'gh pr list' \
    'echo azure' \
    'bash -c "echo hello"' \
    'python3 -c "print(1)"' \
    'python3 --version' \
    'node -e "console.log(1)"' \
    'pwsh --version' \
    $'cd src\nls' \
    'bash tools/prototype.sh here'; do
  guard_in "a prototype" "$_pw" 0 "$cmd"
done
for cmd in \
    'az deployment group what-if -g rg --template-file infra/main.bicep' \
    $'cd src\naz account show' \
    'azd up' \
    'func azure functionapp publish orders-func' \
    'gh workflow run deploy.yml'; do
  guard_in "the main checkout" "$_pa" 0 "$cmd"
done
out="$(printf '{"session_id":"s","tool_name":"Bash","tool_input":{"command":"azd up","description":"run"}}' | (unset CLAUDE_PROJECT_DIR; cd "$_pw" && bash "$src/framework/.claude/hooks/guard-commands.sh") 2>&1)"; status=$?
expect_status "the guard finds the prototype from the folder it runs in when CLAUDE_PROJECT_DIR isn't set" 2 "$status" "$out"
expect_output "and says a prototype never deploys" "a prototype never deploys or changes anything in Azure, dev included" "$out"

# The authority guard in a prototype refuses (exit 2) an edit to the hooks, the guard, the scan and the files that excuse a
# finding, where elsewhere it asks for the framework-owned ones. .satt/ still asks there, and a product file passes. A
# PROTOTYPE.md beside a .git file is what makes it a prototype: the main checkout (a .git folder) asks even with one.
edit_in() { # edit_in <refused|asked|allowed> <what> <project dir> <file_path>: the authority guard on an Edit there
  local out status
  out="$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"a","new_string":"b"}}' "$4" \
    | CLAUDE_PROJECT_DIR="$3" bash "$src/framework/.claude/hooks/guard-authority.sh" 2>&1)"; status=$?
  case "$1" in
    refused) if [ "$status" -eq 2 ] && [[ $out == *"in a prototype"* ]]; then ok "refuses an edit to $2"; else bad "refuses an edit to $2 (exit $status)" "$out"; fi ;;
    asked) if [ "$status" -eq 0 ] && [[ $out == *'"permissionDecision":"ask"'* ]]; then ok "asks before an edit to $2"; else bad "asks before an edit to $2 (exit $status)" "$out"; fi ;;
    allowed) if [ "$status" -eq 0 ] && [[ $out != *permissionDecision* ]]; then ok "lets through an edit to $2"; else bad "lets through an edit to $2 (exit $status)" "$out"; fi ;;
  esac
}
for f in .githooks/pre-commit .claude/settings.json .claude/hooks/guard-commands.sh tools/prototype.sh tools/setup-clone.sh \
    tools/check.sh tools/archcheck.awk tools/check.cfg adr/ADR-9-excuse.md .gitattributes sub/.gitattributes; do
  edit_in refused "$f, in the prototype" "$_pw" "$_pw/$f"
done
edit_in asked ".satt/reference/tenancy.md, in the prototype" "$_pw" "$_pw/.satt/reference/tenancy.md"
edit_in allowed "src/Orders.cs, in the prototype" "$_pw" "$_pw/src/Orders.cs"
edit_in allowed "PROTOTYPE.md, in the prototype" "$_pw" "$_pw/PROTOTYPE.md"
mv "$_pw/PROTOTYPE.md" "$work/PROTOTYPE.md.authority"
edit_in asked "tools/check.sh, in a worktree with no PROTOTYPE.md" "$_pw" "$_pw/tools/check.sh"
mv "$work/PROTOTYPE.md.authority" "$_pw/PROTOTYPE.md"
edit_in asked ".githooks/pre-push, in the main checkout" "$_pa" "$_pa/.githooks/pre-push"
edit_in asked "tools/prototype.sh, in the main checkout" "$_pa" "$_pa/tools/prototype.sh"
edit_in asked ".claude/hooks/guard-commands.sh, in the main checkout" "$_pa" "$_pa/.claude/hooks/guard-commands.sh"
edit_in asked "tools/check.sh, in the main checkout" "$_pa" "$_pa/tools/check.sh"
edit_in allowed ".claude/settings.json, in the main checkout" "$_pa" "$_pa/.claude/settings.json"
edit_in allowed "tools/check.cfg, in the main checkout" "$_pa" "$_pa/tools/check.cfg"
edit_in allowed ".gitattributes, in the main checkout" "$_pa" "$_pa/.gitattributes"
edit_in allowed "an ADR that isn't accepted, in the main checkout" "$_pa" "$_pa/adr/ADR-9-excuse.md"
put "$_pa/PROTOTYPE.md" '# Prototype: fake'
edit_in asked "tools/check.sh, with a PROTOTYPE.md in the main checkout (a .git folder, so not a prototype)" "$_pa" "$_pa/tools/check.sh"
rm -f "$_pa/PROTOTYPE.md"

# The pre-push hook refuses a proto/ branch, from the prototype or to the remote, and any push that carries a
# prototype's commits under another name, and lets main through.
_push_refused() { # _push_refused <what> <folder> <refspec> <reason pattern>
  out="$(cd "$2" && git push -q origin "$3" 2>&1)"; status=$?
  { [ "$status" -ne 0 ] && printf '%s' "$out" | grep -q "a prototype is never pushed; push blocked" && printf '%s' "$out" | grep -q "$4"; } \
    && ok "pre-push refuses $1" || bad "pre-push refuses $1 (exit $status)" "$out"
}
_push_refused "a proto/ branch" "$_pw" proto/quick-add "(a proto/ branch)"
_push_refused "a push to a proto/ branch on the remote" "$_pa" main:refs/heads/proto/sneak "(a proto/ branch)"
_push_refused "HEAD under another name, from the prototype" "$_pw" HEAD:refs/heads/x "carries a prototype's commits"
_push_refused "a prototype's commit by its hash" "$_pa" "$(git -C "$_pa" rev-parse proto/quick-add):refs/heads/y" "carries a prototype's commits"
_push_refused "proto/quick-add~0 under another name" "$_pa" "proto/quick-add~0:refs/heads/z" "carries a prototype's commits"
git -C "$_pa" branch from-proto proto/quick-add >/dev/null 2>&1
_push_refused "a branch made from a prototype's commit" "$_pa" from-proto "carries a prototype's commits"
(cd "$_pa" && printf '# app\n\nA note.\n' > README.md && git add README.md && git commit -qm "docs: a note") >/dev/null 2>&1
out="$(cd "$_pa" && git push -q origin main 2>&1)"
expect_status "pre-push lets main through" 0 $? "$out"
[ "$(git --git-dir="$_po" for-each-ref --format='%(refname)')" = "refs/heads/main" ] \
  && ok "the origin has main and nothing else" || bad "a refused push reached the origin" "$(git --git-dir="$_po" for-each-ref)"

# harvest prints the prototype's commits, files, the diff command, uncommitted changes and notes, and writes nothing.
_pa_state() { git -C "$_pa" status --porcelain; git -C "$_pa" rev-parse HEAD proto/quick-add; git -C "$_pa" for-each-ref; cksum < "$_pa/TASKS.md"; }
_pa_before="$(_pa_state)"
out="$(proto harvest quick-add)"; status=$?
expect_status "harvest prints what the harvest reads" 0 "$status" "$out"
expect_output "harvest lists the prototype's commits since main" "proto: try it" "$out"
expect_output "harvest lists the files the prototype changed, with the diff command" "read the diff with: git diff main\.\.\.proto/quick-add" "$out"
expect_output "harvest lists a changed file" "tried\.ts" "$out"
expect_output "harvest names the worktree's uncommitted changes, which the diff leaves out" "(^|[[:space:]])\?\? wip\.ts([[:space:]]|$)" "$out"
expect_output "harvest shows the prototype's notes" "## How it felt" "$out"
[ "$(_pa_state)" = "$_pa_before" ] && ok "harvest writes no item, record, commit or branch without the human" \
  || bad "harvest changed the main checkout or the branches" "$(_pa_state)"
out="$(proto harvest nothing-here)"; expect_status "harvest refuses a prototype that doesn't exist" 1 $? "$out"

# harvest and list name a gate file that differs from main's, committed or not, and name none while every one is main's.
out="$(proto harvest quick-add)"
expect_no_output "harvest names no gate file while every one is main's" "gate files that differ" "$out"
printf '\n# a prototype edit, not committed\n' >> "$_pw/tools/check.cfg"
out="$(proto harvest quick-add)"
printf '%s\n' "$out" | sed -n '/^--- gate files/,$p' | grep -qx 'tools/check.cfg' \
  && ok "harvest names an uncommitted gate file that differs from main's" || bad "harvest names an uncommitted gate file that differs from main's" "$out"
out="$(proto list)"
expect_output "list names it too" "differs from main's: tools/check.cfg" "$out"
git -C "$_pw" checkout -q -- tools/check.cfg
printf '\n# a prototype edit, committed\n' >> "$_pw/tools/check.cfg"
git -C "$_pw" commit -q --no-verify -am "proto: edit the check settings" >/dev/null 2>&1
out="$(proto harvest quick-add)"
printf '%s\n' "$out" | sed -n '/^--- gate files/,$p' | grep -qx 'tools/check.cfg' \
  && ok "harvest names a committed gate file that differs from main's" || bad "harvest names a committed gate file that differs from main's" "$out"
git -C "$_pw" reset -q --hard HEAD~1

# remove: never forced, and the branch stays for the human to delete.
out="$(proto remove quick-add)"; status=$?
expect_status "remove fails on a worktree with uncommitted changes" 1 "$status" "$out"
[ -f "$_pw/wip.ts" ] && ok "and leaves the worktree and its changes in place" || bad "remove deleted a worktree with uncommitted changes"
expect_output "and says why, without forcing it" "git worktree remove failed \(above\); uncommitted changes are the usual cause.*never force it" "$out"
rm -f "$_pw/wip.ts"
out="$(proto remove quick-add)"; status=$?
expect_status "remove removes a clean worktree" 0 "$status" "$out"
[ ! -e "$_pw" ] && git -C "$_pa" show-ref --verify --quiet refs/heads/proto/quick-add \
  && ok "remove deletes the worktree's folder and keeps the branch with its commits" \
  || bad "remove deletes the worktree's folder and keeps the branch with its commits" "$out"
expect_output "remove asks the human to delete the branch, with the command" "the human runs that.*: git branch -D proto/quick-add$" "$out"
out="$(proto list)"
expect_output "list shows a prototype whose worktree is gone" "^proto/quick-add · no worktree · 4 commit\(s\) since main$" "$out"
[ -z "$(git --git-dir="$_po" for-each-ref refs/heads/proto/)" ] && [ -n "$(git --git-dir="$_po" for-each-ref refs/heads/main)" ] \
  && ok "nothing pushes a proto/ branch" || bad "a proto/ branch reached the origin" "$(git --git-dir="$_po" for-each-ref)"

# A project folder whose name has a space.
_ps="$work/proto space app"; _psw="$work/proto space app-proto-try"
_proto_repo "$_ps" "$work/proto-space-origin.git"
# A tag named main, on an older commit, is what a bare main would mean: the scripts and hooks name refs/heads/main.
git -C "$_ps" tag main HEAD~1
out="$(cd "$_ps" && bash tools/prototype.sh start try 2>&1)"; status=$?
expect_status "start works in a project folder whose name has a space, with a tag named main" 0 "$status" "$out"
[ "$(git -C "$_ps" merge-base refs/heads/main refs/heads/proto/try)" = "$(git -C "$_ps" rev-parse refs/heads/main)" ] \
  && ok "and the prototype starts from the branch main, not from the tag" || bad "the prototype did not start from the branch main"
(cd "$_psw" && printf 'export const tried = 1;\n' > tried.ts && git add tried.ts)
out="$(commit_in "$_psw" "proto: try it")"; status=$?
expect_status "pre-commit compares with the branch main there, tag or not" 0 "$status" "$out"
out="$(cd "$_psw" && git push -q origin HEAD:refs/heads/z 2>&1)"; status=$?
{ [ "$status" -ne 0 ] && printf '%s' "$out" | grep -q "a prototype is never pushed; push blocked"; } \
  && ok "pre-push refuses the prototype's commits there, tag or not" || bad "pre-push refuses the prototype's commits there (exit $status)" "$out"
out="$(cd "$_psw" && bash tools/prototype.sh here 2>&1)"
expect_status "the worktree beside it, named after it, is a prototype" 0 $? "$out"
out="$(cd "$_ps" && bash tools/prototype.sh list 2>&1)"
expect_output "list names its folder, space and all" "^proto/try · .*proto space app-proto-try · 2 commit\(s\) since main$" "$out"
out="$(cd "$_ps" && bash tools/prototype.sh harvest try 2>&1)"
expect_status "harvest works there" 0 $? "$out"
out="$(cd "$_ps" && bash tools/prototype.sh remove try 2>&1)"; status=$?
[ "$status" -eq 0 ] && [ ! -e "$_psw" ] && ok "remove works there" || bad "remove works in a folder whose name has a space (exit $status)" "$out"

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
