#!/usr/bin/env bash
# Push the current work and open (or reuse) its pull request.
#   pr.sh task T003 "feat(api): add price search" [body-file]
#       On the task's branch, with the work already committed. Adds "Closes #N".
#       Every level requires a "## Review" section in the body and a recorded independent review
#       that said "ready" for this exact diff (review.sh), whose recorded facts it adds to the
#       body, folded: patch id, Assessment line, model, any warning and the risk maps as paths;
#       "full" also requires "## Evidence".
#       Runs the constitution's test command before the push and refuses when it fails.
#       On an open PR, replaces its body from body-file.
#   pr.sh spec
#       Stops without a current plan review. Commits the active feature's spec folder on
#       spec/<feature> and opens a docs PR.
# Prints: PR=<url>
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

landspec_cd_root
command -v gh >/dev/null || die "the GitHub CLI (gh) is required: https://cli.github.com"
fdir="$(feature_dir)"
base="$(base_branch)"
mode="${1:-}"

# With a body file (a task PR, whose body must describe the new diff), an open PR's body is replaced.
open_pr() { # open_pr <title> <body> [body-file]
  local url err
  url="$(gh pr list --head "$(git branch --show-current)" --state open --json url --jq '.[0].url // empty')" \
    || die "could not check for an open PR"
  if [[ -z "$url" ]]; then
    url="$(gh pr create --base "$base" --head "$(git branch --show-current)" --title "$1" --body "$2")"
    add_meta pr "$url"
  elif [[ -n "${3:-}" ]]; then
    err="$(gh pr edit "$url" --body "$2" 2>&1 >/dev/null)" || die "could not update the body of $url: ${err%%$'\n'*}"
    echo "PR body replaced from $3; edits made on GitHub are gone"
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
    if [[ "$(landspec_level)" == full ]] && ! grep -qE '^## Evidence' <<<"$body"; then
      die "level 'full' requires an '## Evidence' section in the PR body (test output, screenshots, run links)"
    fi
    grep -qE '^## Review' <<<"$body" \
      || die "the PR body needs a '## Review' section: the independent review's findings and what was done about them (/speckit-landspec-review)"
    # A test that changes to fit the code proves nothing: editing, renaming, skipping or deleting
    # an existing test needs a reason a reviewer can check. Lines only added need none; position
    # cannot decide, as a new test usually lands above a file's closing line.
    # --no-renames: a test moved out of a test folder counts as deleted, not as a new file.
    ref="$(base_ref)"
    git rev-parse --verify --quiet "$ref" >/dev/null || die "base branch '$base' not found locally or on origin"
    diff_id >/dev/null # no merge base: "$ref...HEAD" below would read as no changed tests
    re="$(test_path_re)" || exit 1
    changed_tests=""
    while IFS=$'\t' read -r added deleted f; do
      grep -qE -- "$re" <<<"$f" || continue
      new="$(landspec_diff -U0 "$ref...HEAD" -- "$f" | sed -n '/^@@/,$p' | grep '^+' || true)"
      # A binary file shows "-" and a mode-only change adds nothing: neither is lines only added.
      if ! [[ "$added" =~ ^[1-9] && "$deleted" == 0 ]] || grep -qiE -- "$TEST_SKIP_RE" <<<"$new"; then changed_tests+="$f"$'\n'; fi
    done < <(landspec_numstat --diff-filter=MD "$ref...HEAD")
    if [[ -n "$changed_tests" ]] && ! grep -qE '^## Test changes' <<<"$body"; then
      die "existing tests were changed: $(tr '\n' ' ' <<<"$changed_tests")
add a '## Test changes' section to the PR body saying why (spec changed, test was wrong). Never weaken a test to make it pass."
    fi
    # The review has to have happened, on this diff, and said ready: a heading alone proves nothing.
    # Only that recorded fact and its Assessment go in the body; the report's text never does (the agent's ## Review
    # carries them, a security finding as one line), so nothing private reaches a public PR here.
    review="$(bash "$LANDSPEC_EXT_DIR/scripts/review.sh" report)"
    # Mutation testing too, when the project has a mutate command: mutants.sh records it per diff.
    if [[ -n "$(constitution_cmd mutate)" ]]; then
      mutants="$(diff_record landspec-mutants)"
      [[ -f "$mutants" ]] || die "no mutants.sh result for this diff; run bash .specify/extensions/landspec/scripts/mutants.sh after the last commit"
      grep -q '^mutants unavailable' "$mutants" \
        && die "the mutate command could not run ($(constitution_cmd mutate)); install it or fix it in the constitution, then run mutants.sh again"
      evidence="$(sed -n '/^## Evidence/,/^## /p' <<<"$body")"
      if grep -q '^mutants survivors' "$mutants" && ! grep -qi surviv <<<"$evidence"; then
        die "mutants.sh found surviving mutants; say in '## Evidence' why each changes nothing, or add the test that kills it"
      fi
    else
      body+=$'\n\n'"Mutation testing: not run (no mutate command in the constitution)"
    fi
    # And the scanners on the changed files: a missing scanner or a finding is for the body to say.
    scan="$(diff_record landspec-security)"
    [[ -f "$scan" ]] \
      || die "no security-scan.sh --changed result for this diff; run bash .specify/extensions/landspec/scripts/security-scan.sh --changed after the last commit"
    # Never open a PR on red checks. One log per branch, so parallel worktrees never share one.
    test_cmd="$(constitution_cmd test)"
    if [[ -n "$test_cmd" ]]; then
      log="$(git rev-parse --git-common-dir)/landspec-test/${branch//\//__}.log"; mkdir -p "${log%/*}"
      if ! bash -c "$test_cmd" </dev/null >"$log" 2>&1; then
        tail -n 20 "$log" >&2
        die "the test command failed ($test_cmd); fix it before opening the PR"
      fi
    else
      echo "landspec: tests not run before the PR (no test command in the constitution)" >&2
    fi
    body+=$'\n\n<details><summary>Independent review</summary>\n\n'"$review"$'\n\n</details>'
    grep -qiE "(close[sd]?|fix(e[sd])?|resolve[sd]?) #$issue([^0-9]|$)" <<<"$body" || body+=$'\n\n'"Closes #$issue"
    git push --quiet -u origin "$branch"
    open_pr "$title" "$body" "$body_file"
    ;;
  spec)
    bash "$LANDSPEC_EXT_DIR/scripts/review.sh" check --plan >/dev/null
    # A file tasks.md names that is only untracked here never reaches the base: whoever starts the
    # task from a clean clone has nothing to read.
    missing=""
    while IFS= read -r f; do
      [[ -n "$f" && "$f" != "$fdir"/* ]] || continue
      if grep -qF -- "\`$f\`" "$fdir/tasks.md"; then missing+=" $f"; fi # a path the tasks name, in backticks
    done < <(git ls-files --others --exclude-standard)
    [[ -z "$missing" ]] || die "tasks.md names files that are not in git:$missing. Move each into $fdir/ (it lands with the spec) or write what the task needs into the task, then run again"
    feature="$(basename "$fdir")"
    branch="spec/$feature"
    # An open spec PR is updated in place. Otherwise (first time, or a later run such as after
    # /speckit-converge, when the old spec PR may have been squash-merged) the branch starts
    # fresh from the base, so the new PR shows only what changed. A failed lookup stops here: taken
    # for "none open", the fresh start would overwrite the open PR's branch, teammates' commits too.
    open="$(gh pr list --head "$branch" --state open --json url --jq '.[0].url // empty')" \
      || die "could not check for an open spec PR"
    fresh=false
    if [[ "$(git branch --show-current)" != "$branch" || -z "$open" ]]; then
      ref="$(base_ref)"
      # The spec folder's current content travels with us; nothing else is touched.
      saved="$(mktemp -d)"; cp -R "$fdir" "$saved/"
      restore() { rm -rf "$fdir"; mkdir -p "$(dirname "$fdir")"; cp -R "$saved/$(basename "$fdir")" "$fdir"; rm -rf "$saved"; }
      # If anything fails before the restore below (a switch refused because of other local
      # changes), the folder comes back as it was, instead of surviving only in a temp dir.
      trap 'restore; echo "landspec: the spec folder was put back as it was" >&2' EXIT
      git checkout --quiet -- "$fdir" 2>/dev/null || true; git clean -fdq -- "$fdir"
      if [[ -n "$open" ]]; then sw=(git switch --quiet "$branch"); else sw=(git switch --quiet --no-track -C "$branch" "$ref"); fresh=true; fi
      if ! err="$("${sw[@]}" 2>&1)"; then
        echo "$err" >&2
        die "cannot switch to $branch: local changes outside $fdir conflict with it. Commit or stash them (git stash push -- <file>), then run again"
      fi
      restore; trap - EXIT
    fi
    git add -- "$fdir"
    git diff --cached --quiet || git commit --quiet -m "docs(specs): add $feature spec, plan and tasks"
    # A fresh branch may replace a stale one left by a merged PR (no PR is open on it); the lease
    # still refuses if someone pushed to it since we last fetched.
    if $fresh; then git push --quiet --force-with-lease -u origin "$branch"; else git push --quiet -u origin "$branch"; fi
    issues="$(grep -oE ' — #[0-9]+$' "$fdir/tasks.md" | grep -oE '#[0-9]+' | tr '\n' ' ')"
    # The plan review's model warning, from its record (issues.sh refuses a missing or stale one).
    warn="$(bash "$LANDSPEC_EXT_DIR/scripts/review.sh" report --plan 2>/dev/null | sed -n 's/^warning: /**Plan review:** /p' || true)"
    [[ -z "$warn" ]] || warn=$'\n\n'"$warn"
    open_pr "docs(specs): $feature" "Spec, plan and tasks for \`$feature\`.

**Task issues:** ${issues:-none yet}$warn

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
