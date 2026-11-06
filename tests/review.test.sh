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
check "when no task review was recorded on a task branch, then the hint is review.sh record <report-file>, without --plan" \
  'fails_with "record its report: review.sh record <report-file>" "$r" check'
printf 'Looks fine to me.\n' > "$TMP/report.md"
check "when the report has no assessment line, then it is refused" 'fails_with "Assessment" "$r" record "$TMP/report.md"'
printf 'Assessment: not ready, changes needed\n' > "$TMP/report.md"
check "when the verdict is not the exact line (not ready, already), then it is refused" 'fails_with "exactly" "$r" record "$TMP/report.md"'
printf 'Assessment: changes needed\n\nmy risk assessment is that the retry path is already covered\n' > "$TMP/report.md"
check "when prose after the verdict mentions ready, then the verdict still counts" '"$r" record "$TMP/report.md" | grep -q "^REVIEW=changes needed"'
report "changes needed"
check "when the review said changes needed, then check refuses" '"$r" record "$TMP/report.md" && fails_with "changes needed" "$r" check'
report ready
check "when the review said ready on this diff, then check passes" '"$r" record "$TMP/report.md" | grep -q "^REVIEW=ready" && "$r" check'
# F3.1/F4.3: report prints What changed and the Assessment line, and never a finding, wherever it is.
printf 'Preamble: FINDING-1 before the marker\n\n- **What changed**: Adds search.\n  Wraps here.\n- **Findings**, ranked:\n  - High: FINDING-2 in src/a.ts:3\n\nAssessment: ready\n' > "$TMP/report.md"
"$r" record "$TMP/report.md" >/dev/null; out="$("$r" report 2>&1)" || true
check "when a review is recorded, then report prints its What changed and its Assessment line" \
  '[[ "$out" == "- **What changed**: Adds search."$'"'"'\n'"'"'"  Wraps here."$'"'"'\n\n'"'"'"Assessment: ready" ]]'
check "then report copies no finding, before or after the Findings marker" '! grep -q FINDING <<<"$out"'
printf '## What changed\n\nAdds search.\n\nFINDING-3 in src/auth.ts:9, with no Findings marker\n\nAssessment: ready\n' > "$TMP/report.md"
"$r" record "$TMP/report.md" >/dev/null; out="$("$r" report 2>&1)" || true
check "when the report has no Findings marker, then report copies only What changed's paragraph" \
  'grep -qx "Adds search." <<<"$out" && grep -qx "Assessment: ready" <<<"$out" && ! grep -q FINDING <<<"$out"'
printf 'What changed: Adds search.\n\nFINDING-8 in its own paragraph\n\nAssessment: ready\n' > "$TMP/report.md"
"$r" record "$TMP/report.md" >/dev/null; out="$("$r" report 2>&1)" || true
check "when an unlabeled paragraph follows a one-line What changed, then report stops at the blank line" \
  'grep -qx "What changed: Adds search." <<<"$out" && ! grep -q FINDING <<<"$out"'
printf 'What changed: Adds search.\nHigh: FINDING-4 in src/a.ts:3\nSecurity: FINDING-5\n\nAssessment: ready\n' > "$TMP/report.md"
"$r" record "$TMP/report.md" >/dev/null; out="$("$r" report 2>&1)" || true
check "when a finding follows What changed with no blank line, then report stops before it" \
  'grep -qx "What changed: Adds search." <<<"$out" && ! grep -q FINDING <<<"$out"'
printf 'What changed: one\ntwo\nthree\nFINDING-7 as a fourth line\n\nAssessment: ready\n' > "$TMP/report.md"
"$r" record "$TMP/report.md" >/dev/null; out="$("$r" report 2>&1)" || true
check "when What changed runs past three lines, then report keeps the first three only" \
  'grep -qx three <<<"$out" && ! grep -q FINDING <<<"$out"'
printf 'FINDING-6 only, no What changed\n\nAssessment: ready\n' > "$TMP/report.md"
"$r" record "$TMP/report.md" >/dev/null; out="$("$r" report 2>&1)" || true
check "when the report has no What changed, then report prints only the Assessment line" '[[ "$out" == "Assessment: ready" ]]'
report "changes needed"; "$r" record "$TMP/report.md" >/dev/null
check "when the review said changes needed, then report refuses as check does" 'fails_with "changes needed" "$r" report'
report ready; "$r" record "$TMP/report.md" >/dev/null
echo 'export const more = 2' >> search.ts; git commit --quiet -am "feat: more"
check "when the code changed after the review, then check refuses until a new review is recorded" \
  'fails_with "changed since" "$r" check && "$r" record "$TMP/report.md" >/dev/null && "$r" check'
printf 'export const search = 1\n    export const more = 2\n' > search.ts; git commit --quiet -am "style: indent"
check "when a commit only re-indents a line, then the diff counts as changed (whitespace matters)" 'fails_with "changed since" "$r" check'
"$r" record "$TMP/report.md" >/dev/null
echo dirty > search.ts
check "when tracked files are dirty, then record refuses (the review is of the committed diff)" 'fails_with "commit the work first" "$r" record "$TMP/report.md"'
git checkout --quiet -- search.ts
echo note > notes.txt
check "when only untracked files exist (the report itself, say), then record still works" '"$r" record "$TMP/report.md" >/dev/null'
rm notes.txt
git checkout --quiet --detach
check "when HEAD is detached, then record and check refuse" 'fails_with "not on a branch" "$r" check && fails_with "not on a branch" "$r" record "$TMP/report.md"'
git switch --quiet -
# The base moves on with unrelated work; merging it changes the diff's text but not its content.
git switch --quiet main; echo x > other.txt; git add other.txt; git commit --quiet -m other; git push --quiet origin main:develop; git switch --quiet -
git fetch --quiet origin; git merge --quiet --no-edit origin/develop >/dev/null
check "when the base is merged in without touching the change, then the review still holds" '"$r" check'

# Plan review: tied to tasks.md, ignoring the issue numbers issues.sh appends.
git switch --quiet main
check "when no plan review was recorded, then check --plan refuses" 'fails_with "no independent review" "$r" check --plan'
check "then the plan hint keeps --plan" 'fails_with "record its report: review.sh record --plan <report-file>" "$r" check --plan'
report ready
check "when the plan review said ready, then check --plan passes" '"$r" record --plan "$TMP/report.md" >/dev/null && "$r" check --plan'
sed -i.bak 's/ — #5$/ — #9/' specs/001-demo/tasks.md
check "when only the issue numbers changed, then the plan review still holds" '"$r" check --plan'
echo '# Plan: data model changed' > specs/001-demo/plan.md
check "when plan.md changed, then the plan needs a new review" 'fails_with "changed since" "$r" check --plan'
"$r" record --plan "$TMP/report.md" >/dev/null
printf '%s\n' '- [ ] T002 New task in `b`' >> specs/001-demo/tasks.md
check "when a task was added, then the plan needs a new review" 'fails_with "changed since" "$r" check --plan'

exit "$FAIL"
