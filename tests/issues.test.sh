#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # checks are strings evaluated by check()
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
fake_gh
i="$SCRIPTS/issues.sh"
plan_reviewed() { printf 'Plan read.\n\nAssessment: ready\n' > "$TMP/plan.md"; "$SCRIPTS/review.sh" record --plan "$TMP/plan.md" >/dev/null; }

new_repo standard
commit_tasks '# Tasks

- [ ] T001 Create the schema in `db/schema.sql`
  - Comes from: FR-001
  - Impact: tests/test_schema.py lists every table and
    must include the new one
  - Completed when: `make test` passes
- [ ] T002 [P] [US1] Price * filter [beta] & co in `src/a.ts` — #7
- [ ] T003 [US1] Show prices in src/view.tsx and src/list.tsx, with tests in tests/view.test.ts'

check "when the plan was not reviewed, then no issue is created" 'fails_with "no independent review" "$i" && ! grep -qs "^issue create" "$GH_LOG"'
plan_reviewed
out="$("$i")"
check "when tasks have no issue, then one issue is created per task" '[[ "$(grep -c "^issue create" "$GH_LOG")" == 2 ]]'
check "then each issue number is written at the end of its task line" \
  'grep -qx -- "- \[ \] T001 Create the schema in \`db/schema.sql\` — #1" specs/001-demo/tasks.md && grep -q "T003 \[US1\] Show prices in src/view.tsx and src/list.tsx, with tests in tests/view.test.ts — #2$" specs/001-demo/tasks.md'
check "then a task that already had an issue is left alone" 'grep -qx -- "- \[ \] T002 \[P\] \[US1\] Price \* filter \[beta\] & co in \`src/a.ts\` — #7" specs/001-demo/tasks.md'
check "then it reports what it did" '[[ "$out" == *"CREATED=2 SKIPPED=1"* ]]'
check "then the title has the feature number and no file path, with or without backticks" \
  'grep -qF -- "--title [001] T001: Create the schema --body" "$GH_LOG" && grep -qF -- "--title [001] T003: Show prices --body" "$GH_LOG"'
check "then the body carries Comes from, Impact and Completed when" \
  'grep -qF "**Comes from:** FR-001" "$GH_LOG" && grep -qF "**Impact:** tests/test_schema.py lists every table and must include the new one" "$GH_LOG" && grep -qF "**Completed when:** \`make test\` passes" "$GH_LOG"'
check "then the configured label is applied" 'grep -q -- "--label type:task" "$GH_LOG"'
check "then the user is assigned after creation" '[[ "$(grep -c "^issue edit https://github.com/acme/app/issues/[0-9]* --add-assignee @me" "$GH_LOG")" == 2 ]]'
check "when no milestone or project is configured, then none is set" '! grep -qE -- "--milestone|--add-project" "$GH_LOG"'

out="$("$i")"
check "when run again, then no issue is created twice" '[[ "$out" == *"CREATED=0 SKIPPED=3"* && "$(grep -c "^issue create" "$GH_LOG")" == 2 ]]'

printf '%s\n' '- [ ] T004 Dry task in `x`' >> specs/001-demo/tasks.md
check "when a task was added since the plan review, then it refuses until the plan is reviewed again" 'fails_with "changed since" "$i"'
plan_reviewed
check "when --dry-run, then nothing is created or written" \
  'out="$("$i" --dry-run)"; grep -q "would create" <<<"$out" && [[ "$(grep -c "^issue create" "$GH_LOG")" == 2 ]] && ! grep -q "T004.*#" specs/001-demo/tasks.md'

set_cfg milestone '"Sprint #3"'; set_cfg project '"Road map" # the team board'
printf '%s\n' '- [ ] T005 Meta task in `y`' >> specs/001-demo/tasks.md; plan_reviewed
"$i" >/dev/null
check "when a quoted milestone contains #, then it is kept whole" 'grep -q -- "^issue edit .* --milestone Sprint #3$" "$GH_LOG"'
check "then the project is set, and a trailing comment after the quotes is ignored" 'grep -q -- "^issue edit .* --add-project Road map$" "$GH_LOG"'

set_cfg milestone "'Q4 #2' # single quotes work too"
set_cfg project 'Board # unquoted, comment stripped'
printf '%s\n' '- [ ] T006 Scope task in `z`' >> specs/001-demo/tasks.md; plan_reviewed
out="$(GH_FAIL_EDIT=1 "$i" 2>&1)"
check "when setting metadata fails, then the issue is still created and linked" 'grep -q "T006 Scope task in \`z\` — #[0-9]*$" specs/001-demo/tasks.md'
check "then a single-quoted milestone is read whole, without its quotes" 'grep -q -- "^issue edit .* --milestone Q4 #2$" "$GH_LOG"'
check "then the warning shows gh's own error, for each item that failed" \
  '[[ "$(grep -c "Could not resolve to a ProjectV2" <<<"$out")" == 3 ]] && grep -q "could not set add-project .Board." <<<"$out"'

# F1.7: a create that reached GitHub but failed on the client leaves an open issue with the task's title.
printf '%s\n' '- [ ] T007 Retry task in `r`' >> specs/001-demo/tasks.md; plan_reviewed
GH_FAIL_CREATE_ONCE=1 "$i" >/dev/null 2>&1 || true
lost="$(cat "$GH_N")"; creates="$(grep -c "^issue create" "$GH_LOG")"
check "when the first gh issue create for a task reached GitHub but failed on the client, then a rerun makes no second create and writes the existing number back" \
  'out="$("$i")"; [[ "$(grep -c "^issue create" "$GH_LOG")" == "$creates" ]] && grep -q "T007 Retry task in \`r\` — #$lost$" specs/001-demo/tasks.md && grep -qx "T007 → #$lost (existing)" <<<"$out"'
check "then the lookup asks for open issues only (a closed one never matches), without --search or --label" \
  'grep -q "^issue list --state open --limit 1000 --json number,title" "$GH_LOG" && ! grep "^issue list" "$GH_LOG" | grep -qE -- "--search|--label"'
printf '%s\n' "$((lost + 50)) [001] T008: Regenerated task" > "$GH_CLOSED" # an old issue: same prefix, another summary
printf '%s\n' '- [ ] T008 Brand new summary in `n`' >> specs/001-demo/tasks.md; plan_reviewed
check "when an open issue has the same [NNN] Tnnn: prefix but another summary, then a new issue is created" \
  'out="$("$i")"; [[ "$(grep -c "^issue create" "$GH_LOG")" == "$((creates + 1))" ]] && ! grep -q "#$((lost + 50))" specs/001-demo/tasks.md && grep -q "T008 Brand new summary in \`n\` — #[0-9]*$" specs/001-demo/tasks.md'

exit "$FAIL"
