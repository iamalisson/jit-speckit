#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # checks are strings evaluated by check()
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
fake_gh
p="$SCRIPTS/pr.sh"
# range: the Reviewed: and Model: lines every task report states.
range() { printf 'Reviewed: %s..%s\nModel: claude-sonnet-4-7\n' "$(git merge-base HEAD origin/develop)" "$(git rev-parse HEAD)"; }
# reviewed: a ready review of HEAD that deep-checks every path review.sh risk flags.
reviewed() {
  { printf 'What changed: x\n\n'; { "$SCRIPTS/review.sh" risk 2>/dev/null || true; } | sed -n 's/^RISK=[a-z]* /- deep: /p' | sort -u
    echo; range; printf '\nAssessment: ready\n'; } > "$TMP/review.md"
  "$SCRIPTS/review.sh" record "$TMP/review.md" >/dev/null
}
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
# F3.1/F4.3: the recorded review reaches the body; its findings never do, wherever the report puts them.
printf 'LEAK-1 before the marker\n\n- **What changed**: Adds LEAK-2 search.\n- **Findings**:\n  - High: LEAK-3 in src/a.ts:3\n\nSecurity: LEAK-4 token logged\n\n%s\n\nAssessment: ready\n' "$(range)" > "$TMP/review.md"
"$SCRIPTS/review.sh" record "$TMP/review.md" >/dev/null
rm .specify/memory/constitution.md
out="$("$p" task T001 "feat(search): add search" "$TMP/body.md" 2>"$TMP/pr.err")"
check "when the constitution has no test command, then it says the tests were not run and opens the PR" \
  'grep -qx "jit: tests not run before the PR (no test command in the constitution)" "$TMP/pr.err" && [[ "$out" == *"PR=https://github.com/acme/app/pull/99" ]]'
check "when a review is recorded, then the body sent to gh pr create has the patch-id and Assessment lines, folded, before Closes" \
  'sed -n "/^pr create/,\$p" "$GH_LOG" | grep -A4 -xF "<details><summary>Independent review</summary>" | grep -xE -e "Independent review recorded for this diff \(patch id [0-9a-f]{12}\)" -e "Assessment: ready" | wc -l | grep -qx " *2" \
   && [[ "$(grep -nxF "</details>" "$GH_LOG" | tail -1 | cut -d: -f1)" -lt "$(grep -n "Closes #5" "$GH_LOG" | cut -d: -f1)" ]]'
check "then none of the report's text reaches the body" '! grep -qE "LEAK|What changed|token logged" "$GH_LOG"'
check "when the work is committed, then it pushes and opens the PR into the base" \
  '[[ "$out" == *"PR=https://github.com/acme/app/pull/99" ]] && git ls-remote --exit-code origin "$(git branch --show-current)" && grep -q -- "--base develop" "$GH_LOG"'
check "then the body links the issue with Closes #N" 'grep -q "Closes #5" "$GH_LOG"'
check "then no outside reviewer is asked for" '! grep -q "requested_reviewers" "$GH_LOG" && ! grep -qi copilot <<<"$out"'
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
printf 'Plan read.\n\nModel: claude-haiku-4-5\n\nAssessment: ready\n' > "$TMP/plan.md"; "$SCRIPTS/review.sh" record --plan "$TMP/plan.md" >/dev/null 2>&1
out="$("$p" spec)"
check "when the plan review's record has a model warning, then the spec PR body carries it" \
  'grep -qxF "**Plan review:** the review ran on claude-haiku-4-5; the review did not run on the configured model" "$GH_LOG"'
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
"$SCRIPTS/review.sh" record --plan "$TMP/plan.md" >/dev/null 2>&1
"$p" spec >/dev/null
check "when a later spec PR follows a squash-merged one, then it starts fresh from the base" \
  'git merge-base --is-ancestor origin/develop HEAD && [[ "$(git branch --show-current)" == spec/002-new ]]'
check "then the new spec PR carries only what changed: the converge task" \
  '[[ "$(git diff --name-only origin/develop..HEAD)" == specs/002-new/tasks.md ]] && git diff origin/develop..HEAD | grep -q "^+- \[ \] T003 Added by converge"'

