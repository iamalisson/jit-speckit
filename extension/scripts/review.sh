#!/usr/bin/env bash
# Record and check the independent review (/speckit-jit-review), so nothing opens without one.
#   review.sh record <report-file>          task review: tied to the branch's exact diff against the base
#   review.sh record --plan <report-file>   plan review: tied to the feature's plan.md and tasks.md (issue numbers aside)
#   review.sh check [--plan]                exit 0 when a review that said "ready" matches the current state
#   review.sh report [--plan]               check, then print the report's What changed and Assessment line
#                                           (never its findings: pr.sh puts this in the public PR body)
# The report ends with a line "Assessment: ready" or "Assessment: changes needed".
# Records live in .git, so they never dirty the tree; a new commit or an edited tasks.md needs a new review.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
jit_cd_root

action="${1:-}"; shift || true
plan=false; if [[ "${1:-}" == --plan ]]; then plan=true; shift; fi
dir="$(git rev-parse --git-common-dir)/jit-review"; mkdir -p "$dir"

if $plan; then
  fdir="$(feature_dir)"; name="plan-$(basename "$fdir")"; what="the plan ($fdir/plan.md and tasks.md)"
  state() { # plan.md and tasks.md, without the issue numbers issues.sh appends
    { cat "$fdir/plan.md" 2>/dev/null; sed -E 's/ — #[0-9]+[[:space:]]*$//' "$fdir/tasks.md"; } | sha256
  }
else
  branch="$(git branch --show-current)"; [[ -n "$branch" ]] || die "not on a branch (detached HEAD); switch to the task's branch first"
  name="task-${branch//\//__}"; what="this branch's diff"
  state() { diff_id; }
fi
record="$dir/$name"

case "$action" in
  record)
    report="${1:-}"; [[ -f "$report" ]] || die "usage: review.sh record [--plan] <report-file>"
    # Only the exact line counts ("not ready" or "already" in prose never does); the last one decides.
    verdict="$(grep -iE '^\**assessment\**: *(ready|changes needed)\**\.?$' "$report" | tail -1 | grep -oiE 'changes needed|ready' | tr '[:upper:]' '[:lower:]' || true)"
    [[ -n "$verdict" ]] || die "the report has no line that is exactly 'Assessment: ready' or 'Assessment: changes needed'"
    # Untracked files (the report itself, kept outside the repo anyway) cannot be part of the diff.
    if ! $plan && [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then die "commit the work first: the review is recorded for the committed diff"; fi
    { echo "state: $(state)"; echo "assessment: $verdict"; echo; cat "$report"; } > "$record"
    echo "REVIEW=$verdict" ;;
  check|report)
    [[ -f "$record" ]] || die "no independent review recorded for $what; run /speckit-jit-review and record its report: review.sh record$($plan && echo ' --plan') <report-file>"
    [[ "$(sed -n 's/^state: //p' "$record")" == "$(state)" ]] \
      || die "$what changed since the last review; run /speckit-jit-review again and record it"
    [[ "$(sed -n 's/^assessment: //p' "$record")" == ready ]] \
      || die "the last review said 'changes needed'; fix the findings, then review again and record it"
    if [[ "$action" == check ]]; then echo "REVIEW=ready"; exit 0; fi
    # What changed: its label line and paragraph, 3 lines at most (the Report's limit). Only prose is
    # copied: a line must start with a letter or backtick, its first word must not end in ":" or ")",
    # and it must not name a severity or a finding; the first other line ends the copy. The label is
    # "What changed" followed by ":" or the line's end, so a finding that only starts with those words
    # is skipped like anything else before the label.
    section="$(sed '1,/^$/d' "$record" | awk '
      function prose(s) { s = tolower(s); return s ~ /^[ \t]*[a-z`]/ && s !~ /^[ \t]*[^ \t]+[:)]/ &&
        s !~ /(^|[^a-z])(findings?|high|medium|low|critical|severity|security|assessment|verdict)([^a-z]|$)/ }
      !on { if (!match(tolower($0), /^[ \t]*([-*+][ \t]+)?(#+[ \t]+)?[*_]*what changed[*_]*[ \t]*(:|$)[*_ \t]*/)) next
            rest = substr($0, RLENGTH + 1); bare = (rest == ""); if (!bare && !prose(rest)) exit
            on = 1; print; n = 1; next }
      bare && n == 1 && /^[ \t]*$/ { next }
      n >= 3 || !prose($0) { exit }
      { print; n++ }')"
    [[ -z "$section" ]] || printf '%s\n\n' "$section"
    echo "Assessment: ready" ;;
  *) die "usage: review.sh record [--plan] <report-file> | review.sh check|report [--plan]" ;;
esac
