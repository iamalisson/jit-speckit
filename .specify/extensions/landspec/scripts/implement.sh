#!/usr/bin/env bash
# The state of every task of a feature, for /landspec:implement, and the one record per task it keeps.
#   implement.sh [feature] status [--running T001,T002]
#       One "TASK=<id> STATE=<state> PR=<n|-> BRANCH=<b|-> PARENT=<b|-> [REASON=<why>]" line per
#       task, then START= REVIEW= FIX= OPEN= ORDER= DONE=. States, checked in this order: merged,
#       elsewhere, failed, running, pr, reviewed, fix, implemented, resume, startable, waiting.
#       Reads by branch name and never switches; its one write fast-forwards a task branch that is
#       behind its origin branch and checked out nowhere.
#   implement.sh [feature] mark <task> implemented|changes|ready|pr [<report>]
#   implement.sh [feature] fail <task> <reason>
#   implement.sh [feature] retry <task>
#   implement.sh [feature] restack [--running T001,T002]
#       Moves each stacked branch, parents first, in the run's worktree <repo>-<feature>-run: onto the
#       base once its parent's PR is merged, onto its parent's new head when the parent moved. Prints
#       RESTACKED=<task> REVIEW=kept|needed|none, RESTACK_SKIPPED=<task> (<why>), RESTACK_CONFLICT=<task>,
#       RESTACK_NOT_READY=<task>, and RETARGETED=<task> for a PR a failed `gh pr edit` left on its old base.
#   implement.sh [feature] stack <task> <onto-task>   the same move, onto another task's branch
# The record is <git common dir>/landspec-run/<feature>/<task>: phase=, head=, round=, report=, failed=.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
landspec_cd_root

feature=""
case "${1:-}" in status|mark|fail|retry|restack|stack|"") ;; *) feature="$1"; shift ;; esac
action="${1:-}"; shift || true
if [[ -n "$feature" ]]; then fdir="$(resolve_feature "$feature")"; else fdir="$(feature_dir)"; fi
[[ -f "$fdir/tasks.md" ]] || die "$fdir/tasks.md not found; run /speckit-tasks first"
num="$(feature_key "$fdir")"
rdir="$(git rev-parse --git-common-dir)/landspec-run/$(basename "$fdir")"
MAX_ROUNDS=3

# task_branch <id> [refs/heads|refs/remotes/origin]: the task's branch there, by its name's key.
task_branch() {
  local key; key="/$num-$(tr '[:upper:]' '[:lower:]' <<<"$1")-"
  git for-each-ref --format='%(refname)' "${2:-refs/heads}/" | sed "s#^${2:-refs/heads}/##" | grep -F -- "$key" | grep -v '^HEAD$' | head -1 || true
}
# rec <task> <key>: a field of the task's record, or nothing.
rec() { [[ -f "$rdir/$1" ]] || return 0; sed -n "s/^$2=//p" "$rdir/$1" | tail -1; }
# write_rec <task> <key=value>...: replace those fields, keep the others.
write_rec() {
  local t="$1" f k; shift; mkdir -p "$rdir"; f="$rdir/$t"; touch "$f"
  for k in "$@"; do grep -v "^${k%%=*}=" "$f" > "$f.tmp" || true; echo "$k" >> "$f.tmp"; mv "$f.tmp" "$f"; done
}
valid_task() { [[ "$1" =~ ^T[0-9]{3,}$ && -n "$(task_line "$fdir" "$1")" ]] || die "$1 is not a task of $fdir"; }

