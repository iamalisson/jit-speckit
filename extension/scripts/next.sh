#!/usr/bin/env bash
# Show the active feature's progress and the next task to implement.
# A task is done when its GitHub issue is closed; the next task is the first one, in tasks.md order,
# whose issue is still open.
# A task whose branch has an open PR is in progress (here or in another worktree) and is not picked again.
# Prints a line per task ("done|open|in-progress|no-issue Tnnn #N description"), then
# DONE=x/y IN_PROGRESS=n NEXT=<Tnnn> (NEXT empty when nothing is left to start).
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

jit_cd_root
command -v gh >/dev/null || die "the GitHub CLI (gh) is required: https://cli.github.com"
fdir="$(feature_dir)"
[[ -f "$fdir/tasks.md" ]] || die "$fdir/tasks.md not found; run /speckit-tasks first"

# One API call: this feature's task issues (their titles start with "[<feature number>] T"),
# so a repository with thousands of issues doesn't push old ones out of the result.
num="$(feature_key "$fdir")"
closed=" $(gh issue list --state closed --limit 500 --search "$num in:title" --json number --jq '.[].number' | tr '\n' ' ') "
# Open PRs by head branch: a task branch (<prefix>/<feature>-t003-...) with one is being worked on.
heads=" $(gh pr list --state open --limit 500 --json headRefName --jq '.[].headRefName' 2>/dev/null | tr '\n' ' ') "

next=""; done_n=0; total=0; busy=0
while IFS= read -r line; do
  id="$(sed -E 's/^- \[.\] (T[0-9]{3,}) .*/\1/' <<<"$line")"
  issue="$(task_issue "$line")"
  total=$((total + 1))
  if [[ -z "$issue" ]]; then state=no-issue
  elif [[ "$closed" == *" $issue "* ]]; then state="done"; done_n=$((done_n + 1))
  elif [[ "$heads" == *"/$num-$(tr '[:upper:]' '[:lower:]' <<<"$id")-"* ]]; then state=in-progress; busy=$((busy + 1))
  else state=open; [[ -n "$next" ]] || next="$id"
  fi
  echo "$state $id ${issue:+#$issue} $(task_summary "$line")"
done < <(grep -E '^- \[.\] T[0-9]{3,} ' "$fdir/tasks.md")

echo "DONE=$done_n/$total IN_PROGRESS=$busy NEXT=$next"
