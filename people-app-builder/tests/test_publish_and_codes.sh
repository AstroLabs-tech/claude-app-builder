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
NETLIFY_OK='{"__typename": "StatusContext", "context": "netlify/reviews/deploy-preview", "state": "SUCCESS"}'
ACTIONS_OK='{"__typename": "CheckRun", "name": "checks", "status": "COMPLETED", "conclusion": "SUCCESS"}'
APP_NEUTRAL='{"__typename": "CheckRun", "name": "Header rules - reviews", "status": "COMPLETED", "conclusion": "NEUTRAL"}'
ACTIONS_RUNNING='{"__typename": "CheckRun", "name": "checks", "status": "IN_PROGRESS", "conclusion": null}'
ACTIONS_FAILED='{"__typename": "CheckRun", "name": "checks", "status": "COMPLETED", "conclusion": "FAILURE"}'
NETLIFY_PENDING='{"__typename": "StatusContext", "context": "netlify/reviews/deploy-preview", "state": "PENDING"}'
pr_state() { # rollup-json
  jq -n --argjson r "$1" '{github: {prs: {"7": {state: "OPEN", headRefName: "preview", baseRefName: "main",
    headRefOid: "abc", mergeCommit: null, statusCheckRollup: $r, merge_sha: "m123"}}},
    netlify: {sites: {"site-1": {id: "site-1", ssl_url: "https://reviews.netlify.app", published_deploy: {id: "old"}}},
      builds: {"site-1": []}}}'
}

test_publish_check_ok_prints_head() {
  setup "$(pr_state "[$ACTIONS_OK, $APP_NEUTRAL, $NETLIFY_OK]")"
  run publish.sh check 7
  expect_code 0
  expect_out "head=abc"
}

test_publish_check_pending_exits_6() {
  setup "$(pr_state "[$NETLIFY_OK, $ACTIONS_RUNNING]")"
  run publish.sh check 7
  expect_code 6
}

test_publish_check_failing_exits_1() {
  setup "$(pr_state "[$NETLIFY_OK, $ACTIONS_FAILED]")"
  run publish.sh check 7
  expect_code 1
  expect_err "didn't pass"
}

test_publish_check_needs_netlify_even_when_actions_pass() {
  setup "$(pr_state "[$ACTIONS_OK]")"; linked
  run publish.sh check 7
  expect_code 6
  expect_err "Netlify's build are still running"
}

test_publish_check_pending_netlify_but_held_exits_9() {
  setup "$(pr_state "[$ACTIONS_OK, $NETLIFY_PENDING]")"; linked
  st '.netlify.builds["site-1"] = [{sha: "pull/7/head", deploy_state: "pending_review"}]'
  run publish.sh check 7
  expect_code 9
}

test_publish_check_held_preview_exits_9() {
  setup "$(pr_state "[$ACTIONS_OK]")"; linked
  st '.netlify.builds["site-1"] = [{sha: "pull/7/head", deploy_state: "pending_review"}]'
  run publish.sh check 7
  expect_code 9
}

test_publish_check_failed_netlify_status_exits_1() {
  setup "$(pr_state "[$ACTIONS_OK, {\"__typename\": \"StatusContext\", \"context\": \"netlify/reviews/deploy-preview\", \"state\": \"FAILURE\"}]")"
  run publish.sh check 7
  expect_code 1
}

test_publish_check_wrong_branches_refused() {
  setup "$(pr_state "[$NETLIFY_OK]")"
  st '.github.prs["7"].headRefName = "feature"'
  run publish.sh check 7
  expect_code 1
  expect_err "isn't the preview going into main"
}

test_publish_merge_refuses_unchecked_head() {
  setup "$(pr_state "[$NETLIFY_OK]")"
  st '.github.prs["7"].headRefOid = "def"'
  run publish.sh merge 7 abc
  expect_code 7
  expect_state '.github.prs["7"].state' OPEN
}

test_publish_merge_ok() {
  setup "$(pr_state "[$NETLIFY_OK]")"
  run publish.sh merge 7 abc
  expect_code 0
  expect_out "merged=yes"
  expect_state '.github.prs["7"].mergeCommit.oid' m123
}

status_state() { # deploy-state published-id
  jq -n --arg s "$1" --arg p "$2" '{
    github: {prs: {"7": {state: "MERGED", headRefName: "preview", baseRefName: "main", headRefOid: "abc", mergeCommit: {oid: "m123"}}}},
    netlify: {
    sites: {"site-1": {id: "site-1", ssl_url: "https://reviews.netlify.app", published_deploy: {id: $p}}},
    deploys: {"site-1": [{id: "d2", context: "production", state: $s, commit_ref: "m123", error_message: "Build script returned non-zero exit code"}]},
    builds: {"site-1": []}}}'
}

test_publish_status_live() {
  setup "$(status_state ready d2)"; linked
  run publish.sh status 7
  expect_code 0
  expect_out "live=https://reviews.netlify.app"
}

test_publish_status_unmerged_pr_fails_instead_of_waiting() {
  setup "$(status_state ready d2)"; linked
  st '.github.prs["7"].state = "CLOSED" | .github.prs["7"].mergeCommit = null'
  run publish.sh status 7
  expect_code 1
  expect_err "hasn't been published"
}

test_publish_status_merge_not_recorded_yet_exits_6() {
  setup "$(status_state ready d2)"; linked
  st '.github.prs["7"].mergeCommit = null'
  run publish.sh status 7
  expect_code 6
  expect_err "hasn't finished recording"
}

test_publish_status_ready_but_paused_exits_8() {
  setup "$(status_state ready d1)"; linked
  run publish.sh status 7
  expect_code 8
}

test_publish_status_building_exits_6() {
  setup "$(status_state building d1)"; linked
  run publish.sh status 7
  expect_code 6
}

test_publish_status_error_exits_1_with_reason() {
  setup "$(status_state error d1)"; linked
  run publish.sh status 7
  expect_code 1
  expect_err "non-zero exit code"
}

test_publish_status_held_exits_9() {
  setup "$(status_state ready d1)"; linked
  st '.netlify.deploys["site-1"] = [] | .netlify.builds["site-1"] = [{sha: "m123", deploy_state: "pending_review"}]'
  run publish.sh status 7
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

test_wip_bad_reply_is_an_error_not_nobody() {
  setup '{"github": {"prs": {"4": {"number": 4, "head": "preview", "state": "OPEN", "commits": [{"authors": null}]}}}}'
  git init -q . && git config user.email ribal@astrolabs.com
  run wip-check.sh
  expect_code 1
  expect_err "couldn't read who made"
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
