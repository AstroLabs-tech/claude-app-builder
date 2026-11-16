#!/usr/bin/env bash
# Tests for scripts/access.sh (sourced by tests/run.sh).

# A linked app folder (site-1) with test codes; live codes only when $1 = live.
access_state() {
  local live=${1:-}
  jq -n --arg live "$live" '{
    netlify: {env: {"site-1": {CLERK_SECRET_KEY: ({dev: "sk_test_1"} + (if $live == "live" then {production: "sk_live_1"} else {} end))}}},
    clerk: {
      sk_test_1: {allowlist: [{id: "alw_1", identifier: "ribal@astrolabs.com"}], users: [], restrictions: {allowlist: false}},
      sk_live_1: {allowlist: [], users: [], restrictions: {allowlist: false}}
    }
  }'
}
link_here() {
  mkdir -p .netlify && echo '{"siteId":"site-1"}' > .netlify/state.json
}
user() { # id email status banned
  jq -n --arg id "$1" --arg e "$2" --arg s "$3" --argjson b "$4" \
    '{id:$id, banned:$b, email_addresses:[{email_address:$e, verification:{status:$s}}]}'
}
add_user() { # instance user-json
  jq --arg k "$1" --argjson u "$2" '.clerk[$k].users += [$u]' "$FAKE_STATE" > s && mv s "$FAKE_STATE"
}

test_lists_reports_which_lists_exist() {
  setup "$(access_state)"; link_here
  run access.sh lists
  expect_code 0
  expect_out "test=yes"
  expect_out "live=no"
}

test_live_list_not_set_up_exits_3() {
  setup "$(access_state)"; link_here
  run access.sh list live
  expect_code 3
  expect_err "isn't set up yet"
}

test_unlinked_folder_fails_instead_of_no_list() {
  setup "$(access_state)"
  run access.sh list test
  expect_code 1
  expect_err "couldn't read this app's settings"
}

test_list_pages_past_500() {
  setup "$(access_state)"; link_here
  jq '.clerk.sk_test_1.allowlist = [range(0; 1203) | {id: "alw_\(.)", identifier: "p\(.)@astrolabs.com"}]' "$FAKE_STATE" > s && mv s "$FAKE_STATE"
  run access.sh list test
  expect_code 0
  expect_out "count=1203"
  expect_out "approved p1202@astrolabs.com"
}

test_approve_cleans_emails_and_reports_already() {
  setup "$(access_state)"; link_here
  run access.sh approve test "  Sara@AstroLabs.com " ribal@astrolabs.com not-an-email
  expect_code 0
  expect_out "approved sara@astrolabs.com"
  expect_out "already ribal@astrolabs.com"
  expect_out "skipped not-an-email not-an-email"
  expect_state '.clerk.sk_test_1.allowlist | map(.identifier) | sort | join(",")' "ribal@astrolabs.com,sara@astrolabs.com"
}

test_approve_unblocks_only_verified_account() {
  setup "$(access_state)"; link_here
  add_user sk_test_1 "$(user u_sara sara@astrolabs.com verified true)"
  add_user sk_test_1 "$(user u_other sara@astrolabs.com unverified true)"
  run access.sh approve test sara@astrolabs.com
  expect_code 0
  expect_out "unblocked sara@astrolabs.com u_sara"
  expect_state '.clerk.sk_test_1.users[] | select(.id == "u_sara") | .banned' false
  expect_state '.clerk.sk_test_1.users[] | select(.id == "u_other") | .banned' true
}

test_approve_failure_never_unblocks() {
  setup "$(access_state)"; link_here
  add_user sk_test_1 "$(user u_sara sara@astrolabs.com verified true)"
  jq '.clerk.sk_test_1.fail = {"/allowlist_identifiers": 500}' "$FAKE_STATE" > s && mv s "$FAKE_STATE"
  run access.sh approve test sara@astrolabs.com
  expect_code 1
  expect_out "failed sara@astrolabs.com HTTP-500"
  expect_state '.clerk.sk_test_1.users[0].banned' true
}

