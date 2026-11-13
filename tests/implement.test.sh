#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # checks are strings evaluated by check()
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
fake_gh
I="$SCRIPTS/implement.sh"
TASKS='- [ ] T001 Add search in `src/search.ts` — #1
- [ ] T002 [P] Add filters in `src/filters.ts` — #2
- [ ] T003 Add ranking in `src/rank.ts` (depends on T001) — #3
- [ ] T004 Add export in `src/export.ts` (depends on T002, T003) — #4'
B1=feat/001-t001-a; B2=feat/001-t002-b; B3=feat/001-t003-c; B4=feat/001-t004-d

# setup: a repo with the four tasks on its base, run from a detached HEAD; $W commits on task
# branches without ever checking one out here.
setup() {
  cd "$TMP"; rm -rf "$TMP/origin.git" "$TMP/repo" "$TMP/w" "$TMP/c" "$TMP/l"; : > "$GH_CLOSED"; : > "$GH_OPEN"
  new_repo standard; commit_tasks "$TASKS"
  git switch --quiet --detach origin/develop; HEAD0="$(git rev-parse HEAD)"
  git worktree add --quiet --detach "$TMP/w" origin/develop
}
# mk <branch> [<from>]: the branch with one commit of its own, from origin/develop.
mk() { git -C "$TMP/w" switch --quiet -c "$1" "${2:-origin/develop}"; commit_on "$1"; }
commit_on() {
  git -C "$TMP/w" switch --quiet "$1"; echo "$RANDOM" >> "$TMP/w/${1//\//_}.txt"
  git -C "$TMP/w" add -A; git -C "$TMP/w" commit --quiet -m "feat: $1"; git -C "$TMP/w" switch --quiet --detach
}
# ready <branch>: a recorded ready review of its head, recorded by name from here.
ready() {
  printf 'Reviewed: %s..%s\nModel: claude-sonnet-4-7\n\nAssessment: ready\n' \
    "$(git merge-base "refs/heads/$1" "$(bash -c 'source "$0/lib.sh"; base_ref "$1"' "$SCRIPTS" "$1")")" "$(git rev-parse "refs/heads/$1")" > "$TMP/r.md"
  "$SCRIPTS/review.sh" record --branch "$1" "$TMP/r.md" >/dev/null
}
# Paths in REASON= are git's, resolved: on macOS $TMP is /var/... and git prints /private/var/....
# st [args]: run status, keep its output in $out, and note when HEAD moved.
st() { out="$("$I" status "$@" 2>&1)" || true; [[ "$(git rev-parse HEAD)" == "$HEAD0" ]] || echo moved >> "$TMP/head.moved"; }
state_of() { sed -n "s/^TASK=$1 STATE=\([^ ]*\).*/\1/p" <<<"$out"; }
line_of() { grep "^TASK=$1 " <<<"$out"; }
cfg_set() { sed -i.bak "/^parallel_tasks:/d" .specify/extensions/landspec/landspec-config.yml; [[ -z "$1" ]] || echo "parallel_tasks: $1" >> .specify/extensions/landspec/landspec-config.yml; }
rm -f "$TMP/head.moved"

# ── Dependencies ──
setup
st
check "before anything starts, then START is T001 T002 and T003, T004 wait" \
  'grep -qx "START=T001 T002" <<<"$out" && [[ "$(state_of T003)" == waiting && "$(state_of T004)" == waiting ]]'
mk "$B1"; ready "$B1"; st
check "when T001 is reviewed, then it is reviewed, in OPEN, and T003 becomes startable" \
  '[[ "$(state_of T001)" == reviewed && "$(state_of T003)" == startable ]] && grep -qx "OPEN=T001" <<<"$out" && grep -qx "START=T002 T003" <<<"$out"'
mk "$B2"; ready "$B2"; mk "$B3" "$B1"; git config "branch.$B3.landspec-parent" "$B1"; ready "$B3"; st
check "when T002 and T003 are both reviewed and unmerged, then T004 still waits" '[[ "$(state_of T004)" == waiting ]]'
check "then ORDER lists the parent before its child" 'grep -qx "ORDER=T001 T002 T003" <<<"$out"'
echo 2 >> "$GH_CLOSED"; st
check "when T002 is merged, then T004 becomes startable" '[[ "$(state_of T002)" == merged && "$(state_of T004)" == startable ]]'

