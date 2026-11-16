#!/usr/bin/env bash
# save-preview step 1: does the open preview hold someone else's unpublished changes?
# Everyone shares one GitHub login, so it compares who wrote the changes (commit author
# emails), ignoring Claude's co-author address and this builder's own addresses.
# Prints pr=<n> (if open) and other=<email> lines. Exit 7 if someone else's work is there.

# This script's folder; on Windows the path may use backslashes, which dirname ignores.
HERE=${0%[/\\]*}
[ "$HERE" != "$0" ] || HERE=.
# shellcheck source=lib.sh
. "$HERE/lib.sh"
need gh jq git

mine=$( { git config --global user.email || true; git config user.email || true; } | tr '[:upper:]' '[:lower:]' | sort -u)
prs=$(gh pr list --head preview --state open --json number,commits) || die "$E_FAIL" "couldn't read the open previews"
printf '%s' "$prs" | jqr -r '.[] | "pr=\(.number)"'
others=$(printf '%s' "$prs" | jqr -r '.[].commits[].authors[].email | ascii_downcase' | sort -u \
  | grep -vx 'noreply@anthropic.com' | grep -vxF -f <(printf '%s\n' "$mine") || true)
[ -n "$others" ] || exit 0
printf '%s\n' "$others" | sed 's/^/other=/'
exit "$E_CLASH"
