#!/usr/bin/env bash
# Shared helpers for the people-app-builder scripts: strict mode, exit codes, plain stop
# messages, Windows-safe jq, and reads of the app's settings and sign-in codes.
# Works on macOS's bash 3.2 and Git Bash 5. Sourced by every script, never run directly.

set -euo pipefail

# Exit codes the skills translate into plain words:
#   1 something failed (the message says what)    2 the script was called wrongly
#   3 sign-in codes, or the list they open, don't exist yet
#   4 the builder has to decide something first   5 the Netlify site name is taken
#   6 Netlify is still busy; try again shortly
#   7 changes clash, or someone else's work is in the way
#   8 the new version is ready but isn't the live one (publishing paused, or an older
#     version was put back)
#   9 Netlify is holding a build until an admin approves this person
# shellcheck disable=SC2034  # used by the scripts that source this file
readonly E_FAIL=1 E_USAGE=2 E_NOT_SET_UP=3 E_DECIDE=4 E_TAKEN=5 E_WAIT=6 E_CLASH=7 E_PAUSED=8 E_HELD=9

die() {
  local code=$1
  shift
  printf 'STOP: %s\n' "$*" >&2
  exit "$code"
}

# jq on Windows ends every line with \r; strip it so values compare and loop cleanly.
jqr() {
  jq "$@" | tr -d '\r'
}

need() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null 2>&1 || die "$E_FAIL" "$tool isn't installed here — run set-up-my-computer first"
  done
}

lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

# The Netlify site this folder is linked to.
site_id() {
  local id
  [ -f .netlify/state.json ] || die "$E_FAIL" "this folder isn't connected to its Netlify site"
  id=$(jqr -er '.siteId' .netlify/state.json) || die "$E_FAIL" "this folder's Netlify link is unreadable"
  printf '%s' "$id"
}

# One setting from the app's Netlify site for a context, or empty when it isn't set.
# Plain `netlify env:get` prints a "No value set…" sentence for a missing value, so
# always read the --json form. A failed read stops; it never counts as "not set".
env_get() {
  local name=$1 ctx=$2 out
  out=$(netlify env:get "$name" --context "$ctx" --json 2>/dev/null) \
    || die "$E_FAIL" "couldn't read this app's settings from Netlify"
  printf '%s' "$out" | jqr -er --arg k "$name" '.[$k] // ""' \
    || die "$E_FAIL" "couldn't read this app's settings from Netlify"
}

# State of the first Netlify build for a commit or "pull/<n>/head", or "none". Held builds
# (pending_review) only show in the builds list, never in the deploys list.
build_state() {
  local sid
  sid=$(site_id)
  netlify api listSiteBuilds --data "$(jq -n --arg s "$sid" '{site_id:$s}')" \
    | jqr -r --arg c "$1" '[.[] | select(.sha == $c)][0].deploy_state // "none"' \
    || die "$E_FAIL" "couldn't read the app's builds"
}

# The one rule for "is this address approved?": an exact entry, or a whole-domain entry
# (*@d, @d or d). Used by access.sh for both removing and locking.
# shellcheck disable=SC2034
APPROVED_JQ='def approved($set): (split("@")[1]) as $d | ($set[.] or $set["*@" + $d] or $set["@" + $d] or $set[$d]);'

# Explain a failed git call against GitHub and stop: network trouble or a temporary
# GitHub error is worth retrying (6); a refusal (permissions, rules, missing repo) or
# anything unknown is not (1). Network patterns are checked first.
git_failed() {
  local what=$1 out=$2
  if printf '%s' "$out" | grep -qiE 'could not resolve (host|proxy)|connection (was )?(refused|reset|timed out)|timed out|network is unreachable|failed to connect|tunnel failed|returned error: (5[0-9][0-9]|429|408)|early eof|remote end hung up'; then
    die "$E_WAIT" "couldn't reach GitHub to $what; try again in a moment"
  fi
  if printf '%s' "$out" | grep -qiE 'returned error: 4|denied|permission|protected|rejected|not found|does not appear to be'; then
    die "$E_FAIL" "GitHub refused to $what: $(printf '%s' "$out" | head -1)"
  fi
  die "$E_FAIL" "couldn't $what: $(printf '%s' "$out" | head -1)"
}

# "test" -> dev, "live" -> production.
list_context() {
  case "$1" in
    test) printf 'dev' ;;
    live) printf 'production' ;;
    *) die "$E_USAGE" "list must be 'test' or 'live', not '$1'" ;;
  esac
}
