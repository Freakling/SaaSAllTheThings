# SaaSAllTheThings stack profile: TypeScript / JavaScript on Node.js · framework-owned: replaced on upgrade.
# Sourced by tools/check.sh and tools/setup-clone.sh; see tools/stacks/dotnet.sh for the interface.
# Runs the root package.json's typecheck, lint, build and test scripts, those that exist. In the fast tier of an app
# with npm workspaces the test step covers only the changed packages and those that depend on them (ts_test_command).

stack_toolchain() {
  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    echo "check: can't find node and npm. Install Node.js 20 or newer, then run: bash tools/setup-clone.sh"
    return 3
  fi
  stack_version="$(node --version 2>/dev/null </dev/null | tr -d '\r v')"
  local major="${stack_version%%.*}"
  case "$major" in ''|*[!0-9]*) echo "check: couldn't read the Node.js version"; return 3 ;; esac
  if [ "$major" -lt 20 ]; then echo "check: needs Node.js 20 or newer; found $stack_version"; return 3; fi
  echo "check: Node.js $stack_version"
}

stack_setup() {
  [ -f package.json ] || return 0
  [ -d node_modules ] && return 0
  if [ -f package-lock.json ]; then echo "setup: npm ci"; npm ci --no-audit --no-fund </dev/null >"$state/restore.log" 2>&1
  else echo "setup: npm install"; npm install --no-audit --no-fund </dev/null >"$state/restore.log" 2>&1; fi
}

# The fast tier's package selection (npm workspaces): one node call reads the root package.json's workspaces, each
# package's name and the workspace packages it depends on, and the changed backend paths on stdin (the lines of
# CHECK_BACKEND_CHANGED). It prints, one per line:
#   N                        no workspaces: the test runs as it always does
#   W <reason>               the whole test has to run
#   T <folder> <1|0>         a package to test (changed, or depending on a changed one, directly or through others),
#                            and whether it has its own test script
#   S <folder>               a package the change doesn't reach
ts_write_selector() {
  cat > "$1" <<'JS'
const fs = require('fs');
const out = (...a) => console.log(a.join(' '));
const read = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const dirs = (d) => { try { return fs.readdirSync(d, { withFileTypes: true }).filter((e) => e.isDirectory() && e.name !== 'node_modules' && e.name[0] !== '.').map((e) => e.name); } catch (e) { return []; } };
// The folders a workspace pattern names: * stands for part of one folder name, ** for any depth.
function expand(base, segs) {
  if (!segs.length) return [base];
  const [s, ...rest] = segs;
  const join = (n) => (base ? base + '/' + n : n);
  if (s === '**') return [...expand(base, rest), ...dirs(base || '.').flatMap((n) => expand(join(n), segs))];
  if (!s.includes('*')) return fs.existsSync(join(s)) ? expand(join(s), rest) : [];
  const re = new RegExp('^' + s.split('*').map((x) => x.replace(/[.+?^${}()|[\]\\]/g, '\\$&')).join('.*') + '$');
  return dirs(base || '.').filter((n) => re.test(n)).flatMap((n) => expand(join(n), rest));
}
const folders = (pattern) => expand('', pattern.replace(/^\.\//, '').replace(/\/+$/, '').split('/'));

let workspaces = read('package.json').workspaces;
if (workspaces && !Array.isArray(workspaces)) workspaces = workspaces.packages;
if (!Array.isArray(workspaces) || !workspaces.length) { out('N'); process.exit(0); }
const dirsFound = new Set();
for (const p of workspaces.filter((p) => p[0] !== '!')) for (const d of folders(p)) if (fs.existsSync(d + '/package.json')) dirsFound.add(d);
for (const p of workspaces.filter((p) => p[0] === '!')) for (const d of folders(p.slice(1))) dirsFound.delete(d);
const pkgs = [...dirsFound].sort().map((dir) => {
  const j = read(dir + '/package.json');
  const deps = Object.keys(Object.assign({}, j.dependencies, j.devDependencies, j.peerDependencies, j.optionalDependencies));
  return { dir, name: j.name, deps, hasTest: !!(j.scripts && j.scripts.test) };
});
if (!pkgs.length) { out('W the workspaces of package.json match no package folder'); process.exit(0); }
if (pkgs.some((p) => /\s/.test(p.dir))) { out('W a package folder has a space in its name'); process.exit(0); }

const changed = fs.readFileSync(0, 'utf8').split(/\r?\n/).filter(Boolean);
if (!changed.length) { out('W no changed backend path was listed'); process.exit(0); }
const hit = new Set();
for (const c of changed) {
  const owner = pkgs.filter((p) => c === p.dir || c.startsWith(p.dir + '/')).sort((a, b) => b.dir.length - a.dir.length)[0];
  if (!owner) { out('W ' + c + ' is outside every package'); process.exit(0); }
  hit.add(owner.dir);
}
// The packages that depend on a changed one, and those that depend on them in turn.
for (let grew = true; grew;) {
  grew = false;
  for (const p of pkgs) {
    if (hit.has(p.dir)) continue;
    if (p.deps.some((n) => pkgs.some((q) => q.name === n && hit.has(q.dir)))) { hit.add(p.dir); grew = true; }
  }
}
for (const p of pkgs) out(hit.has(p.dir) ? 'T ' + p.dir + ' ' + (p.hasTest ? 1 : 0) : 'S ' + p.dir);
JS
}

# ts_select: ts_mode is "all" (the test runs as it always does), "whole" (the whole test runs, ts_reason says why) or
# "packages" (ts_tested and ts_left are lists of folders, ts_untested those of ts_tested without a test script).
ts_select() {
  local js="$state/select-packages.js" lines kind rest
  ts_mode=all; ts_reason=""; ts_tested=""; ts_left=""; ts_untested=""
  [ "${CHECK_TIER:-full}" = fast ] && [ -f "${CHECK_BACKEND_CHANGED:-}" ] || return 0
  ts_write_selector "$js"
  if ! lines="$(node "$js" < "$CHECK_BACKEND_CHANGED" 2>"$state/select-packages.err")"; then
    ts_mode=whole; ts_reason="node couldn't work out the packages (see $state/select-packages.err)"
    return 0
  fi
  while read -r kind rest; do
    case "$kind" in
      T) ts_tested="$ts_tested ${rest% *}"; [ "${rest##* }" = 1 ] || ts_untested="$ts_untested ${rest% *}" ;;
      S) ts_left="$ts_left $rest" ;;
      W) ts_mode=whole; ts_reason="$rest"; return 0 ;;
    esac
  done <<< "$lines"
  ts_tested="${ts_tested# }"; ts_left="${ts_left# }"; ts_untested="${ts_untested# }"
  [ -z "$ts_tested" ] || ts_mode=packages
}

