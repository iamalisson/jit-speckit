#!/usr/bin/env bash
# Push the current work and open (or reuse) its pull request.
#   pr.sh task T003 "feat(api): add price search" [body-file]
#       On the task's branch, with the work already committed. Adds "Closes #N".
#       Every level requires a "## Review" section in the body and a recorded independent review
#       that said "ready" for this exact diff (review.sh), whose What changed and Assessment line it
#       adds to the body, folded; "full" also requires "## Evidence".
#       Runs the constitution's test command before the push and refuses when it fails.
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
  local url logins=""
  url="$(gh pr list --head "$(git branch --show-current)" --state open --json url --jq '.[0].url // empty' 2>/dev/null || true)"
  if [[ -z "$url" ]]; then
    url="$(gh pr create --base "$base" --head "$(git branch --show-current)" --title "$1" --body "$2")"
    add_meta pr "$url"
    # A second independent reader when the account has GitHub Copilot code review. GitHub can
    # accept the request and add no one, so the line says what its answer lists.
    if [[ "$url" =~ /([^/]+/[^/]+)/pull/([0-9]+)$ ]]; then
      logins="$(gh api -X POST "repos/${BASH_REMATCH[1]}/pulls/${BASH_REMATCH[2]}/requested_reviewers" -f 'reviewers[]=copilot-pull-request-reviewer[bot]' --jq '.requested_reviewers[].login' 2>/dev/null || true)"
    fi
    if grep -qi copilot <<<"$logins"; then echo "copilot: code review requested"; else echo "copilot: not requested (GitHub did not add the reviewer)"; fi
  fi
  echo "PR=$url"
}

case "$mode" in
  task)
    task="${2:-}"; title="${3:-}"; body_file="${4:-}"
    [[ "$task" =~ ^T[0-9]{3,}$ && -n "$title" ]] || die 'usage: pr.sh task T003 "type(scope): summary" [body-file]'
    line="$(task_line "$fdir" "$task")"
    issue="$(task_issue "$line")"
    [[ -n "$issue" ]] || die "$task has no issue"
    branch="$(git branch --show-current)"
    num="$(feature_key "$fdir")"
    [[ "$branch" == */"$num-$(tr '[:upper:]' '[:lower:]' <<<"$task")-"* ]] \
      || die "not on $task's branch for feature $num (on '$branch'); run /speckit-implement $task"
    [[ -z "$(git status --porcelain)" ]] || die "uncommitted changes; commit the work first"
    git fetch --quiet origin "$base" 2>/dev/null || true
    [[ -n "$(git log --oneline "origin/$base..HEAD" 2>/dev/null || git log --oneline -1)" ]] || die "no commits ahead of $base"

    body=""; [[ -n "$body_file" ]] && body="$(cat "$body_file")"
    if [[ "$(jit_level)" == full ]] && ! grep -qE '^## Evidence' <<<"$body"; then
      die "level 'full' requires an '## Evidence' section in the PR body (test output, screenshots, run links)"
    fi
    grep -qE '^## Review' <<<"$body" \
      || die "the PR body needs a '## Review' section: the independent review's findings and what was done about them (/speckit-jit-review)"
    # A test that changes to fit the code proves nothing: editing, renaming or deleting an
    # existing test needs a reason a reviewer can check. New tests need none.
    # --no-renames: a test moved out of a test folder counts as deleted, not as a new file.
    ref="$(base_ref)"
    git rev-parse --verify --quiet "$ref" >/dev/null || die "base branch '$base' not found locally or on origin"
    re="$(test_path_re)" || exit 1
    changed_tests="$(git diff --no-renames --diff-filter=MD --name-only "$ref...HEAD" | grep -E "$re" || true)"
    if [[ -n "$changed_tests" ]] && ! grep -qE '^## Test changes' <<<"$body"; then
      die "existing tests were changed: $(tr '\n' ' ' <<<"$changed_tests")
