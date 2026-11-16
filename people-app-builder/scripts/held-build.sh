#!/usr/bin/env bash
# save-preview: is Netlify holding this pull request's preview for an admin's approval?
# Held builds only show in the builds list (sha "pull/<n>/head"), never in the deploys list.
# Usage: held-build.sh <pr>   -> state=<deploy_state|none>. Exit 9 when held, 1 on failure.

# This script's folder; on Windows the path may use backslashes, which dirname ignores.
HERE=${0%[/\\]*}
[ "$HERE" != "$0" ] || HERE=.
# shellcheck source=lib.sh
. "$HERE/lib.sh"
need netlify jq

[ $# -eq 1 ] || die "$E_USAGE" "usage: held-build.sh <pr>"
sid=$(site_id)
state=$(netlify api listSiteBuilds --data "$(jq -n --arg s "$sid" '{site_id:$s}')" \
  | jqr -r --arg p "pull/$1/head" '[.[] | select(.sha == $p)][0].deploy_state // "none"') \
  || die "$E_FAIL" "couldn't read the app's builds"
echo "state=$state"
[ "$state" != pending_review ] || exit "$E_HELD"
