#!/usr/bin/env bash
# SaaSAllTheThings orphan report · Claude Code hook · framework-owned: replaced on upgrade.
#
# Lists long-running processes whose parent shell is gone, so one left behind by an ended session doesn't spin a core
# for days unnoticed: a session's cleanup only reaches what that session knows about. At session start it reads the
# process list once (on Windows through PowerShell's Get-CimInstance Win32_Process, for 8 seconds at most where
# `timeout` exists, since wmic is gone and tasklist has no parent; elsewhere through ps) and reports the processes
# that are Python, node, a shell, Godot or a headless browser, an hour old or more, with a parent that is gone: a
# ppid of 0 or 1, no process with that id, or a parent younger than the process (Windows reuses ids and doesn't
# reparent). It prints one line of JSON for the human and for Claude, the oldest ten and how many more; otherwise it
# prints nothing at all. It only reads: it never stops, signals or changes a process, writes no file and sends
# nothing, and stopping what it lists is the human's call. PRIVACY.md says what it reads. SATT_ORPHAN_REPORT=0
# turns it off (e.g. .claude/settings.local.json › env). It never blocks: every path ends in exit 0. Bash 3.2 and BSD
# tools run it, and it starts as few processes as it can (uname, and the process list once).

IFS= read -r -d '' _input || true
[ "${SATT_ORPHAN_REPORT:-1}" = "0" ] && exit 0
LC_ALL=C
num_re='^[0-9]{1,10}$'
etime_re='^(([0-9]{1,6})-)?(([0-9]{1,2}):)?([0-9]{1,2}):([0-9]{1,2})$'   # ps's [[dd-]hh:]mm:ss
# The names that count, in any case and without .exe: python, python3, python3.<n>, pythonw, py, node, bash, sh,
# godot* and chrome-headless-shell (Linux's comm cuts that to chrome-headless). Spelled out, since bash 3.2 has no
# case conversion.
name_re='^([Pp][Yy][Tt][Hh][Oo][Nn]([Ww]|3(\.[0-9]{1,3})?)?|[Pp][Yy]|[Nn][Oo][Dd][Ee]|[Bb][Aa][Ss][Hh]|[Ss][Hh]|[Gg][Oo][Dd][Oo][Tt].*|[Cc][Hh][Rr][Oo][Mm][Ee]-[Hh][Ee][Aa][Dd][Ll][Ee][Ss][Ss](-[Ss][Hh][Ee][Ll][Ll])?)$'

# The process list, as rows of "pid ppid age name" (Windows: the age in seconds, from CreationDate; a process with none
# is skipped) or "pid ppid etime comm" (ps).
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*) win=1 ;;
  *) win=0 ;;
esac
if ((win)); then
  ps_script="\$n = Get-Date; Get-CimInstance Win32_Process | ForEach-Object { if (\$_.CreationDate) { '{0} {1} {2} {3}' -f \$_.ProcessId, \$_.ParentProcessId, [int64][math]::Floor((\$n - \$_.CreationDate).TotalSeconds), \$_.Name } }"
  if command -v timeout >/dev/null 2>&1; then
    rows="$(timeout 8 powershell.exe -NoProfile -NonInteractive -Command "$ps_script" 2>/dev/null </dev/null)" || exit 0
  else
    rows="$(powershell.exe -NoProfile -NonInteractive -Command "$ps_script" 2>/dev/null </dev/null)" || exit 0
  fi
else
  rows="$(ps -A -o pid=,ppid=,etime=,comm= 2>/dev/null)" || exit 0
fi
[ -n "$rows" ] || exit 0

# Every row is kept by id, for the parent lookups; the ones that could be orphans are listed as candidates. Anything
# from the list is reduced to [A-Za-z0-9._-] first, so it can't break the JSON.
nc=0
while read -r pid ppid age name; do
  [[ $pid =~ $num_re && $ppid =~ $num_re ]] || continue
  pid=$((10#$pid)); ppid=$((10#$ppid))
  if ((win)); then
    [[ $age =~ $num_re ]] || continue
    age=$((10#$age))
  else
    [[ $age =~ $etime_re ]] || continue
    age=$((10#${BASH_REMATCH[2]:-0} * 86400 + 10#${BASH_REMATCH[4]:-0} * 3600 + 10#${BASH_REMATCH[5]} * 60 + 10#${BASH_REMATCH[6]}))
    name="${name##*/}"
  fi
  ppid_of[$pid]=$ppid
  age_of[$pid]=$age
  ((age >= 3600)) || continue
  name="${name//[^A-Za-z0-9._-]/}"
  name="${name%.[Ee][Xx][Ee]}"
  [[ $name =~ $name_re ]] || continue
  cand_pid[$nc]=$pid
  cand_name[$nc]=$name
  nc=$((nc + 1))
done <<< "$rows"

# An orphan's parent is gone: a ppid of 0 or 1, no row with that id, or a parent row younger than the process.
no=0
i=0
while ((i < nc)); do
  pid=${cand_pid[$i]}; ppid=${ppid_of[$pid]}; age=${age_of[$pid]}
  if ((ppid <= 1)) || [ -z "${age_of[$ppid]-}" ] || ((${age_of[$ppid]} < age)); then
    o_pid[$no]=$pid; o_age[$no]=$age; o_name[$no]=${cand_name[$i]}
    no=$((no + 1))
  fi
  i=$((i + 1))
done
((no > 0)) || exit 0

# The oldest ten, oldest first: ten passes, each taking the oldest one not yet listed.
shown=$no; ((shown > 10)) && shown=10
list=""
k=0
while ((k < shown)); do
  best=-1
  j=0
  while ((j < no)); do
    if [ -z "${o_used[$j]-}" ] && { ((best < 0)) || ((o_age[$j] > o_age[$best])); }; then best=$j; fi
    j=$((j + 1))
  done
  o_used[$best]=1
  hours=$((o_age[$best] / 3600))
  if ((hours <= 48)); then when="$hours h"; else when="$((hours / 24)) d"; fi
  list="${list:+$list, }pid ${o_pid[$best]} ${o_name[$best]} ($when)"
  k=$((k + 1))
done
((no > shown)) && list="$list, and $((no - shown)) more"

text="Processes that outlived the shell that started them (parent gone, over an hour old): $list. They may be left over from an ended session. Stopping them is your call."
ask="Tell the human this once, in your first reply, and don't stop them unless the human asks."
printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s %s"}}\n' "$text" "$text" "$ask"
exit 0
