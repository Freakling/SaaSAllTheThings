#!/usr/bin/env bash
# SaaSAllTheThings project check · framework-owned: replaced on upgrade.
#
# The single definition of "it works", in two tiers:
#   bash tools/check.sh                  the full tier: every step over the whole project (same as --full)
#   bash tools/check.sh --fast           the fast tier: the architecture rules and the secrets scan over the whole
#                                        project, then only the steps the change from HEAD touches (below)
#   bash tools/check.sh --if-changed     with either tier: repeat the recorded result at once when these exact files
#                                        were checked by a tier that covers the request (a full result covers both
#                                        tiers; a fast one only the fast tier, never the full one)
#   bash tools/check.sh --due            say whether the full tier is due, and why; runs nothing else
#   bash tools/check.sh --architecture   only the architecture rules: seconds, no toolchain needed
#   bash tools/check.sh --secrets        only the secrets rule (step 1's), for the pre-commit hook to run on every commit
#   bash tools/check.sh --fingerprint    print the fingerprint of the current files (for hooks)
#   bash tools/check.sh --unignored      print the paths read from stdin, one per line, that the check counts (the
#                                        fingerprint's rule, counted_path below); the hooks give it the changed paths
# Exit codes: 0 = pass · 1 = fail · 3 = couldn't run (a toolchain is missing, a step hit its limit, an unknown flag,
# a missing tools/cfg.sh)
#
# Steps:
#   1. architecture: tools/archcheck.awk applies the reference architecture's rules
#      (.satt/reference/README.md › What the check enforces) to the layers in tools/check.cfg.
#      Only an exception in an accepted ADR (adr/) excuses a violation. Both tiers, the whole project.
#   2. the backend stack's build and tests: tools/stacks/<stack>.sh (tools/check.cfg › [project])
#   3. infra: compiles infra/*.bicep and infra/env/*.bicepparam when the Bicep CLI is installed
#   4. tools/check.local.sh, if the project has one: clients, emulator tests, extra steps. It gets CHECK_TIER (fast or
#      full) and, in the fast tier, CHECK_CHANGED (an absolute path of a file listing the changed paths, one per line),
#      so it can leave out what the change doesn't touch.
# The fast tier's changes are the paths that differ from HEAD, staged or not (deletions too), and the untracked files git
# doesn't ignore. It runs step 3 only when one is under infra/ or is a bicepconfig.json, and step 2 unless every one is
# Markdown, in the client layer (tools/check.cfg › [layers]), or Bicep's and in no layer. A path that runs the full tier
# counts in the fingerprint even when it is Markdown. It runs as the full tier, and says why, outside a git repository,
# before the first commit, and when a changed path is a dependency, its lockfile, a toolchain setting (full_when_stack
# below, per stack), a file under tools/ or a [tests] full-when path (bash case patterns from the repository root; one
# that ends in / is a folder).
# The full tier is due (--due, and the result line of a fast pass) when no full pass is recorded, when [tests] full-every
# commits (default 10; 0: never by count) were made since the last one, or when such a path differs from HEAD (the
# commit that carries one runs the full tier, so the next one isn't due for it).
# Each tier has its own limit for each test command: [tests] timeout-fast (default 300 seconds) and timeout-full (default
# 600; the older [tests] timeout counts when it isn't set); CHECK_TIMEOUT overrides both. They need GNU timeout; a run
# that hits the limit exits 3, unless a failure was already seen.
# Steps 2 to 4 run one after the other, or side by side with tools/check.cfg › [tests] parallel = on (each
# with its own limit and log, printed in the same order). Every run ends with each step's seconds and the total.
#
# State, in .satt/state/: last-pass and last-fail (line 1 the fingerprint, line 2 tier=<fast|full> commit=<HEAD>
# run=<id>; a fast one has a .changed list beside it: run=<id>, then the changed paths it checked), last-full (the
# commit and time of the last full pass, for --due) and the logs.
# The check never calls Azure or an external system. Process starts are slow on Windows, so it uses shell builtins
# wherever it can.

