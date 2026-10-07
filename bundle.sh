#!/usr/bin/env bash
# Copies the framework files the saas-design-session skill carries into its references/ folder.
# The skills CLI copies only a skill's own folder, and the Claude apps can't clone a repository,
# so the skill brings its own copy of what it argues from. framework/.satt/ stays the only source:
# run this after changing any of these files. selftest.sh fails when the copy has drifted.
#
#   bash bundle.sh           write the copy
#   bash bundle.sh --check   exit 1 if the copy differs from framework/.satt/

set -eu
FIND=find; [ -x /usr/bin/find ] && FIND=/usr/bin/find   # not Windows' find.exe
SORT=sort; [ -x /usr/bin/sort ] && SORT=/usr/bin/sort   # not Windows' sort.exe
TAR=tar;   [ -x /usr/bin/tar ] && TAR=/usr/bin/tar      # not Windows' tar.exe
src="$(cd "$(dirname "$0")" && pwd)"
from="framework/.satt"
to="skills/saas-design-session/references"
cd "$src"

# What the skill needs: the rules, the reference, the playbook, and the session procedures.
list() {
  (cd "$from" && for f in rules.md tasks.md reference/*.md workshops/*.md templates/adr.md \
      templates/integration-contract.md procedures/architect.md procedures/assess.md procedures/design.md procedures/integrate.md; do
    [ -f "$f" ] && printf '%s\n' "$f"
  done) | LC_ALL=C "$SORT"
}
# hashes <folder>: the hash of each listed file in it, in one git call. Paths are given from the
# repository root (where this script runs), which is how --stdin-paths reads them in a repository.
hashes() { list | sed "s|^|$1/|" | git hash-object --no-filters --stdin-paths; }

if [ "${1:-}" = "--check" ]; then
  present=""
  [ -d "$to" ] && present="$(cd "$to" && "$FIND" . -type f | sed 's|^\./||' | LC_ALL=C "$SORT")"
  if [ "$(list)" != "$present" ]; then
    echo "bundle: $to/ doesn't hold the files it should carry. Run: bash bundle.sh"
    exit 1
  fi
  if [ "$(hashes "$from")" != "$(hashes "$to")" ]; then
    echo "bundle: $to/ differs from $from/. Run: bash bundle.sh"
    exit 1
  fi
  echo "bundle: $to/ matches $from/"
  exit 0
fi

rm -rf "$to"
mkdir -p "$to"
list > "$to.list"
(cd "$from" && "$TAR" -cf - -T "$src/$to.list") | (cd "$to" && "$TAR" -xf -)
rm -f "$to.list"
echo "bundle: copied $(list | wc -l | tr -d ' ') files into $to/"