# ── Limits and refusals ──
setup
cfg_set 1; st
check "when parallel_tasks is 1, then START holds one task" 'grep -qx "START=T001" <<<"$out"'
st --running T001
check "when T001 is running and parallel_tasks is 1, then it takes the slot and START is empty" \
  '[[ "$(state_of T001)" == running ]] && grep -qx "START=" <<<"$out"'
for v in 0 abc 17; do
  cfg_set "$v"
  check "when parallel_tasks is $v, then status dies with the exact message" \
    'fails_with "landspec: parallel_tasks must be a number from 1 to 16" "$I" status'
done
cfg_set ""
mk "$B2"; git worktree add --quiet "$TMP/l" "$B2"; git worktree lock "$TMP/l"; st
check "when a task branch is checked out in a locked worktree, then it is running with the worktree named" \
  'line_of T002 | grep -qF "STATE=running" && line_of T002 | grep -qF "REASON=locked worktree $(cd "$TMP/l" && pwd -P)"'
git worktree unlock "$TMP/l"; git worktree remove --force "$TMP/l"
git push --quiet origin "origin/develop:refs/heads/$B4"; git fetch --quiet origin; st
check "when a task's branch is on origin with no local branch, then it is elsewhere" '[[ "$(state_of T004)" == elsewhere ]]'
mkdir -p specs/002-other; printf -- '- [ ] T001 Other in `x` — #9\n' > specs/002-other/tasks.md
check "when a feature's tasks.md is not on origin's base, then status refuses with merge the spec PR first" \
  'fails_with "merge the spec PR first" "$I" 002 status'
rm -rf specs/002-other
check "when gh cannot list the PRs, then status stops with gh's error and prints no state" \
  'gf=0; o="$(GH_FAIL_PR_LIST=1 "$I" status 2>&1)" || gf=$?; ((gf != 0)) && grep -q "cannot list the open pull requests" <<<"$o" && ! grep -q "^START=" <<<"$o"'

# ── The task record ──
setup
mk "$B1"; "$I" mark T001 implemented >/dev/null; st
check "when T001 is marked implemented, then it is implemented, in REVIEW, not in START" \
  '[[ "$(state_of T001)" == implemented ]] && grep -qx "REVIEW=T001" <<<"$out" && ! grep -q "^START=.*T001" <<<"$out"'
commit_on "$B1"; st
check "when a new commit lands on it, then it is resume" '[[ "$(state_of T001)" == resume ]]'
echo "findings" > "$TMP/rep1.md"; "$I" mark T001 changes "$TMP/rep1.md" >/dev/null; st
check "when T001 is marked changes with a report, then it is fix, in FIX, and the report is kept" \
  '[[ "$(state_of T001)" == fix ]] && grep -qx "FIX=T001" <<<"$out" && [[ "$(cat "$(git rev-parse --git-common-dir)/landspec-run/001-demo/T001.report")" == findings ]]'
"$I" mark T001 changes "$TMP/rep1.md" >/dev/null; "$I" mark T001 changes "$TMP/rep1.md" >/dev/null; st
check "when the third changes is marked, then T001 is failed (review rounds)" \
  'line_of T001 | grep -qF "STATE=failed" && line_of T001 | grep -qF "REASON=review rounds"'
commit_on "$B1"; "$I" mark T001 changes "$TMP/rep1.md" >/dev/null; st
check "when a new commit lifts a review-rounds failure, then the next changes starts the rounds again (fix, not failed)" '[[ "$(state_of T001)" == fix ]]'
mk "$B2"; "$I" fail T002 "tests red" >/dev/null; st
check "when T002 is failed, then it is failed and T004 never startable" \
  '[[ "$(state_of T002)" == failed && "$(state_of T004)" != startable ]] && line_of T002 | grep -qF "REASON=tests red"'
commit_on "$B2"; st
check "when a new commit lands on a failed task, then it is lifted" '[[ "$(state_of T002)" == resume ]]'
"$I" mark T002 implemented >/dev/null; st
check "then marking that new work implemented does not bring the failure back" '[[ "$(state_of T002)" == implemented ]]'
"$I" fail T002 "tests red" >/dev/null; "$I" retry T002 >/dev/null; st
check "when a failed task is retried, then it is lifted (back to implemented)" '[[ "$(state_of T002)" == implemented ]]'
"$I" fail T004 "no idea" >/dev/null; mk "$B4"; commit_on "$B4"; st
check "when a task failed before its branch existed, then it stays failed until retry" '[[ "$(state_of T004)" == failed ]]'
"$I" retry T004 >/dev/null; st
check "then retry lifts it" '[[ "$(state_of T004)" == resume ]]'

