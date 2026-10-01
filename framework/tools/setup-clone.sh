#!/usr/bin/env bash
# SaaSAllTheThings per-clone setup · framework-owned: replaced on upgrade.
#
#   bash tools/setup-clone.sh               toolchain, dependencies, pre-commit hook
#   bash tools/setup-clone.sh --skip-hook   the same without the hook
#
# Run it once in every new clone or worktree; running it again is harmless.
# 1. Checks the backend stack's toolchain (tools/check.cfg › [project] stack) and restores its
#    dependencies, so the check can run without the network afterwards.
# 2. Reports the optional tools: the Bicep CLI, the Azure CLI, the Azure Developer CLI and the
#    Functions Core Tools.
# 3. Installs a small pre-commit hook in .git/hooks that runs the committed .githooks/pre-commit.
#    Other hooks keep working; an existing pre-commit is never overwritten.
# Exit codes: 0 = done · 3 = the toolchain is missing · 4 = done, but the hook needs your attention.

set -u
cd "$(dirname "$0")/.." || exit 1
skip_hook=0
for arg in "$@"; do case "$arg" in --skip-hook) skip_hook=1 ;; esac; done
state=".satt/state"
mkdir -p "$state"
. tools/cfg.sh

# --- 1. the stack ---------------------------------------------------------------------------------
profile="tools/stacks/$cfg_stack.sh"
if [ "$cfg_stack_invalid" -eq 1 ] || [ ! -f "$profile" ]; then
  echo "setup: tools/check.cfg › [project] stack is '$cfg_stack', which has no profile in tools/stacks/"
  exit 3
fi
. "$profile"
out="$(stack_toolchain)"
status=$?
printf '%s\n' "$out" | sed 's/^check: /setup: /'
[ "$status" -eq 0 ] || exit 3
stack_toolchain >/dev/null   # again in this shell, for the variables it sets
if ! stack_setup; then echo "setup: note: restoring dependencies failed (see $state/restore.log); the check will say what's missing"; fi

# --- 2. optional tools ----------------------------------------------------------------------------
found=""; missing=""
for tool in bicep az azd func; do
  if command -v "$tool" >/dev/null 2>&1; then found="$found $tool"; else missing="$missing $tool"; fi
done
[ -n "$found" ] && echo "setup: optional tools found:$found"
[ -n "$missing" ] && echo "setup: optional tools not found:$missing (bicep compiles infra/ in the check; az, azd and func are for deploys and local runs)"

# --- 3. pre-commit hook ---------------------------------------------------------------------------
[ "$skip_hook" -eq 1 ] && exit 0
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "setup: not a git repository, so no pre-commit hook."
  exit 4
fi
hooks_path="$(git config --get core.hooksPath)"
if [ -n "$hooks_path" ]; then
  echo "setup: this clone uses core.hooksPath=$hooks_path (e.g. husky)."
  echo "       Add this line to its pre-commit hook: bash .githooks/pre-commit || exit 1"
  exit 4
fi
hooks_dir="$(git rev-parse --git-path hooks)"
hook="$hooks_dir/pre-commit"
if [ -f "$hook" ] && ! grep -q "SaaSAllTheThings" "$hook"; then
  echo "setup: $hook already exists and isn't the framework's."
  echo "       Add this line to it: bash .githooks/pre-commit || exit 1"
  exit 4
fi
mkdir -p "$hooks_dir"
cat > "$hook" <<'HOOK'
#!/usr/bin/env bash
# SaaSAllTheThings: runs the project's committed pre-commit hook. Installed by tools/setup-clone.sh.
root="$(git rev-parse --show-toplevel)" || exit 1
[ -f "$root/.githooks/pre-commit" ] || exit 0
exec bash "$root/.githooks/pre-commit" "$@"
HOOK
chmod +x "$hook"
echo "setup: pre-commit hook installed ($hook)"
exit 0
