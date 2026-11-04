#!/usr/bin/env bash
# SaaSAllTheThings release check · Claude Code hook · framework-owned: replaced on upgrade.
#
# Says when the installed SaaSAllTheThings is older than the latest release, so a project that has fallen behind
# shows it. At session start it compares the version on the first line of .satt/manifest with the highest
# v<major>.<minor>.<patch> tag on GitHub. The tag list is read with `git ls-remote` at most once a day (for 5
# seconds at most, where `timeout` exists); the version found last is kept in .satt/state/latest-release, which git
# ignores. A lookup that fails (offline, no git) keeps the old value and waits for tomorrow. When the project is
# behind, it prints one line of JSON for the human and for Claude; otherwise it prints nothing at all. PRIVACY.md
# says what the request is. SATT_RELEASE_CHECK=0 turns it off (e.g. .claude/settings.local.json › env). It never
# blocks: every path ends in exit 0. Bash 3.2 and BSD tools run it, and it starts as few processes as it can (one
# find when the last answer is on file; once a day also git, under timeout).

IFS= read -r -d '' _input || true
[ "${SATT_RELEASE_CHECK:-1}" = "0" ] && exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
[ -f .satt/manifest ] || exit 0
url="https://github.com/Freakling/SaaSAllTheThings.git"
state=".satt/state"
cache="$state/latest-release"
ver_re='^[[:space:]]*([0-9]{1,9})\.([0-9]{1,9})\.([0-9]{1,9})[[:space:]]*$'
tag_re='^[0-9a-fA-F]+[[:space:]]+refs/tags/v([0-9]{1,9})\.([0-9]{1,9})\.([0-9]{1,9})$'
find_cmd=find; [ -x /usr/bin/find ] && find_cmd=/usr/bin/find

# The installed version: the manifest's "# saasallthethings <version>" line, without a " + unreleased (...)" tail.
installed=""
while IFS= read -r line; do
  line="${line%$'\r'}"
  case "$line" in
    "# saasallthethings "*) installed="${line#"# saasallthethings "}"; break ;;
    "#"*) ;;
    *) break ;;
  esac
done < .satt/manifest
installed="${installed%% + unreleased*}"
[[ $installed =~ $ver_re ]] || exit 0
i1=$((10#${BASH_REMATCH[1]})); i2=$((10#${BASH_REMATCH[2]})); i3=$((10#${BASH_REMATCH[3]}))
installed_text="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"

# The latest release: what was found last, looked up again when that is missing or a day old.
latest=""
if [ -f "$cache" ]; then IFS= read -r latest < "$cache" || true; fi
latest="${latest%$'\r'}"
if [ ! -f "$cache" ] || [ -z "$("$find_cmd" "$cache" -mtime -1 2>/dev/null)" ]; then
  [ -d "$state" ] || mkdir -p "$state" 2>/dev/null || exit 0
  # The file is stamped before the lookup, with the old value, so a lookup that fails, or that is killed at the hook's
  # timeout, isn't tried again until tomorrow. A project that can't keep the stamp makes no request.
  [[ $latest =~ $ver_re ]] || latest=""
  if [ -n "$latest" ]; then printf '%s\n' "$latest" 2>/dev/null > "$cache" || exit 0
  else : 2>/dev/null > "$cache" || exit 0; fi
  if command -v timeout >/dev/null 2>&1; then
    tags="$(GIT_TERMINAL_PROMPT=0 timeout 5 git ls-remote --tags --refs "$url" 'refs/tags/v*' 2>/dev/null)" || tags=""
  else
    tags="$(GIT_TERMINAL_PROMPT=0 git ls-remote --tags --refs "$url" 'refs/tags/v*' 2>/dev/null)" || tags=""
  fi
  # The highest v<major>.<minor>.<patch>, by numeric fields; a tag of any other shape (v2.0.0-rc1, latest) is ignored.
  b1=-1; b2=0; b3=0
  while IFS= read -r line; do
    line="${line%$'\r'}"
    [[ $line =~ $tag_re ]] || continue
    a1=$((10#${BASH_REMATCH[1]})); a2=$((10#${BASH_REMATCH[2]})); a3=$((10#${BASH_REMATCH[3]}))
    if (( a1 > b1 || (a1 == b1 && (a2 > b2 || (a2 == b2 && a3 > b3))) )); then b1=$a1; b2=$a2; b3=$a3; fi
  done <<< "$tags"
  if [ "$b1" -ge 0 ]; then
    latest="$b1.$b2.$b3"
    printf '%s\n' "$latest" 2>/dev/null > "$cache" || exit 0
  fi
fi

# Warn when the latest release is above the installed version, compared field by field as numbers.
[[ $latest =~ $ver_re ]] || exit 0
l1=$((10#${BASH_REMATCH[1]})); l2=$((10#${BASH_REMATCH[2]})); l3=$((10#${BASH_REMATCH[3]}))
latest_text="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
if (( l1 > i1 || (l1 == i1 && (l2 > i2 || (l2 == i2 && l3 > i3))) )); then
  text="SaaSAllTheThings $installed_text is installed, and the latest release is $latest_text. Ask the agent to upgrade it when it suits you."
  printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s Tell the human this once, in your first reply."}}\n' "$text" "$text"
fi
exit 0
