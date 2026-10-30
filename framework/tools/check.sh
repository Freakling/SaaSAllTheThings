#!/usr/bin/env bash
# SaaSAllTheThings project check · framework-owned: replaced on upgrade.
#
# The single definition of "it works":
#   bash tools/check.sh                  run the check
#   bash tools/check.sh --architecture   only the architecture rules: seconds, no toolchain needed
#   bash tools/check.sh --secrets        only the secrets rule (step 1's), for the pre-commit hook to run on every commit
#   bash tools/check.sh --if-changed     repeat the last result at once if these exact files were checked
#   bash tools/check.sh --fingerprint    print the fingerprint of the current files (for hooks)
# Exit codes: 0 = pass · 1 = fail · 3 = couldn't run (a toolchain is missing)
#
# Steps:
#   1. architecture: tools/archcheck.awk applies the reference architecture's rules
#      (.satt/reference/README.md › What the check enforces) to the layers in tools/check.cfg.
#      Only an exception in an accepted ADR (adr/) excuses a violation.
#   2. the backend stack's build and tests: tools/stacks/<stack>.sh (tools/check.cfg › [project])
#   3. infra: compiles infra/*.bicep and infra/env/*.bicepparam when the Bicep CLI is installed
#   4. tools/check.local.sh, if the project has one: clients, emulator tests, extra steps
# Test commands run under GNU timeout when available: [tests] timeout in tools/check.cfg, 600 seconds
# by default; a run that hits the limit exits 3, unless a failure was already seen.
#
# The check never calls Azure or an external system. Logs are in .satt/state/. Process starts
# are slow on Windows, so it uses shell builtins wherever it can.

