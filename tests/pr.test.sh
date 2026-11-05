#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # checks are strings evaluated by check()
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
fake_gh
p="$SCRIPTS/pr.sh"
reviewed() { printf 'What changed: x\n\nAssessment: ready\n' > "$TMP/review.md"; "$SCRIPTS/review.sh" record ${1:-} "$TMP/review.md" >/dev/null; }

new_repo standard
commit_tasks '- [ ] T001 Add search in `src/search.ts` — #5'

check "when not on the task's branch, then it refuses" 'fails_with "not on T001" "$p" task T001 "feat: add search"'

"$SCRIPTS/branch.sh" T001 >/dev/null
echo 'export const search = 1' > search.ts
check "when there are uncommitted changes, then it refuses" 'fails_with "uncommitted" "$p" task T001 "feat: add search"'
git add search.ts; git commit --quiet -m "feat(search): add search"

printf 'Adds search.\n\n## Review\n\nready: no findings\n\n## Evidence\n\n`npm test` passed\n' > "$TMP/body.md"
printf 'Adds search.\n\n## Evidence\n\n`npm test` passed\n' > "$TMP/unreviewed.md"
check "when no independent review was recorded for the diff, then it refuses at every level" \
  'fails_with "no independent review" "$p" task T001 "feat(search): add search" "$TMP/body.md"'
reviewed
check "when the body has no Review section, then it refuses" \
  'fails_with "Review" "$p" task T001 "feat(search): add search" "$TMP/unreviewed.md"'
out="$("$p" task T001 "feat(search): add search" "$TMP/body.md")"
check "when the work is committed, then it pushes and opens the PR into the base" \
  '[[ "$out" == *"PR=https://github.com/acme/app/pull/99" ]] && git ls-remote --exit-code origin "$(git branch --show-current)" && grep -q -- "--base develop" "$GH_LOG"'
check "then the body links the issue with Closes #N" 'grep -q "Closes #5" "$GH_LOG"'
check "then a Copilot code review is requested on the new PR" \
  'grep -q "^api -X POST repos/acme/app/pulls/99/requested_reviewers -f reviewers\[\]=copilot-pull-request-reviewer\[bot\]$" "$GH_LOG"'
check "then the user is assigned and no milestone or project is guessed" \
  'grep -q -- "^pr edit https://github.com/acme/app/pull/99 --add-assignee @me" "$GH_LOG" && ! grep -qE -- "--milestone|--add-project" "$GH_LOG"'

out="$("$p" task T001 "feat(search): add search" "$TMP/body.md")"
check "when the PR already exists, then it is reused, not duplicated" '[[ "$(grep -c "^pr create" "$GH_LOG")" == 1 ]]'

sed -i.bak 's/^level: .*/level: full/' .specify/extensions/jit/jit-config.yml
rm -f "$GH_PR"; printf 'No evidence here.\n' > "$TMP/thin.md"
check "when the level is full and the body has no Evidence section, then it refuses" \
  'fails_with "Evidence" "$p" task T001 "feat(search): add search" "$TMP/thin.md"'

sed -i.bak 's/^level: .*/level: standard/' .specify/extensions/jit/jit-config.yml
echo 'export const x = 2' >> search.ts; git commit --quiet -am "feat: more"
check "when the code changed after the review, then the PR is refused until a new review is recorded" \
  'fails_with "changed since" "$p" task T001 "feat(search): add search" "$TMP/body.md" && reviewed && "$p" task T001 "feat(search): add search" "$TMP/body.md" | grep -q "^PR="'
git switch --quiet main; rm -f "$GH_PR"
mkdir -p specs/002-new
printf '%s\n' '- [ ] T001 Thing in `a` — #11' '- [ ] T002 Other in `b` — #12' > specs/002-new/tasks.md
echo '{ "feature_directory": "specs/002-new" }' > .specify/feature.json
set_cfg milestone v2; set_cfg project Board
out="$("$p" spec)"
check "when opening the spec PR, then the spec folder is committed on spec/<feature>" \
  '[[ "$(git branch --show-current)" == spec/002-new ]] && [[ -z "$(git status --porcelain specs)" ]] && git ls-remote --exit-code origin spec/002-new'
check "then the spec PR lists the task issues" 'grep -q "#11 #12" "$GH_LOG"'
check "then it explains, folded away, why the spec is its own PR" 'grep -q "<summary>Why is the spec its own PR?</summary>" "$GH_LOG"'
check "then it gets the configured milestone and project" \
  'grep -q -- "^pr edit https://github.com/acme/app/pull/99 --milestone v2$" "$GH_LOG" && grep -q -- "^pr edit https://github.com/acme/app/pull/99 --add-project Board$" "$GH_LOG"'
check "when the spec PR step runs again on its branch, then it reuses the branch and the PR" \
  'before="$(grep -c "^pr create" "$GH_LOG")"; "$p" spec && [[ "$(git branch --show-current)" == spec/002-new && "$(grep -c "^pr create" "$GH_LOG")" == "$before" ]]'

