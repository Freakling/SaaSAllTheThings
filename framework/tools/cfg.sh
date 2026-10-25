# SaaSAllTheThings config reader · framework-owned: replaced on upgrade.
# Sourced by tools/check.sh and tools/setup-clone.sh from the repository root. Reads
# tools/check.cfg › [project] into $cfg_stack (default: dotnet, the framework's bias) and
# $cfg_target, and › [tests] timeout into $cfg_timeout (seconds, default 600), without starting a process. Comments go on their own lines.

cfg_stack="dotnet"
cfg_target=""
cfg_timeout=600
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
      case "$cfg_key:$cfg_value" in timeout:""|timeout:*[!0-9]*|timeout:0) ;; timeout:*) cfg_timeout="$cfg_value" ;; esac
      continue
    fi
    case "$cfg_key" in
      stack) [ -n "$cfg_value" ] && cfg_stack="$cfg_value" ;;
      target) cfg_target="$cfg_value" ;;
    esac
  done < tools/check.cfg
fi
case "${CHECK_TIMEOUT:-}" in ""|*[!0-9]*|0) ;; *) cfg_timeout="$CHECK_TIMEOUT" ;; esac
case "$cfg_stack" in *[!a-z0-9-]*) cfg_stack_invalid=1 ;; *) cfg_stack_invalid=0 ;; esac
