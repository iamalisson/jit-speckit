#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # checks are strings evaluated by check()
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
r="$SCRIPTS/review.sh"
# Every task report states its range (the merge-base with the base, then HEAD) and the reviewer's model.
range() { echo "Reviewed: $(git merge-base HEAD origin/develop)..$(git rev-parse HEAD)"; }
report() { printf 'What changed: x\n\nFindings: none\n\n%s\nModel: claude-opus-4-7\n\nAssessment: %s\n' "$(range)" "$1" > "$TMP/report.md"; }

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
printf 'Assessment: changes needed\n\nmy risk assessment is that the retry path is already covered\n%s\nModel: claude-opus-4-7\n' "$(range)" > "$TMP/report.md"
check "when prose after the verdict mentions ready, then the verdict still counts" '"$r" record "$TMP/report.md" | grep -q "^REVIEW=changes needed"'
report "changes needed"
check "when the review said changes needed, then check refuses" '"$r" record "$TMP/report.md" && fails_with "changes needed" "$r" check'
report ready
check "when the review said ready on this diff, then check passes" '"$r" record "$TMP/report.md" | grep -q "^REVIEW=ready" && "$r" check'
# F3.1/F4.3: report prints only what the script checked (the patch id and the verdict), never the report's text.
printf 'Preamble LEAK-1\n\n- **What changed**: Adds LEAK-2 search.\n- **Findings**:\n  - High: LEAK-3 in src/a.ts:3\n  - Security: LEAK-4 token logged\n\n%s\nModel: claude-opus-4-7\n\nAssessment: ready\n' "$(range)" > "$TMP/report.md"
"$r" record "$TMP/report.md" >/dev/null; out="$("$r" report 2>&1)" || true
id="$(sed -n 's/^state: //p' "$(git rev-parse --git-common-dir)/jit-review/task-$(git branch --show-current | sed 's|/|__|g')" | cut -c1-12)"
check "when a review is recorded, then report prints exactly the patch-id line, the Assessment line and the Model line" \
  '[[ ${#id} == 12 && "$out" == "Independent review recorded for this diff (patch id $id)"$'"'"'\n'"'"'"Assessment: ready"$'"'"'\n'"'"'"Model: claude-opus-4-7" ]]'
check "then report prints nothing from the report body (What changed, findings, the security finding)" \
  '! grep -qiE "LEAK|search|what changed|findings|token" <<<"$out"'
report "changes needed"; "$r" record "$TMP/report.md" >/dev/null
check "when the review said changes needed, then report refuses as check does" 'fails_with "changes needed" "$r" report'
report ready; "$r" record "$TMP/report.md" >/dev/null
echo 'export const more = 2' >> search.ts; git commit --quiet -am "feat: more"
check "when the code changed after the review, then check refuses until a new review is recorded" \
  'fails_with "changed since" "$r" check && report ready && "$r" record "$TMP/report.md" >/dev/null && "$r" check'
printf 'export const search = 1\n    export const more = 2\n' > search.ts; git commit --quiet -am "style: indent"
check "when a commit only re-indents a line, then the diff counts as changed (whitespace matters)" 'fails_with "changed since" "$r" check'
report ready; "$r" record "$TMP/report.md" >/dev/null
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
printf 'Plan read.\n\nAssessment: ready\n' > "$TMP/plan.md"
check "when a plan report has no Model: line, then record --plan refuses" \
  'fails_with "the report must state Model: <id> for the plan: run the review again" "$r" record --plan "$TMP/plan.md"'

# ── FR-030/FR-031: the risk map sets the minimum depth ──
rm -rf "$TMP/origin.git" "$TMP/repo"; cd "$TMP"
new_repo standard
commit_tasks '- [ ] T001 Add search in `src/search.ts` — #5'
"$SCRIPTS/branch.sh" T001 >/dev/null
echo 'export const search = 1' > search.ts; git add search.ts; git commit --quiet -m "feat: search"
# rep <assessment> <line...>: a full-round report for HEAD with the given lines (risk map, findings).
rep() { local v="$1"; shift; { echo 'What changed: x'; echo; printf '%s\n' "$@"; echo; range; echo 'Model: claude-opus-4-7'; echo; echo "Assessment: $v"; } > "$TMP/report.md"; }
# drep <assessment> <from> <line...>: a delta report reviewing <from>..HEAD.
drep() { local v="$1" f="$2"; shift 2; { echo 'What changed: y'; echo; printf '%s\n' "$@"; echo; echo "Delta from: $f"; echo "Reviewed: $f..$(git rev-parse HEAD)"; echo 'Model: claude-opus-4-7'; echo; echo "Assessment: $v"; } > "$TMP/report.md"; }
check "when the diff touches nothing risky, then review.sh risk prints exactly RISK=none" '[[ "$("$r" risk)" == RISK=none ]]'
drep ready "$(git rev-parse HEAD)"
check "when no full review was recorded for the branch, then record --delta refuses" \
  'fails_with "a delta follows a recorded full review of this branch: run a new full review, then record it with review.sh record <report-file>" "$r" record --delta "$TMP/report.md"'
