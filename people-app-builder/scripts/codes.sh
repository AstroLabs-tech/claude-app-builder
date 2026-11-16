#!/usr/bin/env bash
# The app's Clerk sign-in codes on its Netlify site.
#   codes.sh store-test <pk_test_…> <sk_test_…>   store them for local runs and previews only
#   codes.sh check-live                          are real live codes on the live app?
# Values are never printed. Exit: 0 ok, 3 live codes missing/not live, 1 failure.

# This script's folder; on Windows the path may use backslashes, which dirname ignores.
HERE=${0%[/\\]*}
[ "$HERE" != "$0" ] || HERE=.
# shellcheck source=lib.sh
. "$HERE/lib.sh"
need netlify jq

TEST_CONTEXTS=(dev deploy-preview branch-deploy)

store_test() {
  local pk=$1 sk=$2
  case "$pk" in pk_test_*) ;; *) die "$E_FAIL" "the first code isn't a test code (it must start with pk_test_)" ;; esac
  case "$sk" in sk_test_*) ;; *) die "$E_FAIL" "the second code isn't a test code (it must start with sk_test_)" ;; esac
  netlify env:set NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY "$pk" --context "${TEST_CONTEXTS[@]}" >/dev/null \
    || die "$E_FAIL" "couldn't store the test codes"
  netlify env:set CLERK_SECRET_KEY "$sk" --context "${TEST_CONTEXTS[@]}" >/dev/null \
    || die "$E_FAIL" "couldn't store the test codes"
  [ "$(env_get NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY dev)" = "$pk" ] && [ "$(env_get CLERK_SECRET_KEY dev)" = "$sk" ] \
    || die "$E_FAIL" "the test codes didn't save correctly"
  echo "test_codes=stored"
}

check_live() {
  local pk sk
  pk=$(env_get NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY production)
  sk=$(env_get CLERK_SECRET_KEY production)
  case "$pk/$sk" in
    pk_live_*/sk_live_*) echo "live_codes=ready" ;;
    *) die "$E_NOT_SET_UP" "the live sign-in isn't set up yet" ;;
  esac
}

case "${1:-}" in
  store-test) [ $# -eq 3 ] || die "$E_USAGE" "usage: codes.sh store-test <pk_test_…> <sk_test_…>"; store_test "$2" "$3" ;;
  check-live) check_live ;;
  *) die "$E_USAGE" "usage: codes.sh store-test <pk> <sk> | check-live" ;;
esac
