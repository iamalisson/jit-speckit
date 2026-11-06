#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # checks are strings evaluated by check()
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
fake_gh
n="$SCRIPTS/next.sh"
closed() { printf '%s\n' "$@" > "$GH_CLOSED"; } # issue numbers the fake gh reports as closed
open_prs() { printf '%s\n' "$@" > "$GH_OPEN"; }  # head branches of the open PRs the fake gh reports

new_repo standard
commit_tasks '- [ ] T001 First in `a` — #1
- [ ] T002 [P] Second in `b` — #2
- [ ] T003 Third in `c` — #3'

closed
out="$("$n")"
check "when no issue is closed, then the next task is the first one" '[[ "$out" == *"DONE=0/3 IN_PROGRESS=0 NEXT=T001"* ]]'

closed 1 3
out="$("$n")"
check "when issues are closed out of order, then the next task is the first still open" '[[ "$out" == *"DONE=2/3 IN_PROGRESS=0 NEXT=T002"* ]]'
check "then each task shows its state" 'grep -q "^done T001 #1 First" <<<"$out" && grep -q "^open T002 #2 Second" <<<"$out"'

# F1.2: the state comes from the issue numbers, so a renamed issue (one a title search misses) still counts.
check "when a closed task issue is not found by a title search, then next shows it done and makes no --search call" \
  ': > "$GH_LOG"; out="$("$n")"; grep -q "^done T001 #1" <<<"$out" && grep -q "^api graphql" "$GH_LOG" && ! grep -q -- --search "$GH_LOG"'
check "when the issue-state query fails, then next stops with gh's error and names the tasks.md to fix" \
  'GH_FAIL_GRAPHQL=999 fails_with "cannot read the state of feature 001'"'"'s task issues; fix or remove the issue number it names in specs/001-demo/tasks.md" "$n" && GH_FAIL_GRAPHQL=999 fails_with "number of 999" "$n"'

closed 1; open_prs feat/001-t002-second-in-b
out="$("$n")"
check "when a task's branch has an open PR (another worktree), then it is in progress and the next open task is picked" \
  'grep -q "^in-progress T002 #2 Second" <<<"$out" && [[ "$out" == *"DONE=1/3 IN_PROGRESS=1 NEXT=T003"* ]]'
open_prs feat/001-t002-second-in-b feat/001-t003-third-in-c
check "when every remaining task has an open PR, then nothing is left to start" '[[ "$("$n" | tail -1)" == "DONE=1/3 IN_PROGRESS=2 NEXT=" ]]'
open_prs feat/002-t002-other-feature
check "then an open PR of another feature's T002 does not count" '[[ "$("$n" | tail -1)" == *"NEXT=T002"* ]]'
open_prs

closed 1 2 3
check "when every issue is closed, then there is no next task" '[[ "$("$n" | tail -1)" == "DONE=3/3 IN_PROGRESS=0 NEXT=" ]]'

# Claims: a branch on origin (another clone started it), one checked out in another worktree,
# one only local (started here, parked), and the current one.
closed; open_prs
git push --quiet origin main:feat/001-t002-second-in-b
check "when a task's branch is on origin without a PR, then it is in progress (claimed elsewhere)" \
  'out="$("$n")"; grep -q "^in-progress T002" <<<"$out" && [[ "$out" == *"NEXT=T001"* ]]'
git push --quiet origin --delete feat/001-t002-second-in-b
git branch --quiet feat/001-t003-third-in-c origin/develop
check "when a task's branch exists only here, then it is yours to resume and is picked before the open ones" \
  'out="$("$n")"; grep -q "^resume T003" <<<"$out" && [[ "$out" == *"IN_PROGRESS=0 NEXT=T003"* ]]'
git worktree add --quiet "$TMP/wt3" feat/001-t003-third-in-c 2>/dev/null
check "when that branch is checked out in another worktree, then it is in progress, not resume" \
  'out="$("$n")"; grep -q "^in-progress T003" <<<"$out" && [[ "$out" == *"NEXT=T001"* ]]'
check "then from inside that worktree the task is the one to resume" \
  'out="$(cd "$TMP/wt3" && mkdir -p .specify/extensions/jit && ln -sfn "$ROOT/extension/scripts" .specify/extensions/jit/scripts && cp "$TMP/repo/.specify/extensions/jit/jit-config.yml" .specify/extensions/jit/ && "$n")"; grep -q "^resume T003" <<<"$out" && [[ "$out" == *"NEXT=T003"* ]]'