# run_wt: the run's worktree, detached at origin/<base>, made when missing; restack works only there.
run_wt() {
  local main w; main="$(git worktree list --porcelain | sed -n '1s/^worktree //p')"; w="$main-$num-run"
  if ! git -C "$w" rev-parse --git-dir >/dev/null 2>&1; then
    git worktree add --quiet --detach "$w" "origin/$(base_branch)" || die "cannot make the run's worktree $w"
  fi
  echo "$w"
}
# all_prs: "<n>\t<head branch>\t<head sha>\t<base branch>\t<draft>\t<state>" for every PR.
all_prs() {
  gh pr list --state all --limit 500 --json number,headRefName,headRefOid,baseRefName,isDraft,state \
    --jq '.[] | [.number, .headRefName, .headRefOid, .baseRefName, .isDraft, .state] | @tsv'
}
# why_not <task> <branch> <status line> <PR line|"">: why that branch must not be moved now, or nothing.
why_not() {
  local wt; wt="$(git worktree list --porcelain | awk -v b="refs/heads/$2" '/^worktree / { p = substr($0, 10) } $0 == "branch " b { print p; exit }')"
  if [[ -n "$wt" ]]; then echo "checked out in $wt"
  elif [[ "$3" == *" STATE=running"* ]]; then echo running
  elif ! git show-ref --verify --quiet "refs/remotes/origin/$2"; then echo "not on origin"
  elif [[ -n "$4" && "$(cut -f3 <<<"$4")" != "$(git rev-parse "refs/remotes/origin/$2")" ]]; then echo "origin moved"
  elif [[ -n "$(git rev-list "refs/heads/$2..refs/remotes/origin/$2")" ]]; then echo "behind origin"
  elif [[ -n "$(git rev-list "refs/remotes/origin/$2..refs/heads/$2")" ]]; then echo "local commits not on origin"
  fi
}
# retarget <task> <branch> <PR> <new base>: a PR a failed `gh pr edit` left on its old base.
retarget() {
  gh pr edit "$3" --base "$4" >/dev/null || die "could not move PR #$3 onto $4; fix gh's error above, then run restack again"
  if [[ "$4" == "$(base_branch)" ]] && bash "$(dirname "$0")/review.sh" check --branch "$2" >/dev/null 2>&1 \
    && ! gh pr ready "$3" >/dev/null; then echo "RESTACK_NOT_READY=$1"; fi
  echo "RETARGETED=$1"
}
# move <task> <branch> <onto ref> <upstream> <new parent|""> <PR number|-> <new base name>:
# rebase <branch> --onto <onto ref> from <upstream> in the run's worktree, push it with a lease on the
# origin head this run fetched, and carry the parent setting, parent-head, record, review and PR along.
move() {
  local t="$1" b="$2" onto="$3" up="$4" np="$5" pr="$6" nb="$7" w old oh new had=false oid="" rv=none ph
  w="$(run_wt)"; old="$(git rev-parse "refs/heads/$b")"; oh="$(git rev-parse "refs/remotes/origin/$b")"
  if bash "$(dirname "$0")/review.sh" check --branch "$b" >/dev/null 2>&1; then had=true; oid="$(diff_id "$b")"; fi
  git -C "$w" switch --quiet --detach "$old"
  if ! git -C "$w" rebase --quiet --onto "$onto" "$up" >/dev/null 2>&1; then
    git -C "$w" rebase --abort >/dev/null 2>&1 || true
    git -C "$w" switch --quiet --detach "origin/$base"; echo "RESTACK_CONFLICT=$t"; return 0
  fi
  new="$(git -C "$w" rev-parse HEAD)"
  git -C "$w" push --quiet --force-with-lease="refs/heads/$b:$oh" origin "HEAD:refs/heads/$b" \
    || { git -C "$w" switch --quiet --detach "origin/$base"; die "could not push $b (moved on origin meanwhile?); run restack again"; }
  git update-ref "refs/heads/$b" "$new" "$old"
  git -C "$w" switch --quiet --detach "origin/$base"
  ph="$(git rev-parse --git-common-dir)/landspec-review/parent-head-${b//\//__}"
  if [[ -n "$np" ]]; then git config "branch.$b.landspec-parent" "$np"; mkdir -p "${ph%/*}"; git rev-parse "$onto" > "$ph"
  else git config --unset "branch.$b.landspec-parent" || true; rm -f "$ph"; fi
  if [[ -f "$rdir/$t" ]]; then write_rec "$t" "head=$new"; fi
  if $had; then
    if [[ "$(diff_id "$b")" == "$oid" ]]; then rv=kept; else rv=needed; bash "$0" "$num" mark "$t" implemented >/dev/null; fi
  fi
  if [[ "$pr" != - ]]; then
    gh pr edit "$pr" --base "$nb" >/dev/null || die "could not move PR #$pr onto $nb; fix gh's error above, then run restack again"
    # only a PR now on the base with its review kept is ready; a stacked one stays a draft
    if [[ -z "$np" && "$rv" == kept ]] && ! gh pr ready "$pr" >/dev/null; then echo "RESTACK_NOT_READY=$t"; fi
  fi
  echo "RESTACKED=$t REVIEW=$rv"
}

