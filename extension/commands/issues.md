---
description: "Create one GitHub issue per task and open the spec PR"
---

# Create task issues (after `/speckit-tasks`)

Every task gets its own GitHub issue, and its number is written at the end of the task's line in
`tasks.md` (`— #12`). This runs automatically after `/speckit-tasks`; running it again only
creates issues for tasks that don't have one yet.

1. Run `bash .specify/extensions/jit/scripts/issues.sh` from the repository root.
   - If it fails (no `gh`, not logged in, no remote), show its message and stop. Do not create
     issues any other way.
   - Show the `Tnnn → #N` lines it printed.
2. Read the level: `level:` in `.specify/extensions/jit/jit-config.yml` (default `standard`).
3. Open the spec PR, so the tasks reach the base branch where task branches start from:
   - **lite**: ask "Open the spec PR now?"; on yes run
     `bash .specify/extensions/jit/scripts/pr.sh spec`.
   - **standard**: run `bash .specify/extensions/jit/scripts/pr.sh spec`.
   - **full**: do not open it yet. Tell the user to run `/speckit-analyze` next; the spec PR opens
     after the analysis.
4. End with one line: the PR URL (if one was opened), and "merge it, then start a task with
   `/speckit-implement T001`".
