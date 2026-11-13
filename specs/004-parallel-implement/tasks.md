---
description: "Tasks for implementing a whole feature in parallel"
---

# Tasks: Implement a whole feature in parallel

**Input**: Design documents from `specs/004-parallel-implement/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/implement-sh.md](contracts/implement-sh.md), [contracts/implement-skill.md](contracts/implement-skill.md), [contracts/feature-review.md](contracts/feature-review.md), [quickstart.md](quickstart.md)

**Tests**: every task ships its checks in the same PR (bash, "when …, then …", through `tests/helpers.sh`).

**Organization**: one phase per user story; User Story 5 (the default) ships with the gap tasks, the last piece of the check.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (no dependency on an unmerged task; overlaps in a shared file are named)
- `(depends on T00n)`: needs that task merged first
- One task = one issue = one branch = one pull request; ` — #N` is appended automatically.

## Rules every task follows

- **Spec 003's T001 (#124) merges before any task here**: it edits `branch.sh`, `pr.sh`, `review.sh`
  and `review.md` at the lines these tasks quote, and it is what runs each review in its own copy.
  Line numbers below are from `origin/main` before it; re-find them after it lands. Spec 003's
  T002 (#125) is not needed.
- After editing `extension/`, sync the installed copy: `specify extension add --dev extension --force`,
  then `git restore .specify/extensions/.registry` when only its timestamp changed.
- Docs in the same PR: `README.md`, `docs/reference.md` (commands, the config table near `:159`),
  `docs/design.md`, and the command prompts that describe the changed behavior.
- Bash 3.2 with BSD or busybox tools; `tests/run.sh` and the lint command pass before the PR.
- **Invariant 1** (data-model "Where the run writes"): the developer's checkout is never written, and
  every step that checks out or commits a branch in a copy the run made ends with `git switch
  --detach` there. Each task that writes a branch tests the developer's checkout (`git status
  --porcelain`, current branch) unchanged and the branch free to `git worktree add` afterwards.
- **Invariant 2** (data-model "Task state"): one state per task; `START` only when nothing works on
  it and nothing is pending on it.

---

## Phase 3: User Story 2 - Dependent tasks start without waiting for a merge (Priority: P1)

Built first: User Story 1's run starts dependent tasks this way.

**Goal**: one owner per task, and a task branch can start from another task's branch with its review, scan and PR covering only its own commits.

**Independent Test**: quickstart scenario 1.

- [ ] T001 [P] [US2] Make a task's claim exclusive, so two sessions never start the same task, in extension/scripts/branch.sh — #127
  - Comes from: FR-005, FR-012; research R6; data-model "Both pending"
  - What: when `branch.sh` creates a new task branch (the `else` near `:57`), the claim push becomes
    `git push --quiet -u --force-with-lease=refs/heads/<branch>: origin <branch>` (expects the branch
    absent on origin). When git refuses it because the branch now exists on origin, `branch.sh`
    switches back to where it started, deletes its new local branch and exits 3 with
    `landspec: <task> was claimed elsewhere (<branch> is on origin)`. Any other push failure keeps
    today's warning and the branch. Switching to a branch that already exists, locally or only on
    origin (`--track`), is unchanged: that is how a developer continues their own task elsewhere
  - Impact: `branch.sh:50-62`; `skills/next/SKILL.md` step 4 (a `parallel` line can now exit 3: say
    "started elsewhere, skipped"); `tests/branch.test.sh`; `docs/reference.md` (the claim paragraph)
  - Completed when: `bash tests/branch.test.sh` passes with new checks, using two clones of one local
    origin: when clone B creates the branch after clone A pushed its claim (B fetched before A's
    push), B exits 3 with the exact message, is back on its starting branch, and has no local task
    branch; when the origin is unreachable, the warning is printed and the branch kept; when the
    branch exists only on origin, `branch.sh` switches to it with `--track` and exits 0. `tests/run.sh`
    passes

- [ ] T002 [US2] Start a task branch from another task's reviewed branch, and read any branch's base, diff and review by name from any HEAD, in extension/scripts/lib.sh, extension/scripts/review.sh, extension/scripts/branch.sh and extension/commands/review.md (depends on T001) — #128
  - Comes from: FR-004, US2 scenario 1; research R3, R5; data-model "Stack", "Task state" (read by branch name); [contracts/implement-sh.md](contracts/implement-sh.md) "Changes to existing scripts"
  - What: `lib.sh` `base_ref [<branch>]`, `diff_base [<branch>]` and `diff_id [<branch>]` take a
    branch (default: the current one, as today): `base_ref <b>` returns `origin/<parent>` (else
    `<parent>`) while `branch.<b>.landspec-parent` is set, else the base; `diff_base <b>` is `git
    merge-base <b> "$(base_ref <b>)"`; `diff_id <b>` diffs that range. `review.sh` `check`,
    `report` and `record` take `--branch <b>` (default: the current branch; detached HEAD without it
    still dies as at `:37`), keyed by `<b>` as today's record name. `branch.sh [feature] T003 --from
    <branch>` starts the new branch from `origin/<branch>` (else the local `<branch>`), refuses a
    `<branch>` for which `review.sh check --branch <branch>` fails, and writes the setting and
    `<git common dir>/landspec-review/parent-head-<new>`. **The reviewer's range**: the reviewer runs
    detached in its own copy, so the author's facts carry `base: <base_ref <b>>`, and `review.md` uses
    that ref wherever it now says `origin/<base>` for the diff: `git diff <base>...HEAD`, `review.sh
    risk "$(git merge-base HEAD <base>)"` (`:58-59`), `Reviewed: <git merge-base HEAD <base>>..<head>`
    (`:124-125`); its facts list names the field. `base_ref` stays offline: only `implement.sh
    restack` (T005) removes the setting
  - Impact: every caller of `base_ref`/`diff_base`/`diff_id` keeps its no-argument call:
    `review.sh:163`, `:181`, `:210`, `mutants.sh:29`, `pr.sh:79`, `pr.sh:151`, `:169` (the spec mode,
    whose branch never has a parent: keep it so, a test); `branch.sh:26-34` (where it picks `from`);
    `extension/commands/pr.md` (the facts it passes: add `base:`); tests: `tests/branch.test.sh`,
    `tests/review.test.sh`, `tests/static.test.sh`; `docs/reference.md` (task branches, near `:77-94`)
  - Completed when: `bash tests/branch.test.sh` passes with new checks: `--from` a branch with a
    `ready` review starts from its head and writes both records; `--from` a branch with no review, a
    review of an older head, or a branch that does not exist refuses with a message naming the branch
    and starts nothing; `--from` a parent that is checked out in another worktree works (it is read
    by name). `bash tests/review.test.sh`: on a stacked branch, `review.sh risk` covers only its own
    commit, and a report stating `Reviewed:` from the merge base with the parent is recorded (one from
    the base's merge base is refused with the existing message); from a detached HEAD, `review.sh
    check --branch <b>` gives the same answer as on `<b>`, and `diff_id <b>` equals `diff_id` run on
    `<b>`. `bash tests/static.test.sh` pins `review.md` reading the facts' `base:` for the diff, `risk`
    and `Reviewed:`. `tests/run.sh` passes

- [ ] T003 [US2] Open a stacked task's PR against its parent, scan only its own files, and warn when a workflow will not run on it, in extension/scripts/pr.sh, extension/scripts/security-scan.sh and extension/scripts/lib.sh (depends on T002) — #129
  - Comes from: FR-004, SC-003; research R6 "Stacked PRs and CI"
  - What: `pr.sh task`'s `--base` (`:27`, `:36`) is the parent's branch name when one is set, and the
    PR is opened with `--draft` (GitHub cannot merge a draft, so it never lands in its parent; it is
    marked ready only once it targets the base with a valid review: T005, T006). When gh refuses
    `--draft` (a plan without drafts), it opens a normal PR and warns `landspec: warning: drafts are not
    available: merge #<parent> first, and only after this PR's review is current`; the body gains `Stacked on #<parent's PR> (merge it first)`; it refuses with `landspec: open the PR of
    <parent> first` while the parent has no open or merged PR; it warns `landspec: warning: <workflow>
    never runs on a PR into <parent>: its pull_request branches filter it out` per workflow whose
    `pull_request` filter excludes the parent (`level.sh` `pr_branches`/`pr_skips_base`, `:177-197`,
    moved into `lib.sh` with the branch as an argument; landspec's generated CI, `level.sh:210`, has
    no filter and runs). `security-scan.sh --changed` (`:33-36`) takes its base from `base_ref`
  - Impact: `pr.sh:27-40`; `level.sh:405` keeps calling the moved helpers; `tests/pr.test.sh`,
    `tests/security-scan.test.sh`, `tests/level.test.sh`; `docs/reference.md` (stacked PRs)
  - Completed when: `bash tests/pr.test.sh` passes with new checks: a stacked PR is created with
    `--base <parent>`, `--draft` and the body line; with a gh mock that refuses `--draft`, a normal PR
    with the warning; it refuses while the parent has no PR; a workflow with
    `pull_request: branches: [main]` warns for a stacked PR and not for an unstacked one; an unstacked
    branch and the spec mode are unchanged. `bash tests/security-scan.test.sh`: `--changed` on a
    stacked branch lists only its files. `bash tests/level.test.sh` passes. `tests/run.sh` passes

---

## Phase 4: User Story 1 - Start every task of a feature at once (Priority: P1) 🎯 MVP

**Goal**: one command starts every task that can start, each in its own copy, and drives each to a reviewed PR.

**Independent Test**: quickstart scenario 2.

- [ ] T004 [US1] Derive every task's state and the next step for each, from git, GitHub and one record per task, in extension/scripts/implement.sh (depends on T002) — #130
  - Comes from: FR-001, FR-005, FR-007, FR-012, FR-015; research R5, R6 (revised), R7, R10; data-model "Task record", "Task state"; [contracts/implement-sh.md](contracts/implement-sh.md)
  - What: new `implement.sh [feature] status [--running T001,T002]` (read-only) prints one
    `TASK=<id> STATE=<state> PR=<n|-> BRANCH=<b|-> PARENT=<b|->` line per task, then `START=`,
    `REVIEW=`, `FIX=`, `OPEN=`, `ORDER=` (parents first) and `DONE=`, with the states of the data-model table checked in its order. `implement.sh mark
    <task> <phase> [<report>]` writes the task record (`phase=`, `head=` the branch head, `round=`
    increased on `changes`, the report copied beside the record); a `changes` that reaches round 3
    writes `failed=review rounds`. `fail <task> <reason>` and `retry <task>` as the data model. Every
    branch fact is read by name (T002's `--branch`), never by switching. `START` holds at most
    `parallel_tasks:` (default `4`, `1-16`; any other value dies with `landspec: parallel_tasks must be
    a number from 1 to 16`) minus the `running` tasks. It refuses, with `branch.sh`'s messages, when
    `tasks.md` is not on `origin/<base>` and on level `full` without the analysis record. `status`
    reads, apart from one write: a local task branch behind its origin branch and **checked out
    nowhere** is fast-forwarded (`update-ref`); behind and checked out somewhere is `elsewhere` with
    `REASON=checked out in <path>`; diverged is `elsewhere` with `REASON=diverged from origin`. A
    `running` task found only by a locked worktree prints `REASON=locked worktree <path>` (an agent
    killed mid-task leaves it: the report names `git worktree unlock <path>` and removing it). A PR
    that targets the base, is still a draft and has a valid review is `reviewed` (in `OPEN=`) only
    when `branch.<b>.landspec-parent` is unset; while it is set (GitHub retargets a child when the
    parent's branch is deleted, before `restack` moved it) the task is `waiting` with `REASON=restack
    pending`
  - Impact: reuse `lib.sh` `task_line`, `task_issue`, `feature_dir`/`resolve_feature`, `cfg`, and
    `next.sh`'s reads of claims, worktrees and open PRs (`next.sh:23-31`) and dependencies (`:65-71`),
    moving shared parts into `lib.sh` (T002 and T003 also edit `lib.sh`: whichever merges second
    rebases); `branch.sh:40`'s analysis marker; new `tests/implement.test.sh`; `docs/reference.md` (`parallel_tasks` row)
  - Completed when: `bash tests/implement.test.sh` passes, with a throwaway repo, a local origin and
    the gh mock, run from a **detached HEAD**, for a feature of T001, T002 [P], T003 (depends on
    T001), T004 (depends on T002, T003): before anything starts, `START=T001 T002`, T003 and T004
    `waiting`; T001 reviewed (a recorded `ready`) is `reviewed`, in `OPEN=`, and makes T003
    `startable`; T002 and T003 both reviewed and unmerged keep T004 `waiting`, and T002 merged makes
    it `startable`; `parallel_tasks: 1` gives one id; `0` and `abc` die with the exact message; a
    branch on origin with no local branch is `elsewhere`; `--running T001` makes T001 `running` and
    takes a slot, and so does a branch checked out in a locked worktree; `mark T001 implemented` is
    `implemented`, in `REVIEW=`, not in `START`, and a new commit on it makes it `resume`; `mark T001
    changes <file>` is `fix`, in `FIX=`, with the report kept, and the third `changes` makes it
    `failed`; `fail T002 "tests red"` is `failed` and T004 never `startable`, a new commit or `retry`
    lifts it; a `fail` before the branch exists stays until `retry`; a branch pushed to on origin by
    someone else is fast-forwarded locally, the same branch checked out in a worktree is not moved and
    is `elsewhere` with the path, and one that diverged is `elsewhere`; a draft PR on the base with a
    valid review is in `OPEN=`, and the same PR with `landspec-parent` still set (retargeted by GitHub,
    restack skipped or conflicted) is `waiting` with `REASON=restack pending` and in no list; `ORDER` lists parents before children; a feature
    whose `tasks.md` is not on `origin/<base>` refuses with "merge the spec PR first"; a failed `gh`
    call stops with gh's error, never an empty state; the current HEAD is the same after every
    call. `tests/run.sh` passes

- [ ] T005 [US2] Move stacked task branches onto the base after their parent is merged, and stack one task on another, in extension/scripts/implement.sh (depends on T003, T004) — #131
  - Comes from: FR-006, FR-009, US2 scenario 3, spec edge cases "a dependency's PR changes" and "merges PRs out of the printed order"; research R4; data-model "Stack" orderings, "Where the run writes"; [contracts/implement-sh.md](contracts/implement-sh.md) `restack`
  - What: `implement.sh [feature] restack`, in the run's worktree `<repo>-<feature>-run` (made
    detached at `origin/<base>` when missing), going through the stacked branches **parents first**
    (`ORDER`). It skips, each with `RESTACK_SKIPPED=<task> (<why>)`: a branch checked out in any
    worktree, a `running` task, one whose origin head differs from its PR's `headRefOid` (`origin
    moved`), one with local commits not on origin. For each other one, on a detached HEAD at its head:
    when the parent's PR is merged into the base, `git rebase --onto origin/<base> <parent's final
    head>` (read from the merged PR's `headRefOid`, never `parent-head`) and the setting removed (or
    set to the next unmerged ancestor); when the parent moved without merging, `git rebase --onto
    origin/<parent> <parent-head>`. Then `git push --force-with-lease=<branch>:<origin head read by this
    restack's fetch> origin HEAD:refs/heads/<branch>`, `git update-ref refs/heads/<branch> HEAD <old>`,
    `parent-head` updated, `gh pr edit <pr> --base <new base>` (and `gh pr ready <pr>` only when the new
    base is the base **and** the review was kept; a `REVIEW=needed` PR stays a draft until its new
    review, whose OPEN step marks it ready), and `git switch --detach origin/<base>`. Every move rewrites the task record's `head=` to the new head, keeping its `phase`,
    `round` and `failed=` (so an `implemented`, `fix` or `failed` task keeps its state). It prints
    `RESTACKED=<task> REVIEW=kept` when the task had a valid review before the move and `diff_id
    <branch>` is unchanged, `REVIEW=needed` and `mark <task> implemented` when it had one and the diff
    changed, and `REVIEW=none` when it had none. A task with no PR yet skips the `gh` calls. A failed
    `gh pr ready` prints `RESTACK_NOT_READY=<task>` and leaves the record, so the task is `reviewed`
    (a draft on the base) and the OPEN step retries it. A conflict runs `git rebase --abort`, prints
    `RESTACK_CONFLICT=<task>` and leaves the branch. `implement.sh [feature] stack
    <task> <onto-task>` (used by T007's check) does the same move onto another task's branch, sets the
    setting and `parent-head`, and refuses a task that already has a parent
  - Impact: T004's `implement.sh`; T002's `diff_id <b>`; `tests/implement.test.sh`;
    `docs/reference.md` (merge order and restack)
  - Completed when: `bash tests/implement.test.sh` passes with new checks on a throwaway repo with a
    local origin: T001 squash-merged into the base (`git merge --squash`, push), then `restack` moves
    T002 onto the base, its diff holds only T002's file, it prints `REVIEW=kept`, the setting is gone,
    and the mocked gh got `pr edit --base main` and `pr ready`; a child moved onto a still-open parent
    gets no `pr ready`; a child whose diff changed in the move (`REVIEW=needed`) gets no `pr ready`
    and stays a draft; an `implemented`, a `fix` and a `failed` stacked task each keep their state
    after a move and none is in `START`; a task with no PR is moved with no `gh` call; a gh mock whose
    `pr ready` fails gives `RESTACK_NOT_READY` and the task in `OPEN=`; in a chain T001 → T002 → T003 with T001 merged, one
    `restack` leaves T003's diff against T002 holding only T003's file; a parent fix round moves the
    child onto the new parent head; a parent fixed after the child started and then squash-merged
    gives a child whose diff holds only its own file, with no conflict; a child touching the parent's
    fixed lines prints `RESTACK_CONFLICT` and keeps its head; each skip case prints its line; `stack
    T003 T002` makes T003's diff against T002 hold only T003's file and refuses a second `stack`; a
    `REVIEW=needed` task is `implemented`; a second `restack` prints nothing; after every case the run's
    worktree is detached, `git worktree add <dir> <branch>` succeeds, and the developer's checkout is
    unchanged. `tests/run.sh` passes

- [ ] T006 [US1] Add /landspec:implement: run every startable task as a background implementer in its own copy and drive each through review, fixes, scan and PR, in skills/implement/SKILL.md and agents/implementer.md (depends on T003, T004, T005) — #132
  - Comes from: FR-001-FR-003, FR-005, FR-007, FR-011, FR-012, FR-014, FR-016; US1 scenarios 1-4; SC-001-SC-003, SC-007; research R1, R2, R7; [contracts/implement-skill.md](contracts/implement-skill.md) steps 1-4 and 6
  - What: the skill's loop, each pass: `restack`, then `status --running <its in-flight tasks>`, then
    one step per listed task: `START` → an implementer; `REVIEW` → a review (facts carry `base:
    <base_ref <b>>`), then `mark` with its result; `FIX` → a fix round given `report=` (SendMessage to
    the implementer still in flight, else a new implementer on the branch); `OPEN` → in the task's copy,
    `git switch <branch>` (free: copies are left detached), the scan and `pr.sh task` (on an existing draft PR
    that now targets the base: `gh pr ready` after it, never while `landspec-parent` is set), parents
    first, then `mark <task> pr` and `git switch --detach` there. It stops when nothing is listed and nothing is in flight. `agents/implementer.md`: name
    `implementer`, `isolation: worktree`; its rules: `branch.sh <feature> <task> [--from <parent>]`
    first, then `worktree_setup:` when set, implement as `/speckit-implement` does with its tests,
    commit by name, never `git add -A`, never touch a path outside its copy, push, `git switch
    --detach` last, return `Copy: <path>` and `BRANCH=`. On return, the skill runs `mark <task>
    implemented` before anything else. Launch model from `implement_model:` (`sonnet`, `opus` or
    `fable`; empty: the session's). A missing `Copy:` is recreated with `git worktree add --detach
    <repo>-<feature>-<task> <branch>`. `branch.sh` exit 3 → `elsewhere`, start the next. Until T008
    lands, the last line says `the whole-feature check is not built yet: check the feature with
    /speckit-converge after merging`, and nothing points to the command by default.
    `/speckit-implement` is unchanged
  - Impact: `extension/commands/pr.md` (the PR step per task, unchanged; the skill points to it);
    `README.md` command table and the "before each PR" row near `:126`; `docs/reference.md` (the
    command; rows `worktree_setup`, `implement_model`); `docs/design.md` (why stacked PRs, why the main
    session starts every agent); `skills/help/SKILL.md` reads the docs; `tests/static.test.sh`; the
    plugin's agent list (`agents/`)
  - Completed when: `bash tests/static.test.sh` passes with new checks that fail when the skill stops
    launching implementers with `isolation: "worktree"`, stops passing `--running` or `base:`, loses
    one of the four list steps (`START`, `REVIEW`, `FIX`, `OPEN`), stops running `mark … implemented`
    first on return, `git switch <branch>` before the PR step, `gh pr ready` after `pr.sh task` on a
    draft that targets the base, or `git switch --detach` after it, merges a PR (`gh pr merge` anywhere),
    or loses the `ORDER=` output; when `agents/implementer.md` loses `isolation: worktree`, the "never
    `git add -A`" rule or its final `git switch --detach`; one pin per failure path: no `Copy:`
    (recreate), SendMessage missing (a new implementer), `worktree_setup` failing (`fail` with its
    output), `branch.sh` exit 3 (`elsewhere`). `tests/run.sh` passes. Quickstart scenario 2 on a
    scratch repo: five PRs, T004 stacked on T001 and T005 on T004, no question asked, the wall time
    and the scratch checkout's `git status --porcelain` before and after pasted into `## Evidence`

**Checkpoint**: a feature runs in parallel end to end, without the whole-feature check yet.

---

## Phase 5: User Story 3 - Check the whole feature together (Priority: P1)

**Goal**: the combination of all task branches passes the full suite and meets every requirement of the spec, or the gaps become tasks.

**Independent Test**: quickstart scenario 4.

- [ ] T007 [US3] Check all task branches combined against the full suite and the spec, in extension/scripts/implement.sh, extension/scripts/review.sh, extension/commands/review.md and skills/implement/SKILL.md (depends on T006) — #133
  - Comes from: FR-008, FR-009, US3 scenarios 1, 2, 4, 5, SC-004, SC-005; research R8; [contracts/feature-review.md](contracts/feature-review.md); [contracts/implement-skill.md](contracts/implement-skill.md) step 5
  - What: `implement.sh [feature] check-copy` makes `<repo>-<feature>-check` (detached at
    `origin/<base>`), merges the task branches in `ORDER` with `git merge --no-ff --no-edit`, stores
    the result at `refs/landspec/check/<feature>`, prints `CHECK=<path>` or, on a conflict, runs `git
    merge --abort` and prints `CONFLICT=<task> WITH=<earlier task> FILES=<paths>`; `check-copy
    --remove` removes the copy and the ref. `review.md` gains the **feature review** mode of the
    contract (one line per FR, scenario and SC: `met`, `not met`, `not verifiable`, with evidence;
    `ready` only when none is `not met`). `review.sh record --feature <file>` records it per feature
    (`<common dir>/landspec-review/feature-<feature>`), refusing `--feature` with `--plan`, `--delta`
    or `--branch`. The skill's step 5, when every task is `pr` or `merged`: check copy, the test command
    there, the feature review. A conflict: `implement.sh stack <task> <earlier task>` (T005), so the
    fix round sees both; when the task already has a parent, stop and report both. A red run: a fix
    round on the branch whose files the failing test covers, stacked on the other branch it needs the
    same way. At most `feature_rounds:` (default `3`, `1-9`) rounds, counted across runs per **check attempt**:
    `check-copy` keeps `round=<n>` and the last combination (the task heads merged) in
    `<common dir>/landspec-review/feature-<feature>-round`, and increases it whenever it runs on a
    combination different from the last one, with the outcome (`conflict`, `red`, `green`) recorded by
    `implement.sh check-result <red|green>`. The feature review runs only after a green run, and only a
    green run plus a `ready` feature review resets the counter. `check-copy` on the same combination
    as the last `conflict` or `red` one, or as an attempt whose outcome was never recorded (the session
    ended between the test run and `check-result`), prints `UNCHANGED=<n>` and creates nothing: the fix round made
    no change (or the test is flaky), and the skill stops and asks. So a conflict, a red run and a
    `changes needed` review each count once per new attempt; when `round` exceeds `feature_rounds:`, `check-copy` prints `ROUNDS_EXHAUSTED=<n>` and
    creates nothing, and the skill stops and asks. The check does not run while the feature has an open spec PR (gaps already filed wait
    for its merge): `gh pr list --repo <repo> --head spec/<feature> --state open` (the branch `pr.sh
    spec` uses); a failed lookup stops the step with gh's error, never read as "none open"; the
    report says `merge <spec PR> first`.
    `not met` lines are listed in the report (T008 turns them into tasks)
  - Impact: T004/T005's `implement.sh`; `review.sh` argument parsing (`:20-24`) and usage (`:212`);
    `review.md`'s Report section and facts list (`:30-43`); `tests/implement.test.sh`,
    `tests/review.test.sh`, `tests/static.test.sh`; `docs/reference.md` (`feature_rounds` row; the
    check), `docs/design.md`
  - Completed when: `bash tests/implement.test.sh` passes with new checks: `check-copy` on three
    branches that merge cleanly prints `CHECK=` and the ref holds all three files; two unstacked
    branches editing the same line print `CONFLICT=<the later> WITH=<the earlier> FILES=<that file>`
    and leave no merge in progress, and after `stack <later> <earlier>` and a fix commit on the later
    one, `check-copy` prints `CHECK=`; `--remove` removes the copy and the ref, a second `--remove` is
    silent; the developer's checkout is unchanged. `bash tests/review.test.sh`: a feature report with
    one `not met` records `changes needed`, one with only `met` and `not verifiable` records `ready`,
    `--feature --plan` is refused; `check-copy` twice on the same heads keeps `round=`, on new heads
    (after a fix commit) increases it, a conflict counts like a clean merge, a recorded `ready`
    feature review after a green run resets it, a `ready` after a red run does not, `check-copy` on the
    same heads as the last red result prints `UNCHANGED=` and makes no copy, and with `feature_rounds: 2` the third attempt on new heads prints
    `ROUNDS_EXHAUSTED=2` and makes no copy. `bash tests/static.test.sh` pins the three line kinds, the
    conflict → `stack` step and the `feature_rounds` stop. `tests/run.sh` passes

- [ ] T008 [US3] File the whole-feature check's gaps as tasks before anything is merged, and make /landspec:implement the default after the tasks, in skills/implement/SKILL.md, extension/scripts/next.sh, extension/commands/issues.md and skills/next/SKILL.md (depends on T007) — #134
  - Comes from: FR-010, FR-014, US3 scenario 3, US5 scenarios 1-3; research R8 "Gaps" (revised)
  - What: each `not met` becomes a task line appended to `tasks.md` through a spec PR, in the run's
    worktree: the check runs only when the feature has no open spec PR (T007), so it is always a new
    one, which `pr.sh spec` opens from `origin/<base>` (its existing "update" path), then `git switch --detach`
    there (a spec branch checked out in the developer's checkout is skipped with `SKIPPED=`, and the
    skill says so and stops). The new lines get a plan review of those lines and their issues
    (`issues.sh`). Gap tasks are **ordinary tasks**: the report lists them and says "merge the PRs in
    `ORDER` and the spec PR, then run `/landspec:implement` again"; the next run starts them from the
    base and runs the check again. **The default**: `next.sh` prints `RUN=/landspec:implement
    <feature>` before `FEATURE=` when two or more tasks can start; `issues.md` step 6 ends with "merge
    it, then run `/landspec:implement` for the whole feature (or `/speckit-implement T001` for one
    task)"; `skills/next/SKILL.md` offers `/landspec:implement` on `RUN=`; T006's "not built yet" line
    is removed
  - Impact: `extension/commands/issues.md:74-75`; `skills/next/SKILL.md:39-48` and its description;
    `next.sh` output (before `FEATURE=`, near `:113`); `pr.sh spec` (unchanged, called from the run's
    worktree); `tests/next.test.sh` (exact output lines), `tests/static.test.sh`; installed copies of
    issues.md; `README.md` (the loop), `docs/reference.md`
  - Completed when: `bash tests/next.test.sh` passes with checks: `RUN=` printed when two tasks can
    start, not with one, and the other lines unchanged. `bash tests/static.test.sh` pins that fail when
    the skill stops filing a `not met` through `pr.sh spec`, or runs the check while the
    feature has an open spec PR, stops ending with the "merge … then run
    again" line when gaps were filed, or leaves the run's worktree attached after the gap step; when
    `issues.md` step 6 stops naming `/landspec:implement`, the next skill stops offering it on `RUN=`,
    or the "not built yet" line comes back. `tests/run.sh` passes; quickstart scenario 4 holds

---

## Phase 6: User Story 4 - A release ready when the feature is merged (Priority: P2)

**Goal**: after the feature's PRs are merged, a reviewed release PR, then a tag and published notes.

**Independent Test**: quickstart scenario 5.

- [ ] T009 [US4] Prepare the release PR when the feature is merged, then tag and publish it, each step once, in extension/scripts/implement.sh and skills/implement/SKILL.md (depends on T008) — #135
  - Comes from: FR-013, US4 scenarios 1-3, SC-006; research R9; data-model config keys `version_files`, `release_notes`
  - What: `implement.sh [feature] release-plan` reads the release's state from git and GitHub, in this
    order, with `V` the version in the first of `version_files:` and `M` the merge commit of the
    feature's last merged task PR: tag `vV` on origin, `M` an ancestor of it (`git merge-base
    --is-ancestor M vV`) and a published release `vV` → `RELEASE=done V`; tag `vV` with `M` an ancestor,
    no release → `RELEASE=publish V`; tag `vV` without `M` an ancestor → this feature is not released
    yet: go on to `bump`; a merged PR titled
    `chore(release): V`, no tag → `RELEASE=tag V COMMIT=<its merge commit>`; an open one →
    `RELEASE=pending X.Y.Z PR=<n>` for any open PR titled `chore(release): *` (it carries the next
    version, not `V`); otherwise, when every task issue of the feature is closed →
    `RELEASE=bump X.Y.Z` (minor from `V`, patch when every task line's description starts with `Fix`)
    with `FILES=`, `NOTES=<release_notes>/X.Y.Z.md` and `PRS=<merged PR numbers>`; with an open task
    issue it refuses naming the task; without `version_files:` → `RELEASE=none (no version_files:)`.
    `implement.sh release-bump X.Y.Z` rewrites `version: "…"` and `"version": "…"` in each file, and
    refuses a file that has neither, changing nothing. The skill acts on the one state printed:
    `bump` → write the notes (by user story, one line per PR, "Upgrading" when a task changed a config
    key or a command), commit on `chore/release-X.Y.Z` in the run's worktree, `pr.sh fix` with its
    review, then `git switch --detach origin/<base>`; `tag` → `git tag vV <commit>` and push it;
    `publish` → `gh release create vV --title "<project> V" --notes-file <notes>`; `pending`, `done` →
    say so. Without `version_files:`, it writes the notes to a `mktemp` file and says the project has
    no release convention
  - Impact: T004's `implement.sh` (T007 and T008 add subcommands: rebase on whichever lands first);
    `pr.sh fix` (`pr.sh:46-63`); landspec's own release (four version files, `docs/releases/`) must
    fit, so this repo's `.specify/extensions/landspec/landspec-config.yml` sets both keys here; `tests/implement.test.sh`,
    `tests/static.test.sh`; `docs/reference.md` (two config rows, the release step)
  - Completed when: `bash tests/implement.test.sh` passes with new checks (gh mock, local origin), with
    `version_files: package.json, extension.yml` at `1.4.2`: every task issue closed → `RELEASE=bump
    1.5.0`, and `1.4.3` when every task starts with `Fix`; one issue open → refuses naming the task; an
    open `chore(release): 1.5.0` with the files still at `1.4.2` → `pending 1.5.0`, not `bump`; bumped and merged, not tagged → `tag 1.4.2` with the merge
    commit (not `bump 1.5.0`); tagged, not published → `publish`; published → `done`; a second feature
    merged after `v1.4.2` was published → `bump 1.5.0`, not `done`; no key →
    `RELEASE=none (no version_files:)`; `release-bump 1.5.0` rewrites both files' version lines only
    (`git diff --stat` one line each) and refuses a listed file with no version line, changing
    nothing; after a `bump` step the run's worktree is detached and the developer's checkout is
    unchanged. `bash tests/static.test.sh` pins the skill acting on `RELEASE=` only and no `gh pr merge`. `tests/run.sh` passes; quickstart scenario 5 holds

- [ ] T010 [US4] Run the full security audit unattended before the release, hold the release on a confirmed Critical or High, and end with only what is left for the developer, in extension/scripts/implement.sh, skills/implement/SKILL.md, skills/security/SKILL.md, skills/next/SKILL.md and README.md (depends on T009) — #136
  - Comes from: FR-017; research R9 "Audit"; data-model "Audit record"
  - What: `implement.sh audit-plan` prints `AUDIT=reuse REPORT=<path> HOLD=<n>` when the audit record
    is for the current `origin/<base>` commit, else `AUDIT=run COMMIT=<sha>`; `implement.sh
    audit-record <commit> <report> <n confirmed Critical or High>` writes the record
    (`<git common dir>/landspec-security/audit`: `commit=`, `report=`, `hold=`) and keeps the report
    beside it. Before a `RELEASE=bump` (and, without `version_files:`, before writing the notes), the
    skill runs `audit-plan`; on `run`, the audit of `skills/security/SKILL.md` in `full` mode in the
    run's worktree at `origin/<base>`, **unattended**: steps 1-6 as written (its subagents,
    `/code-review high` and `/security-review` started by the main session; one that is not available
    is named in the report's coverage, as a missing scanner is), changing nothing and filing nothing
    (its step 7 stays the developer's), then `audit-record`. With `HOLD` above 0 the release stops
    there: no bump, no PR, and the final message is `release held: <n> confirmed critical or high
    findings (report: <path>): run /landspec:security to track and fix them without disclosing them`.
    The security skill gains a short "Unattended" section saying exactly this, and its step 7, run by
    the developer, reads that report instead of auditing again when its commit is the current base.
    With `HOLD=0`: plausible findings and confirmed Medium or Low go in the release notes' "Known
    issues": on a public repository (`gh repo view --json visibility -q .visibility`; a failed call
    stops the step) only a count per severity and a neutral category for anything High or above,
    and no exploit detail for any. Missing scanners do not hold the release; the final message names
    them. The final message names only what is left: the PRs to merge, the held release, or
    `/speckit-specify` for the next feature. `skills/next/SKILL.md`'s "every task's issue is closed"
    branch (`:33-37`) suggests `/landspec:implement` (which runs the check, the audit and the
    release) instead of `/speckit-converge` and `/landspec:security` by hand; the README's "when every
    task is done" row and paragraph (`:99`, `:111-112`) say the same
  - Impact: T004's `implement.sh` (two subcommands); `skills/security/SKILL.md` (the Unattended
    section, step 7 reading the report; its interactive use is otherwise unchanged);
    `skills/next/SKILL.md:33-37`; `README.md:99`, `:111-112`, `:128`; `docs/security.md:33` (when the
    audit runs); `docs/reference.md`; `tests/implement.test.sh`, `tests/static.test.sh`
  - Completed when: `bash tests/implement.test.sh` passes with checks: no record → `AUDIT=run` with
    the base commit; after `audit-record <that commit> <file> 1` → `AUDIT=reuse … HOLD=1`; after the
    base moves → `AUDIT=run` with the new commit; `audit-record` on a commit that is not on origin's
    base refuses. `bash tests/static.test.sh` passes with pins that fail when the skill stops running
    `audit-plan` before `bump` (and before the notes without `version_files:`), bumps or opens a
    release PR with `HOLD` above 0, files an issue, advisory or task for a finding, stops reading the
    visibility or puts more than a count and category for High and above in a public repository's
    notes, or ends with anything but the PRs to merge, the held release or `/speckit-specify`; when
    the security skill loses its Unattended section or its "change nothing" rule; when the next
    skill's done branch sends the developer to `/speckit-converge` or `/landspec:security` instead of
    `/landspec:implement`. `tests/run.sh` passes; quickstart scenario 5 holds

**Checkpoint**: every story delivered.

---

## Dependencies & Execution Order

- Spec 003's T001 (#124) first.
- **T001**, then **T002**; **T003** and **T004** after T002, in parallel (both edit `lib.sh`: whichever
  merges later rebases).
- **T005** after T003 and T004; **T006** after T003-T005.
- **T007** after T006, then **T008**, **T009** and **T010**, in that order (each builds on the one
  before in the skill).

## Parallel Example

```text
Task: "T003 Open a stacked task's PR against its parent …"
Task: "T004 Derive every task's state and the next step for each …"
```

## Implementation Strategy

1. T001, T002, then T003 + T004, then T005: one owner per task, branch-addressable state, stacked
   branches and PRs, restack.
2. **MVP**: T006: the parallel run, ending with reviewed, stacked PRs and the merge order.
3. T007 + T008: the whole-feature check, its gaps, and the default. T009: the release.

## Phase 7: Convergence

**Goal**: close the gaps `/speckit-converge` found between the merged T001-T010 and the spec, research
and contracts.

**Independent Test**: `tests/run.sh`, and quickstart scenarios 2, 4 and 5.

- [ ] T011 [US2] Make `implement.sh status` print `PARENT=<branch>` for a `startable` task whose one unmerged dependency is `reviewed` or `pr`, so `/landspec:implement` starts it with `--from` that branch and its PR targets it, with a test, in extension/scripts/implement.sh and tests/implement.test.sh — CRITICAL, per FR-004, US2/AC1 (contradicts) — #151
  - Comes from: FR-004, US2 scenario 1; data-model "Task state" (startable)
  - What: in `status`'s startable pass (`implement.sh`, the loop after "No branch yet"), when a task's one
    unmerged dependency is `reviewed` or `pr`, record that dependency's branch as the task's `PARENT`, so
    its line reads `TASK=T002 STATE=startable … PARENT=feat/…-t001-…`; with every dependency merged it
    stays `PARENT=-`. The skill already passes `--from <PARENT>` on START (`skills/implement/SKILL.md`,
    START bullet); ORDER skips a task with no branch and no PR, so the value is harmless there
  - Impact: `implement.sh` status only; `tests/implement.test.sh` (rs_setup: T002 depends on T001)
  - Completed when: `bash tests/implement.test.sh` passes with checks: T001 reviewed, T002 depending on it
    → `TASK=T002 STATE=startable` with `PARENT=<T001's branch>`; T001 merged → `PARENT=-`; `tests/run.sh` passes
- [ ] T012 [US3] When every task of the feature is merged, run the whole-feature check on `origin/<base>` instead of refusing (`check-copy` now dies "no unmerged task branch in this clone to check"), once per base commit, then go on to the release, and drop the `/speckit-converge` pointer from the next skill and README, in extension/scripts/implement.sh, extension/scripts/review.sh, skills/implement/SKILL.md, skills/next/SKILL.md, README.md and tests (depends on T017) — per FR-013, FR-017, US4/AC1, SC-006 (contradicts) — #152
  - Comes from: FR-013, FR-017 ("the whole-feature check (in place of a separate converge step)"), US4
    scenario 1, SC-006; research R8
  - What: `check-copy` with every task merged makes the check copy detached at `origin/<base>` (no
    merges) and prints `CHECK=<path> ROUND=<n> FROM=<sha>`, where `FROM` is the first parent of the
    merge commit of the feature's earliest merged task PR (read from the same `gh pr list --state all
    … mergeCommit,mergedAt` as `release-plan`), so the feature review's facts carry `base: <FROM>` and
    `git diff <FROM>...<check ref>` is the feature's whole change; `review.sh record --feature` already accepts
    `Reviewed: <FROM>..<check ref sha>` (it compares only the right side: no change there, a test
    only). "Every task merged" means every `TASK=` line of `status` is `STATE=merged` (not an empty
    ORDER, which also leaves out unstarted tasks). It prints `CHECKED=<origin/<base> sha>` and makes
    nothing when the feature record (`landspec-review/feature-<name>`, kept after `record --feature`
    removes the round file) has `state:` that sha and `assessment: ready` and no round file says
    `outcome=red` for it; a new base commit is a new combination. The skill runs `release-plan` first
    and this check only on `RELEASE=bump` or `RELEASE=none`, never on `pending`, `tag`, `publish` or
    `done` (so the release PR's own bump commit is not checked again). The feature review's facts say
    the diff from `FROM` may hold unrelated commits merged meanwhile, and the reviewer judges only the
    feature's FRs and files. Green and `ready` → the release; red, or a `not met` line → each becomes a gap task
    through a spec PR (step 5 of the whole-feature check), with no release, since there is no task
    branch to fix. The next skill's done branch and README stop sending the developer to
    `/speckit-converge`. The copy is removed with `check-copy --remove` as today
  - Impact: `implement.sh` check-copy (the `no unmerged task branch` die, the round file's `combo=`),
    `review.sh` (no change: its `record --feature` range test), `skills/implement/SKILL.md` ("The whole-feature
    check" red step and its precondition, "The release" precondition), `skills/next/SKILL.md`
    (IN_PROGRESS=0 branch), `README.md` (the converge sentence after the loop table),
    `docs/reference.md` (the whole-feature check paragraph); `tests/implement.test.sh` (check-copy
    cases), `tests/review.test.sh` or wherever `record --feature` is tested, `tests/static.test.sh`
    (T010's next/README pin)
  - Completed when: `bash tests/implement.test.sh` passes with checks: every task issue closed →
    `check-copy` prints `CHECK=` at origin/main's commit, `ROUND=1`, `FROM=<the parent of the first
    task PR's merge commit>`; after `check-result green` and `review.sh record --feature` of a `ready`
    report (the round file then gone) → `CHECKED=<sha>`, no copy; main moves → `CHECK=` again; one
    task unstarted, the others merged → no all-merged check (the die or the normal path, as today); `record --feature` accepts a report with
    `Reviewed: <FROM>..<check ref>`; `tests/static.test.sh` pins the red → gap task rule, the check only on `RELEASE=bump|none`, and that the
    next skill no longer names `/speckit-converge` for a merged feature; `tests/run.sh` passes
- [ ] T013 [US1] Say what each waiting or locked task needs: `REASON=waits for Tnnn` or `REASON=merge Tnnn or Tmmm first` on `waiting` lines, and `git worktree unlock <path>` in the run report for a `locked worktree`, in extension/scripts/implement.sh, skills/implement/SKILL.md and tests (depends on T011) — per US2/AC4, FR-007, T004 (partial) — #153
  - Comes from: US2 scenario 4, edge case "two open PRs", FR-007; T004 (locked worktree)
  - What: `status` sets, on a `waiting` line: `REASON=waits for Tnnn` naming the first dependency that
    is not `reviewed`, `pr` or `merged` (this wins whenever there is one); else, with two or more
    unmerged `reviewed`/`pr` dependencies, `REASON=merge Tnnn or Tmmm first`. The run report
    (`skills/implement/SKILL.md`, "## End") prints each `waiting` task with its reason, and for
    `REASON=locked worktree <path>` (already printed by `status`) the lines `git worktree unlock
    <path>`, then `git worktree remove <path>`
  - Impact: `implement.sh` status (the `put ST "$t" waiting` line, next to T011's change);
    `skills/implement/SKILL.md` End; `tests/implement.test.sh`, `tests/static.test.sh`
  - Completed when: `bash tests/implement.test.sh` passes with checks: T002 depending on an unstarted
    T001 → `REASON=waits for T001`; a task depending on two reviewed tasks → `REASON=merge T001 or T002
    first`; one unstarted and one reviewed dependency → `waits for` the unstarted one;
    `tests/static.test.sh` pins `git worktree unlock` in End; `tests/run.sh` passes
- [ ] T014 [US4] Make `implement.sh audit-record` refuse a commit that is not on `origin/<base>`, and align contracts/implement-sh.md's audit-plan line with the merged `AUDIT=needed|done|hold`, in extension/scripts/implement.sh, specs/004-parallel-implement/contracts/implement-sh.md and tests/implement.test.sh — per T010 (partial) — #154
  - Comes from: T010's "Completed when" (`audit-record` on a commit that is not on origin's base
    refuses); contracts/implement-sh.md (audit-plan)
  - What: after its argument checks, `audit-record` fetches the base and refuses a commit that is not
    an ancestor of `origin/<base>` (`landspec: <sha> is not on origin/<base>`), writing nothing. The
    merged `AUDIT=needed|done|hold` stays (the skill and tests use it, not T010's `run|reuse`); the
    contract line 43 gains those three states, as `audit-plan` prints them
  - Impact: `implement.sh` audit-record; `contracts/implement-sh.md:43`; `tests/implement.test.sh`
    (the T010 audit cases)
  - Completed when: `bash tests/implement.test.sh` passes with a check: a commit on a side branch, not on
    origin/main → refused, the audit record unchanged; `grep -F "AUDIT=needed" contracts/implement-sh.md`
    finds the line; `tests/run.sh` passes
- [ ] T015 [US1] Apply research R7's limits: only implementers take `parallel_tasks:` slots, while every in-flight task (reviewers too) is still kept from `restack`, and a task whose tests stay red after its implementer said it was done twice is `failed`, in skills/implement/SKILL.md, extension/scripts/implement.sh, docs/reference.md and tests — per research R7 (contradicts) — #155
  - Comes from: research R7
  - What: the skill passes only the implementers in flight to `status --running`, and every task in
    flight (implementers and reviewers) to `restack --running`, so a stacked task under review is never
    rebased mid-review; a task under review is kept from a second review by the skill's own list. When
    an implementer returns done, the main session runs the test command in the task's copy: red →
    `I mark <task> red`, which adds 1 to `red=` in the task record and leaves `phase`, `head` and
    `round` as they are (kept across sessions, as `round=` is); at 2, `I fail <task> "tests red twice"`;
    green → `I mark <task> implemented` as today, which also resets `red=`. `retry` and the "failure
    lifted by a new commit" path of `mark` clear `red=` with `failed=` and `round=`. `docs/reference.md`'s `parallel_tasks` row says reviewers take no slot
  - Impact: `skills/implement/SKILL.md` (the in-flight list, step 1-2, "When an implementer returns");
    `implement.sh` mark (a `red` phase) and its usage line; `docs/reference.md:233`;
    `tests/implement.test.sh`, `tests/static.test.sh`
  - Completed when: `bash tests/implement.test.sh` passes with checks: `mark T001 red` twice → `red=2`
    in the record with `phase=` unchanged (`status` still shows `implemented`); `mark T001 implemented`
    → no `red=`; `retry T001` → no `red=`; `restack --running T001` skips T001 as running; `tests/static.test.sh` pins
    implementers-only `status --running`, all in flight for `restack --running`, and the red-twice
    fail; `tests/run.sh` passes
- [ ] T016 [US4] Without `release_notes:`, publish the notes landspec wrote in the release PR's body (its text before `## Evidence` or `## Review`) instead of `--generate-notes`, in extension/scripts/implement.sh, skills/implement/SKILL.md and tests (depends on T017) — per US4/AC2, T009 (partial) — #156
  - Comes from: US4 scenario 2 ("publishes the release with its notes"); T009
  - What: `release-plan` prints `RELEASE=publish V NOTES=pr:<n>` without `release_notes:`, `<n>` the
    merged PR titled exactly `chore(release): V` it already finds; the skill then `gh pr view <n>
    --json body -q .body`, keeps the text before the first `## Evidence` or `## Review` line,
    whichever comes first (the notes: the skill writes the release PR's body notes first, then those
    sections; `pr.sh fix` adds the review details after them), writes it to a `mktemp` file and `gh
    release create vV --title "<project> V" --notes-file <file>`
  - Impact: `implement.sh` release-plan (the publish line); `skills/implement/SKILL.md` ("The
    release", publish and bump bullets); `tests/implement.test.sh` (the `NOTES=-` publish case),
    `tests/static.test.sh` (T009's publish pin, which today expects `--generate-notes`)
  - Completed when: `bash tests/implement.test.sh` passes with a check: tagged, no release, no
    `release_notes:` → `RELEASE=publish 1.4.2 NOTES=pr:21`; `tests/static.test.sh` pins the notes-first body,
    the cut at the first `## Evidence` or `## Review`, and no `--generate-notes`; `tests/run.sh` passes
- [ ] T017 [US4] Make `release-plan` read the feature's `tasks.md` from `origin/<base>` (the open-issue refusal and the patch rule), as `status` does, with a test for a stale checkout, in extension/scripts/implement.sh and tests/implement.test.sh — per FR-013, T009 (partial) — #157
  - Comes from: FR-013, T009 ("when every task issue of the feature is closed")
  - What: `release-plan` reads the task lines from `git show origin/<base>:<feature dir>/tasks.md`
    (after its fetch), for the open-issue refusal and the patch rule, as `status` does
  - Impact: `implement.sh` release-plan (its two `"$fdir/tasks.md"` reads); `tests/implement.test.sh`
  - Completed when: `bash tests/implement.test.sh` passes with a check: a task line added on
    origin/main with an open issue, the checkout not updated → `release-plan` refuses naming it;
    `tests/run.sh` passes
- [ ] T018 [US1] Without `worktree_setup:`, the implementer prepares its own copy from the project's README and reports `Failed: setup:` for a task it could not prepare, in agents/implementer.md and tests/static.test.sh — per the edge case "files git does not track", research R2 (partial) — #158
  - Comes from: edge case "files git does not track"; research R2
  - What: `agents/implementer.md` step 2 gains: without `worktree_setup:`, the implementer prepares its
    own copy (never the developer's checkout) as the project's README says (install dependencies);
    if it still cannot run the test command there, it returns `Failed: setup: <what is missing>` and stops
  - Impact: `agents/implementer.md`; `tests/static.test.sh` (the implementer pins)
  - Completed when: `tests/static.test.sh` pins the README fallback in its own copy and `Failed:
    setup:`; `tests/run.sh` passes
- [ ] T019 [US4] Finish the audit's skill text as T010 says: the main session runs `/code-review high` and `/security-review` for the unattended audit, with an unavailable one named in the report's coverage; with `HOLD=0`, the notes' "Known issues" by repository visibility; missing scanners named in the final message, in skills/implement/SKILL.md, skills/security/SKILL.md and tests/static.test.sh (depends on T013, T016) — per T010, FR-017 (missing) — #159
  - Comes from: T010's "What" (#136)
  - What: in "The audit before the bump", the main session runs `/code-review high` and
    `/security-review` in the run's worktree at the audited commit and gives their output to the audit
    subagent (the security skill's Unattended section says it takes them from its prompt, and names one
    that was not available in the report's coverage, as a missing scanner is). The report's findings
    table carries severity and `confirmed`/`plausible` per row (step 6); with `HOLD=0` the main session
    copies from it into the release notes' "Known issues": on a public repository (`gh repo view --json
    visibility -q .visibility`; a failed call stops the step) only a count per severity and a neutral
    category; on a private one each confirmed Medium or Low and each plausible finding with its title
    and category; never an exploit detail. The final message names the missing scanners; they do not
    hold the release
  - Impact: `skills/implement/SKILL.md` ("The audit before the bump", the bump notes, End);
    `skills/security/SKILL.md` (Unattended, step 6's table); `docs/reference.md` (the audit
    paragraph); `tests/static.test.sh` (the T010 pins)
  - Completed when: `tests/static.test.sh` pins the main session running `/code-review high` and
    `/security-review`, "Known issues" with the visibility rule for both kinds of repository, no
    exploit detail, and missing scanners in End; `tests/run.sh` passes

## Dependencies (Phase 7)

- T011, T014, T017 and T018 can start at once. T013 after T011 (the same block of `status`); T012 and
  T016 after T017 (`release-plan`, then the skill's release text); T019 after T013 and T016 (the End
  and release sections). T015 alone edits the in-flight list; it rebases on whichever lands first in the skill.
