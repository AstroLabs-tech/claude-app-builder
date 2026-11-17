#!/usr/bin/env bash
# put-it-back: republish the live version before the current one.
#   rollback.sh                       roll back; prints restored=<deploy-id>, good_commit=<sha>
#   rollback.sh check <restored-id>   after an exit 6 that printed restored=…: did the
#                                     rollback hold? prints rollback=holds|replaced
# Waits for nothing: if a live build is in progress it stops with 6 (it would overwrite
# the rollback). Only versions that were really live count. Run inside the app's folder.
# Exit 6 busy, 1 failure/nothing to do.

# This script's folder; on Windows the path may use backslashes, which dirname ignores.
HERE=${0%[/\\]*}
[ "$HERE" != "$0" ] || HERE=.
# shellcheck source=lib.sh
. "$HERE/lib.sh"
need netlify jq

sid=$(site_id)
deploys_page() {
  netlify api listSiteDeploys --data "$(jq -n --arg s "$sid" --argjson p "$1" '{site_id:$s, page:$p, per_page:100}')"
}

# Every state where a production build may still finish and publish over the rollback.
# Builds held for an admin's approval (pending_review) only show in the builds list;
# held_live() reports those.
ACTIVE='["new", "enqueued", "building", "uploading", "uploaded", "preparing", "prepared", "processing", "processed", "retrying", "accepted"]'

# Active production builds, across every page (previews can push them past page 1).
busy_now() {
  local page=1 body n count=0 c
  while :; do
    body=$(deploys_page "$page") || die "$E_FAIL" "couldn't read the app's versions"
    c=$(printf '%s' "$body" | jqr -r --argjson a "$ACTIVE" '[.[] | select(.context == "production" and (.state as $s | $a | index($s)))] | length') \
      || die "$E_FAIL" "couldn't read the app's versions"
    count=$((count + c))
    n=$(printf '%s' "$body" | jqr -r 'length') || die "$E_FAIL" "couldn't read the app's versions"
    [ "$n" -eq 100 ] || break
    page=$((page + 1))
  done
  echo "$count"
}

# Production builds held for an admin's approval: once approved, they would publish over
# the rollback. A build doesn't say what kind it is; its deploy does (previews and
# branch deploys are held the same way, and don't matter here).
held_live() {
  local ids="" page=1 body d ctx n=0
  while :; do
    body=$(netlify api listSiteBuilds --data "$(jq -n --arg s "$sid" --argjson p "$page" '{site_id:$s, page:$p, per_page:100}')") \
      || die "$E_FAIL" "couldn't read the app's builds"
    ids+=$(printf '%s' "$body" | jqr -r '.[] | select(.deploy_state == "pending_review") | .deploy_id // empty') \
      || die "$E_FAIL" "couldn't read the app's builds"
    ids+=$'\n'
    [ "$(printf '%s' "$body" | jqr -r 'length')" -eq 100 ] || break
    page=$((page + 1))
  done
  for d in $ids; do
    ctx=$(netlify api getDeploy --data "$(jq -n --arg d "$d" '{deploy_id:$d}')" | jqr -r '.context // ""') \
      || die "$E_FAIL" "couldn't read a held build"
    [ "$ctx" != production ] || n=$((n + 1))
  done
  echo "$n"
}

live_now() {
  netlify api getSite --data "$(jq -n --arg s "$sid" '{site_id:$s}')" | jqr -er '.published_deploy.id' \
    || die "$E_FAIL" "couldn't read which version is live"
}

# After a rollback that a build may have overtaken: once nothing is building, is the
# restored version still the live one? Re-running the rollback when it still holds would
# go back one version too far.
if [ "${1:-}" = check ]; then
  [ $# -eq 2 ] && [ -n "$2" ] || die "$E_USAGE" "usage: rollback.sh check <restored-id>"
  # Fetch that deploy by id (it may be far down the list) and make sure it's one of
  # this app's live versions.
  known=$(netlify api getDeploy --data "$(jq -n --arg d "$2" '{deploy_id:$d}')" 2>/dev/null \
    | jqr -r --arg s "$sid" 'if .site_id == $s and .context == "production" then "yes" else "no" end') || known=no
  [ "$known" = yes ] || die "$E_USAGE" "'$2' isn't one of this app's live versions; use the restored= value"
  busy=$(busy_now) || exit $?
  [ "$busy" = 0 ] || die "$E_WAIT" "the new live version is still building; check again shortly"
  # What's live decides the outcome; a held build is reported on top of that.
  live=$(live_now) || exit $?
  if [ "$live" != "$2" ]; then echo "rollback=replaced"; exit 0; fi
  echo "rollback=holds"
  held=$(held_live) || exit $?
  [ "$held" = 0 ] || die "$E_HELD" "the rollback holds for now, but a new live version is waiting for an admin's approval and would replace it once approved"
  exit 0
fi
[ $# -eq 0 ] || die "$E_USAGE" "usage: rollback.sh | rollback.sh check <restored-id>"

busy=$(busy_now) || exit $?
[ "$busy" = 0 ] || die "$E_WAIT" "a new live version is still building; wait for it to finish first"

cur=$(live_now) || exit $?

# Every version that was really live, newest publish first. List position isn't publish
# order: a restored version is republished without moving in the list.
live_versions=""
page=1
while :; do
  body=$(deploys_page "$page") || die "$E_FAIL" "couldn't read the app's versions"
  n=$(printf '%s' "$body" | jqr -er 'if type == "array" then length else error("bad") end') \
    || die "$E_FAIL" "Netlify sent an unexpected reply"
  live_versions+=$(printf '%s' "$body" | jqr -c '.[] | select(.context == "production" and .state == "ready" and .published_at != null)
    | {id, commit_ref, published_at}')$'\n'
  [ "$n" -eq 100 ] || break
  page=$((page + 1))
done
ordered=$(printf '%s' "$live_versions" | jqr -rs 'sort_by(.published_at) | reverse | .[] | "\(.id) \(.commit_ref)"') \
  || die "$E_FAIL" "couldn't sort the app's versions"

found=no
prev=""
while read -r id commit; do
  [ -n "$id" ] || continue
  if [ "$found" = yes ]; then prev="$id $commit"; break; fi
  [ "$id" = "$cur" ] && found=yes
done <<<"$ordered"
[ "$found" = yes ] || die "$E_FAIL" "couldn't tell which version is live, so not guessing which one to go back to"
[ -n "$prev" ] || die "$E_FAIL" "there's no earlier version to go back to"

prev_id=${prev%% *}
netlify api restoreSiteDeploy --data "$(jq -n --arg s "$sid" --arg d "$prev_id" '{site_id:$s, deploy_id:$d}')" >/dev/null \
  || die "$E_FAIL" "couldn't republish the earlier version"
now=$(netlify api getSite --data "$(jq -n --arg s "$sid" '{site_id:$s}')" | jqr -r '.published_deploy.id // ""') \
  || die "$E_FAIL" "couldn't confirm the rollback"
[ "$now" = "$prev_id" ] || die "$E_FAIL" "the earlier version didn't go live"
echo "restored=$prev_id"
echo "good_commit=${prev#* }"
# A build that started while this ran would publish over the rollback when it finishes.
busy=$(busy_now) || exit $?
[ "$busy" = 0 ] || die "$E_WAIT" "rolled back, but a new live version started building and may replace it; once it finishes, run 'rollback.sh check $prev_id'"
