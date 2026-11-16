#!/usr/bin/env bash
# put-it-back steps 1–3: republish the live version before the current one.
# Waits for nothing: if a live build is in progress it stops with 6 (it would overwrite
# the rollback). Only versions that were really live count. Run inside the app's folder.
# Prints restored=<deploy-id> and good_commit=<sha>. Exit 6 busy, 1 failure/nothing to do.

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

first=$(deploys_page 1) || die "$E_FAIL" "couldn't read the app's versions"
busy=$(printf '%s' "$first" | jqr -r '[.[] | select(.context == "production" and
  (.state == "new" or .state == "enqueued" or .state == "building" or .state == "uploading" or .state == "preparing"))] | length')
[ "$busy" = 0 ] || die "$E_WAIT" "a new live version is still building; wait for it to finish first"

cur=$(netlify api getSite --data "$(jq -n --arg s "$sid" '{site_id:$s}')" | jqr -er '.published_deploy.id') \
  || die "$E_FAIL" "couldn't read which version is live"

page=1
found=no
prev=""
body=$first
while :; do
  n=$(printf '%s' "$body" | jqr -er 'if type == "array" then length else error("bad") end') \
    || die "$E_FAIL" "Netlify sent an unexpected reply"
  ids=$(printf '%s' "$body" | jqr -r '.[] | select(.context == "production" and .state == "ready" and .published_at != null) | "\(.id) \(.commit_ref)"')
  while read -r id commit; do
    [ -n "$id" ] || continue
    if [ "$found" = yes ]; then prev="$id $commit"; break; fi
    [ "$id" = "$cur" ] && found=yes
  done <<<"$ids"
  [ -z "$prev" ] && [ "$n" -eq 100 ] || break
  page=$((page + 1))
  body=$(deploys_page "$page") || die "$E_FAIL" "couldn't read the app's versions"
done
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
