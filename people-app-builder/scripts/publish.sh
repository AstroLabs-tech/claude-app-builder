#!/usr/bin/env bash
# make-it-live: publish the preview pull request safely.
#   publish.sh check <pr>          checks all passed on the PR's current head -> head=<sha>
#   publish.sh merge <pr> <sha>    merge exactly that head (normal merge)      -> merge=<sha>
#   publish.sh status <merge-sha>  is that version live yet?                    -> live=<url>
# Exit: 0 ok; 6 still building/checking (run again shortly); 7 someone pushed meanwhile
# (check again); 8 ready but publishing is paused; 9 held for an admin's approval; 1 failure.

# This script's folder; on Windows the path may use backslashes, which dirname ignores.
HERE=${0%[/\\]*}
[ "$HERE" != "$0" ] || HERE=.
# shellcheck source=lib.sh
. "$HERE/lib.sh"
need gh jq

# pr_field <pr> <field> [jq path]: one field of the pull request.
pr_field() {
  gh pr view "$1" --json "$2" --jq "${3:-.$2}" | tr -d '\r'
}

check() {
  local pr=$1 head before after rc=0
  [ "$(pr_field "$pr" state)" = OPEN ] || die "$E_FAIL" "there's no open preview to publish"
  [ "$(pr_field "$pr" headRefName)" = preview ] && [ "$(pr_field "$pr" baseRefName)" = main ] \
    || die "$E_FAIL" "pull request $pr isn't the preview going into main"
  before=$(pr_field "$pr" headRefOid) || die "$E_FAIL" "couldn't read the preview"
  gh pr checks "$pr" >/dev/null 2>&1 || rc=$?
  case "$rc" in
    0) ;;
    8) die "$E_WAIT" "the preview's checks are still running" ;;
    *) die "$E_FAIL" "the preview's checks didn't pass" ;;
  esac
  after=$(pr_field "$pr" headRefOid) || die "$E_FAIL" "couldn't read the preview"
  [ "$before" = "$after" ] || die "$E_CLASH" "someone saved new changes to the preview meanwhile — check again"
  head=$after
  echo "head=$head"
}

merge() {
  local pr=$1 sha=$2 msg
  if ! msg=$(gh pr merge "$pr" --merge --match-head-commit "$sha" 2>&1); then
    printf '%s' "$msg" | grep -qi 'modified\|head' && die "$E_CLASH" "the preview changed since it was checked — check again"
    die "$E_FAIL" "couldn't publish: $msg"
  fi
  echo "merge=$(pr_field "$pr" mergeCommit .mergeCommit.oid)"
}

status() {
  local merge_sha=$1 sid deploy state did published held
  need netlify
  sid=$(site_id)
  deploy=$(netlify api listSiteDeploys --data "$(jq -n --arg s "$sid" '{site_id:$s, per_page:100}')" \
    | jqr -c --arg c "$merge_sha" 'first(.[] | select(.context == "production" and .commit_ref == $c)) // empty') \
    || die "$E_FAIL" "couldn't read the app's versions"
  if [ -z "$deploy" ]; then
    held=$(netlify api listSiteBuilds --data "$(jq -n --arg s "$sid" '{site_id:$s}')" \
      | jqr -r --arg c "$merge_sha" '[.[] | select(.sha == $c and .deploy_state == "pending_review")] | length') \
      || die "$E_FAIL" "couldn't read the app's builds"
    [ "$held" = 0 ] || die "$E_HELD" "Netlify is holding the new version until an admin approves this person"
    die "$E_WAIT" "the new version hasn't started building yet"
  fi
  state=$(printf '%s' "$deploy" | jqr -r .state)
  did=$(printf '%s' "$deploy" | jqr -r .id)
  case "$state" in
    ready) ;;
    error | rejected) die "$E_FAIL" "the new version didn't build: $(printf '%s' "$deploy" | jqr -r '.error_message // "no reason given"')" ;;
    *) die "$E_WAIT" "the new version is still building ($state)" ;;
  esac
  published=$(netlify api getSite --data "$(jq -n --arg s "$sid" '{site_id:$s}')" | jqr -r '.published_deploy.id // ""') \
    || die "$E_FAIL" "couldn't read the app"
  [ "$published" = "$did" ] || die "$E_PAUSED" "the new version is ready, but publishing is paused on this app"
  echo "live=$(netlify api getSite --data "$(jq -n --arg s "$sid" '{site_id:$s}')" | jqr -r '.ssl_url // .url')"
}

case "${1:-}" in
  check) [ $# -eq 2 ] || die "$E_USAGE" "usage: publish.sh check <pr>"; check "$2" ;;
  merge) [ $# -eq 3 ] || die "$E_USAGE" "usage: publish.sh merge <pr> <sha>"; merge "$2" "$3" ;;
  status) [ $# -eq 2 ] || die "$E_USAGE" "usage: publish.sh status <merge-sha>"; status "$2" ;;
  *) die "$E_USAGE" "usage: publish.sh check|merge|status …" ;;
esac
