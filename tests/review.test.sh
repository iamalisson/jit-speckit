#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # checks are strings evaluated by check()
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
r="$SCRIPTS/review.sh"
report() { printf 'What changed: x\n\nFindings: none\n\nAssessment: %s\n' "$1" > "$TMP/report.md"; }

new_repo standard
commit_tasks '- [ ] T001 Add search in `src/search.ts` — #5'
"$SCRIPTS/branch.sh" T001 >/dev/null
echo 'export const search = 1' > search.ts; git add search.ts; git commit --quiet -m "feat: search"

check "when no review was recorded, then check refuses and says how to record one" 'fails_with "no independent review" "$r" check'
printf 'Looks fine to me.\n' > "$TMP/report.md"
check "when the report has no assessment line, then it is refused" 'fails_with "Assessment" "$r" record "$TMP/report.md"'
report "changes needed"
check "when the review said changes needed, then check refuses" '"$r" record "$TMP/report.md" && fails_with "changes needed" "$r" check'
report ready
check "when the review said ready on this diff, then check passes" '"$r" record "$TMP/report.md" | grep -q "^REVIEW=ready" && "$r" check'
echo 'export const more = 2' >> search.ts; git commit --quiet -am "feat: more"
check "when the code changed after the review, then check refuses until a new review is recorded" \
  'fails_with "changed since" "$r" check && "$r" record "$TMP/report.md" >/dev/null && "$r" check'
echo dirty > search.ts
check "when the tree is dirty, then record refuses (the review is of the committed diff)" 'fails_with "commit the work first" "$r" record "$TMP/report.md"'
git checkout --quiet -- search.ts
# The base moves on with unrelated work; merging it changes the diff's text but not its content.
git switch --quiet main; echo x > other.txt; git add other.txt; git commit --quiet -m other; git push --quiet origin main:develop; git switch --quiet -
git fetch --quiet origin; git merge --quiet --no-edit origin/develop >/dev/null
check "when the base is merged in without touching the change, then the review still holds" '"$r" check'

# Plan review: tied to tasks.md, ignoring the issue numbers issues.sh appends.
git switch --quiet main
check "when no plan review was recorded, then check --plan refuses" 'fails_with "no independent review" "$r" check --plan'
report ready
check "when the plan review said ready, then check --plan passes" '"$r" record --plan "$TMP/report.md" >/dev/null && "$r" check --plan'
sed -i.bak 's/ — #5$/ — #9/' specs/001-demo/tasks.md
check "when only the issue numbers changed, then the plan review still holds" '"$r" check --plan'
printf '%s\n' '- [ ] T002 New task in `b`' >> specs/001-demo/tasks.md
check "when a task was added, then the plan needs a new review" 'fails_with "changed since" "$r" check --plan'

exit "$FAIL"
