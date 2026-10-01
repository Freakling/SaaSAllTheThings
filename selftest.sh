#!/usr/bin/env bash
# SaaSAllTheThings self-test. It installs the framework into temporary copies of examples/order-desk and
# tests the installer, the architecture check, the command and authority guards, the Stop hook and
# the pre-commit hook. Run it after every change to the framework.
#
#   bash selftest.sh
#
# Nothing here needs a toolchain except the last part: where the .NET SDK is installed, the
# example's full check (build and tests) runs too. KEEP=1 keeps the temporary folder.

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

# --- framework files ----------------------------------------------------------------------------
echo "framework"
plugin_version="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$src/.claude-plugin/plugin.json")"
[ "$plugin_version" = "$(tr -d '\r\n' < "$src/VERSION")" ] && ok "plugin.json version matches VERSION" \
  || bad "plugin.json version ($plugin_version) matches VERSION ($(cat "$src/VERSION"))"
version="$(tr -d '\r\n' < "$src/VERSION")"
for skill in "$src"/skills/*/SKILL.md; do
  folder="${skill%/SKILL.md}"; folder="${folder##*/}"
  name=""; description=""; skill_version=""; branch=""; angle=0; dashes=0
  while IFS= read -r line; do
    [ "$line" = "---" ] && { dashes=$((dashes + 1)); continue; }
    if [ "$dashes" -eq 1 ]; then
      case "$line" in *'<'*|*'>'*) angle=1 ;; esac
      case "$line" in name:\ *) name="${line#name: }" ;; description:\ *) description="${line#description: }" ;; *version:\ *) skill_version="${line##*version: }" ;; esac
    fi
    [[ $line =~ --branch[[:space:]]+v([0-9.]+) ]] && branch="${BASH_REMATCH[1]}"
  done < "$skill"
  [[ $name =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] && [ "$name" = "$folder" ] && [[ ! $name =~ claude|anthropic ]] \
    && ok "the public skill $folder is named after its folder, in lowercase with hyphens" || bad "skill $folder is named '$name'"
  [ "$angle" -eq 0 ] && [ -n "$description" ] && [ "${#description}" -lt 1024 ] \
    && ok "its frontmatter has a description under 1024 characters and no < or >" || bad "skill $folder's frontmatter (description ${#description} characters, angle brackets: $angle)"
  [ "$skill_version" = "$version" ] && [ "$branch" = "$version" ] \
    && ok "its metadata.version and the release it clones match VERSION" || bad "skill $folder: version '$skill_version', clones v$branch, VERSION is $version"
done
cmp -s "$src/LICENSE" "$src/framework/.satt/LICENSE" && ok "the installed LICENSE copy matches LICENSE" \
  || bad "framework/.satt/LICENSE differs from LICENSE"
missing=""
for skill in "$src"/framework/.claude/skills/*/SKILL.md; do
  name="${skill%/SKILL.md}"; name="${name##*/}"
  [ -f "$src/framework/.satt/procedures/$name.md" ] || missing="$missing $name"
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
other=" contract.md prd.md decisions.md README.md TEMPLATE.md ONBOARDING.md CHANGELOG.md AGENTS.md CLAUDE.md TASKS.md TASKS-archive.md adr.md integration-contract.md "
while IFS="$(printf '\t')" read -r doc ref; do
  case "$ref" in
    reference/*) [ -f "$src/framework/.satt/$ref" ] || missing="$missing ${doc##*/}→$ref" ;;
    rules.md|tasks.md) [ -f "$src/framework/.satt/$ref" ] || missing="$missing ${doc##*/}→$ref" ;;
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
awk_rules="$(sed -n 's/^  rules = "\(.*\)"$/\1/p' "$src/framework/tools/archcheck.awk" | tr ' ' '\n' | LC_ALL=C sort | tr '\n' ' ')"
doc_rules="$(sed -n 's/^| `\([a-z-]*\)` | .*/\1/p' "$src/framework/.satt/reference/README.md" | LC_ALL=C sort | tr '\n' ' ')"
[ -n "$awk_rules" ] && [ "$awk_rules" = "$doc_rules" ] && ok "the check's rules match reference/README.md › What the check enforces" \
  || bad "rules differ: archcheck.awk has '$awk_rules', reference/README.md has '$doc_rules'"

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
    'az keyvault secret show --vault-name kv --name db' 'az ad app credential reset --id 123'; do
  guard 2 "$cmd"
done
for cmd in 'git status --short' 'git commit -m "feat: x (T12)" -- a.cs' 'git commit --amend --no-edit' \
    'git push origin feature-flag' 'git restore --staged a.cs' 'git checkout -b topic' 'bash tools/check.sh' \
    'git commit -m "docs: az group delete is for the human" -- a.md' "git commit -m 'fix: handle -f flag' -- a.cs" \
    'git reset --soft HEAD~1' 'az deployment group what-if -g rg --template-file infra/main.bicep' \
    'az bicep build --file infra/main.bicep' 'az ad app federated-credential create --id 1 --parameters fc.json' 'dotnet test'; do
  guard 0 "$cmd"
done

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
fault "an unknown layer in tools/check.cfg" tools/check.cfg "$(printf '[layers]\nweb = web/*')" "isn't a layer"

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
if ! command -v dotnet >/dev/null 2>&1; then
  sed 's/^stack = .*$/stack = dotnet/' tools/check.cfg > "$work/cfg2" && cp "$work/cfg2" tools/check.cfg
  out="$(bash tools/check.sh 2>&1)"; expect_status "exits 3 when the stack's toolchain is missing" 3 $? "$out"
  expect_output "still runs the architecture rules" "architecture: PASS" "$out"
fi
cp "$work/cfg" tools/check.cfg
printf 'exit 1\n' > tools/check.local.sh
out="$(bash tools/check.sh 2>&1)"; expect_status "fails when tools/check.local.sh fails" 1 $? "$out"
rm -f tools/check.local.sh
git add -A >/dev/null 2>&1; git_q commit -qm "stack none for the hook tests" >/dev/null 2>&1

# --- Stop hook ----------------------------------------------------------------------------------
echo "stop hook"
hook() { echo '{}' | CLAUDE_PROJECT_DIR="$app" bash .claude/hooks/stop-check.sh 2>&1; }
out="$(hook)"; expect_status "does nothing when code is unchanged" 0 $? "$out"
printf '# notes\n' > notes.md
out="$(hook)"; expect_status "does nothing for a docs-only change" 0 $? "$out"
rm -f notes.md
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
printf '# ADR-3 · x\n\n- **Status:** proposed\n' > adr/ADR-3-x.md && git add adr/ADR-3-x.md
out="$(git_q commit -qm "an ADR" 2>&1)"; expect_output "runs the check for an ADR" "running the project check" "$out"
printf 'x\n' > tools/check.sh.satt-new
printf '\n// another change\n' >> $domain && git add $domain
out="$(git_q commit -qm "with satt-new" 2>&1)"; expect_status "refuses while a .satt-new file is unmerged" 1 $? "$out"
rm -f tools/check.sh.satt-new
git reset -q HEAD -- $domain && git checkout -q -- $domain

# --- .NET, where the SDK is installed -----------------------------------------------------------
if command -v dotnet >/dev/null 2>&1; then
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
