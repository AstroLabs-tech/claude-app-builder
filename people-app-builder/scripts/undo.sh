#!/usr/bin/env bash
# put-it-back step 4: after a rollback, add the undo on top of the `preview` line as one new
# change, so the next "make it live" can't publish the faulty version again.
# Usage: undo.sh <good-commit> "<what went wrong, in plain words>"
# Needs a clean folder (nothing unsaved). Prints undo_commit=<sha>.
# Exit 4 unsaved work here (decide first), 7 the undo clashes, 1 failure.

# This script's folder; on Windows the path may use backslashes, which dirname ignores.
HERE=${0%[/\\]*}
[ "$HERE" != "$0" ] || HERE=.
# shellcheck source=lib.sh
. "$HERE/lib.sh"
need git

[ $# -eq 2 ] || die "$E_USAGE" "usage: undo.sh <good-commit> <description>"
good=$1
[ -z "$(git status --porcelain)" ] || die "$E_DECIDE" "there are unsaved changes here; save or set them aside first"

rc=0
reason=$(bash "$HERE/preview-branch.sh" 2>&1 >/dev/null) || rc=$?
reason=$(printf '%s\n' "$reason" | sed -n 's/^STOP: //p' | tail -1)
[ "$rc" -eq 0 ] || die "$rc" "couldn't get onto the preview line: ${reason:-unknown reason} (no undo was tried)"
git cat-file -e "$good^{commit}" 2>/dev/null || die "$E_FAIL" "the good version isn't on this computer"

git diff --quiet origin/main "$good" && die "$E_FAIL" "nothing to undo: the live line already matches the good version"
# Exactly what main gained after the good version, undone; unpublished preview work stays.
if ! git diff --binary origin/main "$good" | git apply --index --3way >/dev/null 2>&1; then
  git reset -q --hard HEAD # safe: the folder was clean before
  die "$E_CLASH" "the undo clashes with unpublished changes on the preview"
fi
git diff --cached --quiet && die "$E_FAIL" "nothing to undo: the preview line already matches the good version"
git commit -q -m "Put back the version from before: $2" || die "$E_FAIL" "couldn't save the undo"
undo_commit=$(git rev-parse --short HEAD) || die "$E_FAIL" "saved the undo, but couldn't read it back"
echo "undo_commit=$undo_commit"
