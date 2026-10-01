# SaaSAllTheThings stack profile: Python · framework-owned: replaced on upgrade.
# Sourced by tools/check.sh and tools/setup-clone.sh; see tools/stacks/dotnet.sh for the interface.
# Uses .venv when it exists. Compiles every module, then runs pytest (or unittest without it).

stack_python() {
  local candidate
  for candidate in .venv/Scripts/python.exe .venv/bin/python python3 python; do
    if [ -x "$candidate" ] || command -v "$candidate" >/dev/null 2>&1; then printf '%s' "$candidate"; return; fi
  done
}

stack_toolchain() {
  py="$(stack_python)"
  if [ -z "$py" ]; then echo "check: can't find Python. Install Python 3.10 or newer, then run: bash tools/setup-clone.sh"; return 3; fi
  stack_version="$("$py" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null </dev/null | tr -d '\r')"
  local major="${stack_version%%.*}" minor="${stack_version#*.}"
  case "$major$minor" in ''|*[!0-9]*) echo "check: couldn't read the Python version from $py"; return 3 ;; esac
  if [ "$major" -lt 3 ] || { [ "$major" -eq 3 ] && [ "$minor" -lt 10 ]; }; then
    echo "check: needs Python 3.10 or newer; $py is $stack_version"; return 3
  fi
  echo "check: Python $stack_version ($py)"
}

stack_setup() {
  [ -f requirements.txt ] || return 0
  if [ ! -d .venv ]; then echo "setup: creating .venv"; "$py" -m venv .venv </dev/null >"$state/restore.log" 2>&1 || return 1; py="$(stack_python)"; fi
  echo "setup: pip install -r requirements.txt"
  "$py" -m pip install -q -r requirements.txt </dev/null >>"$state/restore.log" 2>&1
  if [ -f requirements-dev.txt ]; then "$py" -m pip install -q -r requirements-dev.txt </dev/null >>"$state/restore.log" 2>&1; fi
}

stack_check() {
  if ! "$py" -m compileall -q -x '(^|[/\\])(\.venv|venv|node_modules|\.git)([/\\]|$)' . </dev/null >"$state/compile.log" 2>&1; then
    echo "check: Python modules don't compile:"
    head -n 30 "$state/compile.log" | sed 's/^/  /'
    return 1
  fi
  echo "check: Python modules compile"
  if "$py" -c 'import pytest' >/dev/null 2>&1 </dev/null; then
    "$py" -m pytest -q </dev/null >"$state/test.log" 2>&1
    case $? in
      0) echo "check: pytest passed" ;;
      5) echo "check: note: pytest found no tests" ;;
      *) echo "check: pytest failed:"; tail -n 40 "$state/test.log" | sed 's/^/  /'; return 1 ;;
    esac
  else
    if ! "$py" -m unittest discover -q </dev/null >"$state/test.log" 2>&1; then
      echo "check: unittest failed:"; tail -n 40 "$state/test.log" | sed 's/^/  /'; return 1
    fi
    echo "check: unittest passed"
  fi
}