# F1.8: the spec PR is open and a teammate pushed to its branch; origin was fetched after that, so
# only the lookup (not --force-with-lease) can stop the fresh start from overwriting their commit.
git -C "$TMP" clone --quiet "$TMP/origin.git" mate 2>/dev/null
(cd "$TMP/mate" && git config user.email m@m && git config user.name m && git switch --quiet spec/002-new \
  && echo "teammate note" >> specs/002-new/tasks.md && git commit --quiet -am "docs: teammate" && git push --quiet origin spec/002-new)
mate="$(git -C "$TMP/mate" rev-parse HEAD)"; git fetch --quiet origin
out="$(GH_FAIL_PR_LIST=1 "$p" spec 2>&1)" && spec_rc=0 || spec_rc=$?
check "when gh pr list fails while the spec PR is open with a teammate's commit, then pr.sh spec exits non-zero after gh's error" \
  '((spec_rc != 0)) && grep -q "HTTP 502" <<<"$out" && grep -qxF "jit: could not check for an open spec PR" <<<"$out"'
check "then origin's spec branch still has the teammate's commit" '[[ "$(git ls-remote origin refs/heads/spec/002-new | cut -f1)" == "$mate" ]]'

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

# ── FR-006: adding to an existing test file needs no explanation; a deletion, an edit or an added skip does ──
rm -rf "$TMP/origin.git" "$TMP/repo"; cd "$TMP"; rm -f "$GH_PR"
new_repo standard
mkdir -p tests; printf 'check one\nexit "$FAIL"\n' > tests/a.test.sh; printf 'it("a")\n' > tests/b.test.js
printf 'one\n' > tests/xfail.test.sh; printf '\0\1' > tests/data.test.bin
commit_tasks '- [ ] T001 Add search in `src/search.ts` — #5'
"$SCRIPTS/branch.sh" T001 >/dev/null
fresh() { git push --quiet origin --delete "$(git branch --show-current)" 2>/dev/null || true; git reset --quiet --hard origin/develop; rm -f "$GH_PR"; }
opens() { git commit --quiet -am "test: change"; reviewed; scanned; "$p" task T001 "test: change" "$TMP/plain.md" | grep -q "^PR="; }
refused() { git commit --quiet -am "test: change"; fails_with "existing tests were changed: $1" "$p" task T001 "test: change" "$TMP/plain.md"; }
printf 'check one\ncheck two\nexit "$FAIL"\n' > tests/a.test.sh
check "when a test is added above a file's closing exit, then the PR opens with no Test changes section" opens; fresh
printf 'check one\nrun x || true\ncat > stub <<EOF\nexit 0\nEOF\nexit "$FAIL"\n' > tests/a.test.sh
check "when a new test holds || true and a heredoc stub with exit 0, then the PR opens with no Test changes section" opens; fresh
echo two >> tests/xfail.test.sh
check "when a line is added to a test whose path holds a skip word, then the path does not count as a skip" opens; fresh
printf 'it("a")\nit.skip("b")\n' > tests/b.test.js
check "when an added line skips a test, then it refuses and names the file" 'refused tests/b.test.js'; fresh
printf 'it("a")\n@Disabled\n' > tests/b.test.js
check "when an added skip is in another case (@Disabled), then it refuses too" 'refused tests/b.test.js'; fresh
printf 'it("changed")\n' > tests/b.test.js
check "when a line is edited, then it refuses" 'refused tests/b.test.js'; fresh
git config color.ui always; printf 'it("a")\nit("b")\n' > tests/b.test.js; git commit --quiet -am "test: more"
printf 'it("changed")\nit("b")\n' > tests/b.test.js
check "when a line is edited under color.ui=always, then it refuses" 'refused tests/b.test.js'; git config --unset color.ui; fresh
chmod +x tests/a.test.sh; echo x > other.txt; git add other.txt
check "when only a test's mode changes, then it refuses" 'refused tests/a.test.sh'; fresh
printf '\0\2' > tests/data.test.bin
check "when a binary test changes, then it refuses" 'refused tests/data.test.bin'; fresh

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
{ cat "$TMP/survivor.md"; seq 1 20000; } > "$TMP/long.md"; rm -f "$GH_PR"
check "when Evidence explains the survivor and runs on past the pipe buffer, then the PR opens" \
  '"$p" task T001 "feat(search): add search" "$TMP/long.md" | grep -q "^PR="'
