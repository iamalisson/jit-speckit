#!/usr/bin/env bash
# Push the current work and open (or reuse) its pull request.
#   pr.sh task T003 "feat(api): add price search" [body-file]
#       On the task's branch, with the work already committed. Adds "Closes #N".
#       Level "full" requires an "## Evidence" section in the body.
#   pr.sh spec
#       Commits the active feature's spec folder on spec/<feature> and opens a docs PR.
# Prints: PR=<url>
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

jit_cd_root
command -v gh >/dev/null || die "the GitHub CLI (gh) is required: https://cli.github.com"
fdir="$(feature_dir)"
base="$(base_branch)"
mode="${1:-}"

open_pr() { # open_pr <title> <body>
  local url
  url="$(gh pr list --head "$(git branch --show-current)" --state open --json url --jq '.[0].url // empty' 2>/dev/null || true)"
  if [[ -z "$url" ]]; then
    url="$(gh pr create --base "$base" --head "$(git branch --show-current)" --title "$1" --body "$2")"
  fi
  echo "PR=$url"
}

case "$mode" in
  task)
    task="${2:-}"; title="${3:-}"; body_file="${4:-}"
    [[ "$task" =~ ^T[0-9]{3}$ && -n "$title" ]] || die 'usage: pr.sh task T003 "type(scope): summary" [body-file]'
    line="$(task_line "$fdir" "$task")"
    issue="$(task_issue "$line")"
    [[ -n "$issue" ]] || die "$task has no issue"
    branch="$(git branch --show-current)"
    [[ "$branch" == *"-$(tr '[:upper:]' '[:lower:]' <<<"$task")-"* ]] || die "not on $task's branch (on '$branch'); run /speckit-implement $task"
    [[ -z "$(git status --porcelain)" ]] || die "uncommitted changes; commit the work first"
    git fetch --quiet origin "$base" 2>/dev/null || true
    [[ -n "$(git log --oneline "origin/$base..HEAD" 2>/dev/null || git log --oneline -1)" ]] || die "no commits ahead of $base"

    body=""; [[ -n "$body_file" ]] && body="$(cat "$body_file")"
    if [[ "$(jit_level)" == full ]] && ! grep -qE '^## Evidence' <<<"$body"; then
      die "level 'full' requires an '## Evidence' section in the PR body (test output, screenshots, run links)"
    fi
    grep -qiE "(close[sd]?|fix(e[sd])?|resolve[sd]?) #$issue([^0-9]|$)" <<<"$body" || body+=$'\n\n'"Closes #$issue"
    git push --quiet -u origin "$branch"
    open_pr "$title" "$body"
    ;;
  spec)
    feature="$(basename "$fdir")"
    branch="spec/$feature"
    if [[ "$(git branch --show-current)" != "$branch" ]]; then
      git switch --quiet "$branch" 2>/dev/null || git switch --quiet -c "$branch"
    fi
    git add -- "$fdir"
    git diff --cached --quiet || git commit --quiet -m "docs(specs): add $feature spec, plan and tasks"
    git push --quiet -u origin "$branch"
    issues="$(grep -oE ' — #[0-9]+$' "$fdir/tasks.md" | grep -oE '#[0-9]+' | tr '\n' ' ')"
    open_pr "docs(specs): $feature" "Spec, plan and tasks for \`$feature\`.

**Task issues:** ${issues:-none yet}

Merge this before starting tasks: \`/speckit-implement Tnnn\` branches from \`$base\`, so it needs \`tasks.md\` there."
    ;;
  *) die "usage: pr.sh task T003 \"type(scope): summary\" [body-file] | pr.sh spec" ;;
esac
