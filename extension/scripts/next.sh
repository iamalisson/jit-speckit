#!/usr/bin/env bash
# Show a feature's progress and the next task to implement.
#   next.sh [feature]    feature: a number (002) or folder name (002-reports); it becomes the active one
# A task is done when its GitHub issue is closed. A task is in progress, and never picked, when its
# branch is on origin, checked out in another worktree, or has an open PR. A branch you started in
# this clone is yours to resume, and is picked first. A task whose line says "depends on T003" is
# blocked until T003's issue is closed.
# Prints a line per task ("done|resume|in-progress|blocked|open|no-issue Tnnn #N description"), then
# a "parallel <Tnnn> (<command>)" line for each other open task marked [P] right after its id (the
# command makes its worktree beside the repo and claims the task), then DONE=x/y IN_PROGRESS=n
# NEXT=<Tnnn> (NEXT empty when nothing is left to start).
# With no argument on a task branch (<prefix>/NNN-tNNN-...), it serves that branch's feature.
# Otherwise, with several features that have tasks to start, it prints one "feature <name>
# DONE=x/y" line each and CHOOSE=<names>; run it again with the chosen one.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

jit_cd_root
command -v gh >/dev/null || die "the GitHub CLI (gh) is required: https://cli.github.com"

# Branches, once: ours (local), checked out in some worktree, on origin, with an open PR.
cur="$(git branch --show-current)"
local_b=" $(git for-each-ref --format='%(refname:short)' refs/heads/ | tr '\n' ' ') "
checked_out=" $(git worktree list --porcelain | sed -n 's#^branch refs/heads/##p' | tr '\n' ' ') "
remote_b=" $(git ls-remote --heads origin 2>/dev/null | sed 's#.*refs/heads/##' | tr '\n' ' ') "
pr_heads=" $(gh pr list --state open --limit 500 --json headRefName --jq '.[].headRefName' 2>/dev/null | tr '\n' ' ') "

# scan <feature dir> <print>: one line per task when print=true; sets DONE_N TOTAL BUSY NEXT_ID PAR
scan() {
  local fdir="$1" show="$2" num closed=" " nums q="" i out line id issue key state resume="" d dl di
  num="$(feature_key "$fdir")"
  # One API call per feature, by issue number, so a renamed issue still counts. None when no task
  # has an issue (an empty repository { } is an invalid query).
  # shortcut: one query per feature, fine for hundreds of tasks; split into batches of ~100 if a feature ever nears GitHub's 10 s timeout
  nums="$(sed -nE '/^- \[.\] T[0-9]{3,} /s/.* — #([0-9]+)[[:space:]]*$/\1/p' "$fdir/tasks.md" | sort -u)"
  if [[ -n "$nums" ]]; then
    for i in $nums; do q+="i$i: issue(number: $i) { number state } "; done
    out="$(gh api graphql -F owner='{owner}' -F name='{repo}' \
      -f query="query(\$owner: String!, \$name: String!) { repository(owner: \$owner, name: \$name) { $q} }" \
      --jq '.data.repository[] | select(.state == "CLOSED") | .number')" \
      || die "cannot read the state of feature $num's task issues; fix or remove the issue number it names in $fdir/tasks.md"
    closed=" $(tr '\n' ' ' <<<"$out") "
  fi
  NEXT_ID=""; DONE_N=0; TOTAL=0; BUSY=0; PAR=""
  while IFS= read -r line; do
    id="$(sed -E 's/^- \[.\] (T[0-9]{3,}) .*/\1/' <<<"$line")"
    issue="$(task_issue "$line")"
    key="/$num-$(tr '[:upper:]' '[:lower:]' <<<"$id")-"
    TOTAL=$((TOTAL + 1))
    if [[ -z "$issue" ]]; then state=no-issue
    elif [[ "$closed" == *" $issue "* ]]; then state="done"; DONE_N=$((DONE_N + 1))
    elif [[ "$cur" == *"$key"* ]]; then state=resume; resume="${resume:-$id}"
    elif [[ "$checked_out" == *"$key"* ]]; then state=in-progress; BUSY=$((BUSY + 1))
    elif [[ "$local_b" == *"$key"* ]]; then state=resume; resume="${resume:-$id}"
    elif [[ "$remote_b" == *"$key"* || "$pr_heads" == *"$key"* ]]; then state=in-progress; BUSY=$((BUSY + 1))
    else
      state=open
      # "(depends on T003, T004)": blocked while any named task with an issue is still open.
      for d in $(grep -oiE 'depends on T[0-9]{3,}([, ]+(and )?T[0-9]{3,})*' <<<"$line" | grep -oE 'T[0-9]{3,}'); do
        dl="$(task_line "$fdir" "$d")"; di="$(task_issue "$dl")"
        if [[ -n "$di" && "$closed" != *" $di "* ]]; then state=blocked; fi
      done
      [[ "$state" != open ]] || NEXT_ID="${NEXT_ID:-$id}"
      [[ "$state" != open || "$line" != "- ["?"] $id [P] "* ]] || PAR+=" $id"
    fi
    if $show; then echo "$state $id ${issue:+#$issue} $(task_summary "$line")"; fi
  done < <(grep -E '^- \[.\] T[0-9]{3,} ' "$fdir/tasks.md")
  [[ -z "$resume" ]] || NEXT_ID="$resume"
}

if [[ -n "${1:-}" ]]; then
  fdir="$(resolve_feature "$1")"
  mkdir -p .specify; printf '{ "feature_directory": "%s" }\n' "$fdir" > .specify/feature.json
elif fdir="$(branch_feature)" && [[ -n "$fdir" ]]; then
  : # on a task branch, its feature (no feature.json: the branch decides on every call)
else
  # Several features with tasks to start: say so instead of silently serving the last one touched.
  startable=(); summary=""
  while IFS= read -r d; do
    [[ -f "$d/tasks.md" ]] || continue
    scan "$d" false
    summary+="feature $(basename "$d") DONE=$DONE_N/$TOTAL IN_PROGRESS=$BUSY"$'\n'
    [[ -z "$NEXT_ID" ]] || startable+=("$(basename "$d")")
  done < <(find specs -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
  if ((${#startable[@]} > 1)); then
    printf '%s' "$summary"; echo "CHOOSE=${startable[*]}"; exit 0
  elif ((${#startable[@]} == 1)); then
    fdir="specs/${startable[0]}"
    mkdir -p .specify; printf '{ "feature_directory": "%s" }\n' "$fdir" > .specify/feature.json
  else
    fdir="$(feature_dir)"
  fi
fi
[[ -f "$fdir/tasks.md" ]] || die "$fdir/tasks.md not found; run /speckit-tasks first"

scan "$fdir" true
# Every other startable [P] task: one line that makes its worktree and claims it, run one at a time.
num="$(feature_key "$fdir")"
for id in $PAR; do
  [[ "$id" != "$NEXT_ID" ]] || continue
  wt="$(printf %q "$PWD-$num-$(tr '[:upper:]' '[:lower:]' <<<"$id")")"
  echo "parallel $id (git worktree add --quiet --detach $wt origin/$(base_branch) && cd $wt && bash .specify/extensions/jit/scripts/branch.sh $num $id)"
done
echo "DONE=$DONE_N/$TOTAL IN_PROGRESS=$BUSY NEXT=$NEXT_ID"
