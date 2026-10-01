# SaaSAllTheThings stack profile: TypeScript / JavaScript on Node.js · framework-owned: replaced on upgrade.
# Sourced by tools/check.sh and tools/setup-clone.sh; see tools/stacks/dotnet.sh for the interface.
# Runs the root package.json's typecheck, lint, build and test scripts, those that exist.

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

stack_check() {
  local script ran=0
  if [ ! -f package.json ]; then echo "check: FAIL: no package.json at the repository root"; return 1; fi
  if [ ! -d node_modules ]; then echo "check: node_modules is missing. Run: bash tools/setup-clone.sh"; return 3; fi
  for script in typecheck lint build test; do
    grep -qE "\"$script\"[[:space:]]*:" package.json || continue
    ran=1
    if ! npm run --silent "$script" </dev/null >"$state/npm-$script.log" 2>&1; then
      echo "check: npm run $script failed:"
      tail -n 40 "$state/npm-$script.log" | sed 's/^/  /'
      return 1
    fi
    echo "check: npm run $script passed"
  done
  [ "$ran" -eq 1 ] || echo "check: note: package.json has none of the scripts typecheck, lint, build, test"
  return 0
}
