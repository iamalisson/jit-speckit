#!/usr/bin/env bash
# Switch to the branch for one task, creating it from the base branch if needed.
# Usage: branch.sh T003
# Prints: BRANCH=<name> ISSUE=<n> TASK=<id> BASE=<base>
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

task="${1:-}"
[[ "$task" =~ ^T[0-9]{3}$ ]] || die "usage: branch.sh T001 (exactly one task ID)"
jit_cd_root

fdir="$(feature_dir)"
line="$(task_line "$fdir" "$task")"
[[ -n "$line" ]] || die "$task not found in $fdir/tasks.md"
issue="$(task_issue "$line")"
[[ -n "$issue" ]] || die "$task has no issue yet (every task needs one); run /speckit-jit-issues"

base="$(base_branch)"
git fetch --quiet origin 2>/dev/null || true
if git show-ref --verify --quiet "refs/remotes/origin/$base"; then from="origin/$base"
elif git show-ref --verify --quiet "refs/heads/$base"; then from="$base"
else die "base branch '$base' does not exist; run /jit-speckit-level to set up the branch flow"
fi

# Task branches start from the base, so the spec has to be merged there first.
git cat-file -e "$from:$fdir/tasks.md" 2>/dev/null \
  || die "$fdir/tasks.md is not on '$base' yet; merge the spec PR first"

if [[ "$(jit_level)" == full ]]; then
  marker="$(git rev-parse --git-dir)/jit-analyzed/$(basename "$fdir")"
  want="$(git show "$from:$fdir/tasks.md" | sha256)"
  [[ -f "$marker" && "$(cat "$marker")" == "$want" ]] \
    || die "level 'full' requires /speckit-analyze on the current tasks.md before implementing"
fi

num="$(basename "$fdir" | cut -d- -f1)"
slug="$(task_desc "$line" | sed 's/ in `.*//' | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n' '-' | tr -s '-' | sed 's/^-//; s/-$//' | cut -d- -f1-4)"
branch="$(cfg branch_prefix feat)/$num-$(tr '[:upper:]' '[:lower:]' <<<"$task")-$slug"

if [[ "$(git branch --show-current)" != "$branch" ]]; then
  # Never carry uncommitted work onto another task's branch.
  [[ -z "$(git status --porcelain)" ]] || die "uncommitted changes on '$(git branch --show-current)'; commit or stash them first"
  if git show-ref --verify --quiet "refs/heads/$branch"; then git switch --quiet "$branch"
  elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then git switch --quiet --track "origin/$branch"
  else git switch --quiet --no-track -c "$branch" "$from"
  fi
fi

echo "BRANCH=$branch ISSUE=$issue TASK=$task BASE=$base"
