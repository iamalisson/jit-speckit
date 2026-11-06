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
# F3.1/F4.3: report prints only what the script checked (the patch id and the verdict), never the report's text.
printf 'Preamble LEAK-1\n\n- **What changed**: Adds LEAK-2 search.\n- **Findings**:\n  - High: LEAK-3 in src/a.ts:3\n  - Security: LEAK-4 token logged\n\nAssessment: ready\n' > "$TMP/report.md"
"$r" record "$TMP/report.md" >/dev/null; out="$("$r" report 2>&1)" || true
id="$(sed -n 's/^state: //p' "$(git rev-parse --git-common-dir)/jit-review/task-$(git branch --show-current | sed 's|/|__|g')" | cut -c1-12)"
check "when a review is recorded, then report prints exactly the patch-id line and the Assessment line" \
  '[[ ${#id} == 12 && "$out" == "Independent review recorded for this diff (patch id $id)"$'"'"'\n'"'"'"Assessment: ready" ]]'
check "then report prints nothing from the report body (What changed, findings, the security finding)" \
  '! grep -qiE "LEAK|search|what changed|findings|token" <<<"$out"'
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