test_approve_reports_unchecked_block_when_lookup_fails() {
  setup "$(access_state)"; link_here
  jq '.clerk.sk_test_1.fail = {"/users": 500}' "$FAKE_STATE" > s && mv s "$FAKE_STATE"
  run access.sh approve test sara@astrolabs.com
  expect_code 1
  expect_out "approved sara@astrolabs.com"
  expect_out "unchecked sara@astrolabs.com old-block-not-checked"
}

test_secret_never_on_command_line() {
  setup "$(access_state)"; link_here
  run access.sh list test
  expect_code 0
  check "fake would exit 99 if the key were in curl's arguments" [ "$CODE" != 99 ]
}

test_remove_deletes_and_blocks_on_both_lists() {
  setup "$(access_state live)"; link_here
  jq '.clerk.sk_live_1.allowlist = [{id: "alw_9", identifier: "omar@astrolabs.com"}]
      | .clerk.sk_test_1.allowlist += [{id: "alw_8", identifier: "omar@astrolabs.com"}]' "$FAKE_STATE" > s && mv s "$FAKE_STATE"
  add_user sk_live_1 "$(user u_omar omar@astrolabs.com verified false)"
  run access.sh remove Omar@AstroLabs.com
  expect_code 0
  expect_out "removed omar@astrolabs.com test"
  expect_out "removed omar@astrolabs.com live"
  expect_state '.clerk.sk_live_1.allowlist | length' 0
  expect_state '[.clerk.sk_test_1.allowlist[] | select(.identifier == "omar@astrolabs.com")] | length' 0
  expect_state '.clerk.sk_live_1.users[0].banned' true
}

test_remove_reports_other_persons_account_it_blocked() {
  setup "$(access_state)"; link_here
  add_user sk_test_1 "$(jq -n '{id: "u_alice", banned: false, email_addresses: [
      {email_address: "alice@astrolabs.com", verification: {status: "verified"}},
      {email_address: "omar@astrolabs.com", verification: {status: "unverified"}}]}')"
  run access.sh remove omar@astrolabs.com
  expect_code 0
  expect_out "also_blocked test u_alice alice@astrolabs.com"
}

test_remove_stops_before_deleting_when_lookup_fails() {
  setup "$(access_state)"; link_here
  jq '.clerk.sk_test_1.allowlist += [{id: "alw_8", identifier: "omar@astrolabs.com"}]
      | .clerk.sk_test_1.fail = {"/users": 500}' "$FAKE_STATE" > s && mv s "$FAKE_STATE"
  run access.sh remove omar@astrolabs.com
  expect_code 1
  expect_err "couldn't look up accounts for omar@astrolabs.com"
  expect_state '[.clerk.sk_test_1.allowlist[] | select(.identifier == "omar@astrolabs.com")] | length' 1
  expect_log_count "curl DELETE" 0
}

test_remove_flags_domain_entry() {
  setup "$(access_state)"; link_here
  jq '.clerk.sk_test_1.allowlist = [{id: "alw_d", identifier: "*@astrolabs.com"}]' "$FAKE_STATE" > s && mv s "$FAKE_STATE"
  run access.sh remove omar@astrolabs.com
  expect_code 0
  expect_out "covered_by_domain omar@astrolabs.com test"
}

test_lock_switches_on_and_passes_clean_instance() {
  setup "$(access_state)"; link_here
  add_user sk_test_1 "$(user u_r ribal@astrolabs.com verified false)"
  run access.sh lock test
  expect_code 0
  expect_out "locked=yes"
  expect_state '.clerk.sk_test_1.restrictions.allowlist' true
}

