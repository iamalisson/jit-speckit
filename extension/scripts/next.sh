#!/usr/bin/env bash
# Show the active feature's progress and the next task to implement.
# A task is done when its GitHub issue is closed; the next task is the first one, in tasks.md order,
# whose issue is still open.
# Prints a line per task ("done|open|no-issue Tnnn #N description"), then NEXT=<Tnnn> (empty when all done).
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

jit_cd_root
command -v gh >/dev/null || die "the GitHub CLI (gh) is required: https://cli.github.com"
fdir="$(feature_dir)"
[[ -f "$fdir/tasks.md" ]] || die "$fdir/tasks.md not found; run /speckit-tasks first"

# One API call for every issue state, instead of one call per task.
closed=" $(gh issue list --state closed --limit 1000 --json number --jq '.[].number' | tr '\n' ' ') "

next=""; done_n=0; total=0
while IFS= read -r line; do
  id="$(sed -E 's/^- \[.\] (T[0-9]{3}) .*/\1/' <<<"$line")"
  issue="$(task_issue "$line")"
  total=$((total + 1))
  if [[ -z "$issue" ]]; then state=no-issue
  elif [[ "$closed" == *" $issue "* ]]; then state="done"; done_n=$((done_n + 1))
  else state=open; [[ -n "$next" ]] || next="$id"
  fi
  echo "$state $id ${issue:+#$issue} $(task_desc "$line" | sed 's/ in `.*//')"
done < <(grep -E '^- \[.\] T[0-9]{3} ' "$fdir/tasks.md")

echo "DONE=$done_n/$total NEXT=$next"
