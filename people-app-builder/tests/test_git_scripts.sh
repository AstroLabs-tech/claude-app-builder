#!/usr/bin/env bash
# Tests for preview-branch.sh, undo.sh and clean-start.sh, against real temporary git repos
# with a local bare repository standing in for GitHub.

git_quiet() { git -c user.email=t@x.com -c user.name=T -c init.defaultBranch=main "$@" >/dev/null; }

# An app clone ($PWD) of a bare "GitHub" repo with one commit on main.
make_clone() {
  setup
  git init -q --bare -b main "$WORK/github.git"
  git_quiet clone -q "$WORK/github.git" "$WORK/seed"
  (cd "$WORK/seed" && echo one > page.tsx && git add -A && git_quiet commit -m first && git_quiet push -q origin main)
  git_quiet clone -q "$WORK/github.git" "$WORK/app"
  cd "$WORK/app" || exit 1
  git config user.email ribal@astrolabs.com && git config user.name Ribal
}
push_to_main() { # file content: someone else's change reaches main on GitHub
  (cd "$WORK/seed" && git switch -q main && git pull -q origin main && echo "$2" > "$1" && git add -A \
    && git_quiet commit -m "main change" && git_quiet push -q origin main)
}

test_preview_created_from_main_with_unsaved_work() {
  make_clone
  echo draft > new.tsx
  run preview-branch.sh
  expect_code 0
  expect_out "changes=yes"
  expect_out "waiting=0"
  check "on preview" [ "$(git branch --show-current)" = preview ]
  check "work carried" [ -f new.tsx ]
}

test_preview_tracks_github_copy_and_merges_main() {
  make_clone
  (cd "$WORK/seed" && git switch -q -c preview && echo p > p.tsx && git add -A && git_quiet commit -m p && git_quiet push -q origin preview)
  push_to_main m.tsx m
  run preview-branch.sh
  expect_code 0
  check "has preview work" [ -f p.tsx ]
  check "has main change" [ -f m.tsx ]
}

test_preview_clash_leaves_nothing_half_merged() {
  make_clone
  git switch -q -c preview && echo mine > page.tsx && git add -A && git_quiet commit -m mine
  push_to_main page.tsx theirs
  run preview-branch.sh
  expect_code 7
  check "no merge in progress" [ ! -f .git/MERGE_HEAD ]
}

test_undo_refuses_unsaved_work() {
  make_clone
  echo draft > new.tsx
  run undo.sh HEAD "test"
  expect_code 4
}

test_undo_adds_one_commit_that_restores_good_version() {
  make_clone
  good=$(git rev-parse HEAD)
  push_to_main page.tsx broken
  git pull -q
  run undo.sh "$good" "the broken page"
  expect_code 0
  expect_out "undo_commit="
  check "page restored" [ "$(cat page.tsx)" = one ]
  check "commit message" git log -1 --format=%s | grep -q "Put back the version from before: the broken page"
}

test_undo_nothing_to_undo() {
  make_clone
  run undo.sh "$(git rev-parse HEAD)" "nothing"
  expect_code 1
  expect_err "nothing to undo"
}

# ---------------------------------------------------------------- clean-start.sh
make_old_app() {
  setup
  git init -q --bare -b main "$WORK/people.git"
  mkdir "$WORK/app" && cd "$WORK/app" || exit 1
  git init -q -b main && git config user.email ribal@astrolabs.com && git config user.name Ribal
  echo SECRET=1 > .env && echo x > page.tsx && printf 'name,rating\n' > data.csv
  printf 'const k = "sk_live_abc";\n' > lib.ts
  git add -A && git_quiet commit -m "old history with secrets"
  git remote add origin https://example.invalid/old.git
  echo .env > .gitignore
}

test_clean_start_prepare_lists_files_and_key_lines() {
  make_old_app
  run clean-start.sh prepare "$WORK/people.git"
  expect_code 0
  expect_out "data.csv"
  expect_out 'lib.ts:1:const k = "sk_live_abc";'
  check ".env is left out" [ -z "$(grep -x .env <<<"$OUT")" ]
}

test_clean_start_retry_folds_fixes_into_one_commit() {
  make_old_app
  run clean-start.sh prepare "$WORK/people.git"
  git remote add origin "$WORK/nowhere.git" 2>/dev/null || git remote set-url origin "$WORK/nowhere.git"
  run clean-start.sh push "$WORK/people.git" demo
  expect_code 1 # origin points somewhere else
  git remote set-url origin "$WORK/people.git"
  git rm -q --cached data.csv lib.ts && printf '.env\ndata.csv\nlib.ts\n' > .gitignore
  run clean-start.sh prepare "$WORK/people.git"
  run clean-start.sh push "$WORK/people.git" demo
  expect_code 0
  check "one commit on GitHub" [ "$(git -C "$WORK/people.git" rev-list --count main)" = 1 ]
  check "no data.csv anywhere" [ -z "$(git -C "$WORK/people.git" log --all --name-only --format= | grep data.csv)" ]
  check "no lib.ts anywhere" [ -z "$(git -C "$WORK/people.git" log --all --name-only --format= | grep lib.ts)" ]
}

test_clean_start_refuses_foreign_people_main() {
  make_old_app
  git switch -q -c people-main && echo y > y && git add y && git_quiet commit -m "Start x on the People platform" && git switch -q main
  run clean-start.sh prepare "$WORK/people.git"
  expect_code 4
}

test_clean_start_refuses_other_push_url() {
  make_old_app
  run clean-start.sh prepare "$WORK/people.git"
  git remote add origin "$WORK/people.git" && git remote set-url --push origin https://elsewhere.invalid/x.git
  run clean-start.sh push "$WORK/people.git" demo
  expect_code 1
  expect_err "somewhere other than"
}
