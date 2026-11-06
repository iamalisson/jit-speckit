#!/usr/bin/env bash
# Record and check the independent review (/speckit-jit-review), so nothing opens without one.
#   review.sh record <report-file>          task review: tied to the branch's exact diff against the base
#   review.sh record --delta <report-file>  fix round: reviews <last reviewed>..HEAD, after a recorded full round
#   review.sh record --plan <report-file>   plan review: tied to the feature's plan.md and tasks.md (issue numbers aside)
#   review.sh check [--plan]                exit 0 when a review that said "ready" matches the current state
#   review.sh report [--plan]               check, then print the recorded facts: the patch id, "Assessment: ready",
#                                           the model, any warning and the risk maps as paths
#                                           (never the report's text: pr.sh puts this in the public PR body)
#   review.sh risk [<from>]                 the diff's risky paths, one "RISK=<category> <path>" line each (RISK=none)
# The report ends with a line "Assessment: ready" or "Assessment: changes needed", and states the
# lines "Model: <id>" and, for a task, "Reviewed: <from>..<head>" (plus "Delta from: <last>" for a delta).
# Records live in .git, so they never dirty the tree; a new commit or an edited tasks.md needs a new review.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
jit_cd_root

action="${1:-}"; shift || true
plan=false; delta=false
while [[ "${1:-}" == --plan || "${1:-}" == --delta ]]; do
  if [[ "$1" == --plan ]]; then plan=true; else delta=true; fi; shift
done
if $plan && $delta; then die "a plan review is always full: review.sh record --plan <report-file>"; fi
if $plan && [[ "$action" == risk ]]; then die "risk maps a diff; a plan review has none"; fi
# A fix round may change this many lines outside the previous findings' files (tests aside);
# more means the fix is new work, which gets a full review.
DELTA_LINES=20
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

# hdr <key> [file]: the record's header values for <key>. The header ends at the first blank line,
# so nothing in the report below it can add or override a field.
hdr() { K="$1" awk '/^$/ { exit } index($0, ENVIRON["K"] ": ") == 1 { print substr($0, length(ENVIRON["K"]) + 3) }' "${2:-$record}"; }

# field <name>: the value of the report's last exact line "<name>: <value>" (optional bold), or nothing.
field() { grep -iE "^\**$1\**: *[^[:space:]*]+\**$" "$report" | tail -1 | sed -E 's/^[^:]*: *//; s/\*+$//' || true; }

# commit <sha>: the full sha of that commit, or nothing.
commit() { git rev-parse --verify --quiet "$1^{commit}" 2>/dev/null || true; }