# ── Moved on GitHub ──
setup
mk "$B1"; git push --quiet origin "$B1"
git -C "$TMP/w" switch --quiet --detach "$B1"; echo theirs > "$TMP/w/theirs.txt"; git -C "$TMP/w" add -A
git -C "$TMP/w" commit --quiet -m theirs; git -C "$TMP/w" push --quiet origin "HEAD:refs/heads/$B1"; git -C "$TMP/w" switch --quiet --detach origin/develop
st
check "when someone pushed to a task branch checked out nowhere, then status fast-forwards it" \
  '[[ "$(git rev-parse "refs/heads/$B1")" == "$(git rev-parse "refs/remotes/origin/$B1")" && "$(state_of T001)" == resume ]]'
mk "$B2"; git push --quiet origin "$B2"; git worktree add --quiet "$TMP/c" "$B2"; before="$(git rev-parse "refs/heads/$B2")"
git -C "$TMP/w" switch --quiet --detach "$B2"; echo theirs > "$TMP/w/t2.txt"; git -C "$TMP/w" add -A
git -C "$TMP/w" commit --quiet -m theirs; git -C "$TMP/w" push --quiet origin "HEAD:refs/heads/$B2"; git -C "$TMP/w" switch --quiet --detach origin/develop
st
check "when the same happens to a branch checked out in a worktree, then it is not moved and is elsewhere with the path" \
  '[[ "$(git rev-parse "refs/heads/$B2")" == "$before" ]] && line_of T002 | grep -qF "STATE=elsewhere" && line_of T002 | grep -qF "REASON=checked out in $(cd "$TMP/c" && pwd -P)"'
git worktree remove --force "$TMP/c"; commit_on "$B2"; st
check "when the local branch and origin diverged, then it is elsewhere, diverged from origin" \
  'line_of T002 | grep -qF "STATE=elsewhere" && line_of T002 | grep -qF "REASON=diverged from origin"'

# ── Draft PRs on the base ──
setup
mk "$B1"; ready "$B1"
printf '12\t%s\t%s\tdevelop\ttrue\n' "$B1" "$(git rev-parse "refs/heads/$B1")" > "$GH_OPEN"; st
check "when a draft PR on the base has a valid review, then the task is reviewed and in OPEN" \
  '[[ "$(state_of T001)" == reviewed ]] && grep -qx "OPEN=T001" <<<"$out" && line_of T001 | grep -qF "PR=12"'
git config "branch.$B1.landspec-parent" feat/001-t009-gone; st
check "when that PR still has landspec-parent set (retargeted by GitHub), then it is waiting, restack pending, in no list" \
  'line_of T001 | grep -qF "STATE=waiting" && line_of T001 | grep -qF "REASON=restack pending" && grep -qx "OPEN=" <<<"$out" && grep -qx "START=T002" <<<"$out"'
git config --unset "branch.$B1.landspec-parent"; "$I" mark T001 pr >/dev/null
printf '12\t%s\t%s\tdevelop\tfalse\n' "$B1" "$(git rev-parse "refs/heads/$B1")" > "$GH_OPEN"; st
check "when the PR is ready on the base and marked pr, then the task is pr" '[[ "$(state_of T001)" == pr ]]'
mk "$B3" "$B1"; git config "branch.$B3.landspec-parent" "$B1"; ready "$B3"; "$I" mark T003 pr >/dev/null
printf '12\t%s\t%s\tdevelop\tfalse\n13\t%s\t%s\t%s\ttrue\n' "$B1" "$(git rev-parse "refs/heads/$B1")" "$B3" "$(git rev-parse "refs/heads/$B3")" "$B1" > "$GH_OPEN"; st
check "when a stacked draft PR into its parent is marked pr, then the task is pr, not in OPEN" \
  '[[ "$(state_of T003)" == pr ]] && ! grep -q "^OPEN=.*T003" <<<"$out"'

check "then the current HEAD is the same after every call" '[[ ! -e "$TMP/head.moved" ]]'
exit "$FAIL"
