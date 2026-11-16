#!/usr/bin/env bash
# who-can-get-in: manage a People app's approved-email lists through Clerk's Backend API.
# The "test" list (previews, show me) uses the dev codes; the "live" list the production ones.
# The Clerk secret is read from the app's Netlify site and handed to curl on stdin, never
# printed or passed as an argument. Run inside the app's folder.
#
#   access.sh lists                       which lists exist          -> test=yes|no live=yes|no
#   access.sh list    <test|live>         approved entries           -> approved <entry> ... count=N
#   access.sh approve <test|live> <email>... add people              -> approved|already|failed|skipped <email>
#   access.sh remove  <email>...          take people off BOTH lists and block their accounts
#   access.sh lock    <test|live>         switch the list on, then check every existing account
#
# Exit: 0 ok, 3 that list doesn't exist yet, 4 accounts need the builder's decision (lock),
# 1 something failed (message on stderr; per-email failures are also listed on stdout).

# This script's folder; on Windows the path may use backslashes, which dirname ignores.
HERE=${0%[/\\]*}
[ "$HERE" != "$0" ] || HERE=.
# shellcheck source=lib.sh
. "$HERE/lib.sh"

CLERK_API=https://api.clerk.com/v1
PAGE=500
need netlify jq curl

SK=""
RC=""
BODY=""

# Load the secret for one list; stops with 3 when the list has no codes yet.
use_list() {
  local ctx
  ctx=$(list_context "$1")
  SK=$(env_get CLERK_SECRET_KEY "$ctx")
  [ -n "$SK" ] || die "$E_NOT_SET_UP" "the $1 list isn't set up yet (no sign-in codes for it)"
}