check "when record --plan --delta is used, then it is refused" \
  'fails_with "a plan review is always full: review.sh record --plan <report-file>" "$r" record --plan --delta "$TMP/report.md"'
check "when review.sh risk --plan runs, then it refuses" 'fails_with "risk maps a diff; a plan review has none" "$r" risk --plan'

mkdir -p db/migrations src tests
printf 'DROP TABLE users;\n' > db/migrations/002_drop.sql; echo 'def can(u): return True' > src/authorization.py
printf 'make x || true\n' > build.sh; printf 'assert 1\nassert 2\nassert 3\n' > tests/drop.test.sh
git add db src build.sh tests; git commit --quiet -m "feat: risky"
check "when the diff adds db/migrations/002_drop.sql with DROP TABLE, then risk prints RISK=migration and RISK=delete for it" \
  'out="$("$r" risk)"; grep -qx "RISK=migration db/migrations/002_drop.sql" <<<"$out" && grep -qx "RISK=delete db/migrations/002_drop.sql" <<<"$out"'
check "when the diff adds src/authorization.py, then risk prints RISK=auth for it" '"$r" risk | grep -qx "RISK=auth src/authorization.py"'
check "when an added line swallows a failure (x || true), then risk prints RISK=gate for its file" '"$r" risk | grep -qx "RISK=gate build.sh"'
check "then risk prints only paths and categories, never the line content" '! "$r" risk | grep -qiE "drop table|make x"'
deep=("- deep: src/authorization.py — always allows: checked the callers" "- deep: build.sh")
rep ready "${deep[@]}"
check "when the report has no '- deep:' line for a risky path, then record refuses and names the path" \
  'fails_with "the report does not check db/migrations/002_drop.sql (" "$r" record "$TMP/report.md"'
rep ready "${deep[@]}" "- deep: db/migrations/002_drop.sql.bak"
check "when a '- deep:' line names a longer path (002_drop.sql.bak), then it does not cover 002_drop.sql" \
  'fails_with "the report does not check db/migrations/002_drop.sql (" "$r" record "$TMP/report.md"'
rep ready "${deep[@]}" "- proven: db/migrations/002_drop.sql"
check "when a '- proven:' line names no test, then record refuses" \
  'fails_with "db/migrations/002_drop.sql is not proven by <file>:<n> (not a test file, or no such line): check it deep or name the test" "$r" record "$TMP/report.md"'
rep ready "${deep[@]}" "- proven: db/migrations/002_drop.sql by search.ts:1"
check "when a '- proven:' line names a file that is not a test, then record refuses" \
  'fails_with "db/migrations/002_drop.sql is not proven by search.ts:1 (not a test file" "$r" record "$TMP/report.md"'
rep ready "${deep[@]}" "- proven: db/migrations/002_drop.sql by tests/drop.test.sh:4"
check "when a '- proven:' line names a line past the test file's end, then record refuses" \
  'fails_with "db/migrations/002_drop.sql is not proven by tests/drop.test.sh:4" "$r" record "$TMP/report.md"'
rep ready "${deep[@]}" "- proven: db/migrations/002_drop.sql by tests/drop.test.sh:3 — asserts the drop is guarded"
check "when every risky path is deep or proven by an existing test line, then record prints REVIEWED=<HEAD> then REVIEW=ready, and check passes" \
  'out="$("$r" record "$TMP/report.md")"; [[ "$out" == "$(printf "REVIEWED=%s\nREVIEW=ready" "$(git rev-parse HEAD)")" ]] && "$r" check'

