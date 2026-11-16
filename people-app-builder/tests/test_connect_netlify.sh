#!/usr/bin/env bash
# Tests for scripts/connect-netlify.sh (sourced by tests/run.sh).

BASE='{
 "netlify": {"accounts": [{"name": "Ops", "slug": "ops"}, {"name": "AstroLabs People", "slug": "ap"}]},
 "github": {"token": "gho_x", "repos": {"AstroLabs-people/reviews": {"id": 42}}}
}'

test_connects_new_site() {
  setup "$BASE"
  run connect-netlify.sh reviews reviews-app
  expect_code 0
  expect_out "status=connected"
  expect_out "first_build=started"
  expect_state '.netlify.sites["site-1"].account_slug' ap
  expect_state '.netlify.sites["site-1"].build_settings.repo_path' AstroLabs-people/reviews
  expect_state '.netlify.sites["site-1"].plugins[0].package' @netlify/plugin-nextjs
  expect_state '.github.repos["AstroLabs-people/reviews"].keys | length' 1
  expect_state '.github.repos["AstroLabs-people/reviews"].hooks[0].events | join(",")' push,pull_request,delete
  expect_state '.netlify.hooks["site-1"] | map(.event) | sort | join(",")' deploy_building,deploy_created,deploy_failed
  check "folder linked" grep -q site-1 .netlify/state.json
}

test_name_taken_exits_5_and_creates_nothing() {
  setup "$(jq '.netlify.taken_names = ["reviews"]' <<<"$BASE")"
  run connect-netlify.sh reviews reviews
  expect_code 5
  expect_err "is taken"
  expect_state '.netlify.sites // {} | length' 0
  check "not linked" [ ! -f .netlify/state.json ]
}

test_not_on_people_team() {
  setup '{"netlify": {"accounts": [{"name": "Ops", "slug": "ops"}]}}'
  run connect-netlify.sh reviews reviews
  expect_code 1
  expect_err "isn't on the AstroLabs People team"
}

test_rerun_after_webhook_failure_reuses_site_and_finishes() {
  setup "$(jq '.github.fail = {"hooks": "HTTP 500"}' <<<"$BASE")"
  run connect-netlify.sh reviews reviews
  expect_code 1
  expect_err "couldn't read AstroLabs-people/reviews's webhooks"
  jq 'del(.github.fail)' "$FAKE_STATE" > s && mv s "$FAKE_STATE"
  run connect-netlify.sh reviews reviews
  expect_code 0
  expect_state '.netlify.sites | length' 1
  expect_state '.netlify.deploy_keys | length' 1
  expect_state '.github.repos["AstroLabs-people/reviews"].keys | length' 1
  expect_state '.github.repos["AstroLabs-people/reviews"].hooks | length' 1
  expect_log_count "createSiteInTeam" 1
}

test_rerun_when_done_changes_nothing() {
  setup "$BASE"
  run connect-netlify.sh reviews reviews
  run connect-netlify.sh reviews reviews
  expect_code 0
  check "no new first build" [ -z "$(grep first_build <<<"$OUT")" ]
  expect_log_count "createDeployKey" 1
  expect_log_count "createHookBySiteId" 3
  expect_state '.github.repos["AstroLabs-people/reviews"].hooks | length' 1
}

test_adds_missing_runtime_to_existing_site() {
  setup "$BASE"
  run connect-netlify.sh reviews reviews
  jq '.netlify.sites["site-1"].plugins = []' "$FAKE_STATE" > s && mv s "$FAKE_STATE"
  run connect-netlify.sh reviews reviews
  expect_code 0
  expect_state '.netlify.sites["site-1"].plugins[0].package' @netlify/plugin-nextjs
}

test_refuses_site_outside_people_team() {
  setup "$(jq '.netlify.sites = {"site-9": {"id": "site-9", "name": "ops-app", "account_slug": "ops"}}' <<<"$BASE")"
  mkdir -p .netlify && echo '{"siteId":"site-9"}' > .netlify/state.json
  run connect-netlify.sh reviews reviews
  expect_code 1
  expect_err "outside the AstroLabs People team"
}

test_deploy_key_failure_stops_before_attaching() {
  setup "$(jq '.github.fail = {"keys": "HTTP 403"}' <<<"$BASE")"
  run connect-netlify.sh reviews reviews
  expect_code 1
  expect_err "couldn't add the deploy key"
  expect_log_count "updateSite" 0
}

test_app_status_hooks_count_as_present() {
  setup "$BASE"
  run connect-netlify.sh reviews reviews
  jq '.netlify.hooks["site-1"] = [{"type": "github_app_commit_status", "event": "deploy_created"},
      {"type": "github_app_commit_status", "event": "deploy_failed"},
      {"type": "github_app_commit_status", "event": "deploy_building"}]' "$FAKE_STATE" > s && mv s "$FAKE_STATE"
  : > "$FAKE_LOG"
  run connect-netlify.sh reviews reviews
  expect_code 0
  expect_log_count "createHookBySiteId" 0
}

test_rerun_after_link_failure_reuses_the_site() {
  setup "$(jq '.netlify.link_fail_once = true' <<<"$BASE")"
  run connect-netlify.sh reviews reviews
  expect_code 1
  expect_err "couldn't link this folder"
  run connect-netlify.sh reviews reviews
  expect_code 0
  expect_state '.netlify.sites | length' 1
  expect_log_count "createSiteInTeam" 1
}

test_name_used_by_another_team_is_still_taken() {
  setup "$(jq '.netlify.sites = {"site-9": {"id": "site-9", "name": "reviews", "account_slug": "ops", "build_settings": {}}}' <<<"$BASE")"
  run connect-netlify.sh reviews reviews
  expect_code 5
}
