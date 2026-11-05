---
name: speckit-jit-branch
description: Switch to the task's branch before implementing
compatibility: Requires spec-kit project structure with .specify/ directory
metadata:
  author: iamalisson
  source: jit:commands/branch.md
---

# Task branch (before `/speckit-implement`)

One task = one issue = one branch = one PR. This puts the session on the task's branch before
any code is touched.

1. Find the task ID: the single `T###` in the arguments passed to `/speckit-implement`.
   - If there is none, or more than one: **stop the whole implement run**. Tell the user to pass
     exactly one task, e.g. `/speckit-implement T003`. Do not implement anything.
2. Run `bash .specify/extensions/jit/scripts/branch.sh <TASK_ID>`.
   - On failure, stop the implement run and show the script's message as is. It explains what is
     missing: the issue, the spec PR, the analysis, or a clean working tree. Never work around
     it: no stash, no reset, no checkout of other files.
3. On success, print `On <BRANCH> for <TASK> (#<ISSUE>)` and continue `/speckit-implement`
   with **only that task**. Follow the constitution's defaults while implementing.
4. Do not tick the task's checkbox in `tasks.md`. The task is done when its issue closes.