# Every report states its range and model; plain record takes only a full one.
mb="$(git merge-base HEAD origin/develop)"; all=("${deep[@]}" "- deep: db/migrations/002_drop.sql")
range_msg="the report must state Reviewed: <from>..<head> and Model: <id> for $mb..$(git rev-parse HEAD): run the review again"
rep ready "${all[@]}"; sed -i.bak '/^Reviewed: /d' "$TMP/report.md"
check "when a report has no Reviewed: line, then record refuses" 'fails_with "$range_msg" "$r" record "$TMP/report.md"'
rep ready "${all[@]}"; sed -i.bak '/^Model: /d' "$TMP/report.md"
check "when a report has no Model: line, then record refuses" 'fails_with "$range_msg" "$r" record "$TMP/report.md"'
rep ready "${all[@]}"; sed -i.bak "s/^Reviewed: [0-9a-f]*\.\./Reviewed: $(git rev-parse HEAD~1)../" "$TMP/report.md"
check "when the range does not start at the merge-base with the base, then record refuses" 'fails_with "$range_msg" "$r" record "$TMP/report.md"'
rep ready "${all[@]}"; sed -i.bak "s/\.\.[0-9a-f]*$/..$(git rev-parse HEAD~1)/" "$TMP/report.md"
check "when the range does not end at HEAD (a commit made while the review ran), then record refuses" 'fails_with "$range_msg" "$r" record "$TMP/report.md"'
rep ready "${all[@]}" "Delta from: $(git rev-parse HEAD)"
check "when a report with a Delta from: line is recorded without --delta, then record refuses" \
  'fails_with "this is a delta report: record it with --delta, or run a new full review" "$r" record "$TMP/report.md"'

# The model the review ran on: a warning, stored in the record, never a silent downgrade.
warn() { echo "jit: warning: $1; the review did not run on the configured model"; }
rep ready "${all[@]}"; sed -i.bak 's/^Model: .*/Model: claude-haiku-4-5/' "$TMP/report.md"
check "when review_model is unset or opus and Model: is claude-haiku-4-5, then record prints exactly one warning, the review ran on <id>" \
  'err="$("$r" record "$TMP/report.md" 2>&1 >/dev/null)"; [[ "$err" == "$(warn "the review ran on claude-haiku-4-5")" ]] \
   && echo "review_model: opus" >> .specify/extensions/jit/jit-config.yml && err="$("$r" record "$TMP/report.md" 2>&1 >/dev/null)" \
   && [[ "$err" == "$(warn "the review ran on claude-haiku-4-5")" ]]'
check "when CLAUDE_CODE_SUBAGENT_MODEL_FORCE is set, then its reason wins over an outside-family model (one line)" \
  'err="$(CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1 "$r" record "$TMP/report.md" 2>&1 >/dev/null)"; [[ "$err" == "$(warn "CLAUDE_CODE_SUBAGENT_MODEL_FORCE is set")" ]]'
sed -i.bak '/^review_model:/d' .specify/extensions/jit/jit-config.yml; echo "review_model: sonnet" >> .specify/extensions/jit/jit-config.yml
rep ready "${all[@]}"
check "when Model: is opus and review_model is sonnet, then record warns the review ran on <id>, not sonnet" \
  'err="$("$r" record "$TMP/report.md" 2>&1 >/dev/null)"; [[ "$err" == "$(warn "the review ran on claude-opus-4-7, not sonnet")" ]]'
sed -i.bak '/^review_model:/d' .specify/extensions/jit/jit-config.yml; echo "review_model: haiku" >> .specify/extensions/jit/jit-config.yml
check "when review_model is haiku, then record refuses (the config cannot lower the bar)" \
  'fails_with "jit: review_model must be sonnet, opus or fable" "$r" record "$TMP/report.md"'
sed -i.bak '/^review_model:/d' .specify/extensions/jit/jit-config.yml

# ── FR-032/FR-033: delta rounds ──
rep ready "${all[@]}"; "$r" record "$TMP/report.md" >/dev/null || true
drep ready "$(git rev-parse HEAD)" "${all[@]}"
check "when nothing was committed since the last full review, then record --delta refuses" \
  'fails_with "nothing was committed since the last review ($(git rev-parse HEAD)): commit the fixes, then run the delta review" "$r" record --delta "$TMP/report.md"'
