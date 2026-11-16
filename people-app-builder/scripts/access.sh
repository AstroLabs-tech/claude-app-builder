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
#   access.sh block   <account-id>...     block accounts `lock` flagged that have no usable email
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

# ENTRIES ("<id> <identifier>" lines) as a JSON set {identifier: true}.
entry_set() {
  printf '%s\n' "$1" | awk 'NF {print $2}' | jq -R . | jq -sc 'map({(.): true}) | add // {}'
}

# Is EMAIL approved by ENTRIES? Uses the shared APPROVED_JQ rule (lib.sh); the set goes
# in on stdin, never as an argument, so a long list can't hit Windows' command-line limit.
approved_by() {
  entry_set "$2" | jq -e --arg e "$1" "$APPROVED_JQ . as \$set | \$e | approved(\$set)" >/dev/null
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
  local l ctx code
  for l in test live; do
    ctx=$(list_context "$l")
    code=$(env_get CLERK_SECRET_KEY "$ctx") # a failed read stops here; it never reads as "no"
    if [ -n "$code" ]; then echo "$l=yes"; else echo "$l=no"; fi
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
      # A whole-domain entry still lets them in, even after their own entry is gone.
      if approved_by "$email" "$(printf '%s\n' "$entries" | awk -v e="$email" '$2 != e')"; then
        echo "covered_by_domain $email $list"
      fi
      while read -r id state banned; do
        [ -n "$id" ] || continue
        # Whose account is it? Read before blocking; if it can't be read, say "unknown".
        others=""
        if [ "$state" = unverified ]; then
          others=unknown
          api GET "/users/$id"
          if ok; then
            others=$(printf '%s' "$BODY" | jqr -r '[.email_addresses[]? | select(.verification.status == "verified") | .email_address] | join(",")') \
              || others=unknown
          fi
        fi
        if ! set_banned "$id" true; then echo "failed $email $list ban-$id"; failed=1; continue; fi
        [ "$state" != unverified ] || echo "also_blocked $list $id ${others:-no-verified-address}"
      done <<<"$found"
      echo "removed $email $list"
    done
  done
  return "$failed"
}

# Block accounts by id (for `lock` results with no usable email). Both lists' instances
# are tried, since an id belongs to one of them.
cmd_block() {
  local id list ctx done_one failed=0
  for id in "$@"; do
    printf '%s' "$id" | grep -Eq '^user_[A-Za-z0-9]+$' || { echo "skipped $id not-an-account-id"; failed=1; continue; }
    done_one=no
    for list in test live; do
      ctx=$(list_context "$list")
      SK=$(env_get CLERK_SECRET_KEY "$ctx")
      [ -n "$SK" ] || continue
      api GET "/users/$id"
      ok || continue
      if set_banned "$id" true; then echo "blocked $id $list"; done_one=yes; fi
    done
    [ "$done_one" = yes ] || { echo "failed $id not-found-or-not-blocked"; failed=1; }
  done
  return "$failed"
}

cmd_lock() {
  local list=$1 on entries set_json off=0 n
  use_list "$list"
  api PATCH /instance/restrictions '{"allowlist":true}'
  ok || die "$E_FAIL" "couldn't switch the approved list on (HTTP $RC; check the sign-in codes)"
  on=$(printf '%s' "$BODY" | jqr -r .allowlist)
  [ "$on" = true ] || die "$E_FAIL" "the approved list didn't switch on; the admin needs to check this app's sign-in plan"
  entries=$(all_entries)
  set_json=$(entry_set "$entries") || die "$E_FAIL" "couldn't read the approved list"
  # Accounts made before the list was on can still sign in: every unblocked account
  # needs a verified address the list approves (exactly, or by a whole-domain entry).
  # One jq pass per page, so a big list stays quick on Windows.
  local found unapproved=""
  while :; do
    api GET "/users?limit=$PAGE&offset=$off"
    ok || die "$E_FAIL" "couldn't read the accounts (HTTP $RC)"
    n=$(printf '%s' "$BODY" | jqr -er 'if type == "array" then length else error("bad") end') \
      || die "$E_FAIL" "the sign-in service sent an unexpected reply"
    # The set and the page both go in on stdin (no long arguments on Windows).
    found=$(printf '%s\n%s\n' "$set_json" "$BODY" | jqr -rs "$APPROVED_JQ"'
      .[0] as $set | .[1][] | select(.banned | not)
      | [.email_addresses[]? | select(.verification.status == "verified") | .email_address | ascii_downcase] as $v
      | select(all($v[]; approved($set) | not))
      | "unapproved \(.id) \(if ($v | length) == 0 then "no-verified-address" else ($v | join(",")) end)"') \
      || die "$E_FAIL" "the sign-in service sent an unexpected reply"
    if [ -n "$found" ]; then printf '%s\n' "$found"; unapproved=yes; fi
    [ "$n" -eq "$PAGE" ] || break
    off=$((off + PAGE))
  done
  [ -z "$unapproved" ] || exit "$E_DECIDE"
  echo "locked=yes"
}

case "${1:-}" in
  lists) cmd_lists ;;
  list) [ $# -eq 2 ] || die "$E_USAGE" "usage: access.sh list <test|live>"; cmd_list "$2" ;;
  approve) [ $# -ge 3 ] || die "$E_USAGE" "usage: access.sh approve <test|live> <email>..."; shift; cmd_approve "$@" ;;
  remove) [ $# -ge 2 ] || die "$E_USAGE" "usage: access.sh remove <email>..."; shift; cmd_remove "$@" ;;
  lock) [ $# -eq 2 ] || die "$E_USAGE" "usage: access.sh lock <test|live>"; cmd_lock "$2" ;;
  block) [ $# -ge 2 ] || die "$E_USAGE" "usage: access.sh block <account-id>..."; shift; cmd_block "$@" ;;
  *) die "$E_USAGE" "usage: access.sh lists|list|approve|remove|lock|block …" ;;
esac
