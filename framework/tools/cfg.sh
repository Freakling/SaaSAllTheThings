# SaaSAllTheThings config reader · framework-owned: replaced on upgrade.
# Sourced by tools/check.sh and tools/setup-clone.sh from the repository root, without starting a process.
# Comments go on their own lines. Reads tools/check.cfg into:
#   $cfg_stack, $cfg_target    [project] stack (default: dotnet, the framework's bias) and target
#   $cfg_timeout_fast          [tests] timeout-fast: the fast tier's limit in seconds (default 300)
#   $cfg_timeout_full          [tests] timeout-full, or else the older [tests] timeout: the full tier's (default 600)
#   $cfg_timeout_full_key      the key that set it (timeout-full or timeout), for messages
#   $cfg_timeout               the full tier's limit; tools/check.sh sets it to the limit of the tier it runs.
#                              CHECK_TIMEOUT (seconds) overrides both tiers' limits.
#   $cfg_parallel              [tests] parallel: on is 1; absent or anything else 0
#   $cfg_full_every            [tests] full-every: commits after the last full pass that make the full tier due
#                              (default 10; 0: never by count)
#   $cfg_full_when             [tests] full-when: path patterns whose change runs the full tier (default empty)

cfg_stack="dotnet"
cfg_target=""
cfg_timeout_fast=300
cfg_timeout_full=""
cfg_timeout_old=""
cfg_timeout_full_key="timeout-full"
cfg_parallel=0
cfg_full_every=10
cfg_full_when=""
if [ -f tools/check.cfg ]; then
  cfg_section=""
  while IFS= read -r cfg_line || [ -n "$cfg_line" ]; do
    cfg_line="${cfg_line%$'\r'}"
    cfg_line="${cfg_line#"${cfg_line%%[![:space:]]*}"}"
    case "$cfg_line" in
      ''|';'*|'#'*) continue ;;
      '['*) cfg_section="${cfg_line#?}"; cfg_section="${cfg_section%%]*}"; continue ;;
    esac
    [ "$cfg_section" = "project" ] || [ "$cfg_section" = "tests" ] || continue
    case "$cfg_line" in *=*) ;; *) continue ;; esac
    cfg_key="${cfg_line%%=*}"
    cfg_key="${cfg_key%"${cfg_key##*[![:space:]]}"}"
    cfg_value="${cfg_line#*=}"
    cfg_value="${cfg_value#"${cfg_value%%[![:space:]]*}"}"
    cfg_value="${cfg_value%"${cfg_value##*[![:space:]]}"}"
    if [ "$cfg_section" = "tests" ]; then
      case "$cfg_key:$cfg_value" in
        timeout*:""|timeout*:*[!0-9]*|timeout*:0) ;;
        timeout:*) cfg_timeout_old="$cfg_value" ;;
        timeout-fast:*) cfg_timeout_fast="$cfg_value" ;;
        timeout-full:*) cfg_timeout_full="$cfg_value" ;;
        parallel:on) cfg_parallel=1 ;;
        parallel:*) cfg_parallel=0 ;;
        full-every:""|full-every:*[!0-9]*) ;;
        full-every:*) cfg_full_every="$cfg_value" ;;
        full-when:*) cfg_full_when="$cfg_value" ;;
      esac
      continue
    fi
    case "$cfg_key" in
      stack) [ -n "$cfg_value" ] && cfg_stack="$cfg_value" ;;
      target) cfg_target="$cfg_value" ;;
    esac
  done < tools/check.cfg
fi
if [ -z "$cfg_timeout_full" ]; then
  cfg_timeout_full="${cfg_timeout_old:-600}"
  [ -z "$cfg_timeout_old" ] || cfg_timeout_full_key="timeout"
fi
case "${CHECK_TIMEOUT:-}" in ""|*[!0-9]*|0) ;; *) cfg_timeout_fast="$CHECK_TIMEOUT"; cfg_timeout_full="$CHECK_TIMEOUT" ;; esac
cfg_timeout="$cfg_timeout_full"
case "$cfg_stack" in *[!a-z0-9-]*) cfg_stack_invalid=1 ;; *) cfg_stack_invalid=0 ;; esac
