# Research: Implement a whole feature in parallel

## R1. Who starts the agents

- **Decision**: `/landspec:implement` is a plugin skill (`skills/implement/SKILL.md`) that runs in the
  main session. It starts every implementer and every reviewer itself, as background subagents.
  Implementers never start agents.
- **Rationale**: Claude Code subagents cannot start other subagents, so the review of a task cannot
  be launched from inside its implementer. The main session is also the one place that sees every
  task, so it is the one place to decide what starts next.
- **Alternatives**: one long-lived agent per task that reviews its own work. Rejected: the review
  must come from a fresh reader (constitution, "Before a PR opens").

## R2. Where each task runs

- **Decision**: each implementer is launched with `isolation: "worktree"`. Its first command is
  `bash .specify/extensions/landspec/scripts/branch.sh <feature> <task> [--from <parent branch>]`
  inside its copy, which creates the task branch, claims it on origin and prints `BRANCH=`. The
  implementer reports its copy's path (`Copy: <path>`) with its result, and the main session runs
  that task's review record, scan and PR step in that path.
- **Rationale**: Claude Code then guarantees the implementer's commands run outside the
  developer's checkout (FR-011), the same mechanism spec 003 uses for reviewers. The copy shares
  the repository's objects and remote, so the task branch, its claim and its review record (kept in
  the common git dir, keyed by branch) are visible to the main session. The copy starts at the
  remote default branch (spec 003, R1); `branch.sh` starts the task from `origin/<base>` or the
  parent branch anyway.
- **Alternatives**: `git worktree add` beside the repo, as `next.sh`'s `parallel` lines do, with the
  implementer told to `cd` there. Rejected: nothing stops an implementer from running a command in
  the developer's checkout, which is #121's failure.
- **A copy that is gone**: Claude Code may remove an implementer's copy when the agent ends, and
  what counts as "no changes" for a copy whose commits are pushed is not documented. The work is
  safe either way (committed and pushed by the claim and each fix). When the main session finds the
  `Copy:` path missing, it makes its own `git worktree add <repo>-<feature>-<task> <task branch>`
  beside the repository and runs the record, scan and PR step there; a resumed implementer is told
  that path.
- **Untracked files**: a copy has no git-ignored files (dependencies, `.env`). Claude Code copies
  what `.worktreeinclude` lists; a new optional `worktree_setup:` config key names one command the
  implementer runs first (for example `pnpm install`). Without either, the implementer follows the
  project's README and reports a task it could not prepare as failed.

## R3. Stacking: one place decides a branch's base

- **Decision**: a task branch that starts from another task's branch records it:
  `git config branch.<task branch>.landspec-parent <parent branch>`. `base_ref()` in `lib.sh` returns
  `origin/<parent>` while that setting exists and the parent is not merged, else the base as today.
  `diff_base`, `diff_id`, `review.sh` (record, check, risk), the scans scoped to the change and
  `pr.sh` (`--base`) all go through `base_ref()`, so a stacked task's review, scan and PR cover only
  its own commits.
- **Rationale**: one setting in one function, instead of a flag threaded through every script.
  Local git config is shared by all worktrees of a repository, so the main session and the
  implementer's copy see the same parent.
- **Alternatives**: a `--onto` flag on every script (rejected: easy to forget on one call, and a
  review recorded against the wrong base looks valid); git's own `branch.<b>.merge` upstream
  (rejected: it is the push target, the claim uses it).

## R4. After a parent is squash-merged

