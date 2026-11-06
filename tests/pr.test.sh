#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # checks are strings evaluated by check()
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
fake_gh
p="$SCRIPTS/pr.sh"
reviewed() { printf 'What changed: x\n\nAssessment: ready\n' > "$TMP/review.md"; "$SCRIPTS/review.sh" record "$TMP/review.md" >/dev/null; }
scanned() { no_scanners; PATH="$TMP/none" bash "$SCRIPTS/security-scan.sh" --changed >/dev/null; }

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
check "when no scan was recorded for this diff, then it refuses and names security-scan.sh" \
  'fails_with "no security-scan.sh --changed result for this diff; run bash .specify/extensions/jit/scripts/security-scan.sh --changed after the last commit" "$p" task T001 "feat(search): add search" "$TMP/body.md"'
scanned # with no scanner installed: every one is "missing", and that is enough
# A test command that prints 30 lines and fails: the refusal shows the last 20 (11 to 30).
mkdir -p .specify/memory
printf '#!/usr/bin/env bash\nfor i in $(seq 1 30); do echo "red line $i"; done\nexit 1\n' > "$TMP/red.sh"
printf '**Commands**: build `[BUILD_COMMAND]` · test `bash %s` · lint `[LINT_COMMAND]` · mutate `[MUTATE_COMMAND]`\n' "$TMP/red.sh" > .specify/memory/constitution.md
claim="$(git ls-remote origin "refs/heads/$(git branch --show-current)")"
red=0; out="$("$p" task T001 "feat(search): add search" "$TMP/body.md" 2>&1)" || red=$?
check "when the constitution's test command exits 1, then it refuses, prints its last 20 lines and pushes nothing" \
  '((red != 0)) && grep -qxF "jit: the test command failed (bash $TMP/red.sh); fix it before opening the PR" <<<"$out" \
   && grep -qx "red line 30" <<<"$out" && grep -qx "red line 11" <<<"$out" && ! grep -qx "red line 10" <<<"$out" \
   && [[ "$(git ls-remote origin "refs/heads/$(git branch --show-current)")" == "$claim" ]] && ! grep -q "^pr create" "$GH_LOG" \
   && grep -qx "red line 1" "$(git rev-parse --git-common-dir)/jit-test/feat__001-t001-add-search.log"'
check "when a scan was recorded for this diff, then the scan check lets the PR through" \
  '! grep -q "no security-scan.sh --changed result" <<<"$out" && grep -qx "red line 30" <<<"$out"'
printf '#!/usr/bin/env bash\ntouch "%s/green.ran"\n' "$TMP" > "$TMP/green.sh"
printf '**Commands**: build `[BUILD_COMMAND]` · test `bash %s` · lint `[LINT_COMMAND]` · mutate `[MUTATE_COMMAND]`\n' "$TMP/green.sh" > .specify/memory/constitution.md
out="$("$p" task T001 "feat(search): add search" "$TMP/body.md" 2>"$TMP/pr.err")" || true
check "when the constitution's test command exits 0, then it opens the PR with no warning" \
  '[[ -f "$TMP/green.ran" && "$out" == *"PR=https://github.com/acme/app/pull/99" ]] && grep -q "^pr create" "$GH_LOG" && ! grep -q "^jit:" "$TMP/pr.err"'
rm -f "$GH_PR"; : > "$GH_LOG" # the checks below are about the next run's PR alone
rm .specify/memory/constitution.md
out="$("$p" task T001 "feat(search): add search" "$TMP/body.md" 2>"$TMP/pr.err")"
check "when the constitution has no test command, then it says the tests were not run and opens the PR" \
  'grep -qx "jit: tests not run before the PR (no test command in the constitution)" "$TMP/pr.err" && [[ "$out" == *"PR=https://github.com/acme/app/pull/99" ]]'
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
  'fails_with "changed since" "$p" task T001 "feat(search): add search" "$TMP/body.md" && reviewed && scanned && "$p" task T001 "feat(search): add search" "$TMP/body.md" | grep -q "^PR="'
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

git rm --quiet src/keep.test.ts; git commit --quiet -m "chore: drop test"; reviewed; scanned
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
echo 'assert 2 == 2' > tests/test_new.py; git add tests/test_new.py; git commit --quiet -m "test: add"; reviewed; scanned
check "when only new tests are added, then no explanation is needed" '"$p" task T001 "feat(search): add search" "$TMP/plain.md" | grep -q "^PR="'

# ── Common test layouts count as tests, and the constitution can add one ──
layouts=$'app/tests.py\nTests/AppTests/AppTests.swift\nMyApp.Tests/FooTests.cs\ncypress/e2e/login.cy.ts\nsrc/Foo.Test.cs\nsrc/foo.spec.TS\ntests/test_a.py\nsrc/a.test.ts\n__tests__/a.js'
sources=$'src/latest.ts\nlib/contest.py\nsrc/attest.go\npkg/protest.rb\nsrc/greatest.js\nsrc/Contests.java\nsrc/Latests.cs\nsrc/utils.py\napp/Manifest.swift\nsrc/LatestRelease.swift\nsrc/specification.py\ndocs/e2e.md\nlib/testing.go'
check "the test-path pattern matches each of the 9 test layouts and none of the 13 source paths" \
  'source "$SCRIPTS/lib.sh"; [[ "$(grep -E "$TEST_PATH_RE" <<<"$layouts")" == "$layouts" && -z "$(grep -E "$TEST_PATH_RE" <<<"$sources" || true)" ]]'
