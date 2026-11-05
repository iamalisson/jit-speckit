---
name: speckit-jit-pr
description: Review, commit, push and open the task's pull request
compatibility: Requires spec-kit project structure with .specify/ directory
metadata:
  author: iamalisson
  source: jit:commands/pr.md
---

# Task pull request (after `/speckit-implement`)

1. Read the level: `level:` in `.specify/extensions/jit/jit-config.yml` (default `standard`).
   - **lite**: ask "Review and open the PR now?" and continue only on yes.
   - **standard** and **full**: continue.
2. **Checks.** Run the constitution's test command, plus lint and build if they exist. If
   anything fails, stop and report it. Never open a PR on red checks.

   **Tests are evidence, not decoration.** Each test comes from the task's *Completed when* and
   the spec's acceptance scenarios, and must fail if the behavior breaks:
   - assert exact values, both sides of every limit (the last allowed value and the first
     refused one), the error paths, and that nothing extra leaks out;
   - when a test fails, fix the code. Never loosen an assertion, add a retry or a skip, widen
     an accepted value ("200 or 405"), or delete the test to get green;
   - if an existing test really must change (the spec changed, or the test was wrong), the PR
     body needs a `## Test changes` section saying why. The script refuses the PR without it.

   **Mutation testing proves those tests can fail.** Run
   `bash .specify/extensions/jit/scripts/mutants.sh` (the constitution's `mutate` command on this
   branch's changes). `ok` goes in *Evidence*. `survivors` means a behavior no test checks: for
   each surviving mutant in the changed lines, add the test that kills it, or write one line in
   *Evidence* saying why it changes nothing observable (log or help text). `missing` means the
   constitution has no `mutate` command: say so in *Evidence* and suggest `/jit-speckit:adopt`.
3. **Commit.** Commit the task's changes, and only those. Stage files by name, never
   `git add -A`. Use a Conventional Commit message, `<type>(<scope>): <summary>`, with a body line
   `Refs #<ISSUE>`. Attribution lines (`Co-Authored-By` for Claude, "Generated with") follow the
   project's `.claude/settings.json`: with jit-speckit's default `"attribution"` block there are
   none; if the team removed that block to disclose AI use, keep them. The git pre-commit hook checks for secrets. If it refuses, remove the secret;
   never use `--no-verify`.
4. **Independent review**, the gate that catches what this session cannot see about its own
   work. Launch the reviewer exactly as `commands/review.md` (`/speckit-jit-review`) says: one
   fresh general-purpose subagent, given that file and the facts it lists, and nothing of what you
   think about the code. While it runs:
   - `bash .specify/extensions/jit/scripts/security-scan.sh --changed`. Read every finding and fix
     the real ones. List the false positives with the reason.
   - `/security-review` on the branch.

   Then fix every **High** and **Medium** finding in the code (a test changes only when the test
   was wrong: then `## Test changes`, step 2). Commit the fixes (same rules), re-run step 2, and
   run the review again until it says `ready`, at most three rounds; after that stop and show the
   user what remains. **Low** findings are fixed or listed with a reason. Skip nothing because
   the first round was clean: the second round reviews the fixes.
5. **PR body**, written to a temporary file. Keep it short to read: what a reviewer needs is
   visible, the rest folds away.
   - one or two sentences on what changed;
   - `## Review`: the reviewer's *What changed* line, each High and Medium finding and the commit
     that fixed it, the Low ones left with their reason, and the final assessment. On **standard**
     and **full** the script refuses a body without this section;
   - `## Evidence`: one visible line per result (e.g. "tests 42/42 · lint clean · scanners: no
     findings"), showing the task's *Completed when* is met. On **full** the script refuses a body
     without this section.
   - anything long (check output, scan details, false positives with their reason, screenshots)
     goes in a collapsible block, one per topic:
     `<details>` / `<summary>Test output</summary>` / blank line / the content / `</details>`;
   - attribution lines only if the project's settings ask for them (see step 3).
6. Run `bash .specify/extensions/jit/scripts/pr.sh task <TASK_ID> "<commit title>" <body-file>`.
   It pushes (the pre-push hook re-checks every commit for secrets), adds `Closes #<ISSUE>` and
   prints `PR=<url>`, and asks GitHub Copilot code review for a second independent read when the
   account has it. The `Security` and `CI` workflows then run on the PR; they are the gate.
7. End with the PR URL.