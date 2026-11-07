#!/usr/bin/env bash
# Create one GitHub issue per task in the active feature's tasks.md and append "— #N" to its line.
# Idempotent: tasks that already end in "— #N" are skipped.
# Usage: issues.sh [--dry-run]
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

dry=false; [[ "${1:-}" == --dry-run ]] && dry=true
landspec_cd_root
command -v gh >/dev/null || die "the GitHub CLI (gh) is required: https://cli.github.com"

fdir="$(feature_dir)"
tasks="$fdir/tasks.md"
[[ -f "$tasks" ]] || die "$tasks not found; run /speckit-tasks first"
# The plan review (/speckit-landspec-review, plan mode) has to have read this tasks.md: issue bodies
# are the task lines, so they are right before any issue exists. Its model warning, if any, is said here too.
if ! $dry; then
  bash "$LANDSPEC_EXT_DIR/scripts/review.sh" report --plan | sed -n 's/^warning: /landspec: warning: /p' >&2
fi
base="$(base_branch)"
feature="$(basename "$fdir")"
num="$(feature_key "$feature")"

IFS=',' read -ra labels <<<"$(cfg issue_labels "type:task")"
if ! $dry; then
  for l in ${labels[@]+"${labels[@]}"}; do if [[ -n "$l" ]]; then gh label create "$l" >/dev/null 2>&1 || true; fi; done
fi
label_args=(); for l in ${labels[@]+"${labels[@]}"}; do if [[ -n "$l" ]]; then label_args+=(--label "$l"); fi; done

# A create that reached GitHub but failed on the client left an open issue with the task's exact
# title: reuse it. No --search or --label: they switch gh to the search API, which lags behind.
# shortcut: 1000 open issues, the newest first; page through them if a repo ever has more open
existing=""
if ! $dry; then
  existing="$(gh issue list --state open --limit 1000 --json number,title --jq '.[] | "\(.number) \(.title)"')" \
    || die "cannot list the repository's issues to avoid duplicates"
fi

# link <task line> <n>: append "— #n" to that line, at once, so an interrupted run never creates
# duplicates.
link() {
  L="$1" S=" — #$2" awk '!done && $0 == ENVIRON["L"] { print $0 ENVIRON["S"]; done = 1; next } { print }' \
    "$tasks" > "$tasks.tmp" && mv "$tasks.tmp" "$tasks"
}

created=0; skipped=0
while IFS= read -r line; do
  id="$(sed -E 's/^- \[.\] (T[0-9]{3,}) .*/\1/' <<<"$line")"
  if [[ -n "$(task_issue "$line")" ]]; then skipped=$((skipped + 1)); continue; fi

  desc="$(task_desc "$line")"
  title="[$num] $id: $(task_summary "$line")"
  [[ ${#title} -gt 120 ]] && title="${title:0:117}..."
  comes="$(task_field "$fdir" "$id" "Comes from")"
  what="$(task_field "$fdir" "$id" "What")"
  done_when="$(task_field "$fdir" "$id" "Completed when")"
  impact="$(task_field "$fdir" "$id" "Impact")"
  body="**Feature:** \`$feature\` · **Task:** $id in [\`tasks.md\`](../blob/$base/$tasks)

**Task:** $desc"
  [[ -n "$comes" ]] && body+=$'\n\n'"**Comes from:** $comes"
  [[ -n "$what" ]] && body+=$'\n\n'"**What:** $what"
  [[ -n "$impact" ]] && body+=$'\n\n'"**Impact:** $impact"
  [[ -n "$done_when" ]] || done_when="_its tests pass and the change is verified as plan.md describes._"
  body+=$'\n\n'"**Completed when:** $done_when"
  body+=$'\n\n---\n'"**Done** = closed by the merged PR (\`Closes #N\`). Start it with \`/speckit-implement $id\`."

  if $dry; then echo "would create: $title"; created=$((created + 1)); continue; fi
  n="$(T="$title" awk '{ n = $1; sub(/^[^ ]+ /, ""); if ($0 == ENVIRON["T"]) { print n; exit } }' <<<"$existing")"
  if [[ -n "$n" ]]; then
    link "$line" "$n"; add_meta issue "$n"
    echo "$id → #$n (existing)"; skipped=$((skipped + 1)); continue
  fi
  url="$(gh issue create --title "$title" --body "$body" ${label_args[@]+"${label_args[@]}"})"
  n="${url##*/}"
  link "$line" "$n"
  add_meta issue "$url"
  echo "$id → #$n"
  created=$((created + 1))
done < <(grep -E '^- \[.\] T[0-9]{3,} ' "$tasks")

echo "CREATED=$created SKIPPED=$skipped"