# api METHOD PATH [JSON]: sets RC (HTTP status) and BODY. Stops if Clerk can't be reached.
api() {
  local method=$1 path=$2 data=${3-} out
  local args=(-sS -X "$method" -w '\n%{http_code}' -H 'Content-Type: application/json')
  if [ -n "$data" ]; then args+=(--data "$data"); fi
  out=$(printf 'header = "Authorization: Bearer %s"\n' "$SK" | curl "${args[@]}" -K - "$CLERK_API$path") \
    || die "$E_FAIL" "couldn't reach the sign-in service"
  RC=${out##*$'\n'}
  BODY=${out%$'\n'*}
}

ok() { [ "$RC" -ge 200 ] && [ "$RC" -lt 300 ]; }

clean_email() {
  local e
  e=$(lower "$1" | tr -d '[:space:]')
  if printf '%s' "$e" | grep -Eq '^[^@]+@[^@]+\.[^@]+$'; then printf '%s' "$e"; fi
}

# Every approved entry, one per line as "<id> <identifier>". Stops on any bad page.
all_entries() {
  local off=0 total
  while :; do
    api GET "/allowlist_identifiers?paginated=true&limit=$PAGE&offset=$off"
    ok || die "$E_FAIL" "couldn't read the approved list (HTTP $RC)"
    printf '%s' "$BODY" | jq -e '(.data | type == "array") and (.total_count | type == "number")' >/dev/null \
      || die "$E_FAIL" "the sign-in service sent an unexpected reply"
    printf '%s' "$BODY" | jqr -r '.data[] | "\(.id) \(.identifier | ascii_downcase)"'
    total=$(printf '%s' "$BODY" | jqr -r .total_count)
    off=$((off + PAGE))
    [ "$off" -lt "$total" ] || break
  done
}

# Is EMAIL approved by ENTRIES (exact entry, or a whole-domain entry that covers it)?
approved_by() {
  local email=$1 entries=$2 domain=${1#*@}
  printf '%s\n' "$entries" | awk '{print $2}' | grep -Fxq -e "$email" -e "*@$domain" -e "@$domain" -e "$domain"
}

# Accounts that hold EMAIL, as "<id> <verified|unverified> <banned>". Stops on a bad reply.
accounts_for() {
  local enc
  enc=$(jq -rn --arg e "$1" '$e | @uri')
  api GET "/users?email_address=$enc"
  ok || die "$E_FAIL" "couldn't look up accounts for $1 (HTTP $RC)"
  printf '%s' "$BODY" | jq -e 'type == "array" and all(.[]; (.id | type) == "string" and .id != "")' >/dev/null \
    || die "$E_FAIL" "the sign-in service sent an unexpected reply for $1"
  printf '%s' "$BODY" | jqr -r --arg e "$1" '.[] |
    "\(.id) \(if any(.email_addresses[]; (.email_address | ascii_downcase) == $e and .verification.status == "verified") then "verified" else "unverified" end) \(.banned)"'
}

set_banned() { # user_id true|false -> verified result
  local action=ban
  [ "$2" = true ] || action=unban
  api POST "/users/$1/$action"
  ok || return 1
  api GET "/users/$1"
  ok && [ "$(printf '%s' "$BODY" | jqr -r .banned)" = "$2" ]
}

cmd_lists() {
  local l ctx
  for l in test live; do
    ctx=$(list_context "$l")
    if [ -n "$(env_get CLERK_SECRET_KEY "$ctx")" ]; then echo "$l=yes"; else echo "$l=no"; fi
  done
}

cmd_list() {
  local entries
  use_list "$1"
  entries=$(all_entries)
  printf '%s\n' "$entries" | awk 'NF {print "approved " $2}'
  echo "count=$(printf '%s\n' "$entries" | awk 'NF' | wc -l | tr -d ' ')"
}

cmd_approve() {
  local list=$1 raw email failed=0 id state banned found
  shift
  use_list "$list"
  for raw in "$@"; do
    email=$(clean_email "$raw")
    if [ -z "$email" ]; then echo "skipped $raw not-an-email"; continue; fi
    api POST /allowlist_identifiers "$(jq -n --arg e "$email" '{identifier:$e, notify:false}')"
    if ok; then
      echo "approved $email"
    elif printf '%s' "$BODY" | grep -qiE 'already|duplicate'; then
      echo "already $email"
    else
      echo "failed $email HTTP-$RC"
      failed=1
      continue # never lift a block when the approval didn't go through
    fi
    # Lift an old block, only on accounts where this address is verified.
    found=$(accounts_for "$email") || { echo "unchecked $email old-block-not-checked"; failed=1; continue; }
    while read -r id state banned; do
      [ -n "$id" ] && [ "$state" = verified ] && [ "$banned" = true ] || continue
      if set_banned "$id" false; then echo "unblocked $email $id"; else echo "failed $email unblock-$id"; failed=1; fi
    done <<<"$found"
  done
  return "$failed"
}

cmd_remove() {
  local raw email list ctx entries entry_id found id state banned failed=0 others
  for list in test live; do
    ctx=$(list_context "$list")
    SK=$(env_get CLERK_SECRET_KEY "$ctx")
    [ -n "$SK" ] || { echo "no_list $list"; continue; }
    entries=$(all_entries)
    for raw in "$@"; do
      email=$(clean_email "$raw")
      if [ -z "$email" ]; then echo "skipped $raw not-an-email"; continue; fi
      # Look the accounts up first: if that fails, nothing has been changed yet.
      found=$(accounts_for "$email")
      entry_id=$(printf '%s\n' "$entries" | awk -v e="$email" '$2 == e {print $1; exit}')
      if [ -n "$entry_id" ]; then
        api DELETE "/allowlist_identifiers/$entry_id"
        ok || { echo "failed $email $list delete-HTTP-$RC"; failed=1; continue; }
      fi
      approved_by "$email" "$entries" && [ -z "$entry_id" ] && echo "covered_by_domain $email $list"
      while read -r id state banned; do
        [ -n "$id" ] || continue
        if ! set_banned "$id" true; then echo "failed $email $list ban-$id"; failed=1; continue; fi
        if [ "$state" = unverified ]; then
          api GET "/users/$id"
          others=$(printf '%s' "$BODY" | jqr -r '[.email_addresses[] | select(.verification.status == "verified") | .email_address] | join(",")')
          echo "also_blocked $list $id ${others:-no-verified-address}"
        fi
      done <<<"$found"
      echo "removed $email $list"
    done
  done
  return "$failed"
}

cmd_lock() {
  local list=$1 on entries off=0 n page id emails e good unapproved=0
  use_list "$list"
  api PATCH /instance/restrictions '{"allowlist":true}'
  ok || die "$E_FAIL" "couldn't switch the approved list on (HTTP $RC; check the sign-in codes)"
  on=$(printf '%s' "$BODY" | jqr -r .allowlist)
  [ "$on" = true ] || die "$E_FAIL" "the approved list didn't switch on; the admin needs to check this app's sign-in plan"
  entries=$(all_entries)
  # Accounts made before the list was on can still sign in: every unblocked account
  # needs a verified address the list approves.
  while :; do
    api GET "/users?limit=$PAGE&offset=$off"
    ok || die "$E_FAIL" "couldn't read the accounts (HTTP $RC)"
    n=$(printf '%s' "$BODY" | jqr -er 'if type == "array" then length else error("bad") end') \
      || die "$E_FAIL" "the sign-in service sent an unexpected reply"
    page=$(printf '%s' "$BODY" | jqr -r '.[] | select(.banned | not) |
      "\(.id) \([.email_addresses[] | select(.verification.status == "verified") | .email_address | ascii_downcase] | join(","))"')
    while read -r id emails; do
      [ -n "$id" ] || continue
      good=no
      for e in $(printf '%s' "$emails" | tr ',' ' '); do
        if approved_by "$e" "$entries"; then good=yes; break; fi
      done
      if [ "$good" = no ]; then echo "unapproved $id ${emails:-no-verified-address}"; unapproved=1; fi
    done <<<"$page"
    [ "$n" -eq "$PAGE" ] || break
    off=$((off + PAGE))
  done
  [ "$unapproved" -eq 0 ] || exit "$E_DECIDE"
  echo "locked=yes"
}

case "${1:-}" in
  lists) cmd_lists ;;
  list) [ $# -eq 2 ] || die "$E_USAGE" "usage: access.sh list <test|live>"; cmd_list "$2" ;;
  approve) [ $# -ge 3 ] || die "$E_USAGE" "usage: access.sh approve <test|live> <email>..."; shift; cmd_approve "$@" ;;
  remove) [ $# -ge 2 ] || die "$E_USAGE" "usage: access.sh remove <email>..."; shift; cmd_remove "$@" ;;
  lock) [ $# -eq 2 ] || die "$E_USAGE" "usage: access.sh lock <test|live>"; cmd_lock "$2" ;;
  *) die "$E_USAGE" "usage: access.sh lists|list|approve|remove|lock …" ;;
esac
