---
description: "Commit, push and open the task's pull request"
---

# Task pull request (after `/speckit-implement`)

1. Read the level: `level:` in `.specify/extensions/jit/jit-config.yml` (default `standard`).
   - **lite**: ask "Commit, push and open the PR now?" and continue only on yes.
   - **standard** and **full**: continue.
2. Run the checks the constitution names (its test command, plus lint and build if they exist).
   If anything fails, stop and report it. Never open a PR on red checks.
3. Commit the task's changes, and only those. Stage files by name, never `git add -A`.
   Use a Conventional Commit message: `<type>(<scope>): <summary>`, plus a body line
   `Refs #<ISSUE>`.
4. Write the PR body to a temporary file:
   - one or two sentences on what changed;
   - `## Evidence` with the check output (and screenshots or run links when relevant), showing
     the task's *Completed when* is met;
   - on **full**, the Evidence section is required, and the script refuses without it.
5. Run `.specify/extensions/jit/scripts/pr.sh task <TASK_ID> "<commit title>" <body-file>`.
   It pushes, adds `Closes #<ISSUE>` and prints `PR=<url>`.
6. End with the PR URL.