add a '## Test changes' section to the PR body saying why (spec changed, test was wrong). Never weaken a test to make it pass."
    fi
    # The review has to have happened, on this diff, and said ready: a heading alone proves nothing.
    # Its What changed and Assessment go in the body; its findings never do (the agent's ## Review
    # carries them, a security finding as one line), so nothing private reaches a public PR here.
    review="$(bash "$JIT_EXT_DIR/scripts/review.sh" report)"
    # Mutation testing too, when the project has a mutate command: mutants.sh records it per diff.
    if [[ -n "$(constitution_cmd mutate)" ]]; then
      mutants="$(diff_record jit-mutants)"
      [[ -f "$mutants" ]] || die "no mutants.sh result for this diff; run bash .specify/extensions/jit/scripts/mutants.sh after the last commit"
      if grep -q '^mutants survivors' "$mutants" && ! sed -n '/^## Evidence/,/^## /p' <<<"$body" | grep -qi surviv; then
        die "mutants.sh found surviving mutants; say in '## Evidence' why each changes nothing, or add the test that kills it"
      fi
    else
      body+=$'\n\n'"Mutation testing: not run (no mutate command in the constitution)"
    fi
    # And the scanners on the changed files: a missing scanner or a finding is for the body to say.
    [[ -f "$(diff_record jit-security)" ]] \
      || die "no security-scan.sh --changed result for this diff; run bash .specify/extensions/jit/scripts/security-scan.sh --changed after the last commit"
    # Never open a PR on red checks. One log per branch, so parallel worktrees never share one.
    test_cmd="$(constitution_cmd test)"
    if [[ -n "$test_cmd" ]]; then
      log="$(git rev-parse --git-common-dir)/jit-test/${branch//\//__}.log"; mkdir -p "${log%/*}"
      if ! bash -c "$test_cmd" </dev/null >"$log" 2>&1; then
        tail -n 20 "$log" >&2
        die "the test command failed ($test_cmd); fix it before opening the PR"
      fi
    else
      echo "jit: tests not run before the PR (no test command in the constitution)" >&2
    fi
    body+=$'\n\n<details><summary>Independent review</summary>\n\n'"$review"$'\n\n</details>'
    grep -qiE "(close[sd]?|fix(e[sd])?|resolve[sd]?) #$issue([^0-9]|$)" <<<"$body" || body+=$'\n\n'"Closes #$issue"
    git push --quiet -u origin "$branch"
    open_pr "$title" "$body"
    ;;
  spec)
    feature="$(basename "$fdir")"
    branch="spec/$feature"
    # An open spec PR is updated in place. Otherwise (first time, or a later run such as after
    # /speckit-converge, when the old spec PR may have been squash-merged) the branch starts
    # fresh from the base, so the new PR shows only what changed.
    open="$(gh pr list --head "$branch" --state open --json url --jq '.[0].url // empty' 2>/dev/null || true)"
    fresh=false
    if [[ "$(git branch --show-current)" != "$branch" || -z "$open" ]]; then
      ref="$(base_ref)"
      # The spec folder's current content travels with us; nothing else is touched.
      saved="$(mktemp -d)"; cp -R "$fdir" "$saved/"
      restore() { rm -rf "$fdir"; mkdir -p "$(dirname "$fdir")"; cp -R "$saved/$(basename "$fdir")" "$fdir"; rm -rf "$saved"; }
      # If anything fails before the restore below (a switch refused because of other local
      # changes), the folder comes back as it was, instead of surviving only in a temp dir.
      trap 'restore; echo "jit: the spec folder was put back as it was" >&2' EXIT
      git checkout --quiet -- "$fdir" 2>/dev/null || true; git clean -fdq -- "$fdir"
      if [[ -n "$open" ]]; then git switch --quiet "$branch"; else git switch --quiet --no-track -C "$branch" "$ref"; fresh=true; fi
      restore; trap - EXIT
    fi
    git add -- "$fdir"
    git diff --cached --quiet || git commit --quiet -m "docs(specs): add $feature spec, plan and tasks"
    # A fresh branch may replace a stale one left by a merged PR (no PR is open on it); the lease
    # still refuses if someone pushed to it since we last fetched.
    if $fresh; then git push --quiet --force-with-lease -u origin "$branch"; else git push --quiet -u origin "$branch"; fi
    issues="$(grep -oE ' — #[0-9]+$' "$fdir/tasks.md" | grep -oE '#[0-9]+' | tr '\n' ' ')"
    open_pr "docs(specs): $feature" "Spec, plan and tasks for \`$feature\`.

**Task issues:** ${issues:-none yet}

Merge this before starting tasks: \`/speckit-implement Tnnn\` branches from \`$base\`, so it needs \`tasks.md\` there.

<details>
<summary>Why is the spec its own PR?</summary>

- Every task branch starts from \`$base\` and reads its issue from \`tasks.md\` there.
- Each task PR then stays small, independent and closes exactly one issue.
- The design gets reviewed before any code is written, while changing it is still cheap.

</details>"
    ;;
  *) die "usage: pr.sh task T003 \"type(scope): summary\" [body-file] | pr.sh spec" ;;
esac
