# Contract: extension/scripts/implement.sh

`implement.sh [feature] status [--running T001,T002]` — reads, apart from fast-forwarding a task branch checked out nowhere (data-model "Moved on GitHub"); never switches branches (every
branch fact is read by name). Refuses with the same messages as `branch.sh` when the feature's
`tasks.md` is not on `origin/<base>` ("merge the spec PR first") and on level `full` without the
analysis record. States and their order: data-model "Task state". Prints, one per line:

```
TASK=T001 STATE=pr PR=12 BRANCH=feat/004-t001-x PARENT=-
TASK=T002 STATE=fix PR=- BRANCH=feat/004-t002-y PARENT=feat/004-t001-x
TASK=T003 STATE=failed PR=- BRANCH=- PARENT=- REASON=review rounds
START=T004 T005
REVIEW=
FIX=T002
OPEN=
ORDER=T001 T002
DONE=1/5
```

`START` respects `parallel_tasks:` minus the `running` tasks. `ORDER` lists every task with a PR or
a branch, parents before children, then by ID. Stacked PRs are drafts until `restack` moves them
onto the base.

`implement.sh [feature] mark <task> implemented|changes|ready|pr [<report>]` — writes the task record
(data-model "Task record"); `changes` increases `round` and keeps the report; the third writes
`failed=review rounds`.
`implement.sh [feature] fail <task> <reason>` / `retry <task>` — as the data model.

`implement.sh [feature] restack` — in the run's worktree, parents first; the skips, moves, push,
`update-ref`, PR base and detach of T005. Prints `RESTACKED=<task> REVIEW=kept|needed`,
`RESTACK_SKIPPED=<task> (<why>)`, `RESTACK_CONFLICT=<task>`.

`implement.sh [feature] stack <task> <onto-task>` — moves an unstacked task onto another task's
branch the same way and records it as its parent.

`implement.sh [feature] check-copy` — creates the whole-feature check copy, merges the branches in
`ORDER`, prints `CHECK=<path>` or `CONFLICT=<task> WITH=<earlier task> FILES=<paths>`, or, without
making a copy, `UNCHANGED=<n>` (same heads as the last `conflict`, `red` or unrecorded attempt) or
`ROUNDS_EXHAUSTED=<n>`. `implement.sh check-result red|green` records the attempt's outcome.
`implement.sh check-copy --remove` removes it.

`implement.sh [feature] release-plan` / `release-bump X.Y.Z` — T009.
`implement.sh audit-plan` prints `AUDIT=needed COMMIT=<sha>` when origin/<base>'s commit has no audit,
else `AUDIT=done|hold COMMIT=<sha> REPORT=<kept copy> HOLD=<n>` (hold when `<n>` > 0).
`implement.sh audit-record <commit> <report> <hold>` refuses a commit that is not on origin/<base> — T010,
data-model "Audit record".

## Changes to existing scripts

- `branch.sh [feature] T003 [--from <branch>]`: starts from `<branch>` and writes `landspec-parent`
  and `parent-head`; refuses a `<branch>` that has no `ready` review for its head (the open spec
  branch excepted, from T007). Its claim expects the branch absent on origin; claimed elsewhere:
  exit 3, `landspec: <task> was claimed elsewhere (<branch> is on origin)` (T001). An existing branch
  is switched to as today.
- `commands/review.md`: the facts carry `base:` (`base_ref()`), used for the diff, `risk` and
  `Reviewed:` (T002).
- `lib.sh` `base_ref()`: research R3.
- `pr.sh task`: `--base` is `base_ref()`'s branch name; the body gains "Stacked on #N (merge it
  first)" when a parent is set; refuses while the parent has no PR; warns per project workflow whose
  `pull_request` filter excludes the parent.
- `next.sh`: offers `/landspec:implement` in a `RUN=` line when two or more tasks can start.
