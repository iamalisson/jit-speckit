#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # checks are strings evaluated by check()
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
b="$SCRIPTS/branch.sh"

new_repo standard
commit_tasks '- [ ] T001 Split CI credentials into a deploy role in `infra/main.tf` — #57
- [ ] T002 [P] [US1] Sandbox schedule in `infra/stack.tf` — #64
- [ ] T003 Task without an issue in `x`'

out="$("$b" T001)"
check "when the branch does not exist, then it is created from origin/develop (standard)" \
  '[[ "$(git branch --show-current)" == feat/001-t001-split-ci-credentials-into && "$(git merge-base HEAD origin/develop)" == "$(git rev-parse origin/develop)" ]]'
check "then it prints the branch, issue, task and base" \
  '[[ "$out" == "BRANCH=feat/001-t001-split-ci-credentials-into ISSUE=57 TASK=T001 BASE=develop" ]]'
check "when run again on the same branch, then it succeeds" '"$b" T001'

git switch --quiet main
"$b" T002 >/dev/null
check "when the task has [P] and [US1] markers, then they are left out of the name" \
  '[[ "$(git branch --show-current)" == feat/001-t002-sandbox-schedule ]]'

"$b" T001 >/dev/null
check "when the branch exists locally, then it switches to it" \
  '[[ "$(git branch --show-current)" == feat/001-t001-split-ci-credentials-into ]]'

echo dirty > dirty.txt
check "when the tree is dirty and the target differs, then it refuses and stays put" \
  '! "$b" T002 && [[ "$(git branch --show-current)" == feat/001-t001-split-ci-credentials-into ]]'
rm dirty.txt

check "when the task has no issue, then it refuses" '! "$b" T003'
check "when the task does not exist, then it refuses" '! "$b" T999'
check "when the argument is not one task ID, then it refuses" '! "$b" 57 && ! "$b" "T001 T002"'

git switch --quiet main
sed -i.bak 's/^level: .*/level: lite/' .specify/extensions/jit/jit-config.yml
"$b" T002 >/dev/null || true
check "when the level is lite, then the base is the default branch" \
  'out="$("$b" T001)"; grep -q "BASE=main" <<<"$out"'

git switch --quiet main
mkdir -p specs/002-new
printf '%s\n' '- [ ] T001 New thing in `a` — #1' > specs/002-new/tasks.md
echo '{ "feature_directory": "specs/002-new" }' > .specify/feature.json
git add specs/002-new; git commit --quiet -m wip
check "when tasks.md is not on the base yet, then it refuses and says to merge the spec PR" \
  'fails_with "merge the spec PR" "$b" T001'
git reset --quiet --hard HEAD~1
echo '{ "feature_directory": "specs/001-demo" }' > .specify/feature.json

sed -i.bak 's/^level: .*/level: full/' .specify/extensions/jit/jit-config.yml
check "when the level is full and analysis did not run, then it refuses" \
  'fails_with "speckit-analyze" "$b" T001'
"$SCRIPTS/analyzed.sh" >/dev/null
check "when the level is full and analysis ran on the current tasks, then it proceeds" '"$b" T001'

# Parallel work: a second worktree, as `claude --worktree` makes for a [P] task. It shares the
# repo but has its own git dir, and none of the untracked files (feature.json is one of them).
git switch --quiet main
git worktree add --quiet "$TMP/wt" origin/develop 2>/dev/null
mkdir -p "$TMP/wt/.specify/extensions/jit"
cp .specify/extensions/jit/jit-config.yml "$TMP/wt/.specify/extensions/jit/" # committed in a real project
ln -s "$ROOT/extension/scripts" "$TMP/wt/.specify/extensions/jit/scripts"
check "when a task starts in a fresh worktree on level full, then the analysis done in the main checkout counts" \
  '(cd "$TMP/wt" && [[ ! -f .specify/feature.json ]] && "$b" T002 | grep -q "TASK=T002")'
check "then the worktree is on the task's own branch, and the main checkout is untouched" \
  '[[ "$(git -C "$TMP/wt" branch --show-current)" == feat/001-t002-* && "$(git branch --show-current)" == main ]]'
mkdir -p specs/002-other; printf '%s\n' '- [ ] T002 Other thing in `o` — #99' > specs/002-other/tasks.md
echo '{ "feature_directory": "specs/002-other" }' > .specify/feature.json # the main checkout moved on
check "when the main checkout moves to another feature, then the worktree's task branch keeps its own" \
  '(cd "$TMP/wt" && bash -c "source \"$SCRIPTS/lib.sh\"; feature_dir") | grep -qx "specs/001-demo"'
echo '{ "feature_directory": "specs/001-demo" }' > .specify/feature.json; rm -rf specs/002-other
git worktree remove --force "$TMP/wt"

# A repo whose default branch is master and whose origin/HEAD was never set.
git switch --quiet main
git push --quiet --no-verify origin main:master
git remote set-head origin --delete >/dev/null 2>&1 || git symbolic-ref --delete refs/remotes/origin/HEAD 2>/dev/null || true
git -C "$TMP/origin.git" symbolic-ref HEAD refs/heads/master # a remote whose default is master
git push --quiet --no-verify origin --delete main
git fetch --quiet --prune origin
git branch --quiet -m main master
sed -i.bak 's/^level: .*/level: lite/' .specify/extensions/jit/jit-config.yml
check "when origin/HEAD is unset and the repo uses master, then master is the base (not a missing main)" \
  'out="$("$b" T001)"; grep -q "BASE=master" <<<"$out"'

exit "$FAIL"
