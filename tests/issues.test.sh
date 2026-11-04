#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # checks are strings evaluated by check()
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
fake_gh
i="$SCRIPTS/issues.sh"

new_repo standard
commit_tasks '# Tasks

- [ ] T001 Create the schema in `db/schema.sql`
  - Comes from: FR-001
  - Completed when: `make test` passes
- [ ] T002 [P] [US1] Price * filter [beta] & co in `src/a.ts` — #7
- [ ] T003 [US1] Show prices in src/view.tsx'

out="$("$i")"
check "when tasks have no issue, then one issue is created per task" '[[ "$(grep -c "^issue create" "$GH_LOG")" == 2 ]]'
check "then each issue number is written at the end of its task line" \
  'grep -qx -- "- \[ \] T001 Create the schema in \`db/schema.sql\` — #1" specs/001-demo/tasks.md && grep -q "T003 \[US1\] Show prices in src/view.tsx — #2$" specs/001-demo/tasks.md'
check "then a task that already had an issue is left alone" 'grep -qx -- "- \[ \] T002 \[P\] \[US1\] Price \* filter \[beta\] & co in \`src/a.ts\` — #7" specs/001-demo/tasks.md'
check "then it reports what it did" '[[ "$out" == *"CREATED=2 SKIPPED=1"* ]]'
check "then the title has the feature number and no file path" 'grep -qF -- "--title [001] T001: Create the schema " "$GH_LOG"'
check "then the body carries Comes from and Completed when" 'grep -qF "**Comes from:** FR-001" "$GH_LOG" && grep -qF "**Completed when:** \`make test\` passes" "$GH_LOG"'
check "then the configured label is applied" 'grep -q -- "--label type:task" "$GH_LOG"'

out="$("$i")"
check "when run again, then no issue is created twice" '[[ "$out" == *"CREATED=0 SKIPPED=3"* && "$(grep -c "^issue create" "$GH_LOG")" == 2 ]]'

printf '%s\n' '- [ ] T004 Dry task in `x`' >> specs/001-demo/tasks.md
check "when --dry-run, then nothing is created or written" \
  'out="$("$i" --dry-run)"; grep -q "would create" <<<"$out" && [[ "$(grep -c "^issue create" "$GH_LOG")" == 2 ]] && ! grep -q "T004.*#" specs/001-demo/tasks.md'

exit "$FAIL"
