#!/usr/bin/env bash
# Tests for codes.sh, run-dev.sh, publish.sh, held-build.sh, wip-check.sh and rollback.sh.

linked() { # JSON state -> state with this folder linked to site-1
  mkdir -p .netlify && echo '{"siteId":"site-1"}' > .netlify/state.json
}
st() { jq "$1" "$FAKE_STATE" > s && mv s "$FAKE_STATE"; }

# ---------------------------------------------------------------- codes.sh
test_codes_store_test_refuses_live_code() {
  setup '{"netlify": {"env": {}}}'; linked
  run codes.sh store-test pk_live_x sk_test_y
  expect_code 1
  expect_err "isn't a test code"
  expect_log_count "env:set" 0
}

test_codes_store_test_stores_both_and_reads_back() {
  setup '{"netlify": {"env": {}}}'; linked
  run codes.sh store-test pk_test_aaa sk_test_bbb
  expect_code 0
  expect_out "test_codes=stored"
  expect_state '.netlify.env["site-1"].CLERK_SECRET_KEY["deploy-preview"]' sk_test_bbb
  check "values never printed" [ -z "$(grep -E 'pk_test_aaa|sk_test_bbb' <<<"$OUT$ERR")" ]
}

test_codes_check_live_missing_exits_3() {
  setup '{"netlify": {"env": {"site-1": {"CLERK_SECRET_KEY": {"dev": "sk_test_1"}}}}}'; linked
  run codes.sh check-live
  expect_code 3
}

test_codes_check_live_ready() {
  setup '{"netlify": {"env": {"site-1": {"CLERK_SECRET_KEY": {"production": "sk_live_1"},
    "NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY": {"production": "pk_live_1"}}}}}'; linked
  run codes.sh check-live
  expect_code 0
  expect_out "live_codes=ready"
}

# ---------------------------------------------------------------- run-dev.sh
test_run_dev_without_codes_does_not_start() {
  setup '{"netlify": {"env": {}}}'; linked
  run run-dev.sh
  expect_code 3
  expect_log_count "npm run dev" 0
}

test_run_dev_passes_codes_in_environment() {
  setup '{"netlify": {"env": {"site-1": {"CLERK_SECRET_KEY": {"dev": "sk_test_1"},
    "NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY": {"dev": "pk_test_1"}}}}}'; linked
  run run-dev.sh
  expect_code 0
  expect_out "Local: http://localhost:3000 pk=pk_test_ sk=set"
}

# ---------------------------------------------------------------- publish.sh
pr_state() { # checks-json [extra]
  jq -n --argjson checks "$1" '{github: {prs: {"7": {state: "OPEN", headRefName: "preview", baseRefName: "main",
    headRefOid: "abc", checks: $checks, merge_sha: "m123"}}},
    netlify: {sites: {"site-1": {id: "site-1", ssl_url: "https://reviews.netlify.app", published_deploy: {id: "old"}}}}}'
}

test_publish_check_ok_prints_head() {
  setup "$(pr_state '[{"state":"SUCCESS"}]')"
  run publish.sh check 7
  expect_code 0
  expect_out "head=abc"
}

test_publish_check_pending_exits_6() {
  setup "$(pr_state '[{"state":"PENDING"}]')"
  run publish.sh check 7
  expect_code 6
}

test_publish_check_failing_exits_1() {
  setup "$(pr_state '[{"state":"FAILURE"}]')"
  run publish.sh check 7
  expect_code 1
  expect_err "didn't pass"
}

test_publish_check_head_moved_exits_7() {
  setup "$(pr_state '[{"state":"SUCCESS"}]')"
  st '.github.prs["7"].move_head_after_checks = "def"'
  run publish.sh check 7
  expect_code 7
}

test_publish_merge_refuses_unchecked_head() {
  setup "$(pr_state '[{"state":"SUCCESS"}]')"
  st '.github.prs["7"].headRefOid = "def"'
  run publish.sh merge 7 abc
  expect_code 7
  expect_state '.github.prs["7"].state' OPEN
}

test_publish_merge_ok() {
  setup "$(pr_state '[{"state":"SUCCESS"}]')"
  run publish.sh merge 7 abc
  expect_code 0
  expect_out "merge=m123"
}

status_state() { # deploy-state published-id
  jq -n --arg s "$1" --arg p "$2" '{netlify: {
    sites: {"site-1": {id: "site-1", ssl_url: "https://reviews.netlify.app", published_deploy: {id: $p}}},
    deploys: {"site-1": [{id: "d2", context: "production", state: $s, commit_ref: "m123", error_message: "Build script returned non-zero exit code"}]},
    builds: {"site-1": []}}}'
}

test_publish_status_live() {
  setup "$(status_state ready d2)"; linked
  run publish.sh status m123
  expect_code 0
  expect_out "live=https://reviews.netlify.app"
}

