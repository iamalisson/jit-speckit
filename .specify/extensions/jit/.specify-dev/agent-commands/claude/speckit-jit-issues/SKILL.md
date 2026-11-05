---
name: speckit-jit-issues
description: Create one GitHub issue per task and open the spec PR
compatibility: Requires spec-kit project structure with .specify/ directory
metadata:
  author: iamalisson
  source: jit:commands/issues.md
---

# Create task issues (after `/speckit-tasks`)

Every task gets its own GitHub issue, and its number is written at the end of the task's line in
`tasks.md` (`— #12`). This runs automatically after `/speckit-tasks`; running it again only
creates issues for tasks that don't have one yet.

1. **Ground the plan in the code** before anyone reviews it. A plan that was never checked against
   the repo breaks on the first task. Check, and fix `tasks.md`, `plan.md` and `quickstart.md`
   in place:
   - **References:** for every symbol, table, file, route and config key a task adds, renames or
     removes, search the code, the tests, the docs and data files, and the other tasks. Every hit
     must be handled by some task (its *Impact* line). A task must never delete something a
     later or earlier task still uses.
   - **Guards:** find the existing tests and checks the change trips over, for example a test that
     lists every table, a schema snapshot, or a docs-vs-code check. Name them in *Impact*.
   - **Commands:** for every command in *Completed when* and in `quickstart.md`, read what it
     really runs (the `justfile`/`Makefile`/script, its default arguments, what it logs) and
     confirm it shows what the step claims.
   - **Writes:** every step that writes data names its target and refuses production (an
     explicit dev config, a check of the database name or host).
   - **Independent tests:** expected values are literals in the test, never imported from the
     code under test.

   Never renumber tasks, and never rewrite the text of a line that already ends in `— #N` (its
   issue is linked to that ID and text). A missing task is appended with the next free ID; a
   linked task gets sub-bullets added or fixed, not a new line. Report what changed in one short
   list.
2. **Independent review of the plan.** Launch the reviewer exactly as `commands/review.md`
   (`/speckit-jit-review`) says, as a plan review: one fresh general-purpose subagent, given that
   file and the feature folder, nothing of your own conclusions. Save its report to a file outside the repository (`mktemp`) and record it:
   `bash .specify/extensions/jit/scripts/review.sh record --plan <file>`. Fix what it finds in
   `tasks.md` and `plan.md` under the same rules as step 1, and run it again until it says
   `ready` (at most three rounds). The issue bodies are the task lines, so they must be right
   before any issue exists: `issues.sh` refuses to run without a recorded `ready` plan review for
   the current `tasks.md`.
3. Then create the issues: run `bash .specify/extensions/jit/scripts/issues.sh` from the repository root.
   - If it fails (no `gh`, not logged in, no remote), show its message and stop. Do not create
     issues any other way.
   - Show the `Tnnn → #N` lines it printed.
4. Read the level: `level:` in `.specify/extensions/jit/jit-config.yml` (default `standard`).
5. Open the spec PR, so the tasks reach the base branch where task branches start from:
   - **lite**: ask "Open the spec PR now?"; on yes run
     `bash .specify/extensions/jit/scripts/pr.sh spec`.
   - **standard**: run `bash .specify/extensions/jit/scripts/pr.sh spec`.
   - **full**: do not open it yet. Tell the user to run `/speckit-analyze` next; the spec PR opens
     after the analysis.
6. End with one line: the PR URL (if one was opened), and "merge it, then start a task with
   `/speckit-implement T001`".