# risk <from>: one "RISK=<category> <path>" line per risky path of <from>..HEAD, by fixed rules on
# the paths and the added lines; only paths and categories are printed, never a line's content.
risk() {
  local g=(git -c core.quotePath=false diff --no-renames --no-color --no-ext-diff --src-prefix=a/ --dst-prefix=b/)
  { "${g[@]}" --name-status "$1" HEAD | awk '{ print "S\t" $0 }'; "${g[@]}" -U0 "$1" HEAD; } | awk '
    function flag(c, p) { print "RISK=" c " " p }
    /^S\t/ {
      split($0, f, "\t"); p = f[3]; l = tolower(p)
      if (f[2] == "D") flag("delete", p)
      if (l ~ /(^|\/)(migrations?|migrate|alembic|flyway|liquibase)\// || l ~ /\.sql$/) flag("migration", p)
      if (l ~ /^\.github\/|^\.gitlab-ci\.yml$|^\.circleci\/|jenkinsfile|azure-pipelines|bitbucket-pipelines|^\.githooks\/|^\.husky\/|pre-commit-config/) flag("ci", p)
      if (l ~ /auth([^o]|$)|authori[sz]|login|permission|rbac|(^|[^a-z])acls?([^a-z]|$)|oauth|jwt|passw|crypt/) flag("auth", p)
      if (l ~ /(^|\/)\.env|secret|credential|\.pem$|\.key$|id_rsa/) flag("secrets", p)
      if (l ~ /payment|billing|invoice|checkout|pricing|refund|wallet|ledger/) flag("money", p)
      next
    }
    # Added lines count only inside a hunk, so a "+++" line in the content is never a header.
    /^diff --git / { hunk = 0; next }
    !hunk && /^\+\+\+ b\// { path = substr($0, 7); next }
    /^@@/ { hunk = 1; next }
    hunk && /^\+/ {
      l = tolower(substr($0, 2))
      if (l ~ /rm -r|rmtree|unlink\(|drop (table|column|database)|truncate |delete from|os\.remove|fs\.rm/) flag("delete", path)
      if (l ~ /--no-verify|continue-on-error: *true|\|\| *true|\.only\(|\.skip\(|xfail|@disabled|@ignore|t\.skip\(|pytest\.mark\.skip/) flag("gate", path)
    }
  ' | sort -u | grep . || echo RISK=none
}

# checked <from>: dies unless every risky path of <from>..HEAD has a "- deep: <path>" line, or a
# "- proven: <path> by <file>:<n>" line naming an existing line of a test file at HEAD
# (never for a gate, delete or test path: those need "- deep:").
checked() {
  local l p f n o cats re pre='^- proven: ([^ ]+) by ([^ ]+):([0-9]+)( .*)?$'
  re="$(test_path_re)" || exit 1
  while IFS= read -r l; do
    if [[ "$l" =~ $pre ]]; then
      p="${BASH_REMATCH[1]}"; f="${BASH_REMATCH[2]}"; n="${BASH_REMATCH[3]}"
      if grep -qE -- "$re" <<<"$f" && git cat-file -e "HEAD:$f" 2>/dev/null \
        && ((10#$n >= 1 && 10#$n <= $(git show "HEAD:$f" | awk 'END { print NR }'))); then continue; fi
    else
      p="$(sed -E 's/^- proven: ([^ ]*).*/\1/' <<<"$l")"; f="<file>"; n="<n>"
    fi
    die "$p is not proven by $f:$n (not a test file, or no such line): check it deep or name the test"
  done < <(grep -E '^- proven: ' "$report" || true)
  while IFS=$'\t' read -r cats p; do
    # A disabled gate, a deletion or a test itself cannot be proven by a test (a skipped test never fails).
    o=" or '- proven: $p by <test file:line>'"
    if [[ ", $cats," == *", gate,"* || ", $cats," == *", delete,"* ]] || grep -qE -- "$re" <<<"$p"; then o=" (a gate, delete or test path needs a deep read)"; fi
    P="$p" O="$o" awk 'BEGIN { d = "- deep: " ENVIRON["P"]; q = "- proven: " ENVIRON["P"] " by " }
      (index($0, q) == 1 && ENVIRON["O"] ~ /^ or /) || (index($0, d) == 1 && (length($0) == length(d) || substr($0, length(d) + 1, 1) == " ")) { f = 1 }
      END { exit !f }' "$report" \
      || die "the report does not check $p ($cats): add '- deep: $p'$o"
  done < <(risk "$1" | awk '$0 != "RISK=none" { c = substr($1, 6); p = substr($0, length($1) + 2)
      if (!(p in cats)) { order[++n] = p; cats[p] = c } else cats[p] = cats[p] ", " c }
      END { for (i = 1; i <= n; i++) print cats[order[i]] "\t" order[i] }')
}

# outside <last>: the lines the fix changed since <last> outside the previous findings' files
# (the first file:line of each line from "findings" on) and outside test paths; a binary file
# counts as more than the limit.
outside() {
  local found re a d f n=0
  found="$(awk 'NR == 1, /^$/ { next } tolower($0) ~ /findings/ { on = 1 }
    on && match($0, /[A-Za-z0-9_.\/-]+:[0-9]+/) { s = substr($0, RSTART, RLENGTH); sub(/:[0-9]+$/, "", s); print s }' "$record")"
  re="$(test_path_re)" || exit 1
  while IFS=$'\t' read -r a d f; do
    if grep -qxF -- "$f" <<<"$found" || grep -qE -- "$re" <<<"$f"; then continue; fi
    if [[ "$a" == - ]]; then n=$((n + DELTA_LINES + 1)); else n=$((n + a + d)); fi
  done < <(git -c core.quotePath=false diff --numstat --no-renames "$1" HEAD)
  echo "$n"
}

case "$action" in
  record)
    report="${1:-}"; [[ -f "$report" ]] || die "usage: review.sh record [--plan|--delta] <report-file>"
    # Only the exact line counts ("not ready" or "already" in prose never does); the last one decides.
    verdict="$(grep -iE '^\**assessment\**: *(ready|changes needed)\**\.?$' "$report" | tail -1 | grep -oiE 'changes needed|ready' | tr '[:upper:]' '[:lower:]' || true)"
    [[ -n "$verdict" ]] || die "the report has no line that is exactly 'Assessment: ready' or 'Assessment: changes needed'"
    # Untracked files (the report itself, kept outside the repo anyway) cannot be part of the diff.
    if ! $plan && [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then die "commit the work first: the review is recorded for the committed diff"; fi
    want="$(review_model)" || exit 1
    model="$(field model)"; from=""; head=""; carried=""
    if $plan; then
      [[ -n "$model" ]] || die "the report must state Model: <id> for the plan: run the review again"
    else
      head="$(git rev-parse HEAD)"; df="$(field 'delta from')"
      rf=""; rh=""; rre='^([0-9a-f]{7,40})[.][.]([0-9a-f]{7,40})$'
      if [[ "$(field reviewed)" =~ $rre ]]; then
        rf="$(commit "${BASH_REMATCH[1]}")"; rh="$(commit "${BASH_REMATCH[2]}")"
      fi
      if $delta; then
        [[ -f "$record" && "$(hdr round)" == full ]] \
          || die "a delta follows a recorded full review of this branch: run a new full review, then record it with review.sh record <report-file>"
        from="$(hdr head)"
        [[ -n "$df" ]] || die "a delta report names its base: Delta from: $from; run the delta review again"
        git merge-base --is-ancestor "$from" HEAD 2>/dev/null || die "$from is no longer on this branch (rebased?): run a new full review"
        [[ "$head" != "$from" ]] || die "nothing was committed since the last review ($from): commit the fixes, then run the delta review"
        # The specific delta line wins over the generic one when the range is there but wrong.
        if [[ -n "$rf" && ( "$(commit "$df")" != "$from" || "$rf" != "$from" || "$rh" != "$head" ) ]]; then
          die "the delta must review $from..HEAD (Reviewed: $from..$head): run the delta review again from $from"
        fi
        [[ -n "$rf" && -n "$model" ]] \
          || die "the report must state Reviewed: <from>..<head> and Model: <id> for $from..$head: run the review again"
        n="$(outside "$from")" || exit 1
        ((n <= DELTA_LINES)) || die "the delta changes $n lines outside the previous findings (limit $DELTA_LINES): run a new full review"
        carried="$(hdr map-full)"
      else
        [[ -z "$df" ]] || die "this is a delta report: record it with --delta, or run a new full review"
        from="$(diff_base)"
        [[ -n "$model" && "$rf" == "$from" && "$rh" == "$head" ]] \
          || die "the report must state Reviewed: <from>..<head> and Model: <id> for $from..$head: run the review again"
      fi
      checked "$from"
    fi
    # The model the review ran on: a warning, never a refusal (the session may force one model).
    warn=""; fam="$(tr '[:upper:]' '[:lower:]' <<<"$model" | grep -oE 'sonnet|opus|fable|haiku' | head -1 || true)"
    if [[ -n "${CLAUDE_CODE_SUBAGENT_MODEL_FORCE:-}" ]]; then warn="CLAUDE_CODE_SUBAGENT_MODEL_FORCE is set"
    elif [[ "$fam" != sonnet && "$fam" != opus && "$fam" != fable ]]; then warn="the review ran on $model"
    elif [[ "$fam" != "$want" ]]; then warn="the review ran on $model, not $want"
    fi
    if [[ -n "$warn" ]]; then warn="$warn; the review did not run on the configured model"; echo "jit: warning: $warn" >&2; fi
    map="$(grep -oE '^- (deep|proven): [^ ]+' "$report" || true)"
    {
      echo "state: $(state)"; echo "assessment: $verdict"
      if ! $plan; then echo "head: $head"; if $delta; then echo "round: delta"; else echo "round: full"; fi; fi
      echo "model: $model"
      if [[ -n "$warn" ]]; then echo "warning: $warn"; fi
      # A delta keeps round 1's map, so the PR shows both.
      if $delta; then [[ -z "$carried" ]] || sed 's/^/map-full: /' <<<"$carried"; [[ -z "$map" ]] || sed 's/^/map-fix: /' <<<"$map"
      elif [[ -n "$map" ]]; then sed 's/^/map-full: /' <<<"$map"; fi
      echo; cat "$report"
    } > "$record.tmp" && mv "$record.tmp" "$record"
    if ! $plan; then echo "REVIEWED=$head"; fi
    echo "REVIEW=$verdict" ;;
  check|report)
    [[ -f "$record" ]] || die "no independent review recorded for $what; run /speckit-jit-review and record its report: review.sh record$($plan && echo ' --plan') <report-file>"
    [[ "$(hdr state)" == "$(state)" ]] \
      || die "$what changed since the last review; run /speckit-jit-review again and record it"
    [[ "$(hdr assessment)" == ready ]] \
      || die "the last review said 'changes needed'; fix the findings, then review again and record it"
    if [[ "$action" == check ]]; then echo "REVIEW=ready"; exit 0; fi
    # Only facts checked or stored by record: no reviewer prose can be filtered for findings reliably (F3.1/F4.3).
    echo "Independent review recorded for this diff (patch id $(hdr state | cut -c1-12))"
    echo "Assessment: ready"
    m="$(hdr model)"; [[ -z "$m" ]] || echo "Model: $m"
    hdr warning | sed 's/^/warning: /'
    m="$(hdr map-full)"; [[ -z "$m" ]] || printf 'Risk map (round 1)\n%s\n' "$m"
    m="$(hdr map-fix)"; [[ -z "$m" ]] || printf 'Risk map (fix round)\n%s\n' "$m" ;;
  risk)
    from="${1:-$(diff_base)}"; c="$(commit "$from")"; [[ -n "$c" ]] || die "usage: review.sh risk [<from>] (no commit '$from')"
    risk "$c" ;;
  *) die "usage: review.sh record [--plan|--delta] <report-file> | review.sh check|report [--plan] | review.sh risk [<from>]" ;;
esac
