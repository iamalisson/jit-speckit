---
description: "Review, commit, push and open the task's pull request"
---

# Task pull request (after `/speckit-implement`)

1. Read the level: `level:` in `.specify/extensions/jit/jit-config.yml` (default `standard`).
   - **lite**: ask "Review and open the PR now?" and continue only on yes.
   - **standard** and **full**: continue.
2. **Checks.** Run the constitution's test command, plus lint and build if they exist. If
   anything fails, stop and report it. Never open a PR on red checks.
3. **Commit.** Commit the task's changes, and only those. Stage files by name, never
   `git add -A`. Use a Conventional Commit message, `<type>(<scope>): <summary>`, with a body line
   `Refs #<ISSUE>`. The git pre-commit hook checks for secrets. If it refuses, remove the secret;
   never use `--no-verify`.
4. **Review before anyone else sees it** (qualified check):
   - `bash .specify/extensions/jit/scripts/security-scan.sh --changed`. Read every finding and fix
     the real ones. List the false positives with the reason.
   - `/security-review` on the branch.
   - `/code-review` on the branch at `medium` on **standard** and `high` on **full** (skip it on
     **lite**). Fix what it confirms.

   Commit the fixes (same rules), then re-run step 2 if code changed.
5. **PR body**, written to a temporary file:
   - one or two sentences on what changed;
   - `## Evidence`: the check output and the security scan summary (which scanners ran, findings
     fixed, false positives), plus screenshots or run links when relevant. It must show the task's
     *Completed when* is met. On **full** the script refuses a body without this section.
6. Run `bash .specify/extensions/jit/scripts/pr.sh task <TASK_ID> "<commit title>" <body-file>`.
   It pushes (the pre-push hook re-checks every commit for secrets), adds `Closes #<ISSUE>` and
   prints `PR=<url>`. The `Security` and `CI` workflows then run on the PR; they are the gate.
7. End with the PR URL.
