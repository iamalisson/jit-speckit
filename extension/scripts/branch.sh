#!/usr/bin/env bash
# Switch to the branch for one task, creating it from the base branch if needed.
# Usage: branch.sh [feature] T003      feature: a number (002) or folder name, else the active one
# A new branch is pushed to origin at once, so the task shows as in progress to every clone.
# Prints: BRANCH=<name> ISSUE=<n> TASK=<id> BASE=<base>
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

task=""; feature=""
for a in "$@"; do
  case "$a" in
    T[0-9]*) [[ -z "$task" ]] || die "usage: branch.sh [feature] T001 (exactly one task ID)"; task="$a" ;;
    *) [[ -z "$feature" ]] || die "usage: branch.sh [feature] T001 (one feature at most)"; feature="$a" ;;
  esac
done
[[ "$task" =~ ^T[0-9]{3,}$ ]] || die "usage: branch.sh [feature] T001 (exactly one task ID)"
jit_cd_root

if [[ -n "$feature" ]]; then fdir="$(resolve_feature "$feature")"; else fdir="$(feature_dir)"; fi
line="$(task_line "$fdir" "$task")"
[[ -n "$line" ]] || die "$task not found in $fdir/tasks.md"
issue="$(task_issue "$line")"
[[ -n "$issue" ]] || die "$task has no issue yet (every task needs one); run /speckit-jit-issues"

base="$(base_branch)"
git fetch --quiet origin 2>/dev/null || true
if git show-ref --verify --quiet "refs/remotes/origin/$base"; then from="origin/$base"
elif git show-ref --verify --quiet "refs/heads/$base"; then from="$base"
else die "base branch '$base' does not exist; run /jit-speckit:level to set up the branch flow"
fi

# Task branches start from the base, so the spec has to be merged there first.
git cat-file -e "$from:$fdir/tasks.md" 2>/dev/null \
  || die "$fdir/tasks.md is not on '$base' yet; merge the spec PR first"

if [[ "$(jit_level)" == full ]]; then
  marker="$(git rev-parse --git-common-dir)/jit-analyzed/$(basename "$fdir")"
  want="$(git show "$from:$fdir/tasks.md" | sha256)"
  [[ -f "$marker" && "$(cat "$marker")" == "$want" ]] \
    || die "level 'full' requires /speckit-analyze on the current tasks.md before implementing"
fi

num="$(feature_key "$fdir")"
slug="$(task_summary "$line" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n' '-' | tr -s '-' | sed 's/^-//; s/-$//' | cut -d- -f1-4)"
branch="$(cfg branch_prefix feat)/$num-$(tr '[:upper:]' '[:lower:]' <<<"$task")-$slug"

if [[ "$(git branch --show-current)" != "$branch" ]]; then
  # Never carry uncommitted work onto another task's branch.
  [[ -z "$(git status --porcelain)" ]] || die "uncommitted changes on '$(git branch --show-current)'; commit or stash them first"
  if git show-ref --verify --quiet "refs/heads/$branch"; then git switch --quiet "$branch"
  elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then git switch --quiet --track "origin/$branch"
  else
    git switch --quiet --no-track -c "$branch" "$from"
    # The claim: an empty branch on origin tells every other clone's `next` this task is taken.
    if git push --quiet -u origin "$branch" 2>/dev/null; then echo "claim: $branch pushed to origin" >&2; fi
  fi
fi

# spec-kit's own /speckit-implement reads only this file (git-ignored, so a new worktree has none):
# point it at the task's feature, so jit and spec-kit always work on the same one.
mkdir -p .specify
printf '{ "feature_directory": "%s" }\n' "$fdir" > .specify/feature.json

echo "BRANCH=$branch ISSUE=$issue TASK=$task BASE=$base"
