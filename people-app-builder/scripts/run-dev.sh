#!/usr/bin/env bash
# show-me: start the app on this computer with its test sign-in codes, read straight from
# the Netlify site so they never appear in a command or a file. Run it in the background;
# read the "Local: http://localhost:<port>" line it prints for the address.
# Exit: 3 if the app has no test codes yet (the app is not started), 1 on failure.

# This script's folder; on Windows the path may use backslashes, which dirname ignores.
HERE=${0%[/\\]*}
[ "$HERE" != "$0" ] || HERE=.
# shellcheck source=lib.sh
. "$HERE/lib.sh"
need netlify jq npm

pk=$(env_get NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY dev)
sk=$(env_get CLERK_SECRET_KEY dev)
[ -n "$pk" ] && [ -n "$sk" ] || die "$E_NOT_SET_UP" "this app has no test sign-in codes yet"
[ -d node_modules ] || npm install >/dev/null || die "$E_FAIL" "couldn't install the app's parts"

export NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY="$pk" CLERK_SECRET_KEY="$sk"
exec npm run dev