set -u
case "$0" in */*) cd "${0%/*}/.." ;; *) cd .. ;; esac || exit 3
state=".satt/state"
nl='
'
FIND=find; [ -x /usr/bin/find ] && FIND=/usr/bin/find   # not Windows' find.exe
SORT=sort; [ -x /usr/bin/sort ] && SORT=/usr/bin/sort   # not Windows' sort.exe
usage="usage: bash tools/check.sh [--full | --fast] [--if-changed] | --due | --architecture | --secrets | --fingerprint | --unignored"

# --- the command line -------------------------------------------------------------------------------
requested=""; if_changed=0; mode=""
for arg; do
  case "$arg" in
    --full|--fast)
      if [ -n "$requested" ] && [ "$requested" != "${arg#--}" ]; then echo "check: --full and --fast can't be combined"; echo "$usage"; exit 3; fi
      requested="${arg#--}" ;;
    --if-changed) if_changed=1 ;;
    --due|--architecture|--secrets|--fingerprint|--unignored)
      if [ -n "$mode" ] && [ "$mode" != "$arg" ]; then echo "check: $mode and $arg can't be combined"; echo "$usage"; exit 3; fi
      mode="$arg" ;;
    *) echo "check: unknown flag: $arg"; echo "$usage"; exit 3 ;;
  esac
done
requested="${requested:-full}"

read_file() { REPLY=""; [ -f "$1" ] && IFS= read -r REPLY < "$1"; return 0; }
# Every mode reads the settings, so without the reader nothing can run: exit 3, never 1, which --secrets would mean
# as a secret found.
if [ ! -f tools/cfg.sh ]; then
  echo "check: tools/cfg.sh is missing, so the check can't read tools/check.cfg and nothing was checked."
  echo "check: it is framework-owned: restore it with 'git checkout HEAD -- tools/cfg.sh', or upgrade SaaSAllTheThings."
  exit 3
fi
. tools/cfg.sh

# Paths whose change runs the full tier: a file under tools/ (the check, its settings, the stack profiles), the stack's
# dependencies, lockfiles and toolchain settings, and [tests] full-when. Bash case patterns from the repository root,
# where * crosses folders; one that ends in / is a folder.
full_when_stack=""
case "$cfg_stack" in
  dotnet) full_when_stack="*.csproj *.fsproj *.vbproj *.sln *.slnx *.props *.targets Directory.Build.rsp */Directory.Build.rsp global.json */global.json [Nn]u[Gg]et.[Cc]onfig */[Nn]u[Gg]et.[Cc]onfig *packages.lock.json .config/dotnet-tools.json .editorconfig */.editorconfig *.globalconfig" ;;
  typescript) full_when_stack="package.json */package.json package-lock.json */package-lock.json pnpm-lock.yaml */pnpm-lock.yaml pnpm-workspace.yaml yarn.lock */yarn.lock .yarnrc.yml bun.lock* */bun.lock* .npmrc .nvmrc .node-version tsconfig*.json */tsconfig*.json eslint.config.* */eslint.config.* .eslintrc* */.eslintrc* vitest.config.* */vitest.config.* vite.config.* */vite.config.* jest.config.* */jest.config.*" ;;
  python) full_when_stack="pyproject.toml */pyproject.toml requirements*.txt */requirements*.txt poetry.lock uv.lock Pipfile Pipfile.lock setup.py */setup.py setup.cfg */setup.cfg .python-version pytest.ini tox.ini mypy.ini ruff.toml .flake8" ;;
esac
full_when="tools/ $full_when_stack $cfg_full_when"

# path_in <path> <patterns>: 0 when the path matches one of the space-separated patterns. Unquoted, so a wildcard in a
# folder pattern (src/*/Migrations/) matches as one.
path_in() {
  local p="$1" pat hit=1
  set -f
  for pat in $2; do
    case "$pat" in
      */) case "$p" in $pat*) hit=0; break ;; esac ;;
      *) case "$p" in $pat) hit=0; break ;; esac ;;
    esac
  done
  set +f
  return "$hit"
}