test_publish_status_ready_but_paused_exits_8() {
  setup "$(status_state ready d1)"; linked
  run publish.sh status m123
  expect_code 8
}

test_publish_status_building_exits_6() {
  setup "$(status_state building d1)"; linked
  run publish.sh status m123
  expect_code 6
}

test_publish_status_error_exits_1_with_reason() {
  setup "$(status_state error d1)"; linked
  run publish.sh status m123
  expect_code 1
  expect_err "non-zero exit code"
}

test_publish_status_held_exits_9() {
  setup "$(status_state ready d1)"; linked
  st '.netlify.deploys["site-1"] = [] | .netlify.builds["site-1"] = [{sha: "m123", deploy_state: "pending_review"}]'
  run publish.sh status m123
  expect_code 9
}

# ---------------------------------------------------------------- held-build.sh
test_held_build_detects_pending_review() {
  setup '{"netlify": {"builds": {"site-1": [{"sha": "pull/3/head", "deploy_state": "pending_review"}]}}}'; linked
  run held-build.sh 3
  expect_code 9
  expect_out "state=pending_review"
}

test_held_build_none() {
  setup '{"netlify": {"builds": {"site-1": []}}}'; linked
  run held-build.sh 3
  expect_code 0
  expect_out "state=none"
}

# ---------------------------------------------------------------- wip-check.sh
wip_state() { # authors-json
  jq -n --argjson a "$1" '{github: {prs: {"4": {number: 4, head: "preview", state: "OPEN",
    commits: [{authors: $a}]}}}}'
}

test_wip_ignores_claude_and_own_address() {
  setup "$(wip_state '[{"email":"Ribal@AstroLabs.com"},{"email":"noreply@anthropic.com"}]')"
  git init -q . && git config user.email ribal@astrolabs.com
  run wip-check.sh
  expect_code 0
  expect_out "pr=4"
}

test_wip_flags_someone_else() {
  setup "$(wip_state '[{"email":"nauf@astrolabs.com"}]')"
  git init -q . && git config user.email ribal@astrolabs.com
  run wip-check.sh
  expect_code 7
  expect_out "other=nauf@astrolabs.com"
}

# ---------------------------------------------------------------- rollback.sh
rb_state() { # deploys-json published
  jq -n --argjson d "$1" --arg p "$2" '{netlify: {sites: {"site-1": {id: "site-1", published_deploy: {id: $p}}}, deploys: {"site-1": $d}}}'
}
dep() { # id context state published commit
  jq -n --arg i "$1" --arg c "$2" --arg s "$3" --arg p "$4" --arg r "$5" \
    '{id:$i, context:$c, state:$s, published_at:(if $p == "" then null else $p end), commit_ref:$r}'
}

test_rollback_restores_previous_published_version() {
  setup "$(rb_state "[$(dep d3 production ready t3 c3), $(dep pv deploy-preview ready '' cp), $(dep d2 production ready '' c2), $(dep d1 production ready t1 c1)]" d3)"; linked
  run rollback.sh
  expect_code 0
  expect_out "restored=d1"
  expect_out "good_commit=c1"
  expect_state '.netlify.sites["site-1"].published_deploy.id' d1
}

test_rollback_waits_for_building_live_version() {
  setup "$(rb_state "[$(dep d4 production building '' c4), $(dep d3 production ready t3 c3), $(dep d1 production ready t1 c1)]" d3)"; linked
  run rollback.sh
  expect_code 6
  expect_log_count "restoreSiteDeploy" 0
}

test_rollback_current_not_found_does_not_guess() {
  setup "$(rb_state "[$(dep d3 production ready t3 c3), $(dep d1 production ready t1 c1)]" zz)"; linked
  run rollback.sh
  expect_code 1
  expect_err "couldn't tell which version is live"
}

test_rollback_nothing_earlier() {
  setup "$(rb_state "[$(dep d1 production ready t1 c1)]" d1)"; linked
  run rollback.sh
  expect_code 1
  expect_err "no earlier version"
}

test_rollback_previous_on_second_page() {
  local d i
  d="[$(dep d9 production ready t9 c9)"
  for i in $(seq 1 99); do d="$d, $(dep "p$i" deploy-preview ready '' x)"; done
  d="$d, $(dep d8 production ready t8 c8)]"
  setup "$(rb_state "$d" d9)"; linked
  run rollback.sh
  expect_code 0
  expect_out "restored=d8"
}

test_rollback_fails_if_restore_did_not_stick() {
  setup "$(rb_state "[$(dep d3 production ready t3 c3), $(dep d1 production ready t1 c1)]" d3)"; linked
  st '.netlify.restore_noop = true'
  run rollback.sh
  expect_code 1
  expect_err "didn't go live"
}
