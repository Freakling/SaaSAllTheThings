#!/usr/bin/env bash
# SaaSAllTheThings authority guard · Claude Code PreToolUse hook on Edit, Write and MultiEdit ·
# framework-owned: replaced on upgrade.
#
# The architecture is framework-owned, and only the human accepts an ADR (.satt/rules.md ›
# Who decides). This hook doesn't block: it makes Claude Code ask the human to confirm when the
# assistant is about to
#   - edit a framework-owned file: .satt/, the check and its stack profiles, the git hook,
#     or these hooks;
#   - write "Status: accepted" into an ADR in adr/.
# It pattern-matches the tool input, so it's a strong safety net, not a guarantee. It starts no
# other processes.

IFS= read -r -d '' input || true
re='"file_path"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'
[[ $input =~ $re ]] || exit 0
path="${BASH_REMATCH[1]}"
path="${path//\\\\//}"   # JSON-escaped Windows separators (\\) to /

ask() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

case "/$path" in
  */.satt/state/*) exit 0 ;;
  */.satt/*|*/tools/check.sh|*/tools/archcheck.awk|*/tools/cfg.sh|*/tools/setup-clone.sh|*/tools/stacks/*|*/.githooks/*|*/.claude/hooks/*)
    ask "SaaSAllTheThings: this file is framework-owned, and holds the architecture's authority. Change it upstream in SaaSAllTheThings, or record a deviation as an ADR. Approve only if you mean to diverge locally." ;;
esac
case "/$path" in
  */adr/ADR-*)
    status_re='Status[*_[:space:]]*:[*_[:space:]]*[Aa]ccepted'
    [[ $input =~ $status_re ]] && ask "SaaSAllTheThings: only the human accepts an ADR. Approve only if you have accepted it." ;;
esac
exit 0