# counted_path <path from the repository root>: 0 when the check counts it: everything but Markdown, which counts only
# in adr/ and where it is a path that runs the full tier (full_when). The fingerprint and --unignored read this one rule,
# so a change the check counts is never taken for nothing changed, nor one a hook starts no check for.
counted_path() {
  case "$1" in
    adr/*) return 0 ;;
    *.md) path_in "$1" "$full_when" ;;
    *) return 0 ;;
  esac
}

# --unignored: the paths on stdin that the check counts, as they came. The pre-commit hook gives it the staged paths and
# the Stop hook the changed ones, so a change of none of them starts no check.
if [ "$mode" = "--unignored" ]; then
  while IFS= read -r p || [ -n "$p" ]; do
    [ -n "$p" ] && counted_path "$p" && printf '%s\n' "$p"
  done
  exit 0
fi

# Hash of every file that can change the result (counted_path). The paths are sorted before they are hashed: git lists
# untracked files before tracked ones, so staging a new file would otherwise change the hash though no file's content
# changed.
fingerprint() {
  local path list=()
  while IFS= read -r path; do
    counted_path "$path" || continue
    [ -f "$path" ] && list+=("$path")
  done < <(git -c core.quotePath=false ls-files -c -o --exclude-standard 2>/dev/null | LC_ALL=C "$SORT" -u)
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
# scan_secrets <file>: the lines that match a pattern, as path:line:text (the text is never printed), in the
# working tree (tracked and untracked files) and in the index, so a secret that is staged and edited out of
# the file on disk is still found by the commit that would carry it. The check's own files hold the patterns,
# so they're left out. git grep exits 0 for a match, 1 for none and more for an error: any error means the scan
# didn't look, and this returns 1 for the caller to say so.
scan_secrets() {
  local tree_status staged_status
  git -c core.quotePath=false grep -n -I -i -E --untracked "${secret_patterns[@]}" -- . \
    ':(exclude)tools/check.sh' ':(exclude)tools/archcheck.awk' > "$1" 2>/dev/null
  tree_status=$?
  git -c core.quotePath=false grep --cached -n -I -i -E "${secret_patterns[@]}" -- . \
    ':(exclude)tools/check.sh' ':(exclude)tools/archcheck.awk' > "$1.staged" 2>/dev/null
  staged_status=$?
  [ "$tree_status" -le 1 ] && [ "$staged_status" -le 1 ] || return 1
  # Add the staged lines the working tree's scan didn't report, once each.
  if [ "$staged_status" -eq 0 ]; then
    awk 'FILENAME == ARGV[1] { seen[$0] = 1; next } !($0 in seen)' "$1" "$1.staged" > "$1.new" && cat "$1.new" >> "$1"
    rm -f "$1.new"
  fi
  rm -f "$1.staged"
  return 0
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
# emulator keys and accepted ADR exceptions, over the whole working tree and the index (so a staged secret
# edited out on disk is still found); a git grep error exits 3. The pre-commit hook runs it on every commit,
# because it runs the check only for a commit that stages a path the check counts (--unignored).
# It only reads, so it takes no lock and no fingerprint. Other violations are the full check's to report.
if [ "$mode" = "--secrets" ]; then
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "check: note: not a git repository, so secrets aren't scanned"
    exit 0
  fi
  found="$state/secrets-scan.txt"; adrs="$state/secrets-adrs.txt"; log="$state/secrets-scan.log"
  list_adrs "$adrs"; : > "$log"
  scan_secrets "$found" || { echo "check: secrets: git grep couldn't scan the files, so nothing was checked"; exit 3; }
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
# --- the change and the tiers -------------------------------------------------------------------------
# read_head: HEAD's commit in head (empty before the first commit and outside a git repository), in_git 1 inside one.
# The changed paths are read again after it (changed_ready).
read_head() {
  head="$(git rev-parse -q --verify HEAD 2>/dev/null)"
  in_git=1; [ -n "$head" ] || { git rev-parse --is-inside-work-tree >/dev/null 2>&1 || in_git=0; }
  changed_ready=0
}
# changed_paths: the paths that differ from HEAD, staged or not (deletions too), and the untracked files git doesn't
# ignore, one per line in changed_list, less the check's own state. Read once per HEAD: changed_ready is 1 while the
# list is current.
changed_ready=0; changed_list=""
changed_paths() {
  local raw p
  [ "$changed_ready" -eq 1 ] && return 0
  changed_ready=1
  changed_list=""
  [ -n "$head" ] || return 0
  raw="$( { git -c core.quotePath=false diff --name-only --no-renames -z HEAD -- 2>/dev/null
            git -c core.quotePath=false ls-files -o --exclude-standard -z 2>/dev/null; } | tr '\0' '\n')"
  while IFS= read -r p; do
    case "$p" in ''|.satt/state/*) continue ;; esac
    changed_list="$changed_list$p$nl"
  done <<< "$raw"
}
# full_path <list>: the first path in the list that runs the full tier, in full_hit (empty when none does).
full_path() {
  local p
  full_hit=""
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if path_in "$p" "$full_when"; then full_hit="$p"; return 0; fi
  done <<< "$1"
  return 1
}

# due_check: whether the full tier is due (due_now 1 or 0) and why (due_why); due_in, the commits until
# [tests] full-every brings it (empty when that is 0). Reads changed_list.
due_check() {
  local lf_commit="" lf_at="" word count
  due_now=1; due_why=""; due_in=""; due_count=0; lf_desc=""
  [ -f "$state/last-full" ] && read -r lf_commit lf_at < "$state/last-full"
  if [ -z "$lf_commit" ]; then due_why="no full pass recorded yet"; return 0; fi
  lf_desc="${lf_commit:0:7}, ${lf_at/T/ }"
  if [ -z "$head" ] || ! git merge-base --is-ancestor "$lf_commit" "$head" >/dev/null 2>&1; then
    due_why="the last full pass ($lf_desc) isn't in this history"; return 0
  fi
  # The path rule reads only the changes from HEAD: the commit that carried such a path ran the full tier, since the
  # pre-commit hook asks this first, so a later commit doesn't run it again for that path. A commit made without the
  # hook is covered by the count.
  if full_path "$changed_list"; then
    due_why="$full_hit changed (a dependency, a toolchain setting, tools/ or [tests] full-when)"; return 0
  fi
  count="$(git rev-list --count "$lf_commit..$head" 2>/dev/null)"
  case "$count" in ''|*[!0-9]*) count=0 ;; esac
  due_count="$count"
  word=commits; [ "$count" -eq 1 ] && word=commit
  if [ "$cfg_full_every" -gt 0 ]; then
    if [ "$count" -ge "$cfg_full_every" ]; then
      due_why="$count $word since the last full pass ($lf_desc), [tests] full-every = $cfg_full_every"; return 0
    fi
    due_in=$((cfg_full_every - count))
  fi
  due_now=0
}

if [ "$mode" = "--due" ]; then
  read_head; changed_paths; due_check
  if [ "$due_now" -eq 1 ]; then
    echo "check: full tier due: $due_why"
  else
    word=commits; [ "$due_count" -eq 1 ] && word=commit
    echo "check: full tier not due: $due_count $word since the last full pass ($lf_desc), [tests] full-every = $cfg_full_every"
  fi
  exit 0
fi

before=""
[ "$mode" = "--architecture" ] || { before="$(fingerprint)"; read_head; }

# --- the recorded results ------------------------------------------------------------------------------
# read_record <file>: rec_fp (line 1), and line 2's rec_tier, rec_commit and rec_run. Returns 1 without a record.
read_record() {
  local meta="" w
  rec_fp=""; rec_tier=""; rec_commit=""; rec_run=""
  [ -f "$1" ] || return 1
  { IFS= read -r rec_fp; IFS= read -r meta; } < "$1"
  for w in $meta; do
    case "$w" in
      tier=*) rec_tier="${w#tier=}" ;;
      commit=*) rec_commit="${w#commit=}" ;;
      run=*) rec_run="${w#run=}" ;;
    esac
  done
  case "$rec_tier" in fast|full) ;; *) rec_tier="" ;; esac
  return 0
}
# stands <file>: 0 when the record read_record read from that file stands for this request: the same files, and a
# full result, or a fast one for a fast request that checked the changes from this HEAD, or from another commit when
# every path that differs from HEAD now was among those it checked (as after committing them). A record without a
# tier (an older check's) stands for nothing.
stands() {
  local first="" checked="" p
  [ -n "$rec_tier" ] && [ -n "$before" ] && [ "$rec_fp" = "$before" ] || return 1
  [ "$rec_tier" = full ] && return 0
  [ "$requested" = fast ] && [ -n "$head" ] || return 1
  [ "$rec_commit" = "$head" ] && return 0
  [ -f "$1.changed" ] || return 1
  { IFS= read -r first; IFS= read -r -d '' checked; } < "$1.changed"
  [ "$first" = "run=$rec_run" ] || return 1
  changed_paths
  checked="$nl$checked"
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$checked" in *"$nl$p$nl"*) ;; *) return 1 ;; esac
  done <<< "$changed_list"
  return 0
}
# --if-changed: reuse the recorded result that stands for this request (asked again once the lock is ours).
reuse_last() {
  [ "$if_changed" -eq 1 ] && [ -n "$before" ] || return 0
  if read_record "$state/last-pass" && stands "$state/last-pass"; then
    echo "check: PASS (nothing changed since the last passing run: the $rec_tier tier, commit ${rec_commit:0:7})"
    exit 0
  fi
  if read_record "$state/last-fail" && stands "$state/last-fail"; then
    local flag=""; [ "$rec_tier" = fast ] && flag=" --fast"
    echo "check: FAIL (nothing changed since the last failing run of the $rec_tier tier; run 'bash tools/check.sh$flag' to see why)"
    exit 1
  fi
}
# write_record <pass|fail>: this run's result for these files, and for a fast one the changed paths it checked.
write_record() {
  local f="$state/last-$1" run="$$.$RANDOM"
  if [ "$tier" = fast ]; then printf 'run=%s\n%s' "$run" "$changed_list" > "$f.changed"; else rm -f "$f.changed"; fi
  printf '%s\ntier=%s commit=%s run=%s\n' "$before" "$tier" "${head:-none}" "$run" > "$f"
}
remove_record() { rm -f "$state/last-$1" "$state/last-$1.changed"; }
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
# Side-by-side steps are background jobs: an interrupted run stops them and what they started, then
# frees the lock.
job_pids=()
cleanup() {
  local p
  for p in ${job_pids[@]+"${job_pids[@]}"}; do
    pkill -P "$p" 2>/dev/null
    kill "$p" 2>/dev/null
  done
  rm -rf "$lock"
}
trap cleanup EXIT
trap 'exit 130' INT TERM
# The run we waited for may have checked exactly these files, and a commit may have come meanwhile.
if [ "$waited" -gt 0 ] && [ "$mode" != "--architecture" ]; then read_head; fi
reuse_last

# --- the tier ---------------------------------------------------------------------------------------
# A fast request runs as the full tier, and says why, outside a git repository, before the first commit and when a
# changed path is one that runs the full tier (full_when).
tier="$requested"
if [ "$mode" != "--architecture" ]; then
  if [ "$tier" = fast ]; then
    why=""
    if [ "$in_git" -eq 0 ]; then why="this isn't a git repository"
    elif [ -z "$head" ]; then why="there's no commit yet"
    else
      changed_paths
      if full_path "$changed_list"; then why="$full_hit changed (a dependency, a toolchain setting, tools/ or [tests] full-when)"; fi
    fi
    if [ -n "$why" ]; then
      echo "check: note: $why, so the fast tier runs as the full tier"
      tier=full
    fi
  fi
  echo "check: running the $tier tier"
fi
if [ "$tier" = fast ]; then
  cfg_timeout="$cfg_timeout_fast"; limit_name="tools/check.cfg › [tests] timeout-fast"
else
  cfg_timeout="$cfg_timeout_full"; limit_name="tools/check.cfg › [tests] $cfg_timeout_full_key"
fi
case "${CHECK_TIMEOUT:-}" in ""|*[!0-9]*|0) ;; *) limit_name="CHECK_TIMEOUT" ;; esac

# Each test command runs under GNU timeout (the tier's limit, above) when it's available. A run that hits the limit
# makes the check exit 3 (couldn't finish), not 1, unless a test already failed.
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
timed_out() { echo "check: $1 ran past the $cfg_timeout-second limit ($limit_name, the $tier tier's) and was stopped, so this isn't a pass"; }

failed=0; unverified=0
run_start=$SECONDS

# --- 1. architecture ------------------------------------------------------------------------------
architecture() {
  local list="$state/files.txt" adrs="$state/adrs.txt" secrets="$state/secrets.txt"
  : > "$secrets"
  if git -c core.quotePath=false ls-files -c -o --exclude-standard > "$list" 2>/dev/null; then
    scan_secrets "$secrets" || { echo "check: git grep couldn't scan the files for secrets, so this isn't a pass"; unverified=1; }
  else
    "$FIND" . -type f ! -path './.git/*' ! -path "./$state/*" | sed 's|^\./||' > "$list"
    echo "check: note: not a git repository, so secrets aren't scanned"
  fi
  list_adrs "$adrs"
  awk -v cfg=tools/check.cfg -v files="$list" -v adrs="$adrs" -v secrets="$secrets" \
    -v logfile="$state/architecture.log" -f tools/archcheck.awk || failed=1
}
architecture
secs_architecture=$((SECONDS - run_start))
if [ "$mode" = "--architecture" ]; then
  [ "$failed" -eq 0 ] || exit 1
  [ "$unverified" -eq 0 ] || exit 3
  exit 0
fi

# --- what the fast tier runs ----------------------------------------------------------------------
# The Bicep compile for a change under infra/ or to a bicepconfig.json; the backend stack unless every changed path is
# Markdown, in the client layer (tools/archcheck.awk names each path's layer), or outside every layer and Bicep's;
# tools/check.local.sh always, with the changed paths in CHECK_CHANGED. The full tier runs every step.
run_stack=1; run_infra=1
export CHECK_TIER="$tier"
if [ "$tier" = fast ]; then
  printf '%s' "$changed_list" > "$state/changed"
  export CHECK_CHANGED="$PWD/$state/changed"
  run_stack=0; run_infra=0
  if [ -n "$changed_list" ]; then
    # The Bicep compile is decided here, from the paths alone: a change under infra/, or to a bicepconfig.json (Bicep
    # reads the nearest one above each file). awk names only each path's layer.
    classified=0; wanted=0
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      wanted=$((wanted + 1))
      case "$p" in infra/*|bicepconfig.json|*/bicepconfig.json) run_infra=1 ;; esac
    done <<< "$changed_list"
    # The backend runs for a path that isn't Markdown, in a layer other than client, or outside every layer and not
    # Bicep's (so a path under infra/ that a [layers] pattern covers runs both).
    while IFS=' ' read -r layer p; do
      [ -n "$p" ] || continue
      classified=$((classified + 1))
      case "$p" in *.md) continue ;; esac
      case "$layer" in client) continue ;; -) ;; *) run_stack=1; continue ;; esac
      case "$p" in infra/*|bicepconfig.json|*/bicepconfig.json) ;; *) run_stack=1 ;; esac
    done < <(awk -v cfg=tools/check.cfg -v classify="$state/changed" -f tools/archcheck.awk 2>/dev/null)
    [ "$classified" -eq "$wanted" ] || run_stack=1   # a path the layers couldn't be read for: run the backend
  fi
