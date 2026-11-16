#!/usr/bin/env bash
# Runs the people-app-builder script tests against fake netlify, gh and curl (tests/fakes).
# Usage: bash people-app-builder/tests/run.sh [test-file ...]   (default: every tests/test_*.sh)

set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPTS=$(cd "$HERE/../scripts" && pwd)
FAKES=$(mktemp -d)
PY=$(command -v python3 || command -v python) || { echo "tests need python3" >&2; exit 1; }
# Small wrappers rather than symlinks, so the fakes also work on Windows Git Bash.
for cli in netlify gh curl npm; do
  printf '#!/usr/bin/env bash\nexec "%s" "%s" %s "$@"\n' "$PY" "$HERE/fakes/fakecli.py" "$cli" > "$FAKES/$cli"
  chmod +x "$FAKES/$cli"
done
export SCRIPTS FAKES

PASS=0
FAIL=0
FAILED=()

# Each test gets a fresh temp folder (its cwd) and state file; $1 = JSON state.
setup() {
  WORK=$(mktemp -d)
  export FAKE_STATE="$WORK/.fake-state.json" FAKE_LOG="$WORK/.fake-log"
  if [ -n "${1:-}" ]; then printf '%s' "$1"; else printf '{}'; fi > "$FAKE_STATE"
  : > "$FAKE_LOG"
  cd "$WORK" || exit 1
}

# run <script> [args...]: runs it with the fakes first on PATH; sets OUT, ERR, CODE.
run() {
  local script=$1
  shift
  CODE=0
  OUT=$(PATH="$FAKES:$PATH" bash "$SCRIPTS/$script" "$@" 2>"$WORK/.err") || CODE=$?
  ERR=$(cat "$WORK/.err")
}

state() { jq -r "$1" "$FAKE_STATE"; }

# Every failed check is recorded, so a test fails on ANY failed check, not just its
# last one (bash ignores errexit inside conditional contexts, so we don't rely on it).
check() {
  local what=$1
  shift
  if "$@"; then return 0; fi
  printf '    FAILED: %s\n      code=%s\n      out=%s\n      err=%s\n' "$what" "${CODE:-}" "${OUT:-}" "${ERR:-}"
  echo "$what" >> "$FAILURES"
  return 0
}

expect_code() { check "exit code $1" [ "$CODE" = "$1" ]; }
expect_out() { check "stdout contains '$1'" grep -qF -- "$1" <<<"$OUT"; }
expect_err() { check "stderr contains '$1'" grep -qF -- "$1" <<<"$ERR"; }
expect_state() { check "state $1 == $2" [ "$(state "$1")" = "$2" ]; }
expect_log_count() { check "log has $2 × '$1'" [ "$(grep -cF -- "$1" "$FAKE_LOG")" = "$2" ]; }

files=("$@")
[ ${#files[@]} -gt 0 ] || files=("$HERE"/test_*.sh)
FAILURES="$FAKES/.failures"
export FAILURES
for file in "${files[@]}"; do
  # shellcheck source=/dev/null
  if ! source "$file"; then
    echo "can't load $file" >&2
    exit 1
  fi
  for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
    : > "$FAILURES"
    rc=0
    ( $t ) >"$FAKES/.out" 2>&1 || rc=$?
    if [ "$rc" -eq 0 ] && [ ! -s "$FAILURES" ]; then
      PASS=$((PASS + 1))
      printf 'ok   %s\n' "$t"
    else
      FAIL=$((FAIL + 1))
      FAILED+=("$t")
      printf 'FAIL %s%s\n' "$t" "$([ "$rc" -eq 0 ] || echo " (exit $rc)")"
      sed 's/^/  /' "$FAKES/.out"
    fi
    unset -f "$t"
  done
done
[ "$((PASS + FAIL))" -gt 0 ] || { echo "no tests ran" >&2; exit 1; }
rm -rf "$FAKES"
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
