#!/usr/bin/env bash
# SaaSAllTheThings command guard · Claude Code PreToolUse hook on Bash · framework-owned: replaced on upgrade.
#
# Permission rules match how a command starts, so `git commit -m x --no-verify` or
# `git push origin main --force` would slip past them. This hook looks at the whole command and
# blocks what .satt/rules.md › Git and Azure reserves for the human: rewriting history,
# discarding work, skipping the check, deleting Azure resources, reading secrets and creating
# client secrets. It pattern-matches the text, so it's a strong safety net, not a guarantee. It
# starts no other processes (it runs on every Bash call).

IFS= read -r -d '' input || true
re='"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'
[[ $input =~ $re ]] || exit 0
raw="${BASH_REMATCH[1]}"                       # still JSON-escaped: \" for "
[[ $raw =~ (^|[^[:alnum:]_./-])(git|az|azd)([[:space:]]|$) ]] || exit 0

# `code` is the command with quoted strings blanked, so a commit message can't trip a flag test.
code="$raw"
dq='\\"([^\\]|\\[^"])*\\"'
while [[ $code =~ $dq ]]; do code="${code/"${BASH_REMATCH[0]}"/ Q }"; done
sq="'[^']*'"
while [[ $code =~ $sq ]]; do code="${code/"${BASH_REMATCH[0]}"/ Q }"; done

block() {
  echo "SaaSAllTheThings: blocked: $1. If it's really needed, ask the human to run it." >&2
  exit 2
}
seg='[^;&|]*'   # stays within one command of a compound command line

# --- git ------------------------------------------------------------------------------------------
shopt -s nocasematch   # git config keys are case-insensitive
[[ $raw =~ core\.hookspath ]] && block "changing core.hooksPath switches the pre-commit hook off"
shopt -u nocasematch
[[ $raw =~ --no-veri ]] && block "--no-verify skips the project check"
[[ $code =~ commit${seg}[[:space:]]-[a-mo-zA-Z]*n[a-zA-Z]*([[:space:]]|$) ]] && block "git commit -n skips the project check"
[[ $code =~ push${seg}[[:space:]](--force|--force-with-lease|--force-if-includes|-[a-zA-Z]*f[a-zA-Z]*)([[:space:]=]|$) ]] && block "force-push rewrites shared history"
[[ $code =~ push${seg}[[:space:]]\+[^[:space:]] ]] && block "a +refspec force-pushes"
[[ $code =~ reset${seg}[[:space:]]--ha ]] && block "git reset --hard discards uncommitted work"
[[ $code =~ clean${seg}[[:space:]](-[a-zA-Z]*f|--force) ]] && block "git clean -f deletes untracked files"
[[ $code =~ (checkout|switch)${seg}[[:space:]](-f|--force|--discard-changes)([[:space:]]|$) ]] && block "this discards uncommitted changes"
[[ $code =~ (checkout|restore)${seg}[[:space:]](--[[:space:]]+)?\.([[:space:]]|$) ]] && block "this discards every uncommitted change"
[[ $code =~ stash[[:space:]]+(drop|clear) ]] && block "this deletes stashed work"
[[ $code =~ branch${seg}[[:space:]]-D([[:space:]]|$) ]] && block "git branch -D deletes unmerged work"

# --- Azure ----------------------------------------------------------------------------------------
[[ $code =~ (^|[^[:alnum:]_./-])azd[[:space:]]+down([[:space:]]|$) ]] && block "azd down deletes the environment's resources"
[[ $code =~ (^|[^[:alnum:]_./-])az[[:space:]]${seg}[[:space:]]delete([[:space:]]|$) ]] && block "deleting Azure resources is for the human"
shopt -s nocasematch
[[ $code =~ --mode[[:space:]=]+complete ]] && block "a complete-mode deployment deletes every resource the template doesn't list"
shopt -u nocasematch
[[ $code =~ keyvault[[:space:]]+secret[[:space:]]+(show|download|backup) ]] && block "never read a secret into the session"
[[ $code =~ (^|[^[:alnum:]_./-])az[[:space:]]+ad[[:space:]]+(app|sp)[[:space:]]+credential[[:space:]]+reset ]] && block "this creates a client secret; use a federated credential (.satt/reference/identity.md)"
exit 0
