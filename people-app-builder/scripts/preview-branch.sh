#!/usr/bin/env bash
# save-preview step 2 (and put-it-back): get onto the `preview` line, carrying unsaved
# changes along, up to date with GitHub's copy and with anything newer on `main`.
# Prints changes=yes|no (unsaved work here) and waiting=<n> (saved but not on GitHub yet).
# Exit 7 if the changes clash (nothing is left half-merged), 1 on failure.

# This script's folder; on Windows the path may use backslashes, which dirname ignores.
HERE=${0%[/\\]*}
[ "$HERE" != "$0" ] || HERE=.
# shellcheck source=lib.sh
. "$HERE/lib.sh"
need git

out=$(git fetch -q origin 2>&1) || git_failed "fetch the latest changes" "$out"
remote_preview=no
git rev-parse -q --verify origin/preview >/dev/null && remote_preview=yes

if git rev-parse -q --verify preview >/dev/null; then
  git switch -q preview 2>/dev/null || die "$E_CLASH" "unsaved changes clash with the preview line"
  if [ "$remote_preview" = yes ]; then
    git merge -q --ff-only origin/preview 2>/dev/null \
      || die "$E_CLASH" "this computer's preview and GitHub's have both changed"
  fi
elif [ "$remote_preview" = yes ]; then
  git switch -q -c preview --track origin/preview 2>/dev/null || die "$E_CLASH" "unsaved changes clash with the preview line"
else
  git switch -q -c preview origin/main 2>/dev/null || die "$E_CLASH" "unsaved changes clash with the live line"
fi

# Bring in anything newer on main (a normal merge, never a rebase). Merging with unsaved
# changes is only safe when they don't touch the same files; git refuses otherwise.
if ! git merge -q --no-edit origin/main >/dev/null 2>&1; then
  git merge --abort >/dev/null 2>&1 || true
  die "$E_CLASH" "the latest live version clashes with these changes"
fi

if [ -n "$(git status --porcelain)" ]; then echo "changes=yes"; else echo "changes=no"; fi
if [ "$remote_preview" = yes ]; then
  echo "waiting=$(git rev-list --count origin/preview..preview)"
else
  echo "waiting=$(git rev-list --count origin/main..preview)"
fi