case "$action" in
  mark)
    t="${1:-}"; phase="${2:-}"; report="${3:-}"; valid_task "$t"
    [[ "$phase" =~ ^(implemented|changes|ready|pr)$ ]] || die "usage: implement.sh mark <task> implemented|changes|ready|pr [<report>]"
    b="$(task_branch "$t")"; [[ -n "$b" ]] || die "$t has no branch in this clone"
    head="$(git rev-parse "refs/heads/$b")"; round="$(rec "$t" round)"; round="${round:-0}"
    # A failure a new commit lifted (its head is not this one) is gone, its rounds with it; one
    # recorded before the branch existed (empty head) stays until retry.
    oldh="$(rec "$t" head)"
    if [[ -n "$(rec "$t" failed)" && -n "$oldh" && "$oldh" != "$head" ]]; then
      grep -vE '^(failed|round)=' "$rdir/$t" > "$rdir/$t.tmp" || true; mv "$rdir/$t.tmp" "$rdir/$t"; round=0
    fi
    set -- "phase=$phase" "head=$head"
    if [[ "$phase" == changes ]]; then
      [[ -f "$report" ]] || die "usage: implement.sh mark <task> changes <report> (the review that asked for them)"
      round=$((round + 1)); mkdir -p "$rdir"; cp "$report" "$rdir/$t.report"
      set -- "$@" "report=$rdir/$t.report"
      if ((round >= MAX_ROUNDS)); then set -- "$@" "failed=review rounds"; fi
    fi
    write_rec "$t" "$@" "round=$round"
    echo "MARKED=$t PHASE=$phase ROUND=$round" ;;
  fail)
    t="${1:-}"; why="${2:-}"; valid_task "$t"; [[ -n "$why" ]] || die "usage: implement.sh fail <task> <reason>"
    b="$(task_branch "$t")"; head=""; [[ -z "$b" ]] || head="$(git rev-parse "refs/heads/$b")"
    write_rec "$t" "head=$head" "failed=$why"; echo "FAILED=$t" ;;
  retry)
    t="${1:-}"; valid_task "$t"
    if [[ -f "$rdir/$t" ]]; then grep -vE '^(failed|round)=' "$rdir/$t" > "$rdir/$t.tmp" || true; mv "$rdir/$t.tmp" "$rdir/$t"; fi
    echo "RETRY=$t" ;;
  status)
    running_list=""
    if [[ "${1:-}" == --running ]]; then running_list=" $(tr ',' ' ' <<<"${2:-}") "; fi
    base="$(base_branch)"
    par="$(cfg parallel_tasks 4)"
    [[ "$par" =~ ^[0-9]+$ ]] && ((10#$par >= 1 && 10#$par <= 16)) || die "parallel_tasks must be a number from 1 to 16"
    par=$((10#$par))
    command -v gh >/dev/null || die "the GitHub CLI (gh) is required: https://cli.github.com"
    git fetch --quiet origin || die "cannot fetch origin, so tasks claimed in other clones cannot be seen; fix the error above"
    # The same refusals as branch.sh: a run starts tasks, and each starts from the base.
    git cat-file -e "origin/$base:$fdir/tasks.md" 2>/dev/null \
      || die "$fdir/tasks.md is not on '$base' yet; merge the spec PR first"
    if [[ "$(landspec_level)" == full ]]; then
      marker="$(git rev-parse --git-common-dir)/landspec-analyzed/$(basename "$fdir")"
      [[ -f "$marker" && "$(cat "$marker")" == "$(git show "origin/$base:$fdir/tasks.md" | sha256)" ]] \
        || die "level 'full' requires /speckit-analyze on the current tasks.md before implementing"
    fi
    # The tasks, their issues and dependencies come from the base's tasks.md, the one checked above.
    tasks="$(git show "origin/$base:$fdir/tasks.md" | grep -E '^- \[.\] T[0-9]{3,} ' || true)"
    closed="$(closed_issues "$fdir")" || die "cannot read the state of feature $num's task issues; fix gh's error above"
    prs="$(gh pr list --state open --limit 500 --json number,headRefName,headRefOid,baseRefName,isDraft \
      --jq '.[] | [.number, .headRefName, .headRefOid, .baseRefName, .isDraft] | @tsv')" \
      || die "cannot list the open pull requests; fix gh's error above"
    # Worktrees: "<branch>\t<path>\t<locked 0|1>" per checked-out branch.
    wts="$(git worktree list --porcelain | awk '
      /^worktree / { if (b != "") print b "\t" p "\t" l; p = substr($0, 10); b = ""; l = 0 }
      /^branch refs\/heads\// { b = substr($0, 19) } /^locked/ { l = 1 }
      END { if (b != "") print b "\t" p "\t" l }')"
    # Per task: ST_<id> BR_<id> PA_<id> PRN_<id> WHY_<id> (bash 3.2 has no associative arrays).
    ids=""
    put() { printf -v "$1_$2" '%s' "$3"; }
    get() { local v="$1_$2"; printf '%s' "${!v-}"; }
    while IFS= read -r line; do
      t="$(sed -E 's/^- \[.\] (T[0-9]{3,}) .*/\1/' <<<"$line")"; ids+=" $t"
      issue="$(task_issue "$line")"; b="$(task_branch "$t")"; rb="$(task_branch "$t" refs/remotes/origin)"
      st=""; why=""; p=""; pr="-"
      [[ -z "$b" ]] || p="$(git config --get "branch.$b.landspec-parent" || true)"
      wt=""; [[ -z "$b" ]] || wt="$(awk -F'\t' -v b="$b" '$1 == b { print $2 "\t" $3; exit }' <<<"$wts")"
      if [[ -n "$issue" && "$closed" == *" $issue "* ]]; then st=merged
      elif [[ -z "$b" && -n "$rb" ]]; then st=elsewhere; b="$rb"
      elif [[ -n "$b" && -n "$rb" ]] && [[ "$(git rev-parse "refs/heads/$b")" != "$(git rev-parse "refs/remotes/origin/$rb")" ]] \
           && ! git merge-base --is-ancestor "refs/remotes/origin/$rb" "refs/heads/$b"; then
        # Someone pushed to it: behind is caught up when no checkout would be left behind.
        if git merge-base --is-ancestor "refs/heads/$b" "refs/remotes/origin/$rb"; then
          if [[ -z "$wt" ]]; then git update-ref "refs/heads/$b" "refs/remotes/origin/$rb" "refs/heads/$b"
          else st=elsewhere; why="checked out in ${wt%%$'\t'*}"; fi
        else st=elsewhere; why="diverged from origin"; fi
      fi
      if [[ -z "$st" ]]; then
        head=""; [[ -z "$b" ]] || head="$(git rev-parse "refs/heads/$b")"
        f="$(rec "$t" failed)"; fh="$(rec "$t" head)"; phase="$(rec "$t" phase)"; round="$(rec "$t" round)"
        prl=""; [[ -z "$b" ]] || prl="$(awk -F'\t' -v b="$b" '$2 == b { print; exit }' <<<"$prs")"
        [[ -z "$prl" ]] || pr="$(cut -f1 <<<"$prl")"
        if [[ -n "$f" && ( -z "$fh" || "$fh" == "$head" ) ]]; then st=failed; why="$f"
        elif [[ "$running_list" == *" $t "* ]]; then st=running
        elif [[ -n "$wt" && "${wt##*$'\t'}" == 1 ]]; then st=running; why="locked worktree ${wt%%$'\t'*}"
        elif [[ -n "$prl" && "$(cut -f3 <<<"$prl")" == "$head" && "$phase" == pr \
                && ( "$(cut -f4 <<<"$prl")" != "$base" || "$(cut -f5 <<<"$prl")" == false ) ]]; then
          st="pr" # open into its parent (a draft until restack), or ready on the base; a draft on the base is "reviewed"
        elif [[ -n "$prl" && "$(cut -f5 <<<"$prl")" == true && "$(cut -f4 <<<"$prl")" == "$base" && -n "$p" ]]; then
          # GitHub retargets a child onto the base when its parent's branch goes (so its review cannot
          # even be read against that parent): until restack moves it, it waits.
          st=waiting; why="restack pending"
        elif [[ -n "$b" ]] && bash "$(dirname "$0")/review.sh" check --branch "$b" >/dev/null 2>&1; then st=reviewed
        elif [[ "$phase" == changes && "$fh" == "$head" && -n "$head" && "${round:-0}" -lt "$MAX_ROUNDS" ]]; then st=fix
        elif [[ "$phase" == implemented && "$fh" == "$head" && -n "$head" ]]; then st=implemented
        elif [[ -n "$b" ]]; then st=resume
        fi
      fi
      put ST "$t" "$st"; put BR "$t" "${b:--}"; put PA "$t" "${p:--}"; put PRN "$t" "$pr"; put WHY "$t" "$why"
    done <<<"$tasks"
    # No branch yet: startable when every dependency is reviewed, in a PR or merged, with at most one
    # unmerged (a branch stacks on one parent only); otherwise waiting.
    for t in $ids; do
      [[ -z "$(get ST "$t")" ]] || continue
      ok=true; unmerged=0
      for d in $(grep -oiE 'depends on T[0-9]{3,}([, ]+(and )?T[0-9]{3,})*' <<<"$(grep -m1 -E "^- \[.\] $t " <<<"$tasks")" | grep -oE 'T[0-9]{3,}'); do
        case "$(get ST "$d")" in merged) ;; reviewed|pr) unmerged=$((unmerged + 1)) ;; *) ok=false ;; esac
      done
      if $ok && ((unmerged <= 1)); then put ST "$t" startable; else put ST "$t" waiting; fi
    done
    running=0; done_n=0; total=0
    for t in $ids; do
      total=$((total + 1))
      case "$(get ST "$t")" in running) running=$((running + 1)) ;; merged) done_n=$((done_n + 1)) ;; esac
    done
    slots=$((par - running)); n_start=0; start=""; review=""; fix=""; open=""
    for t in $ids; do
      w="$(get WHY "$t")"
      echo "TASK=$t STATE=$(get ST "$t") PR=$(get PRN "$t") BRANCH=$(get BR "$t") PARENT=$(get PA "$t")${w:+ REASON=$w}"
      case "$(get ST "$t")" in
        startable|resume) if ((n_start < slots)); then start+=" $t"; n_start=$((n_start + 1)); fi ;;
        implemented) review+=" $t" ;; fix) fix+=" $t" ;; reviewed) open+=" $t" ;;
      esac
    done
    # ORDER: every task with a PR or a branch, parents before children, then by ID.
    left=""; order=""
    for t in $ids; do [[ "$(get BR "$t")" == - && "$(get PRN "$t")" == - ]] || left+=" $t"; done
    while [[ -n "${left// /}" ]]; do
      next=""; moved=false
      for t in $left; do
        pt=""; for u in $left; do if [[ "$u" != "$t" && "$(get PA "$t")" == "$(get BR "$u")" ]]; then pt="$u"; fi; done
        if [[ -z "$pt" ]]; then order+=" $t"; moved=true; else next+=" $t"; fi
      done
      if ! $moved; then order+="$next"; break; fi # a cycle cannot happen; never loop on one
      left="$next"
    done
    echo "START=${start# }"; echo "REVIEW=${review# }"; echo "FIX=${fix# }"; echo "OPEN=${open# }"
    echo "ORDER=${order# }"; echo "DONE=$done_n/$total" ;;
  restack)
    base="$(base_branch)"
    st="$(bash "$0" "$num" status "$@")" || exit 1 # fetches; dies with gh's or git's error
    prs="$(all_prs)" || die "cannot list the pull requests; fix gh's error above"
    for t in $(sed -n 's/^ORDER=//p' <<<"$st"); do
      l="$(grep "^TASK=$t " <<<"$st")"; b="$(sed -E 's/.* BRANCH=([^ ]+).*/\1/' <<<"$l")"
      p="$(git config --get "branch.$b.landspec-parent" || true)"
      [[ "$b" != - ]] || continue
      [[ "$(sed -E 's/.* STATE=([^ ]+).*/\1/' <<<"$l")" != merged ]] || continue
      prl="$(awk -F'\t' -v b="$b" '$2 == b && $6 == "OPEN" { print; exit }' <<<"$prs")"; pr="$(cut -f1 <<<"$prl")"; pr="${pr:--}"
      if [[ -z "$p" ]]; then # not stacked (any more): finish a move whose `gh pr edit` failed
        if [[ "$pr" != - && "$(cut -f4 <<<"$prl")" != "$base" ]]; then retarget "$t" "$b" "$pr" "$base"; fi
        continue
      fi
      ppr="$(awk -F'\t' -v b="$p" '$2 == b && $6 != "CLOSED" { print; exit }' <<<"$prs")"
      ph="$(cat "$(git rev-parse --git-common-dir)/landspec-review/parent-head-${b//\//__}" 2>/dev/null || true)"
      # What it would move onto, if anything: a merged parent's PR base, or a parent that moved.
      if [[ "$(cut -f6 <<<"$ppr")" == MERGED ]]; then
        nb="$(cut -f4 <<<"$ppr")"; onto="origin/$nb"; up="$(cut -f3 <<<"$ppr")"; np=""; [[ "$nb" == "$base" ]] || np="$nb"
      else
        nb="$p"; onto="refs/heads/$p"; git show-ref --verify --quiet "$onto" || onto="refs/remotes/origin/$p"
        up="$ph"; np="$p"
        if [[ -z "$up" || "$(git rev-parse "$onto")" == "$up" ]]; then
          if [[ "$pr" != - && "$(cut -f4 <<<"$prl")" != "$p" ]]; then retarget "$t" "$b" "$pr" "$p"; fi
          continue
        fi
      fi
      why="$(why_not "$t" "$b" "$l" "$prl")"
      if [[ -n "$why" ]]; then echo "RESTACK_SKIPPED=$t ($why)"; continue; fi
      move "$t" "$b" "$onto" "$up" "$np" "$pr" "$nb"
    done ;;
  stack)
    t="${1:-}"; o="${2:-}"; valid_task "$t"; valid_task "$o"; base="$(base_branch)"
    b="$(task_branch "$t")"; ob="$(task_branch "$o")"
    [[ -n "$b" && -n "$ob" ]] || die "both $t and $o need a branch in this clone"
    [[ -z "$(git config --get "branch.$b.landspec-parent" || true)" ]] || die "$t is already stacked on $(git config --get "branch.$b.landspec-parent")"
    st="$(bash "$0" "$num" status)" || exit 1 # fetches; dies with gh's or git's error
    prs="$(all_prs)" || die "cannot list the pull requests; fix gh's error above"
    prl="$(awk -F'\t' -v b="$b" '$2 == b && $6 == "OPEN" { print; exit }' <<<"$prs")"; pr="$(cut -f1 <<<"$prl")"
    why="$(why_not "$t" "$b" "$(grep "^TASK=$t " <<<"$st")" "$prl")"
    [[ -z "$why" ]] || die "$t cannot be stacked now: $why"
    move "$t" "$b" "refs/heads/$ob" "$(diff_base "$b")" "$ob" "${pr:--}" "$ob" ;;
  *) die "usage: implement.sh [feature] status [--running T001,T002] | mark <task> <phase> [<report>] | fail <task> <reason> | retry <task> | restack | stack <task> <onto-task>" ;;
esac