mutate no-such-mutator; "$SCRIPTS/mutants.sh" >/dev/null; rm -f "$GH_PR"
check "when the mutate command could not run, then it refuses naming it, whatever Evidence says of survivors" \
  'fails_with "the mutate command could not run (no-such-mutator)" "$p" task T001 "feat(search): add search" "$TMP/survivor.md"'
rm .specify/memory/constitution.md; rm -f "$GH_PR"; : > "$GH_LOG"
check "when there is no mutate command, then the body says mutation testing was not run" \
  '"$p" task T001 "feat(search): add search" "$TMP/body.md" | grep -q "^PR=" && grep -qxF "Mutation testing: not run (no mutate command in the constitution)" "$GH_LOG"'

# ── FR-030–FR-033: the review block carries the record's facts: model, warning, both risk maps ──
rm -rf "$TMP/origin.git" "$TMP/repo"; cd "$TMP"; rm -f "$GH_PR"; : > "$GH_LOG"
new_repo standard
commit_tasks '- [ ] T001 Add search in `src/search.ts` — #5'
"$SCRIPTS/branch.sh" T001 >/dev/null
mkdir -p db/migrations; echo 'DROP TABLE users;' > db/migrations/002_drop.sql; git add db; git commit --quiet -m "feat: drop"; h1="$(git rev-parse HEAD)"
printf 'What changed: x\n\n- deep: db/migrations/002_drop.sql — PROSE-1 drops users: checked the backup\n\n%s\n\nAssessment: changes needed\n' "$(range)" > "$TMP/review.md"
"$SCRIPTS/review.sh" record "$TMP/review.md" >/dev/null 2>&1 || true
echo 'DROP TABLE orders;' >> db/migrations/002_drop.sql; git commit --quiet -am "fix: drop orders"
printf 'What changed: y\n\n- deep: db/migrations/002_drop.sql — PROSE-2 second drop\n\nDelta from: %s\nReviewed: %s..%s\nModel: claude-sonnet-4-7\n\nAssessment: ready\n' "$h1" "$h1" "$(git rev-parse HEAD)" > "$TMP/review.md"
CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1 "$SCRIPTS/review.sh" record --delta "$TMP/review.md" >/dev/null 2>&1 || true
scanned; "$p" task T001 "feat: drop" "$TMP/body.md" >/dev/null 2>&1 || true
body="$(sed -n "/^pr create/,\$p" "$GH_LOG")"
check "after a delta, then the PR body lists both labeled risk maps, as paths" \
  'grep -A1 -xF "Risk map (round 1)" <<<"$body" | grep -qxF -- "- deep: db/migrations/002_drop.sql" && grep -A1 -xF "Risk map (fix round)" <<<"$body" | grep -qxF -- "- deep: db/migrations/002_drop.sql"'
check "when the record was made with CLAUDE_CODE_SUBAGENT_MODEL_FORCE set, then the PR body has the model and the warning, though pr.sh ran without it" \
  'grep -qxF "Model: claude-sonnet-4-7" <<<"$body" && grep -qxF "warning: CLAUDE_CODE_SUBAGENT_MODEL_FORCE is set; the review did not run on the configured model" <<<"$body"'
check "then no risk-map prose reaches the PR body" '[[ -n "$body" ]] && ! grep -q PROSE "$GH_LOG"'
printf 'What changed: x\n\n- deep: db/migrations/002_drop.sql\n\n%s\n\nAssessment: ready\n' "$(range | sed 's/^Model: .*/Model: claude-opus-4-8/')" > "$TMP/review.md"
"$SCRIPTS/review.sh" record "$TMP/review.md" >/dev/null 2>&1 || true; rm -f "$GH_PR"; : > "$GH_LOG"
"$p" task T001 "feat: drop" "$TMP/body.md" >/dev/null 2>&1 || true
check "when Model: is outside the configured family, then the warning reaches the PR body from the record" \
  'grep -qxF "warning: the review ran on claude-opus-4-8, not sonnet; the review did not run on the configured model" "$GH_LOG"'

