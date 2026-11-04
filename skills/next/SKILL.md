---
name: next
description: "Show the current spec-kit feature's progress (a task is done when its issue is closed) and start the next open task with /speckit-implement. Use when the user asks what's next or has just merged a task PR."
---

# Next task

1. Run `bash .specify/extensions/jit/scripts/next.sh`.
   - If `.specify/extensions/jit/` does not exist, tell the user to run `/jit-speckit:init`
     first, and stop.
2. Show the progress as a short list (done / open / no-issue), then `DONE=x/y`.
   - If tasks have **no issue**, say so and suggest `/speckit-jit-issues`.
   - If `NEXT` is empty, the feature is complete. Suggest `/jit-speckit:security` before the next
     release, and `/speckit-specify` for the next feature. Stop.
3. Make sure the working tree is clean. If it isn't, stop and say so; never stash or discard.
4. Run `/speckit-implement <NEXT>`. It switches to the task's branch, implements it, runs the
   pre-PR checks and opens the PR.
