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