- **Decision**: `implement.sh restack` (also run at the start of every `/landspec:implement`, in the
  run's own worktree, skipping branches checked out elsewhere) finds each
  task branch whose recorded parent's PR is merged and runs
  `git rebase --onto origin/<base> <parent's final head, from the merged PR's headRefOid> <task branch>`, removes the
  `landspec-parent` setting (or points it at the next unmerged ancestor), pushes with
  `--force-with-lease`, and sets the PR's base (`gh pr edit --base`). Its review stays valid when the
  patch id of its own diff is unchanged (the record is a patch id, `lib.sh` `diff_id`); otherwise
  the task is marked for a new review.
- **Rationale**: a squash merge rewrites the parent's commits, so the child still carries the old
  ones; `--onto` with the parent's old head drops exactly those. The parent's last reviewed head is
  kept in the child's review record directory when the child starts (`parent-head`), since the
  parent branch may be deleted on merge.
- **Alternatives**: wait for GitHub's automatic retarget when the parent branch is deleted. Rejected:
  the child's diff then shows the parent's changes again until rebased.

## R5. When a dependent task may start

- **Decision**: a task whose line says `(depends on Tnnn)` may start when each named task's branch
  has a recorded `ready` review for its current head, or its issue is closed (merged). With one
  unmerged dependency it starts from that branch; with two or more unmerged dependencies it starts
  when all but one are merged, from the remaining one.
- **Rationale**: a branch can stack on one parent only; two unmerged parents would need a merge
  commit, which the reviewer would have to read twice. The longest chain still runs without a
  human merge; only diamonds (two unmerged parents) wait.
- **Alternatives**: an octopus base for multiple parents (rejected for the review cost above).

## R6. The run's state lives in git, GitHub and the records

> **Revised after plan review round 3**: derived state alone loses a `changes needed` review, the
> round count and a ready-but-unopened PR when the session ends. Each started task gets one small
> record written by `implement.sh mark` (data-model "Task record"); claims, PRs, merges and review
> records stay derived. The skill passes its in-flight agents as `--running`; the worktree lock only
> covers another session's agents.

- **Decision**: no new state file. `implement.sh status` derives each task's state from what exists: the
  issue (open or closed), the claim (branch on origin), the review record (`review.sh check` for
  that branch), the PR (open, merged) and the `landspec-parent` setting. It prints one line per task
  and `START=<ids>` (what can start now, up to `parallel_tasks:`), `ORDER=<ids>` (merge order:
  parents before children, then task ID order).
- **Rationale**: an interrupted run resumes by asking the same question (FR-012), and two sessions
  running at once cannot double-start a task because the claim is a push to origin, which one of
  them loses: the claim becomes exclusive (a push that expects the branch absent on origin;
  `branch.sh` exits 3 when it was claimed elsewhere), which today it is not: the second push of the
  same sha succeeds (plan review round 1). A live implementer is told from an interrupted one by the
  worktree lock Claude Code holds while an agent runs.
- **Stacked PRs and CI**: landspec's generated CI has no `pull_request` branch filter (`level.sh:210`),
  so it runs on a PR into a task branch. A project workflow that filters by branch would not:
  `pr.sh` warns for it on a stacked PR (SC-003 holds for landspec's own checks, and the warning says
  which project workflow does not run).

## R7. Limits

- **Decision**: `parallel_tasks:` (default 4) bounds implementers running together; reviewers do not
  count against it (they are short). A task that ends 3 review rounds still `changes needed`, or
  whose tests stay red after its implementer says it is done twice, is **failed**: its branch and
  PR draft stay, its dependants do not start. The whole-feature check stops after 3 rounds that
  still find gaps (`feature_rounds:`, default 3).

## R8. The whole-feature check

- **Decision**: when every task has a reviewed PR, the main session makes one more copy
  (`git worktree add --detach <repo>-<feature>-check origin/<base>`, removed at the end), merges the
  task branches in `ORDER` with `git merge --no-ff --no-edit`, and runs the constitution's test
  command there. A merge conflict or a red run names the tasks whose files are involved; the fix
  goes to the newest of those task branches as a fix round (implementer resumed, delta review). Then
  it launches a reviewer in **feature review** mode (a new section of `review.md`): given the spec,
  the plan and the combined diff `origin/<base>...HEAD`, it reports each FR, user-story scenario and
  SC as met (with the file, test or output that shows it), not met, or not verifiable, and ends
  `Assessment: ready` only when none is "not met".
- **Rationale**: the per-task reviews read one diff each; only a read of the combination against
  the spec answers "nothing left". The check copy is made by the main session, not by Claude Code's
  isolation, because it must hold all task branches at once; it is detached and never pushed.
- **Gaps** (revised after plan review round 4): each "not met" becomes a task appended to
  `tasks.md` through a spec PR (`pr.sh spec`, in the run's worktree), with its issue, before any
  merge. Gap tasks are ordinary tasks: they start on a later run, after the developer merges the
  feature's PRs and that spec PR, from the base. Stacking them on unmerged work was rejected: no
  single branch holds every independent task's code, and the task line lives only on the spec branch
  (rounds 3 and 4).
- **Stacked PRs are drafts** (round 4): GitHub cannot merge a draft, so a child can never land in its
  parent's branch; `restack` marks it ready (`gh pr ready`) once it targets the base.
- **Default**: the pointers to `/landspec:implement` (issues.md step 6, the next skill) land with the
  check, not before, so the default never skips it.

## R9. Release

- **Decision**: two config keys, `version_files:` (comma-separated paths, each holding the version as
  `version: "X.Y.Z"` or `"version": "X.Y.Z"`) and `release_notes:` (a folder; notes go to
  `<folder>/X.Y.Z.md`). When every task issue of the feature is closed, `/landspec:implement` writes
  the bump (minor; patch when every task line starts with `Fix`), the notes (grouped by user story,
  one line per merged PR, an "Upgrading" section when a task changed config or a command), and opens
  the release PR through `pr.sh fix` with its review. When that PR is merged (found by its title
  `chore(release): X.Y.Z`), it tags the merge commit `vX.Y.Z` and publishes the notes with
  `gh release create`. Without `version_files:` it writes the notes to a temp file and says the
  project has no release convention.
- **Rationale**: landspec's own release (four version files, `docs/releases/X.Y.Z.md`, a lightweight
  tag, notes as the release body) fits these keys, and so do most projects; anything more exotic
  keeps the draft.

- **Audit** (FR-017, T010, revised after round 11): before the bump, the run runs `/landspec:security`'s
  `full` audit unattended (steps 1-6, changing nothing, filing nothing), once per base commit
  (`implement.sh audit-plan`/`audit-record`). A confirmed Critical or High holds the release and the
  final message hands it to `/landspec:security`, whose step 7 tracks and fixes it without
  disclosure. Filing fix tasks from the run was rejected: a task without the finding's detail cannot
  be implemented or reviewed, and one with it discloses the finding (round 11). This replaces telling
  the developer to run `/speckit-converge` and `/landspec:security` by hand when nothing is found:
  the whole-feature check is the converge step.

## R10. Analysis gate and spec PR

- **Decision**: `implement.sh status` refuses (as `branch.sh` does today) when the feature's `tasks.md` is not
  on `origin/<base>`, and on level `full` when the analysis record is missing (`analyzed.sh`'s check).
