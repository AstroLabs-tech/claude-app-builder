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
prs=$(gh pr list --head preview --state open --json number --jq '.[].number' | tr -d '\r') \
  || die "$E_FAIL" "couldn't read the open previews"
authors=""
for pr in $prs; do
  echo "pr=$pr"
  # Every commit (the pr list's commits field stops at 100). Co-authors aren't listed
  # here, so Claude's co-author line never shows up as another person.
  a=$(gh api --paginate "repos/{owner}/{repo}/pulls/$pr/commits" --jq '.[].commit.author.email' | tr -d '\r') \
    || die "$E_FAIL" "couldn't read who made the open preview's changes"
  # GitHub's list stops at 250 commits: if the PR has more than were listed, a bigger
  # preview can't be fully checked.
  total=$(gh api "repos/{owner}/{repo}/pulls/$pr" --jq '.commits' | tr -d '\r') \
    || die "$E_FAIL" "couldn't read the open preview"
  listed=$(gh api --paginate "repos/{owner}/{repo}/pulls/$pr/commits" --jq '.[] | "x"' | grep -c x || true)
  [ "$listed" -ge "$total" ] \
    || die "$E_FAIL" "the open preview has too many changes to check who made them ($total)"
  authors+=$(printf '%s\n' "$a" | tr '[:upper:]' '[:lower:]')$'\n'
done
others=$(printf '%s\n' "$authors" | sort -u | grep -v '^$' | grep -vx 'noreply@anthropic.com' \
  | grep -vxF -f <(printf '%s\n' "$mine") || true)
[ -n "$others" ] || exit 0
printf '%s\n' "$others" | sed 's/^/other=/'
exit "$E_CLASH"