rep "changes needed" "${all[@]}" "Findings:" "- High: search.ts:1 the search is wrong"
"$r" record "$TMP/report.md" >/dev/null || true; h1="$(git rev-parse HEAD)"
seq 1 25 | sed 's/^/export const s/; s/$/ = 1/' >> search.ts; seq 1 30 | sed 's/^/assert /' > tests/search.test.ts
git add search.ts tests/search.test.ts; git commit --quiet -m "fix: search"
drep ready "$h1"; sed -i.bak '/^Delta from: /d' "$TMP/report.md"
check "when a delta report has no Delta from: line, then record --delta refuses" \
  'fails_with "a delta report names its base: Delta from: $h1; run the delta review again" "$r" record --delta "$TMP/report.md"'
drep ready "$mb"
check "when Delta from: names another commit than the recorded head, then record --delta refuses" \
  'fails_with "the delta must review $h1..HEAD (Reviewed: $h1..$(git rev-parse HEAD)): run the delta review again from $h1" "$r" record --delta "$TMP/report.md"'
drep ready "$h1"; sed -i.bak "s/^Reviewed: [0-9a-f]*\.\./Reviewed: $mb../" "$TMP/report.md"
check "when a delta's range starts elsewhere, then record --delta prints exactly one refusal line, the delta one" \
  'err="$("$r" record --delta "$TMP/report.md" 2>&1)" && exit 1; [[ "$err" == "jit: the delta must review $h1..HEAD (Reviewed: $h1..$(git rev-parse HEAD)): run the delta review again from $h1" ]]'
drep ready "$h1"; sed -i.bak '/^Model: /d' "$TMP/report.md"
check "when a delta report has no Model: line, then record --delta refuses" \
  'fails_with "the report must state Reviewed: <from>..<head> and Model: <id> for $h1..$(git rev-parse HEAD)" "$r" record --delta "$TMP/report.md"'
drep ready "$h1" "round: full"
check "when the fix changes 25 lines of a findings file plus a new 30-line test, then a ready delta is recorded and check passes on the whole diff" \
  'out="$("$r" record --delta "$TMP/report.md")"; [[ "$out" == "$(printf "REVIEWED=%s\nREVIEW=ready" "$(git rev-parse HEAD)")" ]] && "$r" check'
check "when the last round was a delta (its body has a line round: full), then another --delta is refused" \
  'fails_with "a delta follows a recorded full review" "$r" record --delta "$TMP/report.md"'

rep "changes needed" "${all[@]}" "Findings:" "- High: search.ts:1 still wrong"
"$r" record "$TMP/report.md" >/dev/null || true; h2="$(git rev-parse HEAD)"
seq 1 21 | sed 's/^/export const o/; s/$/ = 1/' > other.ts; git add other.ts; git commit --quiet -m "fix: other"
drep ready "$h2"
check "when the fix adds 21 lines to a file outside the previous findings, then record --delta refuses and check still refuses" \
  'fails_with "the delta changes 21 lines outside the previous findings (limit 20): run a new full review" "$r" record --delta "$TMP/report.md" && fails_with "changed since" "$r" check'
git reset --quiet --hard "$h2"
echo 'DROP TABLE orders;' >> db/migrations/002_drop.sql; git commit --quiet -am "fix: drop orders"
drep ready "$h2"
check "when the fix adds DROP TABLE to a path round 1 marked deep and the delta has no '- deep:' for it, then record --delta refuses" \
  'fails_with "the report does not check db/migrations/002_drop.sql (" "$r" record --delta "$TMP/report.md"'
drep ready "$h2" "- deep: db/migrations/002_drop.sql — drops orders: checked"
check "when the delta deep-checks it, then the delta is recorded and report lists both labeled risk maps, paths only" \
  '"$r" record --delta "$TMP/report.md" >/dev/null && out="$("$r" report)" && grep -A3 -x "Risk map (round 1)" <<<"$out" | grep -qx -- "- deep: build.sh" \
   && grep -A1 -x "Risk map (fix round)" <<<"$out" | grep -qx -- "- deep: db/migrations/002_drop.sql" && ! grep -qE "drops|checked|always allows" <<<"$out"'

rep ready "${all[@]}"; "$r" record "$TMP/report.md" >/dev/null || true; h3="$(git rev-parse HEAD)"
git reset --quiet --hard HEAD~1; git commit --quiet --amend -m rewritten
drep ready "$h3"
check "when the last reviewed commit is no longer on the branch (rebased), then record --delta refuses" \
  'fails_with "$h3 is no longer on this branch (rebased?): run a new full review" "$r" record --delta "$TMP/report.md"'

exit "$FAIL"