rm -rf "$TMP/origin.git" "$TMP/repo"; cd "$TMP"; rm -f "$GH_PR"
new_repo standard
mkdir -p app Tests/AppTests src checks
echo 'assert 1 == 1' > app/tests.py; echo 'XCTAssertEqual(1, 1)' > Tests/AppTests/AppTests.swift; echo 'x' > src/latest.ts; echo 'check 1' > checks/price.sh
commit_tasks '- [ ] T001 Add search in `src/search.ts` — #5'
"$SCRIPTS/branch.sh" T001 >/dev/null
echo 'pass' > app/tests.py; echo '// nothing checked' > Tests/AppTests/AppTests.swift; git commit --quiet -am "feat: weaken"; reviewed; scanned
check "when an existing app/tests.py or Tests/AppTests/AppTests.swift is edited and the body says nothing, then it refuses and names the file" \
  'fails_with "app/tests.py" "$p" task T001 "feat(search): add search" "$TMP/plain.md" && fails_with "Tests/AppTests/AppTests.swift" "$p" task T001 "feat(search): add search" "$TMP/plain.md"'
git reset --quiet --hard origin/develop
echo 'y' > src/latest.ts; git commit --quiet -am "feat: latest"; reviewed; scanned
check "when an existing src/latest.ts is edited, then it is not taken for a test and the PR opens" \
  '"$p" task T001 "feat(search): add search" "$TMP/plain.md" | grep -q "^PR="'
echo 'check 2' > checks/price.sh; git commit --quiet -am "feat: weaken a check"; reviewed; scanned; rm -f "$GH_PR"
mkdir -p .specify/memory; printf '# Constitution\n\ntests: ^checks/\n' > .specify/memory/constitution.md
check "when the constitution adds a tests: regex, then a file it matches counts as a test" \
  'fails_with "existing tests were changed: checks/price.sh" "$p" task T001 "feat(search): add search" "$TMP/plain.md"'
printf '# Constitution\n\ntests: ([\n' > .specify/memory/constitution.md
check "when the constitution's tests: regex is invalid, then it refuses and names it" \
  'fails_with "the constitution'"'"'s tests: regex is invalid: ([" "$p" task T001 "feat(search): add search" "$TMP/plain.md"'

# ── Mutation testing ran on this diff, when the constitution has a mutate command ──
rm -rf "$TMP/origin.git" "$TMP/repo"; cd "$TMP"; rm -f "$GH_PR"
new_repo standard
commit_tasks '- [ ] T001 Add search in `src/search.ts` — #5'
"$SCRIPTS/branch.sh" T001 >/dev/null
mkdir -p src .specify/memory; echo 'export const search = 1' > src/search.ts; git add src; git commit --quiet -m "feat: search"; reviewed
mutate() { printf '**Commands**: build `[BUILD_COMMAND]` · test `[TEST_COMMAND]` · lint `[LINT_COMMAND]` · mutate `%s`\n' "$1" > .specify/memory/constitution.md; }
mutate true
check "when a mutate command is set and mutants.sh was not run on this diff, then it refuses and names mutants.sh" \
  'fails_with "no mutants.sh result for this diff; run bash .specify/extensions/jit/scripts/mutants.sh after the last commit" "$p" task T001 "feat(search): add search" "$TMP/body.md"'
"$SCRIPTS/mutants.sh" >/dev/null; scanned
check "when mutants.sh ran on this diff, then the PR opens" '"$p" task T001 "feat(search): add search" "$TMP/body.md" | grep -q "^PR="'
echo 'export const more = 2' >> src/search.ts; git commit --quiet -am "feat: more"; reviewed; rm -f "$GH_PR"
check "when a commit follows the mutants.sh run, then it refuses again" \
  'fails_with "no mutants.sh result for this diff" "$p" task T001 "feat(search): add search" "$TMP/body.md"'
mutate false; "$SCRIPTS/mutants.sh" >/dev/null; scanned
check "when mutants.sh found survivors and Evidence does not mention them, then it refuses" \
  'fails_with "mutants.sh found surviving mutants; say in '"'"'## Evidence'"'"' why each changes nothing, or add the test that kills it" "$p" task T001 "feat(search): add search" "$TMP/body.md"'
printf 'Adds search.\n\n## Review\n\nready: no findings\n\n## Evidence\n\nOne survivor, in a log line: it changes nothing observable.\n' > "$TMP/survivor.md"
check "when Evidence says why the survivor changes nothing, then the PR opens" \
  '"$p" task T001 "feat(search): add search" "$TMP/survivor.md" | grep -q "^PR="'
rm .specify/memory/constitution.md; rm -f "$GH_PR"; : > "$GH_LOG"
check "when there is no mutate command, then the body says mutation testing was not run" \
  '"$p" task T001 "feat(search): add search" "$TMP/body.md" | grep -q "^PR=" && grep -qxF "Mutation testing: not run (no mutate command in the constitution)" "$GH_LOG"'

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
