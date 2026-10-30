#!/usr/bin/env bash
# SaaSAllTheThings command guard · Claude Code PreToolUse hook on Bash · framework-owned: replaced on upgrade.
#
# Permission rules match how a command starts, so `git commit -m x --no-verify` or
# `git push origin main --force` would slip past them. This hook looks at the whole command and
# blocks what .satt/rules.md › Git and Azure reserves for the human: rewriting history,
# discarding work, skipping the check, deleting Azure resources, reading secrets and creating
# client secrets. It also blocks commands that hang or run past the five-minute prompt cache (see
# "hangs" below). It pattern-matches the text, so it's a strong safety net, not a guarantee. It
# starts no other processes (it runs on every Bash call).
#
# It also blocks the git flags that write a file, read a file outside the repository or run a
# configured command (--output, --no-index, --ext-diff, commit -F and --file), because the allow
# rules in settings.json let `git diff *`, `git log *`, `git show *` and `git commit *` run with
# any flag. See the section "git: flags that write a file" below.

IFS= read -r -d '' input || true
re='"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'
[[ $input =~ $re ]] || exit 0
raw="${BASH_REMATCH[1]}"                       # still JSON-escaped: \" for "

# `code` is the command with quoted strings blanked, so a commit message can't trip a flag test.
code="$raw"
dq='\\"([^\\]|\\[^"])*\\"'
while [[ $code =~ $dq ]]; do code="${code/"${BASH_REMATCH[0]}"/ Q }"; done
sq="'[^']*'"
while [[ $code =~ $sq ]]; do code="${code/"${BASH_REMATCH[0]}"/ Q }"; done

# --- hangs ----------------------------------------------------------------------------------------
# A command that never returns, or that runs past five minutes, costs the prompt cache: the turn
# after it rewrites the whole context. Each block says what works instead.
hang() {
  echo "SaaSAllTheThings: blocked: $1" >&2
  exit 2
}
nl='\\n'
wsp='[[:space:]]'
# An empty heredoc into Python's stdin: on Windows Python waits for console input and never returns.
py='(^|[^[:alnum:]_.-])(python3?|py)(\.exe)?'"$wsp"'+-('"$wsp"'+[0-9]?>[^[:space:]\\]+)*'"$wsp"'*<<-?'"$wsp"'*(\\"|'"'"')?([A-Za-z_][A-Za-z0-9_]*)'
if [[ $raw =~ $py ]]; then
  delim="${BASH_REMATCH[6]}"
  rest="${raw#*"${BASH_REMATCH[0]}"}"
  empty='^([^\\]|\\[^n])*'"$nl"'(\\t|\\r| )*'"$delim"'(\\r|\\n|'"$wsp"'|$)'
  [[ $rest =~ $empty ]] && hang "Python reads an empty heredoc from stdin here, which waits for console input on Windows and never returns. To test whether Python is installed, run: python3 --version"
