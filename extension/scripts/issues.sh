#!/usr/bin/env bash
# Create one GitHub issue per task in the active feature's tasks.md and append "— #N" to its line.
# Idempotent: tasks that already end in "— #N" are skipped.
# Usage: issues.sh [--dry-run]
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

dry=false; [[ "${1:-}" == --dry-run ]] && dry=true
jit_cd_root
command -v gh >/dev/null || die "the GitHub CLI (gh) is required: https://cli.github.com"

fdir="$(feature_dir)"
tasks="$fdir/tasks.md"
[[ -f "$tasks" ]] || die "$tasks not found; run /speckit-tasks first"
base="$(base_branch)"
feature="$(basename "$fdir")"
num="${feature%%-*}"

IFS=',' read -ra labels <<<"$(cfg issue_labels "type:task")"
if ! $dry; then
  for l in ${labels[@]+"${labels[@]}"}; do if [[ -n "$l" ]]; then gh label create "$l" >/dev/null 2>&1 || true; fi; done
fi
label_args=(); for l in ${labels[@]+"${labels[@]}"}; do if [[ -n "$l" ]]; then label_args+=(--label "$l"); fi; done

created=0; skipped=0
while IFS= read -r line; do
  id="$(sed -E 's/^- \[.\] (T[0-9]{3}) .*/\1/' <<<"$line")"
  if [[ -n "$(task_issue "$line")" ]]; then skipped=$((skipped + 1)); continue; fi

  desc="$(task_desc "$line")"
  title="[$num] $id: $(sed 's/ in `.*//' <<<"$desc")"
  [[ ${#title} -gt 120 ]] && title="${title:0:117}..."
  comes="$(task_field "$fdir" "$id" "Comes from")"
  what="$(task_field "$fdir" "$id" "What")"
  done_when="$(task_field "$fdir" "$id" "Completed when")"
  body="**Feature:** \`$feature\` · **Task:** $id in [\`tasks.md\`](../blob/$base/$tasks)

**Task:** $desc"
  [[ -n "$comes" ]] && body+=$'\n\n'"**Comes from:** $comes"
  [[ -n "$what" ]] && body+=$'\n\n'"**What:** $what"
  [[ -n "$done_when" ]] || done_when="_its tests pass and the change is verified as plan.md describes._"
  body+=$'\n\n'"**Completed when:** $done_when"
  body+=$'\n\n---\n'"**Done** = closed by the merged PR (\`Closes #N\`). Start it with \`/speckit-implement $id\`."

  if $dry; then echo "would create: $title"; created=$((created + 1)); continue; fi
  url="$(gh issue create --title "$title" --body "$body" ${label_args[@]+"${label_args[@]}"})"
  n="${url##*/}"
  # Write the link back immediately so an interrupted run never creates duplicates.
  L="$line" S=" — #$n" awk '!done && $0 == ENVIRON["L"] { print $0 ENVIRON["S"]; done = 1; next } { print }' \
    "$tasks" > "$tasks.tmp" && mv "$tasks.tmp" "$tasks"
  echo "$id → #$n"
  created=$((created + 1))
done < <(grep -E '^- \[.\] T[0-9]{3} ' "$tasks")

echo "CREATED=$created SKIPPED=$skipped"
