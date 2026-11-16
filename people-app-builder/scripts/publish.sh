#!/usr/bin/env bash
# make-it-live: publish the preview pull request safely.
#   publish.sh check <pr>          every check passed on the PR's head, Netlify's too -> head=<sha>
#   publish.sh merge <pr> <sha>    merge exactly that head (normal merge)            -> merged=yes
#   publish.sh status <pr>         is the merged version live yet?                   -> live=<url>
# Exit: 0 ok; 6 still building/checking (run again shortly); 7 someone pushed meanwhile
# (check again); 8 ready but not the live one (paused, or an older version put back);
# 9 held for an admin's approval; 1 failure.

# This script's folder; on Windows the path may use backslashes, which dirname ignores.
HERE=${0%[/\\]*}
[ "$HERE" != "$0" ] || HERE=.
# shellcheck source=lib.sh
. "$HERE/lib.sh"
need gh jq

# One consistent snapshot of the pull request: its head and every check on that head.
pr_snapshot() {
  gh pr view "$1" --json state,headRefName,baseRefName,headRefOid,mergeCommit,statusCheckRollup \
    || die "$E_FAIL" "couldn't read the preview"
}

# passed | pending | failed | no-netlify, from a snapshot. Netlify's own deploy-preview
# status must be there and green: GitHub's checks can pass before Netlify has built.
CHECKS_JQ='[.statusCheckRollup[]?] as $r
  | if any($r[]; (.__typename == "CheckRun" and .status != "COMPLETED")
        or (.__typename == "StatusContext" and (.state == "PENDING" or .state == "EXPECTED"))) then "pending"
    elif any($r[]; (.__typename == "CheckRun" and (.conclusion | IN("FAILURE", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED", "STARTUP_FAILURE")))
        or (.__typename == "StatusContext" and (.state | IN("FAILURE", "ERROR")))) then "failed"
    elif any($r[]; .__typename == "StatusContext" and (.context | test("^netlify/.+/deploy-preview$")) and .state == "SUCCESS") then "passed"
    else "no-netlify" end'

check() {
  local pr=$1 snap fields verdict state head_ref base_ref head held
  snap=$(pr_snapshot "$pr")
  fields=$(printf '%s' "$snap" | jqr -r '"\(.state) \(.headRefName) \(.baseRefName) \(.headRefOid)"') \
    || die "$E_FAIL" "couldn't read the preview"
  read -r state head_ref base_ref head <<<"$fields"
  [ "$state" = OPEN ] || die "$E_FAIL" "there's no open preview to publish"
  [ "$head_ref" = preview ] && [ "$base_ref" = main ] || die "$E_FAIL" "pull request $pr isn't the preview going into main"
  verdict=$(printf '%s' "$snap" | jqr -r "$CHECKS_JQ") || die "$E_FAIL" "couldn't read the preview's checks"
  case "$verdict" in
    passed) echo "head=$head" ;;
    failed) die "$E_FAIL" "the preview's checks didn't pass" ;;
    pending | no-netlify)
      # A held preview can show as pending, or as no Netlify status at all: check first.
      need netlify
      held=$(build_state "pull/$pr/head") || exit $?
      [ "$held" != pending_review ] || die "$E_HELD" "Netlify is holding the preview until an admin approves this person"
      die "$E_WAIT" "the preview's checks or Netlify's build are still running" ;;
  esac
}

merge() {
  local pr=$1 sha=$2 msg
  if ! msg=$(gh pr merge "$pr" --merge --match-head-commit "$sha" 2>&1); then
    printf '%s' "$msg" | grep -qi 'modified\|head' && die "$E_CLASH" "the preview changed since it was checked — check again"
    die "$E_FAIL" "couldn't publish: $msg"
  fi
  echo "merged=yes"
}