fi
# A loop that polls with sleep needs a time limit of 280 seconds or less, and a loop that reads a
# background command's tasks/<id>.output has to wait for the line Claude Code appends when it ends.
scan="$code"
[[ $code =~ (^|[^[:alnum:]_./-])(bash|sh|zsh)${wsp}+-[a-z]*c${wsp} ]] && scan="$raw"
if [[ $scan =~ (^|[^[:alnum:]_./-])(until|while)${wsp} ]]; then
  if [[ $raw =~ tasks[/\\][^[:space:]]*\.output ]]; then
    [[ $raw =~ exited${wsp}+with${wsp}+code|killed ]] \
      || hang "this loop reads a background command's output file without waiting for its end marker, so it can run forever. Wait for the completion notice instead, or loop until grep -q 'exited with code' <file> (or '[killed]') succeeds, under timeout 240"
  elif [[ $scan =~ (^|[^[:alnum:]_./-])sleep(${wsp}|$) ]]; then
    ok_limit=0
    tm='(^|[^[:alnum:]_./-])timeout'"$wsp"'+((-k|--kill-after|-s|--signal)'"$wsp"'+[^[:space:]]+'"$wsp"'+|-[^[:space:]]+'"$wsp"'+)*([0-9]+)([sm]?)'"$wsp"
    if [[ $scan =~ $tm ]]; then
      secs="${BASH_REMATCH[4]}"; secs=$((10#$secs))
      [ "${BASH_REMATCH[5]}" = m ] && secs=$((secs * 60))
      [ "$secs" -ge 1 ] && [ "$secs" -le 280 ] && ok_limit=1
    fi
    [ "$ok_limit" -eq 1 ] || hang "this loop polls with sleep and has no time limit under five minutes, so it can run for the whole session and let the prompt cache expire. Start the command with run_in_background and keep working until its completion notice, or put the loop under timeout 240 (the limit is 280 seconds)"
  fi
fi
# A lone sleep past 280 seconds: the wait outlives the prompt cache.
rest="$code"
sl='(^|[^[:alnum:]_./-])sleep'"$wsp"'+([0-9]+)(\.[0-9]*)?([smhd]?)([^[:alnum:].]|$)'
while [[ $rest =~ $sl ]]; do
  secs="${BASH_REMATCH[2]}"; secs=$((10#$secs))
  case "${BASH_REMATCH[4]}" in m) secs=$((secs * 60)) ;; h) secs=$((secs * 3600)) ;; d) secs=$((secs * 86400)) ;; esac
  [ "$secs" -gt 280 ] && hang "sleep $secs seconds is past the 280-second limit that keeps a wait inside the five-minute prompt cache. Start the command with run_in_background and keep working until its completion notice, or sleep in steps of 240 seconds or less"
  rest="${rest#*"${BASH_REMATCH[0]}"}"
done

[[ $raw =~ (^|[^[:alnum:]_./-])(git|az|azd)([[:space:]]|$) ]] || exit 0

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

# --- git: flags that write a file, read outside the repository or run a configured command --------
# settings.json allows `git diff *`, `git log *`, `git show *` and `git commit *` without a prompt, so
# every flag after them runs without one too. These turn them into a file write (--output), a read of
# any file on the machine (--no-index; a `git diff` of a path outside the repository, which git treats
# as --no-index; commit -F and --file) or the run of a configured command (--ext-diff). The command
# is read as the shell hands it to git: '--output=x', "--output"=x and --out\put=x are the flag, while
# a flag named inside a quoted message or a heredoc body is not. Variables and command substitutions
# outside quotes are not expanded, so this is a text match like the rest.
lf=$'\n'; bs='\'; sq1="'"
cmdsub='$'"("; bt=$'\x60'   # built here so this file holds no command substitution of its own
real="${raw//\\\\/$'\x01'}"; real="${real//\\\"/\"}"; real="${real//\\n/$lf}"
real="${real//\\t/ }"; real="${real//\\r/}"; real="${real//$'\x01'/$bs}"

# Cut out the heredoc bodies (git commit -F - <<'EOF' ...). A quoted delimiter makes the body plain
# text; an unquoted one expands command substitutions and backticks, so a body with those stays.
hre='(^|[^<])<<-?[[:space:]]*(\\?["'"'"']?)([A-Za-z_][A-Za-z0-9_]*)'
gtext=""; delim=""; hquote=""; body=""
while IFS= read -r line || [ -n "$line" ]; do
  if [ -n "$delim" ]; then
    if [ "${line#"${line%%[![:space:]]*}"}" = "$delim" ]; then
      delim=""
      [[ -n $hquote || ( $body != *"$cmdsub"* && $body != *"$bt"* ) ]] || gtext+="$body"
      body=""
    else body+="$line$lf"; fi
    continue
  fi
  gtext+="$line$lf"
  [[ $line =~ $hre ]] && { delim="${BASH_REMATCH[3]}"; hquote="${BASH_REMATCH[2]}"; }
done <<<"$real"
gtext+="$body"   # a heredoc that never closes keeps its text: a false block beats a miss

# Walk the quoted strings from the left. One that is a flag by itself ('--output=x') or sits inside
# a word (--out"put"=x) is unquoted so the flag shows; any other is message text and is blanked.
# A "..." holding a command substitution or backticks runs a command, so its text stays and is read again.
qre='^(([^"'$sq1'\\]|\\.)*)("(([^"\\]|\\.)*)"|'$sq1'([^'$sq1']*)'$sq1')'
glued='^[^[:space:];&|<>)]'
gcode=""; rest="$gtext"
while [[ $rest =~ $qre ]]; do
  pre="${BASH_REMATCH[1]}"; quoted="${BASH_REMATCH[3]}"; rest="${rest:${#BASH_REMATCH[0]}}"
  inner="${quoted:1:${#quoted}-2}"
  if [[ $pre == *'$' && $pre != *'\$' ]]; then   # $'...' and $"...": drop the $
    pre="${pre%?}"
    [[ $quoted == "'"* && $inner =~ \\[xuU0-7] ]] && block "ANSI-C quoting with a numeric escape (\$'\\055') can spell any flag past this check"
  fi
  pre="${pre//\\$lf/}"; pre="${pre//\\/}"        # outside quotes a backslash only escapes the next character
  gcode+="$pre"
  word="${gcode##*[[:space:];&|]}"               # the word so far
  if [[ $inner =~ ^--?[A-Za-z] ]]; then gcode+="$inner"
  elif [[ $inner != *[[:space:]]* && ( -n $word || $rest =~ $glued ) ]]; then gcode+="$inner"
  elif [[ -n $word && $word =~ ^--[^=]*$ ]]; then gcode+="$inner"
  elif [[ $quoted == '"'* && ( $inner == *"$cmdsub"* || $inner == *"$bt"* ) ]]; then rest="$inner $rest"
  else gcode+=" Q "; fi
done
rest="${rest//\\$lf/}"; rest="${rest//\\/}"; gcode+="${rest//[\"$sq1]/}"   # a quote left over never closes
gcode="${gcode//$lf/;}"; gcode="${gcode//>&/> }"; gcode="${gcode//&>/> }"

gitre='(^|[^[:alnum:]_./-])git[[:space:]]'
gitflag() { [[ $gcode =~ $gitre($seg[[:space:]])?$1 ]]; }
gitflag '--output([[:space:]=;&|]|$)' && block "--output writes a file to any path, such as one a later command runs"
gitflag '--no-index([[:space:]=;&|]|$)' && block "--no-index reads any file on the machine"
gitflag '--ext' && block "--ext-diff runs a configured external command"

# Per command: git commit -F and --file read any file (the message may come from stdin: -F -), and a
# git diff of a path outside the repository reads it too. The subcommand is the first word after git
# that isn't an option, so `git log --grep commit -F` is not a commit.
outre='^(/|~|[A-Za-z]:|\$[A-Za-z_{])|(^|/)\.\.(/|$)'
brackets=$'[(){}\x60]'
IFS=';&|' read -r -d '' -a gsegs <<<"$gcode" || true
for gs in "${gsegs[@]}"; do
  gs="${gs//$brackets/ }"
  read -ra w <<<"$gs"
  n=${#w[@]}; k=0
  while ((k < n)) && [[ ${w[k]} != git ]]; do ((k++)); done
  ((k++))
  while ((k < n)); do
    case ${w[k]} in -C|-c) ((k += 2)) ;; -*) ((k++)) ;; *) break ;; esac
  done
  case ${w[k]:-} in
    commit)
      for ((k++; k < n; k++)); do
        a="${w[k]}"
        if [[ $a =~ ^-[aeinopqsvz]*F(.*)$ ]]; then v="${BASH_REMATCH[1]:-${w[k+1]:-}}"
        elif [[ $a =~ ^--fil(e?)(=(.*))?$ ]]; then
          if [[ -n ${BASH_REMATCH[2]} ]]; then v="${BASH_REMATCH[3]}"; else v="${w[k+1]:-}"; fi
        else continue; fi
        [[ $v == - ]] || block "git commit -F and --file read any file on the machine; give the message on stdin: git commit -F - <<'EOF'"
      done ;;
    diff)
      for ((k++; k < n; k++)); do
        [[ ${w[k]} == -* ]] && continue
        [[ ${w[k]} =~ $outre ]] && block "git diff of a path outside the repository reads any file on the machine"
      done ;;
  esac
done

# --- Azure ----------------------------------------------------------------------------------------
[[ $code =~ (^|[^[:alnum:]_./-])azd[[:space:]]+down([[:space:]]|$) ]] && block "azd down deletes the environment's resources"
[[ $code =~ (^|[^[:alnum:]_./-])az[[:space:]]${seg}[[:space:]]delete([[:space:]]|$) ]] && block "deleting Azure resources is for the human"
shopt -s nocasematch
[[ $code =~ --mode[[:space:]=]+complete ]] && block "a complete-mode deployment deletes every resource the template doesn't list"
shopt -u nocasematch
[[ $code =~ keyvault[[:space:]]+secret[[:space:]]+(show|download|backup) ]] && block "never read a secret into the session"
[[ $code =~ (^|[^[:alnum:]_./-])az[[:space:]]+ad[[:space:]]+(app|sp)[[:space:]]+credential[[:space:]]+reset ]] && block "this creates a client secret; use a federated credential (.satt/reference/identity.md)"
exit 0