# The first spec PR was squash-merged (its branch is now stale), then /speckit-converge added a task.
git push --quiet --no-verify origin "spec/002-new:refs/heads/tmp-squash"
git -C "$TMP" clone --quiet "$TMP/origin.git" squash 2>/dev/null
(cd "$TMP/squash" && git config user.email t@t && git config user.name t && git switch --quiet develop \
  && git checkout --quiet origin/tmp-squash -- specs/002-new && git commit --quiet --no-verify -m "docs(specs): 002-new (#20)" \
  && git push --quiet --no-verify origin develop && git push --quiet --no-verify origin --delete tmp-squash)
git fetch --quiet origin; rm -f "$GH_PR"; git switch --quiet main
mkdir -p specs/002-new; git checkout --quiet origin/develop -- specs/002-new; git reset --quiet
printf '%s\n' '- [ ] T003 Added by converge in `c` — #13' >> specs/002-new/tasks.md
"$p" spec >/dev/null
check "when a later spec PR follows a squash-merged one, then it starts fresh from the base" \
  'git merge-base --is-ancestor origin/develop HEAD && [[ "$(git branch --show-current)" == spec/002-new ]]'
check "then the new spec PR carries only what changed: the converge task" \
  '[[ "$(git diff --name-only origin/develop..HEAD)" == specs/002-new/tasks.md ]] && git diff origin/develop..HEAD | grep -q "^+- \[ \] T003 Added by converge"'

# ── Changing existing tests needs a reason ──
rm -rf "$TMP/origin.git" "$TMP/repo"; cd "$TMP"; rm -f "$GH_PR"
new_repo standard
mkdir -p tests src; echo 'assert 1 == 1' > tests/test_price.py; echo 'x' > src/keep.test.ts
commit_tasks '- [ ] T001 Add search in `src/search.ts` — #5'
"$SCRIPTS/branch.sh" T001 >/dev/null
printf 'Adds search.\n\n## Review\n\nready: no findings\n' > "$TMP/plain.md"

echo 'assert True' > tests/test_price.py; git commit --quiet -am "feat: weaken"
check "when an existing test is edited and the body says nothing, then it refuses and names the file" \
  'fails_with "tests/test_price.py" "$p" task T001 "feat(search): add search" "$TMP/plain.md"'
check "then no commit was pushed (origin still has only the empty claim)" \
  '[[ "$(git ls-remote origin "refs/heads/$(git branch --show-current)" | cut -f1)" == "$(git rev-parse origin/develop)" ]]'

git rm --quiet src/keep.test.ts; git commit --quiet -m "chore: drop test"; reviewed
check "when an existing test is deleted, then it refuses too" 'fails_with "src/keep.test.ts" "$p" task T001 "feat(search): add search" "$TMP/plain.md"'

printf 'Adds search.\n\n## Review\n\nready: no findings\n\n## Test changes\n\nThe spec changed the price rule (FR-002).\n' > "$TMP/why.md"
check "when the body explains the test changes, then the PR opens" '"$p" task T001 "feat(search): add search" "$TMP/why.md" | grep -q "^PR="'

git push --quiet origin --delete "$(git branch --show-current)" 2>/dev/null || true; git reset --quiet --hard origin/develop; rm -f "$GH_PR"
mkdir -p attic; git mv tests/test_price.py attic/price_checks.py; git commit --quiet -m "chore: move"
check "when a test is moved out of the test folders, then it counts as deleted and is refused" \
  'fails_with "tests/test_price.py" "$p" task T001 "feat(search): add search" "$TMP/plain.md"'

git branch --quiet develop origin/develop # the base exists locally...
git remote set-url origin "$TMP/no-such-remote.git"; git update-ref -d refs/remotes/origin/develop # ...but not on origin
check "when origin cannot be reached, then the check still runs against the local base branch" \
  'fails_with "existing tests were changed" "$p" task T001 "feat(search): add search" "$TMP/plain.md"'
git remote set-url origin "$TMP/origin.git"; git fetch --quiet origin; git branch --quiet -D develop

# A fresh branch for this scenario: drop the pushed one and start again from the base.
git push --quiet origin --delete "$(git branch --show-current)" 2>/dev/null || true; git reset --quiet --hard origin/develop; rm -f "$GH_PR"
echo 'assert 2 == 2' > tests/test_new.py; git add tests/test_new.py; git commit --quiet -m "test: add"; reviewed
check "when only new tests are added, then no explanation is needed" '"$p" task T001 "feat(search): add search" "$TMP/plain.md" | grep -q "^PR="'


# ── The spec folder survives a refused branch switch ──
rm -rf "$TMP/origin.git" "$TMP/repo"; cd "$TMP"; rm -f "$GH_PR"
new_repo standard
echo a > app.txt; git add app.txt; git commit --quiet -m app; git push --quiet origin main; git push --quiet origin main:develop
echo b > app.txt; git add app.txt; git commit --quiet -m app2   # local only: HEAD differs from origin/develop...
echo c > app.txt                                                  # ...and an unstaged edit on top: git switch refuses
printf '%s\n' '- [ ] T001 Thing in `a` — #11' > specs/001-demo/tasks.md; echo draft > specs/001-demo/spec.md
check "when the switch to the spec branch is refused, then it fails and the spec folder is put back untouched" \
  'fails_with "put back" "$p" spec && [[ "$(cat specs/001-demo/spec.md)" == draft && "$(cat specs/001-demo/tasks.md)" == *"#11" && "$(git branch --show-current)" == main ]]'

exit "$FAIL"
