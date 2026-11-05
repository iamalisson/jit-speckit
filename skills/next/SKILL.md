---
name: next
description: "Show the current spec-kit feature's progress (a task is done when its issue is closed) and start the next open task with /speckit-implement. Use when the user asks what's next or has just merged a task PR."
---

# Next task

1. Run `bash .specify/extensions/jit/scripts/next.sh`.
   - If `.specify/extensions/jit/` does not exist, tell the user to run `/jit-speckit:init`
     first, and stop.
2. Show the progress as a short list (done / in-progress / open / no-issue), then `DONE=x/y`.
   - **in-progress** tasks have an open PR (from this or another worktree) and are never picked
     again; they finish when their PR merges.
   - If tasks have **no issue**, say so and suggest `/speckit-jit-issues`.
   - If `NEXT` is empty and `IN_PROGRESS` is not 0, nothing is left to start: list the open PRs
     to merge, and stop.
   - If `NEXT` is empty and `IN_PROGRESS=0`, every task's issue is closed. Before calling the feature done, suggest
     `/speckit-converge`: it compares the merged code with the spec and adds any unbuilt work as
     new tasks, which then get their own issues. If it finds nothing, the feature is complete:
     suggest `/jit-speckit:security` before the next release, and `/speckit-specify` for the
     next feature. Stop.
3. Make sure the working tree is clean. If it isn't, stop and say so; never stash or discard.
4. Run `/speckit-implement <NEXT>`. It switches to the task's branch, implements it, runs the
   pre-PR checks and opens the PR.
