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
# configured command (--output, --no-index, --ext-diff, commit -F and --file, grep -O and
# --open-files-in-pager), because the allow rules in settings.json let `git diff *`, `git log *`,
# `git show *`, `git commit *` and `git grep *` run with any flag. See the section "git: flags that
# write a file" below.
#
# And shell commands that read the credential stores (~/.ssh, git's credentials files, the gh CLI's
# hosts.yml) and the commands that print a stored credential (gh auth token, gh auth status -t, git
# credential fill or get). See the section "credential stores" below. This is a guardrail, not a
# guarantee: complex pipelines or indirect reads are not detected. The Read-tool deny rules in
# settings.json cover the Read tool.

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

block() {
  echo "SaaSAllTheThings: blocked: $1. If it's really needed, ask the human to run it." >&2
  exit 2
}

# --- credential stores ----------------------------------------------------------------------------
# Block direct shell reads of the credential stores: ~/.ssh (any key, known_hosts too), git's credentials
# files, and the gh CLI's hosts.yml (.config/gh, or AppData's GitHub CLI). A path is blocked when it is
# one of those or sits inside one, however it is written: ~/, $HOME/, ${HOME}/, /c/Users/<name>/,
# C:\Users\<name>\ or relative. The commands that print a stored credential are blocked as well (gh auth
# token, gh auth status -t, git credential fill or get). These files may hold live credentials, and any
# credential read in a conversation has to be treated as compromised and rotated. This is a best-effort
# check on the command text; indirect reads are not detected. settings.json denies the Read tool the
# same stores.
cred_end="([[:space:]\"';&|)]|\$)"
cred_store_re='\.ssh([/\\]|'"$cred_end"')|\.git-credentials|\.config[/\\]git[/\\]credentials|\.config[/\\]gh([/\\]|'"$cred_end"')|GitHub CLI([/\\]|'"$cred_end"')'
reads_cred_store() {
  # The command as the shell reads it: JSON escapes undone (\\ is one backslash, so C:\Users\V
  # works) and the \n that separates commands becomes ;. Bash expansions only, so no process starts.
  local cmd="${raw//\\\\/$'\x01'}" bs='\'
  cmd="${cmd//\\\"/\"}"; cmd="${cmd//\\n/;}"; cmd="${cmd//$'\x01'/$bs}"
  # A store read: the command word, then a path that is a store, or has one after a character that
  # isn't part of a name, so ~/.ssh, $HOME/.ssh and "C:\...\.ssh" match, and x.ssh doesn't.
  local store_read_re='(^|[[:space:]|;&(])(cat|head|tail|less|more|strings)[[:space:]]+([^;&|]*[^[:alnum:]_.-])?('"$cred_store_re"')'
  [[ $cmd =~ $store_read_re ]]
}
reads_cred_store && block "reading a credential store (~/.ssh, git's credentials files, the gh CLI's hosts.yml) puts live credentials in the conversation, where they have to be treated as compromised and rotated"
# Matched on code (the command with its quoted text blanked), so a commit message that names them isn't blocked.
gh_print_re='(^|[^[:alnum:]_./-])gh[[:space:]]+auth[[:space:]]+(token([[:space:]]|$|[;&|)])|status[^;&|]*[[:space:]](-[[:alpha:]]*t[[:alpha:]]*|--show-token)([[:space:]]|$|[;&|)]))'
git_print_re='(^|[^[:alnum:]_./-])git[[:space:]]+([^;&|]*[[:space:]])?credential[[:space:]]+(fill|get)([[:space:]]|$|[;&|)])'
[[ $code =~ $gh_print_re ]] && block "gh auth token and gh auth status -t print the gh CLI's stored token"
[[ $code =~ $git_print_re ]] && block "git credential fill and get print a credential from git's credential store"

[[ $raw =~ (^|[^[:alnum:]_./-])(git|az|azd)([[:space:]]|$) ]] || exit 0

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
# settings.json allows `git diff *`, `git log *`, `git show *`, `git commit *` and `git grep *` without a
# prompt, so every flag after them runs without one too. These turn them into a file write (--output), a
# read of any file on the machine (--no-index; a `git diff` of a path outside the repository, which git
# treats as --no-index; commit -F and --file) or the run of a configured command (--ext-diff; grep -O,
# which runs its argument as the pager). The command is read as the shell hands it to git:
# '--output=x', "--output"=x and --out\put=x are the flag, while a flag named inside a quoted message or
# a heredoc body is not. Variables and command substitutions outside quotes are not expanded, so this
# is a text match like the rest.
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

# Per command: git commit -F and --file read any file (the message may come from stdin: -F -), a git
# diff of a path outside the repository reads it too, and git grep -O and --open-files-in-pager run a
# command as the pager. The subcommand is the first word after git that isn't an option, so
# `git log --grep commit -F` is not a commit.
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
    grep)
      # -O takes its command attached (-Ovim; -O alone runs the configured pager), and git reads it inside a
      # cluster too (-iO, -nOvim). -e -f -A -B -C -m take the rest of the word, or the next word, as their
      # value, so a -O after them is a value (-eO is the pattern O). After -- come paths. --open-files-in-pager
      # may be shortened to any prefix git accepts, --op and longer.
      for ((k++; k < n; k++)); do
        a="${w[k]}"
        [[ $a == -- ]] && break
        if [[ $a == --* ]]; then
          name="${a%%=*}"
          [[ $name == --op* && --open-files-in-pager == "$name"* ]] && block "git grep --open-files-in-pager runs a command as the pager"
        elif [[ $a == -* ]]; then
          cl="${a#-}"
          while [[ -n $cl ]]; do
            c="${cl:0:1}"; cl="${cl:1}"
            case $c in
              O) block "git grep -O runs a command as the pager" ;;
              [efABCm]) [[ -n $cl ]] || ((k++)); break ;;
            esac
          done
        fi
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