# ts_test_command: the test step in the fast tier of an app with npm workspaces: only the packages the change reaches,
# through the app's root test:fast script (given their folders in CHECK_PACKAGES, separated by spaces) or through each
# package's own test script; with neither, the whole root test, and the check says so. Sets ts_label, ts_cmd.
ts_test_command() {
  local f has_test=0
  grep -qE '"test"[[:space:]]*:' package.json && has_test=1
  ts_label="npm run test"; ts_cmd=(npm run --silent test)
  ts_select
  case "$ts_mode" in
    all) [ "$has_test" -eq 1 ] ;;
    whole)
      [ "$has_test" -eq 1 ] || return 1
      echo "check: fast tier: the whole test runs: $ts_reason" ;;
    packages)
      if grep -qE '"test:fast"[[:space:]]*:' package.json; then
        export CHECK_PACKAGES="$ts_tested"
        ts_label="npm run test:fast"; ts_cmd=(npm run --silent test:fast)
      else
        [ "$has_test" -eq 1 ] || return 1
        if [ -n "$ts_untested" ]; then
          echo "check: fast tier: the whole test runs: no test:fast script in package.json, and no test script in ${ts_untested// /, }"
          return 0
        fi
        ts_label="npm run test in the packages"
        for f in $ts_tested; do ts_cmd+=(--workspace "$f"); done
      fi
      echo "check: fast tier: tested the packages $ts_tested (changed, or depending on a changed package)"
      echo "check: fast tier: left to the full tier: ${ts_left:-none}" ;;
  esac
}

stack_check() {
  local script ran=0 status
  if [ ! -f package.json ]; then echo "check: FAIL: no package.json at the repository root"; return 1; fi
  if [ ! -d node_modules ]; then echo "check: node_modules is missing. Run: bash tools/setup-clone.sh"; return 3; fi
  for script in typecheck lint build test; do
    ts_label="npm run $script"; ts_cmd=(npm run --silent "$script")
    if [ "$script" = test ] && [ "${CHECK_TIER:-full}" = fast ]; then
      ts_test_command || continue
    else
      grep -qE "\"$script\"[[:space:]]*:" package.json || continue
    fi
    ran=1
    run_limited "$state/npm-$script.log" "${ts_cmd[@]}"
    status=$?
    unset CHECK_PACKAGES
    if [ "$status" -eq 124 ]; then timed_out "$ts_label"; return 3; fi
    if [ "$status" -ne 0 ]; then
      echo "check: $ts_label failed:"
      tail -n 40 "$state/npm-$script.log" | sed 's/^/  /'
      return 1
    fi
    echo "check: $ts_label passed"
  done
  [ "$ran" -eq 1 ] || echo "check: note: package.json has none of the scripts typecheck, lint, build, test"
  return 0
}
