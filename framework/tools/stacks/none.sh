# SaaSAllTheThings stack profile: none · framework-owned: replaced on upgrade.
# For a stack SaaSAllTheThings has no profile for yet (Java, for one; see .satt/reference/stacks.md).
# The architecture rules still run; the build and tests run only from tools/check.local.sh.

stack_toolchain() { echo "check: stack none: builds and tests run only from tools/check.local.sh"; }
stack_setup() { :; }
stack_check() {
  [ -f tools/check.local.sh ] || echo "check: note: stack none and no tools/check.local.sh, so nothing is built or tested"
  return 0
}
