# SaaSAllTheThings stack profile: .NET · framework-owned: replaced on upgrade.
# Sourced by tools/check.sh and tools/setup-clone.sh. A profile defines:
#   stack_toolchain   finds the toolchain and prints one line; returns 0, or 3 when it's missing
#   stack_setup       restores dependencies once per clone (setup-clone.sh)
#   stack_check       builds and tests; prints check: lines; returns 0 pass, 1 fail, 3 couldn't run
# It may use $state (the log folder) and $cfg_target (tools/check.cfg › [project] target).

stack_target() {
  local f
  if [ -n "$cfg_target" ]; then printf '%s' "$cfg_target"; return; fi
  for f in *.slnx *.sln; do [ -f "$f" ] && { printf '%s' "$f"; return; }; done
}

stack_toolchain() {
  if ! command -v dotnet >/dev/null 2>&1; then
    echo "check: can't find dotnet. Install the .NET SDK 8 or newer, then run: bash tools/setup-clone.sh"
    return 3
  fi
  stack_version="$(dotnet --version 2>/dev/null </dev/null | tr -d '\r' | tail -n 1)"
  local major="${stack_version%%.*}"
  case "$major" in ''|*[!0-9]*) echo "check: couldn't read the .NET SDK version ('$stack_version')"; return 3 ;; esac
  if [ "$major" -lt 8 ]; then echo "check: needs the .NET SDK 8 or newer; found $stack_version"; return 3; fi
  echo "check: .NET SDK $stack_version"
}

stack_setup() {
  local target; target="$(stack_target)"
  [ -n "$target" ] || return 0
  echo "setup: dotnet restore $target"
  dotnet restore "$target" -nologo -v:q </dev/null >"$state/restore.log" 2>&1
}

stack_check() {
  local target status
  target="$(stack_target)"
  if [ -z "$target" ]; then
    echo "check: FAIL: no .sln or .slnx at the repository root (or set tools/check.cfg › [project] target)"
    return 1
  fi
  dotnet build "$target" -nologo -v:q -clp:NoSummary </dev/null >"$state/build.log" 2>&1
  status=$?
  if [ "$status" -ne 0 ]; then
    echo "check: dotnet build failed:"
    grep -E ': (error|warning) [A-Z]+[0-9]+' "$state/build.log" | sed 's/^[[:space:]]*//' | awk '!seen[$0]++' | head -n 40 | sed 's/^/  /'
    return 1
  fi
  echo "check: dotnet build passed"
  dotnet test "$target" --no-build -nologo -v:q </dev/null >"$state/test.log" 2>&1
  status=$?
  grep -E '(Passed!|Failed!)|^[[:space:]]*Failed [A-Za-z_]|error' "$state/test.log" | head -n 40 | sed 's/^[[:space:]]*/  /'
  if [ "$status" -ne 0 ]; then echo "check: dotnet test failed"; return 1; fi
  echo "check: dotnet test passed"
}
