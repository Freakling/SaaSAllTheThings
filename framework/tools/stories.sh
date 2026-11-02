#!/usr/bin/env bash
# SaaSAllTheThings user stories · framework-owned: replaced on upgrade.
#
# Whether the user stories in product/user-stories.md are due for validation (.satt/procedures/design.md
# › Validate the stories), counted the way .satt/procedures/next-task.md counts items for the security assessment:
#   bash tools/stories.sh --due    due when the stories were never validated (Last validated: never), or after
#                                  tools/check.cfg › [stories] every (default 10) built items (commits whose subject
#                                  ends in "(T<n>)" or "(B<n>)", or that and a squash merge's " (#<pr>)") since the
#                                  commit on the file's Last validated line; by its date when that commit isn't in
#                                  this history. Not due while the file has no stories.
# Exit codes: 0 = it printed its line · 3 = couldn't run
# Process starts are slow on Windows, so the file and the setting are read with shell builtins.

set -u
case "$0" in */*) cd "${0%/*}/.." ;; *) cd .. ;; esac || exit 3
mode="${1:-}"
stories="product/user-stories.md"
every_default=10

[ "$mode" = "--due" ] || { echo "usage: bash tools/stories.sh --due"; exit 3; }

repo="$(git rev-parse --is-inside-work-tree --is-shallow-repository 2>/dev/null)" \
  || { echo "stories: couldn't count: not a git repository"; exit 3; }
[ "$repo" = "true"$'\n'"true" ] \
  && echo "stories: note: this is a shallow clone, so items before its oldest commit aren't counted"

# tools/check.cfg › [stories] every, read as tools/cfg.sh reads its sections: comments go on their own lines.
every=""
if [ -f tools/check.cfg ]; then
  section=""
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    line="${line#"${line%%[![:space:]]*}"}"
    case "$line" in
      ''|';'*|'#'*) continue ;;
      '['*) section="${line#?}"; section="${section%%]*}"; continue ;;
    esac
    [ "$section" = "stories" ] || continue
    case "$line" in *=*) ;; *) continue ;; esac
    key="${line%%=*}"; key="${key%"${key##*[![:space:]]}"}"
    [ "$key" = "every" ] || continue
    every="${line#*=}"; every="${every#"${every%%[![:space:]]*}"}"; every="${every%"${every##*[![:space:]]}"}"
  done < tools/check.cfg
fi
case "$every" in
  ''|*[!0-9]*) valid=0 ;;
  *[1-9]*) valid=1 ;;
  *) valid=0 ;;
esac
if [ "$valid" -eq 0 ]; then
  [ -n "$every" ] && echo "stories: note: [stories] every = $every isn't a whole number above 0; using $every_default"
  every="$every_default"
fi

if [ ! -f "$stories" ]; then
  echo "stories: not due: no stories yet (no $stories), [stories] every = $every"
  exit 0
fi
# A story is a table row whose first cell is its ID (US-<n>; an app's own US-<prefix><n> IDs count too).
row_re='^[|][[:space:]]*US-[A-Za-z0-9]+[[:space:]]*[|]'
unconfirmed_re='[|][[:space:]]*[Uu][Nn][Cc][Oo][Nn][Ff][Ii][Rr][Mm][Ee][Dd][[:space:]]*[|]'
validated_re='[*][*]Last validated:[*][*][[:space:]]*(.*)$'
total=0; unconfirmed=0; validated=""; found=0
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  if [[ $line =~ $row_re ]]; then
    total=$((total + 1))
    [[ $line =~ $unconfirmed_re ]] && unconfirmed=$((unconfirmed + 1))
  elif [ "$found" -eq 0 ] && [[ $line =~ $validated_re ]]; then
    found=1; validated="${BASH_REMATCH[1]}"
  fi
done < "$stories"
if [ "$total" -eq 0 ]; then
  echo "stories: not due: no stories yet in $stories, [stories] every = $every"
  exit 0
fi
summary="$total stories, $unconfirmed unconfirmed"
day=""; commit=""
day_re='([0-9]{4}-[0-9]{2}-[0-9]{2})'
commit_re='`([0-9a-fA-F]{7,40})`'
[[ $validated =~ $day_re ]] && day="${BASH_REMATCH[1]}"
[[ $validated =~ $commit_re ]] && commit="${BASH_REMATCH[1]}"

# Built items: commit subjects ending in "(T<n>)" or "(B<n>)", also with a squash merge's " (#<pr>)" after it.
item_re='[(](T|B)[0-9]+[)]( [(]#[0-9]+[)])?$'
count_items() { # count_items <git log arguments>: the built items among those commits
  local subject n=0
  while IFS= read -r subject; do
    [[ $subject =~ $item_re ]] && n=$((n + 1))
  done < <(git log --format=%s "$@" 2>/dev/null)
  count="$n"
}
count=0
if [ -n "$commit" ] && git cat-file -e "$commit^{commit}" 2>/dev/null; then
  count_items "$commit..HEAD"
  since="the last validation (${day:-no date}, commit $commit)"
elif [ -n "$day" ]; then
  count_items --since="${day}T00:00:00"
  if [ -n "$commit" ]; then since="the last validation ($day, by its date: its commit isn't in this history)"
  else since="the last validation ($day, by its date: the line names no commit)"; fi
else
  if [ "$found" -eq 0 ]; then why="$stories has no Last validated line"; else why="Last validated: $validated"; fi
  echo "stories: due: never validated ($why), $summary, [stories] every = $every"
  exit 0
fi
if [ "$count" -ge "$every" ]; then
  echo "stories: due: built items since $since: $count, [stories] every = $every; $summary"
else
  echo "stories: not due: built items since $since: $count, [stories] every = $every; $summary"
fi
exit 0