status() {
  local pr=$1 snap merge_sha sid deploys deploy state did site published url held locked live_commit out
  need netlify
  snap=$(pr_snapshot "$pr")
  [ "$(printf '%s' "$snap" | jqr -r .state)" = MERGED ] || die "$E_FAIL" "pull request $pr hasn't been published"
  merge_sha=$(printf '%s' "$snap" | jqr -r '.mergeCommit.oid // ""') || die "$E_FAIL" "couldn't read the preview"
  [ -n "$merge_sha" ] || die "$E_WAIT" "GitHub hasn't finished recording the publish yet"
  sid=$(site_id)
  deploys=$(netlify api listSiteDeploys --data "$(jq -n --arg s "$sid" '{site_id:$s, per_page:100}')") \
    || die "$E_FAIL" "couldn't read the app's versions"
  deploy=$(printf '%s' "$deploys" | jqr -c --arg c "$merge_sha" 'first(.[] | select(.context == "production" and .commit_ref == $c)) // empty') \
    || die "$E_FAIL" "couldn't read the app's versions"
  if [ -z "$deploy" ]; then
    held=$(build_state "$merge_sha") || exit $?
    [ "$held" != pending_review ] || die "$E_HELD" "Netlify is holding the new version until an admin approves this person"
    die "$E_WAIT" "the new version hasn't started building yet"
  fi
  state=$(printf '%s' "$deploy" | jqr -r .state) || die "$E_FAIL" "couldn't read the new version"
  did=$(printf '%s' "$deploy" | jqr -r .id) || die "$E_FAIL" "couldn't read the new version"
  case "$state" in
    ready) ;;
    error | rejected) die "$E_FAIL" "the new version didn't build: $(printf '%s' "$deploy" | jqr -r '.error_message // "no reason given"')" ;;
    *) die "$E_WAIT" "the new version is still building ($state)" ;;
  esac
  site=$(netlify api getSite --data "$(jq -n --arg s "$sid" '{site_id:$s}')") || die "$E_FAIL" "couldn't read the app"
  published=$(printf '%s' "$site" | jqr -r '.published_deploy.id // ""') || die "$E_FAIL" "couldn't read the app"
  url=$(printf '%s' "$site" | jqr -r '.ssl_url // .url') || die "$E_FAIL" "couldn't read the app's address"
  if [ "$published" != "$did" ]; then
    locked=$(printf '%s' "$site" | jqr -r '.published_deploy.locked // "unknown"') || die "$E_FAIL" "couldn't read the app"
    [ "$locked" != true ] || die "$E_PAUSED" "the new version is ready, but publishing is paused on this app"
    # Only say it's live if the live version's commit contains the merged one (git
    # ancestry). A newer timestamp alone isn't proof: a redeploy of an old commit, a
    # put-back older version, or a manual deploy can all be newer.
    live_commit=$(printf '%s' "$deploys" | jqr -r --arg p "$published" \
      'first(.[] | select(.id == $p and .context == "production")) | .commit_ref // ""') \
      || die "$E_FAIL" "couldn't read the live version"
    [ -n "$live_commit" ] || die "$E_PAUSED" "the new version is ready, but a different version is live"
    need git
    out=$(git fetch -q origin 2>&1) || git_failed "check which version is live" "$out"
    git merge-base --is-ancestor "$merge_sha" "$live_commit" 2>/dev/null \
      || die "$E_PAUSED" "the new version is ready, but an older version is still the live one"
    echo "note=newer-version-live"
  fi
  echo "live=$url"
}

case "${1:-}" in
  check) [ $# -eq 2 ] || die "$E_USAGE" "usage: publish.sh check <pr>"; check "$2" ;;
  merge) [ $# -eq 3 ] || die "$E_USAGE" "usage: publish.sh merge <pr> <sha>"; merge "$2" "$3" ;;
  status) [ $# -eq 2 ] || die "$E_USAGE" "usage: publish.sh status <pr>"; status "$2" ;;
  *) die "$E_USAGE" "usage: publish.sh check|merge|status …" ;;
esac
