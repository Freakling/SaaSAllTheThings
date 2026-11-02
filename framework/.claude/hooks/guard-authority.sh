#!/usr/bin/env bash
# SaaSAllTheThings authority guard · Claude Code PreToolUse hook on Edit, Write, MultiEdit and NotebookEdit ·
# framework-owned: replaced on upgrade.
#
# The architecture is framework-owned, and only the human accepts an ADR (.satt/rules.md ›
# Who decides). For those this hook doesn't block: it makes Claude Code ask the human to confirm
# when the assistant is about to
#   - edit a framework-owned file: .satt/, the check and its stack profiles, the prototype script, the git hooks,
#     or these hooks;
#   - write "Status: accepted" into an ADR in adr/.
# In a prototype it blocks, rather than asks, an edit to the git hooks, the guard (.claude/), tools/prototype.sh,
# tools/setup-clone.sh, the scan (tools/check.sh, tools/archcheck.awk, tools/check.cfg), adr/ and .gitattributes.
# It blocks any write into director/ at the project root, the director's own workspace, screen
# drawings included (.satt/rules.md › Protected space).
# It pattern-matches the tool input, so it's a strong safety net, not a guarantee. It starts no
# other processes.

IFS= read -r -d '' input || true
re='"(file_path|notebook_path)"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'
[[ $input =~ $re ]] || exit 0
path="${BASH_REMATCH[2]}"
path="${path//\\\\//}"   # JSON-escaped Windows separators (\\) to /

# The path from the project root: C:/x, C:\x and /c/x spell one Windows folder, in any case.
same_form() { # same_form <path>: / separators, a drive as c:/, no ./ or trailing /
  local p="${1//\\//}"
  case "$p" in /[A-Za-z]/*|/[A-Za-z]) p="${p:1:1}:${p:2}" ;; esac
  p="${p#./}"; p="${p%/}"
  REPLY="$p"
}
same_form "$path"; rel="$REPLY"
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  same_form "$CLAUDE_PROJECT_DIR"; root="$REPLY"
  shopt -s nocasematch
  [[ $rel == "$root"/* ]] && rel="${rel:${#root}+1}"
  shopt -u nocasematch
fi
# A path that climbs (/..) and names director/ is blocked too, wherever it starts.
[[ "/$rel/" == */../* && "/$rel/" == */director/* ]] && rel="director/"
case "$rel" in
  director|director/*)
    echo "SaaSAllTheThings: blocked: director/ is the director's own workspace (screen drawings, mockups, notes). Read files there for context; never write to them." >&2
    exit 2 ;;
esac

ask() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

# In a prototype (PROTOTYPE.md beside a .git file, the test guard-commands.sh reads with builtins) the hooks, the
# guard, the scan and the files that excuse a finding are refused rather than asked: a prototype has no review to
# catch a change to them, and the harvest in the main session names any that differ from main's.
root="${CLAUDE_PROJECT_DIR:-$PWD}"
if [ -f "$root/PROTOTYPE.md" ] && [ -f "$root/.git" ]; then
  case "/$path" in
    */.githooks/*|*/.claude/*|*/tools/prototype.sh|*/tools/setup-clone.sh|*/tools/check.sh|*/tools/archcheck.awk|*/tools/check.cfg|*/adr/*|*/.gitattributes)
      echo "SaaSAllTheThings: blocked: in a prototype, the hooks, the guard, the scan and the files that excuse a finding stay main's, and a prototype can't change them. Make the change on main, in the main session (.satt/procedures/prototype.md)." >&2
      exit 2 ;;
  esac
fi

case "/$path" in
  */.satt/state/*) exit 0 ;;
  */.satt/*|*/tools/check.sh|*/tools/archcheck.awk|*/tools/cfg.sh|*/tools/setup-clone.sh|*/tools/prototype.sh|*/tools/stacks/*|*/.githooks/*|*/.claude/hooks/*)
    ask "SaaSAllTheThings: this file is framework-owned, and holds the architecture's authority. Change it upstream in SaaSAllTheThings, or record a deviation as an ADR. Approve only if you mean to diverge locally." ;;
esac
case "/$path" in
  */adr/ADR-*)
    status_re='Status[*_[:space:]]*:[*_[:space:]]*[Aa]ccepted'
    [[ $input =~ $status_re ]] && ask "SaaSAllTheThings: only the human accepts an ADR. Approve only if you have accepted it." ;;
esac
exit 0