# ── FR-009: the diff id ignores the user's git config ──
rm -rf "$TMP/origin.git" "$TMP/repo"; cd "$TMP"; rm -f "$GH_PR"
new_repo standard
seq 1 40 | sed '4s/.*//; 16s/.*//' > big.txt; echo one > a.conv; printf '*.conv diff=conv\n' > .gitattributes
commit_tasks '- [ ] T001 Add search in `src/search.ts` — #5'
"$SCRIPTS/branch.sh" T001 >/dev/null
sed -i.bak '5s/.*/five/; 15s/.*/fifteen/' big.txt; rm big.txt.bak; mkdir sub
git update-index --add --cacheinfo "160000,$(git rev-parse HEAD),sub"; git add big.txt; git commit --quiet -m "feat: edit"
printf '#!/usr/bin/env bash\necho same\n' > "$TMP/same.sh"; chmod +x "$TMP/same.sh"
lib_id() { (source "$SCRIPTS/lib.sh"; diff_id); }
# config_case <key> <value> <edit>: with the key set, the id is the one without it, and a commit
# (whose change the key would hide) after a ready review makes pr.sh refuse.
config_case() {
  git config "$1" "$2"; reviewed
  on="$(lib_id)"; git config --unset "$1"; off="$(lib_id)"; git config "$1" "$2"
  eval "$3"; git commit --quiet -am "chore: $1"
  check "with $1 set, then the diff id is the one without it, and a commit after a ready review makes pr.sh refuse" \
    '[[ -n "$on" && "$on" == "$off" ]] && fails_with "changed since" "$p" task T001 "feat: edit" "$TMP/body.md"'
  git config --unset "$1"
}
config_case color.ui always 'echo a >> big.txt'
config_case diff.external "$TMP/same.sh" 'echo b >> big.txt'
config_case diff.conv.textconv "$TMP/same.sh" 'echo two > a.conv'
config_case diff.ignoreSubmodules all 'git update-index --cacheinfo "160000,$(git rev-parse HEAD~1),sub"'
config_case diff.interHunkContext 20 'echo c >> big.txt'
config_case diff.suppressBlankEmpty true 'echo d >> big.txt'

# A shallow clone that lost the merge base stops at once: an empty id would pass for an empty diff.
shallow_repo
check "on a --depth 1 clone with no merge base, then pr.sh task prints one refusal naming git fetch --unshallow and opens nothing" \
  ': > "$GH_LOG"; one_refusal "git fetch --unshallow" "$p" task T001 "feat: edit" "$TMP/body.md" && ! grep -q "^pr create" "$GH_LOG"'
cd "$TMP"

# ── FR-009: an open task PR stays true to its diff ──
rm -rf "$TMP/origin.git" "$TMP/repo"; cd "$TMP"; rm -f "$GH_PR"; : > "$GH_LOG"
new_repo standard
commit_tasks '- [ ] T001 Add search in `src/search.ts` — #5'
"$SCRIPTS/branch.sh" T001 >/dev/null
mkdir -p .specify/memory; printf '**Commands**: build `[BUILD_COMMAND]` · test `true` · lint `[LINT_COMMAND]` · mutate `[MUTATE_COMMAND]`\n' > .specify/memory/constitution.md
echo 'export const search = 1' > search.ts; git add search.ts; git commit --quiet -m "feat: search"; reviewed; scanned
"$p" task T001 "feat: search" "$TMP/body.md" >/dev/null 2>&1
echo 'export const more = 2' >> search.ts; git commit --quiet -am "feat: more"; reviewed; scanned
id2="$(source "$SCRIPTS/lib.sh"; diff_id | cut -c1-12)"; : > "$GH_LOG"
out="$("$p" task T001 "feat: search" "$TMP/body.md")"
check "when pr.sh task runs again on an open PR, then the body is updated to the new patch id and no PR is created" \
  'grep -q "^pr edit https://github.com/acme/app/pull/99 --body " "$GH_LOG" && grep -qxF "Independent review recorded for this diff (patch id $id2)" "$GH_LOG" && ! grep -q "^pr create" "$GH_LOG"'