test_lock_flags_unapproved_and_unverified_accounts() {
  setup "$(access_state)"; link_here
  add_user sk_test_1 "$(user u_r ribal@astrolabs.com verified false)"
  add_user sk_test_1 "$(user u_x stranger@gmail.com verified false)"
  add_user sk_test_1 "$(user u_y ribal@astrolabs.com unverified false)"
  add_user sk_test_1 "$(user u_z banned@gmail.com verified true)"
  run access.sh lock test
  expect_code 4
  expect_out "unapproved u_x stranger@gmail.com"
  expect_out "unapproved u_y no-verified-address"
  check "banned account isn't flagged" [ -z "$(grep u_z <<<"$OUT")" ]
}

test_lock_accepts_domain_entry() {
  setup "$(access_state)"; link_here
  jq '.clerk.sk_test_1.allowlist = [{id: "alw_d", identifier: "*@astrolabs.com"}]' "$FAKE_STATE" > s && mv s "$FAKE_STATE"
  add_user sk_test_1 "$(user u_a anyone@astrolabs.com verified false)"
  run access.sh lock test
  expect_code 0
}

test_lock_pages_accounts_on_raw_page_size() {
  setup "$(access_state)"; link_here
  # 500 banned accounts fill page one; the unapproved one is on page two
  jq '.clerk.sk_test_1.users = ([range(0; 500) | {id: "u\(.)", banned: true, email_addresses: []}]
      + [{id: "u_late", banned: false, email_addresses: [{email_address: "late@gmail.com", verification: {status: "verified"}}]}])' \
    "$FAKE_STATE" > s && mv s "$FAKE_STATE"
  run access.sh lock test
  expect_code 4
  expect_out "unapproved u_late late@gmail.com"
}

test_lock_fails_when_switch_does_not_stick() {
  setup "$(access_state)"; link_here
  jq '.clerk.sk_test_1.allowlist_locked_off = true' "$FAKE_STATE" > s && mv s "$FAKE_STATE"
  run access.sh lock test
  expect_code 1
  expect_err "didn't switch on"
}

test_lists_failed_read_is_an_error_not_no() {
  setup "$(access_state)"
  run access.sh lists
  expect_code 1
  check "no 'no' printed" [ -z "$(grep '=no' <<<"$OUT")" ]
}

test_remove_flags_domain_even_with_own_entry() {
  setup "$(access_state)"; link_here
  jq '.clerk.sk_test_1.allowlist = [{id: "alw_o", identifier: "omar@astrolabs.com"}, {id: "alw_d", identifier: "*@astrolabs.com"}]' "$FAKE_STATE" > s && mv s "$FAKE_STATE"
  run access.sh remove omar@astrolabs.com
  expect_code 0
  expect_out "covered_by_domain omar@astrolabs.com test"
  expect_out "removed omar@astrolabs.com test"
}

test_remove_keeps_going_when_other_account_cannot_be_read() {
  setup "$(access_state)"; link_here
  add_user sk_test_1 "$(jq -n '{id: "u_alice", banned: false, email_addresses: [{email_address: "omar@astrolabs.com", verification: {status: "unverified"}}]}')"
  jq '.clerk.sk_test_1.fail = {"/users/u_alice": 500}' "$FAKE_STATE" > s && mv s "$FAKE_STATE"
  run access.sh remove omar@astrolabs.com
  # the ban itself also goes through /users/u_alice/ban, which the fake still serves
  check "finished the removal" grep -q "removed omar@astrolabs.com test" <<<"$OUT"
}

test_block_by_account_id() {
  setup "$(access_state)"; link_here
  add_user sk_test_1 "$(jq -n '{id: "u_x", banned: false, email_addresses: []}')"
  run access.sh block u_x
  expect_code 0
  expect_out "blocked u_x test"
  expect_state '.clerk.sk_test_1.users[0].banned' true
}

test_block_unknown_id_fails() {
  setup "$(access_state)"; link_here
  run access.sh block u_nope
  expect_code 1
  expect_out "failed u_nope"
}
