#!/usr/bin/env bash
# adopt-existing-app: put an existing app on AstroLabs-people as ONE clean commit, never its
# old history (older versions can hold employee data, keys, or a version without sign-in).
#   clean-start.sh prepare <people-repo-url>   stage everything on people-main and list it,
#                                              plus anything that looks like a key, for review
#   clean-start.sh push <people-repo-url> <app name>
#                                              make (or amend) the single clean-start commit
#                                              and push it as main
# Safe to re-run after a failed push: fixes fold into the one commit (nothing reached GitHub).
# Exit 4 a people-main branch exists that this didn't make, or the repo already has a
# different main (ask the builder); 6 couldn't reach GitHub (retry); 1 refused/failure.

# This script's folder; on Windows the path may use backslashes, which dirname ignores.
HERE=${0%[/\\]*}
[ "$HERE" != "$0" ] || HERE=.
# shellcheck source=lib.sh
. "$HERE/lib.sh"
need git

SUBJECT_RE='^Start .* on the People platform$'
KEY_RE='sk_(live|test)_|pk_live_|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|(password|secret|api[_-]?key|token)["'"'"']?[[:space:]]*[:=]'

# Explain a failed git call against GitHub: a network problem is worth retrying (6);
# a refusal (permissions, rules, missing repo) or anything unknown is not (1).
git_failed() {
  local what=$1 out=$2
  if printf '%s' "$out" | grep -qiE 'returned error: 4|denied|permission|protected|rejected|not found|does not appear to be'; then
    die "$E_FAIL" "GitHub refused to $what: $(printf '%s' "$out" | head -1)"
  fi
  if printf '%s' "$out" | grep -qiE 'could not resolve host|connection (refused|reset|timed out)|timed out|network is unreachable|failed to connect'; then
    die "$E_WAIT" "couldn't reach GitHub to $what; try again in a moment"
  fi
  die "$E_FAIL" "couldn't $what: $(printf '%s' "$out" | head -1)"
}

prepare() {
  local url=$1
  [ ! -f .git ] || die "$E_FAIL" "this folder is part of another git project (a worktree or submodule); copy the app into a folder of its own first"
  if git rev-parse -q --verify people-main >/dev/null 2>&1; then
    if ! { [ "$(git rev-list --count people-main)" = 1 ] && git log -1 --format=%s people-main | grep -q "$SUBJECT_RE"; }; then
      die "$E_DECIDE" "a people-main branch already exists that this didn't make"
    fi
    git switch -q people-main || die "$E_FAIL" "couldn't switch to the clean start"
  elif [ -d .git ]; then
    if git remote get-url origin >/dev/null 2>&1 && [ "$(git remote get-url origin)" != "$url" ]; then
      git remote rename origin "old-$(date +%Y%m%d%H%M%S)" || die "$E_FAIL" "couldn't set the old remote aside"
    fi
    git checkout -q --orphan people-main || die "$E_FAIL" "couldn't start the clean line"
    git read-tree --empty || die "$E_FAIL" "couldn't empty the file list" # so .gitignore applies to every file
  else
    git init -q -b people-main || die "$E_FAIL" "couldn't set up git here"
  fi
  git add -A || die "$E_FAIL" "couldn't stage the files"
  echo "--- files that will be pushed:"
  git ls-files
  echo "--- lines that look like keys or passwords:"
  git grep --cached -nIiE "$KEY_RE" || echo "(none)"
}

push() {
  local url=$1 app=$2 head remote_main out
  [ "$(git branch --show-current)" = people-main ] || die "$E_FAIL" "run 'prepare' first"
  if ! git rev-parse -q --verify HEAD >/dev/null; then
    git commit -q -m "Start $app on the People platform" || die "$E_FAIL" "couldn't save the clean start"
  elif ! git diff --cached --quiet; then
    git commit -q --amend --no-edit || die "$E_FAIL" "couldn't fold the fixes into the clean start"
  fi
  git remote get-url origin >/dev/null 2>&1 || git remote add origin "$url" || die "$E_FAIL" "couldn't add the People repo"
  [ "$(git remote get-url origin)" = "$url" ] && [ "$(git remote get-url --push --all origin)" = "$url" ] \
    || die "$E_FAIL" "this folder would push somewhere other than $url"
  out=$(git ls-remote origin refs/heads/main 2>&1) || git_failed "read $url" "$out"
  remote_main=$(printf '%s\n' "$out" | awk '$2 == "refs/heads/main" {print $1}')
  if [ -n "$remote_main" ]; then
    [ "$remote_main" = "$(git rev-parse HEAD)" ] \
      || die "$E_DECIDE" "$url already has a different main; this won't overwrite it"
    echo "already_pushed=yes" # an earlier run's push went through
  else
    out=$(git push -q -u origin people-main:main 2>&1) || git_failed "push to $url" "$out"
  fi
  head=$(git rev-parse --short HEAD) || die "$E_FAIL" "pushed, but couldn't read the commit"
  echo "pushed=$head"
}

case "${1:-}" in
  prepare) [ $# -eq 2 ] || die "$E_USAGE" "usage: clean-start.sh prepare <url>"; prepare "$2" ;;
  push) [ $# -eq 3 ] || die "$E_USAGE" "usage: clean-start.sh push <url> <app name>"; push "$2" "$3" ;;
  *) die "$E_USAGE" "usage: clean-start.sh prepare|push …" ;;
esac
