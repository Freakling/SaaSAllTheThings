#!/usr/bin/env bash
# SaaSAllTheThings per-clone setup · framework-owned: replaced on upgrade.
#
#   bash tools/setup-clone.sh               toolchain, dependencies, pre-commit and pre-push hooks
#   bash tools/setup-clone.sh --skip-hook   the same without the hooks
#
# Run it once in every new clone or worktree; running it again is harmless.
# 1. Checks the backend stack's toolchain (tools/check.cfg › [project] stack) and restores its
#    dependencies, so the check can run without the network afterwards.
# 2. Reports the optional tools: the Bicep CLI, the Azure CLI, the Azure Developer CLI and the
#    Functions Core Tools.
# 3. Installs small pre-commit and pre-push hooks in .git/hooks that run the committed .githooks/pre-commit
#    and .githooks/pre-push. Other hooks keep working; an existing hook is never overwritten. The hooks are
#    installed even when step 1 fails (exit 3): the pre-commit hook scans every commit for secrets and the
#    pre-push hook refuses a prototype's commits, and neither depends on the toolchain.
# Exit codes: 0 = done · 3 = the toolchain is missing (the hooks are installed all the same) · 4 = done, but a
# hook needs your attention.

set -u
cd "$(dirname "$0")/.." || exit 1
skip_hook=0
for arg in "$@"; do case "$arg" in --skip-hook) skip_hook=1 ;; esac; done
state=".satt/state"
mkdir -p "$state"
. tools/cfg.sh
exit_code=0

# --- 1. the stack ---------------------------------------------------------------------------------
profile="tools/stacks/$cfg_stack.sh"
if [ "$cfg_stack_invalid" -eq 1 ] || [ ! -f "$profile" ]; then
  echo "setup: tools/check.cfg › [project] stack is '$cfg_stack', which has no profile in tools/stacks/"
  exit_code=3
else
  . "$profile"
  out="$(stack_toolchain)"
  status=$?
  printf '%s\n' "$out" | sed 's/^check: /setup: /'
  if [ "$status" -ne 0 ]; then
    exit_code=3
  else
    stack_toolchain >/dev/null   # again in this shell, for the variables it sets
    if ! stack_setup; then echo "setup: note: restoring dependencies failed (see $state/restore.log); the check will say what's missing"; fi
  fi
fi

# --- 2. optional tools ----------------------------------------------------------------------------
found=""; missing=""
for tool in bicep az azd func; do
  if command -v "$tool" >/dev/null 2>&1; then found="$found $tool"; else missing="$missing $tool"; fi
done
[ -n "$found" ] && echo "setup: optional tools found:$found"
[ -n "$missing" ] && echo "setup: optional tools not found:$missing (bicep compiles infra/ in the check; az, azd and func are for deploys and local runs)"

# --- 3. pre-commit and pre-push hooks ---------------------------------------------------------------
# Installed even when the toolchain is missing (exit 3 above): the hooks need only git and awk. Worktrees
# share them, prototypes too.
done_with() { [ "$exit_code" -ne 0 ] && exit "$exit_code"; exit "$1"; }
[ "$skip_hook" -eq 1 ] && done_with 0
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "setup: not a git repository, so no pre-commit or pre-push hook."
  done_with 4
fi
hooks_path="$(git config --get core.hooksPath)"
if [ -n "$hooks_path" ]; then
  echo "setup: this clone uses core.hooksPath=$hooks_path (e.g. husky)."
  echo "       Add this line to its pre-commit hook: bash .githooks/pre-commit || exit 1"
  echo "       and this one to its pre-push hook: bash .githooks/pre-push \"\$@\" || exit 1"
  done_with 4
fi

# Each hook is a small shim that runs the committed one, so an upgrade needs no new setup. Worktrees
# share the shims: git's hooks folder is the main clone's.
hooks_dir="$(git rev-parse --git-path hooks)"
mkdir -p "$hooks_dir"
hook_status=0
for hook_name in pre-commit pre-push; do
  hook="$hooks_dir/$hook_name"
  if [ -f "$hook" ] && ! grep -q "SaaSAllTheThings" "$hook"; then
    echo "setup: $hook already exists and isn't the framework's."
    echo "       Add this line to it: bash .githooks/$hook_name \"\$@\" || exit 1"
    hook_status=4
    continue
  fi
  printf '%s\n' '#!/usr/bin/env bash' \
    "# SaaSAllTheThings: runs the project's committed $hook_name hook. Installed by tools/setup-clone.sh." \
    'root="$(git rev-parse --show-toplevel)" || exit 1' \
    "[ -f \"\$root/.githooks/$hook_name\" ] || exit 0" \
    "exec bash \"\$root/.githooks/$hook_name\" \"\$@\"" > "$hook"
  chmod +x "$hook"
  echo "setup: $hook_name hook installed ($hook)"
done
done_with "$hook_status"