else
  unset CHECK_CHANGED
fi

# --- 2. the stack ---------------------------------------------------------------------------------
stack_step() {
  local profile="tools/stacks/$cfg_stack.sh" status
  if [ "$run_stack" -eq 0 ]; then
    echo "check: fast tier: the backend stack is left out (every change is Bicep's, in the client layer or Markdown)"
    return
  fi
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

# --- 3. infra -------------------------------------------------------------------------------------
infra_step() {
  local f bicep="" any=0 log="$state/bicep.log" bad=0 hung=0 rc limit=""
  [ -z "$timeout_cmd" ] || limit="$timeout_cmd $cfg_timeout"   # each compile runs under the limit
  for f in infra/*.bicep infra/env/*.bicepparam; do [ -f "$f" ] && any=1; done
  [ "$any" -eq 1 ] || return 0
  if [ "$run_infra" -eq 0 ]; then
    echo "check: fast tier: the Bicep compile is left out (no change under infra/ or to a bicepconfig.json)"
    return 0
  fi
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
      *.bicep)      if [ "$bicep" = "bicep" ]; then $limit bicep build "$f" --stdout; else $limit az bicep build --file "$f" --stdout; fi ;;
      *.bicepparam) if [ "$bicep" = "bicep" ]; then $limit bicep build-params "$f" --stdout; else $limit az bicep build-params --file "$f" --stdout; fi ;;
    esac </dev/null >/dev/null 2>>"$log"
    rc=$?
    case "$rc" in 0) ;; 124) hung=1 ;; *) bad=1 ;; esac
  done
  if [ "$bad" -eq 1 ] || grep -q ' Error ' "$log"; then
    echo "check: infra/ doesn't compile:"
    grep -E 'Error|error' "$log" | head -n 30 | sed 's/^/  /'
    failed=1
  elif [ "$hung" -eq 1 ]; then
    timed_out "the Bicep compile"
    unverified=1
  else
    echo "check: infra/ compiles"
  fi
}

# --- 4. project-specific steps --------------------------------------------------------------------
project_step() {
  [ -f tools/check.local.sh ] || return 0
  echo "check: running tools/check.local.sh"
  if [ -n "$timeout_cmd" ]; then "$timeout_cmd" "$cfg_timeout" bash tools/check.local.sh </dev/null; else bash tools/check.local.sh </dev/null; fi
  case $? in 0) ;; 124) timed_out "tools/check.local.sh"; unverified=1 ;; 3) echo "check: tools/check.local.sh couldn't run"; unverified=1 ;; *) echo "check: tools/check.local.sh failed"; failed=1 ;; esac
}

# --- running steps 2 to 4 ---------------------------------------------------------------------------
# In order (the default), each step prints as it goes. With tools/check.cfg › [tests] parallel = on they run
# as background jobs, each with its lines in .satt/state/step-<name>.out and its result in step-<name>.status,
# and when all have ended their lines are printed in the same order, so the output reads as a serial run's.
# Each step keeps its own time limit. The statuses combine as they do in order.
step_names="stack infra project"
if [ "$cfg_parallel" -eq 1 ]; then
  echo "check: running the stack, infra and project steps side by side (tools/check.cfg › [tests] parallel)"
  for name in $step_names; do
    rm -f "$state/step-$name.out" "$state/step-$name.status"
    (
      failed=0; unverified=0; started=$SECONDS
      "${name}_step"
      echo "$failed $unverified $((SECONDS - started))" > "$state/step-$name.status"
    ) > "$state/step-$name.out" 2>&1 &
    job_pids+=($!)
  done
  for pid in "${job_pids[@]}"; do wait "$pid"; done
  job_pids=()
  for name in $step_names; do
    cat "$state/step-$name.out"
    if [ -f "$state/step-$name.status" ]; then
      read -r step_failed step_unverified step_secs < "$state/step-$name.status"
      [ "$step_failed" -eq 0 ] || failed=1
      [ "$step_unverified" -eq 0 ] || unverified=1
    else
      echo "check: the $name step ended without a result, so this isn't a pass"
      unverified=1; step_secs=0
    fi
    eval "secs_$name=$step_secs"
  done
else
  for name in $step_names; do
    started=$SECONDS
    "${name}_step"
    eval "secs_$name=$((SECONDS - started))"
  done
fi

echo "check: seconds: architecture $secs_architecture · stack $secs_stack · infra $secs_infra · project steps $secs_project · total $((SECONDS - run_start))"

hook_file="$(git rev-parse --git-path hooks 2>/dev/null)/pre-commit"
hook_ok=0
if [ -f "$hook_file" ]; then
  while IFS= read -r line; do case "$line" in *SaaSAllTheThings*) hook_ok=1; break ;; esac; done < "$hook_file"
fi
[ "$hook_ok" -eq 1 ] || echo "check: note: this clone has no SaaSAllTheThings pre-commit hook. Run: bash tools/setup-clone.sh"

# --- the result -------------------------------------------------------------------------------------
# A result is recorded only for the files it checked: the fingerprint is taken again, and must be the same.
stable=0
if [ -n "$before" ] && [ "$before" = "$(fingerprint)" ]; then stable=1; fi
if [ "$failed" -ne 0 ]; then
  remove_record pass
  if [ "$stable" -eq 1 ]; then write_record fail; else remove_record fail; fi
  echo "check: FAIL ($tier tier; full logs in $state/)"
  exit 1
fi
if [ "$unverified" -ne 0 ]; then
  echo "check: UNVERIFIED ($tier tier): part of the check couldn't run (see above), so this isn't a pass"
  exit 3
fi
if [ "$stable" -eq 1 ]; then
  # A fast pass doesn't replace a full pass of the same files: the full one covers more.
  if [ "$tier" = full ] || ! { read_record "$state/last-pass" && [ "$rec_tier" = full ] && [ "$rec_fp" = "$before" ]; }; then
    write_record pass
  fi
  if [ "$tier" = full ] && [ -n "$head" ]; then
    printf -v now '%(%Y-%m-%dT%H:%M)T' -1 2>/dev/null || now="$(date '+%Y-%m-%dT%H:%M')"
    printf '%s %s\n' "$head" "$now" > "$state/last-full"
  fi
elif [ -n "$before" ]; then
  echo "check: note: files changed while the check ran; run it again to cover the changes."
fi
remove_record fail
if [ "$tier" = full ]; then
  echo "check: PASS (full tier)"
  exit 0
fi
due_check
if [ "$due_now" -eq 1 ]; then echo "check: PASS (fast tier; the full tier is due: $due_why)"
elif [ -n "$due_in" ]; then
  word=commits; [ "$due_in" -eq 1 ] && word=commit
  echo "check: PASS (fast tier; the full tier is due in $due_in $word)"
else
  echo "check: PASS (fast tier; the full tier isn't due by count, [tests] full-every = 0)"
fi
exit 0