set -u
case "$0" in */*) cd "${0%/*}/.." ;; *) cd .. ;; esac || exit 3
mode="${1:-}"
state=".satt/state"
FIND=find; [ -x /usr/bin/find ] && FIND=/usr/bin/find   # not Windows' find.exe

read_file() { REPLY=""; [ -f "$1" ] && IFS= read -r REPLY < "$1"; return 0; }

# Hash of every file that can change the result: everything but Markdown, which counts only in adr/.
fingerprint() {
  local path list=()
  while IFS= read -r path; do
    case "$path" in adr/*) ;; *.md) continue ;; esac
    [ -f "$path" ] && list+=("$path")
  done < <(git -c core.quotePath=false ls-files -c -o --exclude-standard 2>/dev/null)
  [ "${#list[@]}" -gt 0 ] || return 0
  { printf '%s\n' "${list[@]}"; printf '%s\n' "${list[@]}" | git hash-object --no-filters --stdin-paths; } \
    | git hash-object --stdin
}

# What counts as a secret, for step 1 and for --secrets.
secret_patterns=(
  -e 'AccountKey=[A-Za-z0-9+/]{30,}'
  -e 'SharedAccessKey=[A-Za-z0-9+/]{30,}'
  -e '-----BEGIN ([A-Z]+ )*PRIVATE KEY-----'
  -e '[A-Za-z0-9_~.-]{3}[0-9]Q~[A-Za-z0-9_~.-]{31,}'
  -e '(sig|SharedAccessSignature)=[A-Za-z0-9%+/=]{40,}'
  -e '(password|pwd)=[^;"'"'"'<>{}$[:space:]]{6,}'
  -e '"(password|pwd|secret|client_?secret|api_?key|access_?key)"[[:space:]]*:[[:space:]]*"[^"<>{}$[:space:]]{6,}"'
  -e 'AKIA[0-9A-Z]{16}'
  -e 'gh[pousr]_[A-Za-z0-9]{36}'
  -e 'xox[abprs]-[A-Za-z0-9-]{10,}'
)
# scan_secrets <file>: the working tree's lines that match a pattern, as path:line:text (the text is
# never printed). The check's own files hold the patterns, so they're left out.
scan_secrets() {
  git -c core.quotePath=false grep -n -I -i -E --untracked "${secret_patterns[@]}" -- . \
    ':(exclude)tools/check.sh' ':(exclude)tools/archcheck.awk' > "$1" 2>/dev/null
}
# list_adrs <file>: the ADRs, for the exceptions that excuse a violation.
list_adrs() {
  local f
  : > "$1"
  for f in adr/ADR-*.md; do [ -f "$f" ] && printf '%s\n' "$f" >> "$1"; done
}

if [ "$mode" = "--fingerprint" ]; then fingerprint; exit 0; fi
[ -d "$state" ] || mkdir -p "$state" || exit 3

# --secrets: only the secrets rule of step 1, with the same patterns, [scan] skip folders, public
# emulator keys and accepted ADR exceptions, over the whole working tree. The pre-commit hook runs it
# on every commit, because it runs the whole check only for a commit that stages more than documentation.
# It only reads, so it takes no lock and no fingerprint. Other violations are the full check's to report.
if [ "$mode" = "--secrets" ]; then
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "check: note: not a git repository, so secrets aren't scanned"
    exit 0
  fi
  found="$state/secrets-scan.txt"; adrs="$state/secrets-adrs.txt"; log="$state/secrets-scan.log"
  list_adrs "$adrs"; : > "$log"
  scan_secrets "$found"
  awk -v cfg=tools/check.cfg -v adrs="$adrs" -v secrets="$found" -v logfile="$log" -f tools/archcheck.awk >/dev/null
  [ $? -le 1 ] || { echo "check: secrets: awk couldn't run the rules"; exit 3; }
  count=0
  while IFS= read -r line; do
    case "$line" in "  [secrets] "*) printf '%s\n' "$line"; count=$((count + 1)) ;; esac
  done < "$log"
  if [ "$count" -gt 0 ]; then
    echo "check: secrets: FAIL: $count (if it's real it's exposed: rotate it, remove it; only an accepted ADR in adr/ excuses one)"
    exit 1
  fi
  echo "check: secrets: PASS"
  exit 0
fi
. tools/cfg.sh

before=""
[ "$mode" = "--architecture" ] || before="$(fingerprint)"
# --if-changed: reuse the last result for exactly these files (asked again once the lock is ours).
reuse_last() {
  [ "$mode" = "--if-changed" ] && [ -n "$before" ] || return 0
  read_file "$state/last-pass"
  if [ "$REPLY" = "$before" ]; then
    echo "check: PASS (nothing changed since the last passing run)"
    exit 0
  fi
  read_file "$state/last-fail"
  if [ "$REPLY" = "$before" ]; then
    echo "check: FAIL (nothing changed since the last failing run; run 'bash tools/check.sh' to see why)"
    exit 1
  fi
}
reuse_last

# --- one run at a time (hooks and sessions share .satt/state) --------------------------------
lock="$state/lock"
waited=0
until mkdir "$lock" 2>/dev/null; do
  read_file "$lock/pid"
  if [ -n "$REPLY" ] && ! kill -0 "$REPLY" 2>/dev/null; then rm -rf "$lock"; continue; fi
  if [ "$waited" -ge 1800 ]; then
    echo "check: another check has run for 30 minutes. If none is running, delete $lock."
    exit 3
  fi
  [ "$waited" -eq 0 ] && echo "check: waiting for another check to finish…"
  sleep 2; waited=$((waited + 2))
done
echo $$ > "$lock/pid"
trap 'rm -rf "$lock"' EXIT
reuse_last   # the run we waited for may have checked exactly these files

# Each test command runs under GNU timeout (tools/check.cfg › [tests] timeout, default 600 seconds)
# when it's available. A run that hits the limit makes the check exit 3 (couldn't finish), not 1,
# unless a test already failed.
timeout_cmd=""
for candidate in timeout gtimeout; do   # GNU only: Windows' timeout.exe is something else
  if "$candidate" --version 2>/dev/null | grep -qi coreutils; then timeout_cmd="$candidate"; break; fi
done
[ -n "$timeout_cmd" ] || echo "check: note: no GNU timeout found, so a hung test can't be cut short"
# run_limited <log> <command…>: stdin closed, output to the log; status 124 means it hit the limit.
run_limited() {
  local log="$1"; shift
  if [ -n "$timeout_cmd" ]; then
    "$timeout_cmd" "$cfg_timeout" "$@" </dev/null >"$log" 2>&1
  else
    "$@" </dev/null >"$log" 2>&1
  fi
}
timed_out() { echo "check: $1 ran past the $cfg_timeout-second limit (tools/check.cfg › [tests] timeout) and was stopped, so this isn't a pass"; }

failed=0; unverified=0

# --- 1. architecture ------------------------------------------------------------------------------
architecture() {
  local list="$state/files.txt" adrs="$state/adrs.txt" secrets="$state/secrets.txt"
  : > "$secrets"
  if git -c core.quotePath=false ls-files -c -o --exclude-standard > "$list" 2>/dev/null; then
    scan_secrets "$secrets"
  else
    "$FIND" . -type f ! -path './.git/*' ! -path "./$state/*" | sed 's|^\./||' > "$list"
    echo "check: note: not a git repository, so secrets aren't scanned"
  fi
  list_adrs "$adrs"
  awk -v cfg=tools/check.cfg -v files="$list" -v adrs="$adrs" -v secrets="$secrets" \
    -v logfile="$state/architecture.log" -f tools/archcheck.awk || failed=1
}
architecture
if [ "$mode" = "--architecture" ]; then
  [ "$failed" -eq 0 ] && exit 0
  exit 1
fi

# --- 2. the stack ---------------------------------------------------------------------------------
stack_step() {
  local profile="tools/stacks/$cfg_stack.sh" status
  if [ "$cfg_stack_invalid" -eq 1 ] || [ ! -f "$profile" ]; then
    echo "check: FAIL: tools/check.cfg › [project] stack is '$cfg_stack', which has no profile in tools/stacks/"
    failed=1
    return
  fi
  . "$profile"
  stack_toolchain
  status=$?
  if [ "$status" -ne 0 ]; then unverified=1; return; fi
  stack_check
  status=$?
  case "$status" in 0) ;; 3) unverified=1 ;; *) failed=1 ;; esac
}
stack_step

# --- 3. infra -------------------------------------------------------------------------------------
infra_step() {
  local f bicep="" any=0 log="$state/bicep.log" bad=0
  for f in infra/*.bicep infra/env/*.bicepparam; do [ -f "$f" ] && any=1; done
  [ "$any" -eq 1 ] || return 0
  if command -v bicep >/dev/null 2>&1; then bicep="bicep"
  elif command -v az >/dev/null 2>&1; then bicep="az bicep"
  else
    echo "check: note: the Bicep CLI isn't installed, so infra/ wasn't compiled"
    return 0
  fi
  : > "$log"
  for f in infra/*.bicep infra/env/*.bicepparam; do
    [ -f "$f" ] || continue
    case "$f" in
      *.bicep)      if [ "$bicep" = "bicep" ]; then bicep build "$f" --stdout; else az bicep build --file "$f" --stdout; fi ;;
      *.bicepparam) if [ "$bicep" = "bicep" ]; then bicep build-params "$f" --stdout; else az bicep build-params --file "$f" --stdout; fi ;;
    esac </dev/null >/dev/null 2>>"$log" || bad=1
  done
  if [ "$bad" -eq 1 ] || grep -q ' Error ' "$log"; then
    echo "check: infra/ doesn't compile:"
    grep -E 'Error|error' "$log" | head -n 30 | sed 's/^/  /'
    failed=1
  else
    echo "check: infra/ compiles"
  fi
}
infra_step

# --- 4. project-specific steps --------------------------------------------------------------------
if [ -f tools/check.local.sh ]; then
  echo "check: running tools/check.local.sh"
  if [ -n "$timeout_cmd" ]; then "$timeout_cmd" "$cfg_timeout" bash tools/check.local.sh </dev/null; else bash tools/check.local.sh </dev/null; fi
  case $? in 0) ;; 124) timed_out "tools/check.local.sh"; unverified=1 ;; 3) echo "check: tools/check.local.sh couldn't run"; unverified=1 ;; *) echo "check: tools/check.local.sh failed"; failed=1 ;; esac
fi

hook_file="$(git rev-parse --git-path hooks 2>/dev/null)/pre-commit"
hook_ok=0
if [ -f "$hook_file" ]; then
  while IFS= read -r line; do case "$line" in *SaaSAllTheThings*) hook_ok=1; break ;; esac; done < "$hook_file"
fi
[ "$hook_ok" -eq 1 ] || echo "check: note: this clone has no SaaSAllTheThings pre-commit hook. Run: bash tools/setup-clone.sh"

if [ "$failed" -ne 0 ]; then
  rm -f "$state/last-pass"
  if [ -n "$before" ] && [ "$before" = "$(fingerprint)" ]; then printf '%s' "$before" > "$state/last-fail"; fi
  echo "check: FAIL (full logs in $state/)"
  exit 1
fi
if [ "$unverified" -ne 0 ]; then
  echo "check: UNVERIFIED: part of the check couldn't run (see above), so this isn't a pass"
  exit 3
fi
after="$(fingerprint)"
if [ -n "$before" ] && [ "$before" = "$after" ]; then
  printf '%s' "$before" > "$state/last-pass"
elif [ -n "$before" ]; then
  echo "check: note: files changed while the check ran; run it again to cover the changes."
fi
rm -f "$state/last-fail"
echo "check: PASS"
exit 0