git worktree remove --force "$TMP/wt3"; git branch --quiet -D feat/001-t003-third-in-c

# Dependencies: "(depends on T001)" holds a task until T001's issue is closed.
closed; open_prs
printf '%s\n' '- [ ] T005 [US2] Report screen (depends on T001, T002) in `s` — #8' >> specs/001-demo/tasks.md
check "when a task depends on open tasks, then it is blocked and not picked" \
  'out="$("$n")"; grep -q "^blocked T005 #8" <<<"$out" && [[ "$out" == *"NEXT=T001"* ]]'
closed 1 2 3
check "when the tasks it depends on are done, then it is open and picked" \
  'out="$("$n")"; grep -q "^open T005 #8" <<<"$out" && [[ "$out" == *"NEXT=T005"* ]]'
closed 2 3
check "when only one dependency is still open, then it stays blocked" 'out="$("$n")"; grep -q "^blocked T005" <<<"$out"'
sed -i.bak '/T005/d' specs/001-demo/tasks.md; rm -f specs/001-demo/tasks.md.bak; closed

# Several features: a second one with tasks to start.
mkdir -p specs/002-reports; printf '%s\n' '- [ ] T001 Report in `r` — #30' > specs/002-reports/tasks.md
check "when two features have tasks to start and none is named, then it lists them and asks" \
  'out="$("$n")"; grep -q "^feature 001-demo DONE=0/3" <<<"$out" && grep -q "^feature 002-reports DONE=0/1" <<<"$out" && [[ "$(tail -1 <<<"$out")" == "CHOOSE=001-demo 002-reports" ]]'
# F1.9: on a task branch, the branch names the feature.
git switch --quiet -c feat/001-t001-first-in-a
check "when the current branch is a task branch of one feature and another feature has tasks to start, then next prints that feature's tasks and no CHOOSE=" \
  'out="$("$n")"; grep -q "^resume T001 #1 First" <<<"$out" && grep -q "^open T003 #3 Third" <<<"$out" && ! grep -q CHOOSE <<<"$out"'
check "then an explicit argument still wins over the branch" \
  'out="$("$n" 002)"; grep -q "^open T001 #30 Report" <<<"$out" && ! grep -q "First" <<<"$out"'
git switch --quiet main; git branch --quiet -D feat/001-t001-first-in-a
check "when a feature is named, then it becomes the active one and its next task is picked" \
  'out="$("$n" 002)"; [[ "$out" == *"NEXT=T001"* ]] && grep -q "specs/002-reports" .specify/feature.json'
check "when the name matches no single feature, then it refuses" 'fails_with "no single feature" "$n" 009'
closed 30
check "when only one feature has tasks to start, then it is served without asking" \
  'out="$("$n")"; [[ "$out" == *"NEXT=T001"* ]] && ! grep -q CHOOSE <<<"$out"'
rm -rf specs/002-reports; echo '{ "feature_directory": "specs/001-demo" }' > .specify/feature.json; closed 1 2 3

printf '%s\n' '- [ ] T004 Fourth in `d`' >> specs/001-demo/tasks.md
check "when a task has no issue, then it is listed as no-issue and not picked" \
  'out="$("$n")"; grep -q "^no-issue T004" <<<"$out" && [[ "$out" == *"NEXT="* && "$out" != *"NEXT=T004"* ]]'
mkdir -p specs/003-bare; printf '%s\n' '- [ ] T001 Nothing linked yet in `n`' > specs/003-bare/tasks.md
check "when no task of the feature has an issue, then no issue-state query is made" \
  ': > "$GH_LOG"; "$n" 003 | grep -q "^no-issue T001" && ! grep -q "^api graphql" "$GH_LOG"'
rm -rf specs/003-bare; echo '{ "feature_directory": "specs/001-demo" }' > .specify/feature.json

mkdir -p "$TMP/mono/apps/web/.specify" && git -C "$TMP/mono" init --quiet
check "when spec-kit lives in a subfolder of the repo, then scripts refuse instead of writing into the parent" \
  '(cd "$TMP/mono/apps/web" && fails_with "a subfolder of the repository" "$SCRIPTS/next.sh") && [[ ! -e "$TMP/mono/.specify" ]]'

exit "$FAIL"