check "then it prints that the body was replaced from the author's file" 'grep -qxF "PR body replaced from $TMP/body.md; edits made on GitHub are gone" <<<"$out"'
edit_rc=0; out="$(GH_FAIL_EDIT=1 "$p" task T001 "feat: search" "$TMP/body.md" 2>"$TMP/pr.err")" || edit_rc=$?
check "when the edit fails, then it prints one refusal naming the PR and no PR= line" \
  '((edit_rc != 0)) && [[ "$(wc -l < "$TMP/pr.err")" -eq 1 ]] && grep -q "^jit: .*https://github.com/acme/app/pull/99" "$TMP/pr.err" && ! grep -q "^PR=" <<<"$out"'
list_rc=0; out="$(GH_FAIL_PR_LIST=1 "$p" task T001 "feat: search" "$TMP/body.md" 2>&1)" || list_rc=$?
check "when the open-PR lookup fails, then it stops after gh's error and creates no PR" \
  '((list_rc != 0)) && grep -q "HTTP 502" <<<"$out" && grep -qxF "jit: could not check for an open PR" <<<"$out" && ! grep -q "^PR=" <<<"$out" && ! grep -q "^pr create" "$GH_LOG"'
printf 'What changed: x\n\n- deep: ghp_abc123\n- deep: Token=abc\n- deep: search.ts\n\n%s\n\nAssessment: ready\n' "$(range)" > "$TMP/review.md"
"$SCRIPTS/review.sh" record "$TMP/review.md" >/dev/null 2>&1; : > "$GH_LOG"
"$p" task T001 "feat: search" "$TMP/body.md" >/dev/null
check "when a report's map names a token outside the diff, then it never reaches the body, and a path in the diff does" \
  '! grep -qE "ghp_abc123|Token=abc" "$GH_LOG" && grep -qxF -- "- deep: search.ts" "$GH_LOG"'

# ── A stale plan review stops pr.sh spec ──
git switch --quiet main; rm -f "$GH_PR"; : > "$GH_LOG"
printf 'Plan read.\n\nModel: claude-sonnet-4-7\n\nAssessment: ready\n' > "$TMP/plan.md"
check "when no plan review was recorded, then pr.sh spec stops and opens nothing" \
  'fails_with "no independent review" "$p" spec && ! grep -q "^pr create" "$GH_LOG"'
"$SCRIPTS/review.sh" record --plan "$TMP/plan.md" >/dev/null
printf '%s\n' '- [ ] T002 Added by analysis in `b`' >> specs/001-demo/tasks.md
printf '## Specification Analysis Report\n\nCoverage Summary Table\n' > "$TMP/analysis.md"; "$SCRIPTS/analyzed.sh" "$TMP/analysis.md" >/dev/null
check "when the analysis changed tasks.md after the plan review, then pr.sh spec stops, pushes nothing and stays on the branch" \
  'fails_with "changed since the last review" "$p" spec && ! grep -q "^pr create" "$GH_LOG" && [[ "$(git branch --show-current)" == main ]] && ! git ls-remote --exit-code origin spec/001-demo'
git checkout --quiet -- specs/001-demo/tasks.md

# ── The spec folder survives a refused branch switch ──
rm -rf "$TMP/origin.git" "$TMP/repo"; cd "$TMP"; rm -f "$GH_PR"
new_repo standard
echo a > app.txt; git add app.txt; git commit --quiet -m app; git push --quiet origin main; git push --quiet origin main:develop
echo b > app.txt; git add app.txt; git commit --quiet -m app2   # local only: HEAD differs from origin/develop...
echo c > app.txt                                                  # ...and an unstaged edit on top: git switch refuses
printf '%s\n' '- [ ] T001 Thing in `a` — #11' > specs/001-demo/tasks.md; echo draft > specs/001-demo/spec.md
"$SCRIPTS/review.sh" record --plan "$TMP/plan.md" >/dev/null
check "when the switch to the spec branch is refused, then it fails and the spec folder is put back untouched" \
  'fails_with "put back" "$p" spec && [[ "$(cat specs/001-demo/spec.md)" == draft && "$(cat specs/001-demo/tasks.md)" == *"#11" && "$(git branch --show-current)" == main ]]'

exit "$FAIL"
