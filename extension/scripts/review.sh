#!/usr/bin/env bash
# Record and check the independent review (/speckit-jit-review), so nothing opens without one.
#   review.sh record <report-file>          task review: tied to the branch's exact diff against the base
#   review.sh record --plan <report-file>   plan review: tied to the feature's tasks.md (issue numbers aside)
#   review.sh check [--plan]                exit 0 when a review that said "ready" matches the current state
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
  fdir="$(feature_dir)"; name="plan-$(basename "$fdir")"; what="the plan ($fdir/tasks.md)"
  state() { sed -E 's/ — #[0-9]+[[:space:]]*$//' "$fdir/tasks.md" | sha256; }
else
  branch="$(git branch --show-current)"; name="task-${branch//\//__}"; what="this branch's diff"
  state() { # the patch id of the branch against the base: merges that change nothing keep it
    local base ref from; base="$(base_branch)"
    ref="origin/$base"; git rev-parse --verify --quiet "$ref" >/dev/null || ref="$base"
    from="$(git merge-base HEAD "$ref" 2>/dev/null || echo HEAD)"
    git diff "$from" HEAD | git patch-id --stable | cut -d' ' -f1
  }
fi
record="$dir/$name"

case "$action" in
  record)
    report="${1:-}"; [[ -f "$report" ]] || die "usage: review.sh record [--plan] <report-file>"
    # The last line that names the assessment decides; "changes needed" wins when both words appear.
    verdict="$(grep -iE 'assessment' "$report" | tail -1 | grep -oiE 'changes needed|ready' | head -1 | tr '[:upper:]' '[:lower:]' || true)"
    [[ -n "$verdict" ]] || die "the report has no 'Assessment: ready' or 'Assessment: changes needed' line"
    if ! $plan && [[ -n "$(git status --porcelain)" ]]; then die "commit the work first: the review is recorded for the committed diff"; fi
    { echo "state: $(state)"; echo "assessment: $verdict"; echo; cat "$report"; } > "$record"
    echo "REVIEW=$verdict" ;;
  check)
    [[ -f "$record" ]] || die "no independent review recorded for $what; run /speckit-jit-review and record its report: review.sh record${plan:+ --plan} <report-file>"
    [[ "$(sed -n 's/^state: //p' "$record")" == "$(state)" ]] \
      || die "$what changed since the last review; run /speckit-jit-review again and record it"
    [[ "$(sed -n 's/^assessment: //p' "$record")" == ready ]] \
      || die "the last review said 'changes needed'; fix the findings, then review again and record it"
    echo "REVIEW=ready" ;;
  *) die "usage: review.sh record [--plan] <report-file> | review.sh check [--plan]" ;;
esac
