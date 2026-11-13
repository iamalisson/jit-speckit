---
description: "Tasks for reviewer isolation and privacy findings"
---

# Tasks: Reviewer isolation and privacy findings

**Input**: Design documents from `specs/003-reviewer-isolation-privacy/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/guard-review.md](contracts/guard-review.md), [contracts/review-record.md](contracts/review-record.md), [quickstart.md](quickstart.md)

**Tests**: every task ships its checks in the same PR (bash, "when …, then …", through `tests/helpers.sh`).

**Organization**: one phase per user story. The project already has everything the stories need, so
there is no setup or foundational phase.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependencies)
- `(depends on T00n)`: needs that task merged first
- One task = one issue = one branch = one pull request; ` — #N` is appended automatically.

## Rules every task follows

- After editing `extension/`, sync the installed copy: `specify extension add --dev extension --force`,
  then `git restore .specify/extensions/.registry` when only its timestamp changed.
- Docs in the same PR: the rows that describe the changed behavior in `README.md`, `docs/*.md` and the
  command prompts.
- Bash 3.2 with BSD or busybox tools: no GNU-only flags, no `timeout(1)`.
- `tests/run.sh` and the constitution's lint command pass before the PR.

---

## Phase 3: User Story 1 - The reviewer can never change the author's checkout (Priority: P1) 🎯 MVP

**Goal**: every review runs in its own copy of the reviewed commit, a launch without one is refused,
and a copy left behind never stops the author and is removed when the review is recorded.

**Independent Test**: quickstart scenarios 1, 2, 3 and 3b.

- [ ] T001 [US1] Run every review in its own copy of the reviewed commit, refuse a launch without one, and clean up a copy left behind, in hooks/guard-review.sh, extension/commands/review.md, extension/commands/pr.md, extension/commands/issues.md, agents/reviewer.md, extension/scripts/review.sh, extension/scripts/pr.sh and extension/scripts/branch.sh — #124
  - Comes from: FR-001-FR-005a, FR-008 (isolation part), FR-009, FR-010; US1 scenarios 1-4; SC-001-SC-003; research R1-R5, R7, R8; [contracts/guard-review.md](contracts/guard-review.md); [contracts/review-record.md](contracts/review-record.md); data-model "Reviewer's copy: lifecycle" and "Validation rules"
  - Size: if the diff passes about 400 lines with tests, split it into isolation plus the
    `pr.sh`/`branch.sh` exclusion first and the `Copy:` removal second (the exclusion alone keeps the
    author unblocked); append the second as a new task with the next free ID
  - What, in this order, one commit each:
    - **Guard**, built on the invariant in [contracts/guard-review.md](contracts/guard-review.md):
      for a review launch the hook allows at one place only, after the isolation check, and nothing
      skips that check; the fork and model checks only refuse, so the two `exit 0`s in today's model
      `case` (`:24-30`, a good model and the `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` branch) become
      fall-throughs. `hooks/guard-review.sh` reads `isolation` with its `field()` helper and, unless it
      is `worktree`, exits 2 with exactly
      `landspec: the review must run in its own copy of the repository: pass isolation: "worktree" (an older landspec copy in this project? run /landspec:init; Claude Code too old to take it? update it)`.
      It reads no project file and no directory (R8)
    - **Prompts**: `extension/commands/review.md` "Two roles": the author passes
      `isolation: "worktree"` on the launch (the `general-purpose` fallback too), and two new facts,
      `commit: <git rev-parse HEAD>` and `checkout: <repository root, absolute>`. "If you are that
      subagent": first, before any command that writes, check `git rev-parse --show-toplevel` differs
      from `<checkout>` and is an `agent-*` folder directly under a `.claude/worktrees/`, else run and
      write nothing, report `Copy: none (running in <path>)` and end `Assessment: changes needed`
      ([contracts/review-record.md](contracts/review-record.md) step 0); then `git checkout --quiet --detach <commit>` in its own copy and check
      `git rev-parse HEAD` equals it, else say so and end `Assessment: changes needed`; a plan review
      reads `<checkout>/specs/NNN-*/` in place and copies a spec-folder script into its copy only to
      run it; never write to `<checkout>` (no editing command, no `git checkout`, `reset`, `clean`,
      `stash` or `restore` there, no lock or temp files there), and do not run a command that writes
      outside its copy, except `mktemp` for the report file. Method step 2's "only in a throwaway copy" becomes "only in your own copy".
      The step-0 check, the `commit:` requirement and the switch to `commit:` are also written in
      `agents/reviewer.md`'s body, which ships with the plugin and the guard, so an older project copy
      cannot drop them: with no `commit:` fact the reviewer reports `Copy: none (the project's landspec
      copy predates the plugin: run /landspec:init)` and ends `Assessment: changes needed`
      ([contracts/review-record.md](contracts/review-record.md) step 0, which also lists the read-only
      commands and `mktemp` it may still run).
      The Report section asks for a line `Copy: <git rev-parse --show-toplevel>` before `Reviewed:`
      (and before `Model:` in a plan review). `pr.md` step 4 and `issues.md` step 2 say "with `model`
      and `isolation: "worktree"` as review.md says". `agents/reviewer.md` frontmatter gains
      `isolation: worktree`, and its body's "restore every file you change to break a test" becomes
      "you work in your own copy: never write to the author's checkout"
    - **Author not blocked**: the "uncommitted changes" refusals in `pr.sh:65` and `branch.sh:52` read
      `git status --porcelain -- . ':(exclude).claude/worktrees'`
    - **Cleanup**: `review.sh record` (task, `--plan`, `--delta`), after the record is written, reads
      the last `Copy: ` line of the report. It removes that copy only when "its folder is `agent-*`
      directly under `<root>/.claude/worktrees/` (`<root>`: `git rev-parse --show-toplevel`, or the
      main worktree's top level), it is listed in `git worktree list --porcelain` with a
      `worktree-agent-*` branch, its HEAD is the reviewed commit, and it is not the current checkout"
      (the reviewed commit: the report's `Reviewed:` head for a task or delta review, the author's
      `git rev-parse HEAD` for a plan review): `git worktree remove --force <path>`, then
      `git branch -D <its branch>`, printing `landspec: removed the reviewer's copy <path>`. A rule
      that fails, or a removal git refuses, prints `landspec: left the reviewer's copy <path> (<reason>)`
      and `record` still succeeds. No `Copy:` line, or a path that no longer exists: nothing printed
      or removed
  - Impact: `hooks/guard-review.sh:16-31` (order of checks, header comment). `tests/guard-review.test.sh`
    `launch()` (`:12-15`) builds the JSON without `isolation`: every existing review launch that is
    allowed today must now pass it (see *Completed when*). Every project with an older landspec copy
    is refused until `/landspec:init`: `docs/reference.md` and the next release notes' Upgrading
    section say so. `tests/static.test.sh:192-203`
    pins agents/reviewer.md (`name`, `model: sonnet`, `effort: medium`, no `## Method`) and the launch
    text in review.md, pr.md, issues.md: keep them, add new ones. `extension/scripts/review.sh`
    `record)` (`:127-175`): the removal goes after the record write and before the `REVIEW=` line;
    `hdr()` reads only the record's header, so the report is read with its own `grep`, the last match
    winning, as the verdict is (`:130`); the dirty check at `:133` already ignores untracked files.
    `tests/review.test.sh` builds reports with `printf` (`:15-53`): add checks at the end with a real
    `git worktree add`. `tests/pr.test.sh:24` ("when there are uncommitted changes, then it refuses")
    must keep passing; `tests/branch.test.sh` has no such check yet, so this task adds the tracked-edit
    refusal next to the new one. Docs: `docs/security.md:29`
    (the review hook row), `docs/reference.md` review row near `:165`, `docs/design.md:43`,
    `README.md:126`. FR-003's init and level skills launch no reviewer themselves:
    `skills/init/SKILL.md:102` and `skills/level/SKILL.md` send to `pr.md`, so they are covered by it
    (say so in the PR body). Installed copies under `.specify/extensions/landspec/` (commands, scripts,
    and `.specify/extensions/landspec/.specify-dev/agent-commands/claude/speckit-landspec-{review,pr,issues}/SKILL.md`)
  - Completed when:
    - `bash tests/guard-review.test.sh` passes with new checks, for both `Agent` and `Task`: a
      reviewer launch on sonnet without `isolation` is blocked with the exact line above; with
      `isolation: "remote"` it is blocked; with `isolation: "worktree"` it is allowed; a fork with
      `isolation: worktree` is still blocked with the fork line; a launch that is not a review,
      without `isolation`, is allowed; with `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` set, a launch with no
      `model` and no `isolation` is blocked with the isolation line, and with `isolation: worktree`
      allowed; without python3 on PATH (sed parser) the same decisions hold. The existing "allowed"
      checks for reviews (`:34-37`, `:41-42`, `:53`) now pass `isolation: worktree`: `launch()`
      (`:12-15`) gains a fifth argument for it, default empty; the existing "blocked" checks keep
      their messages, since fork and model are checked first
    - `bash tests/review.test.sh` passes with new checks: a `Copy:` naming
      `.claude/worktrees/agent-x` on `worktree-agent-x` at the reviewed commit, with an uncommitted
      change in it, is removed with its branch and the `removed the reviewer's copy` line, for a
      task, a `--plan` and a `--delta` record; a `Copy: none (…)` line removes and prints nothing; each of these is left with its files, a `left the
      reviewer's copy` line and a successful record: a listed worktree `.claude/worktrees/feature` on
      branch `worktree-feature`, an `agent-y` worktree at another commit, the repository root, a path
      outside `.claude/worktrees/`, a folder made with `mkdir` there; a report without `Copy:` records
      as before; recording the same report twice prints no error the second time; from a checkout
      that is itself a linked worktree, a copy under the main worktree's `.claude/worktrees/` is
      removed; the author's `git status --porcelain` is the same before and after every case
    - `bash tests/pr.test.sh` and `bash tests/branch.test.sh` pass with new checks: an untracked
      `.claude/worktrees/agent-x/` folder alone does not refuse; a tracked edit still refuses
    - `bash tests/static.test.sh` passes with new checks that fail when `isolation: "worktree"` is
      removed from review.md, pr.md or issues.md, when `commit:`/`checkout:`, the
      `git checkout --quiet --detach <commit>` step, the step-0 "is an `agent-*` folder" check (in review.md and in agents/reviewer.md), the "run /landspec:init" stop, the
      "never write to `<checkout>`" sentence or the `Copy:` line is removed from review.md, or when `isolation: worktree` is removed from
      agents/reviewer.md
    - `tests/run.sh` and the lint command pass; quickstart scenarios 1, 2, 3 and 3b hold on a real
      launch. `## Evidence` gets the blocked line, the `Reviewed:` range of scenario 2, where Claude
      Code put the copy when the author's checkout is itself a linked worktree, and the failure path: a launch whose `commit:` names a sha that is not in the repository, ending
      `Assessment: changes needed` with the reason

**Checkpoint**: a review cannot write to the author's work, never stops the author, and leaves nothing behind once recorded.

---

## Phase 4: User Story 2 - The reviewer follows personal data and secrets into the helpers that log them (Priority: P2)

**Goal**: the reviewer reports personal data or a secret reaching a log through a helper, and a test that fakes what it asserts.

**Independent Test**: quickstart scenario 4, on `specs/003-reviewer-isolation-privacy/fixtures/leak-through-helper/`.

- [ ] T002 [P] [US2] Report personal data or a secret that reaches a log through a helper, and a test that fakes what it asserts, in extension/commands/review.md — #125
  - Comes from: FR-006, FR-007, FR-008 (privacy part), FR-010; US2 scenarios 1-4; SC-004, SC-005; research R6
  - What: Method step 2's bug list gains "personal data or a secret that reaches a log, including
    inside a helper the changed lines call with it", and the step says to open each helper a changed
    line passes personal data or a secret to and read what it does with it; a value masked or hashed
    before the log is not a finding; one the reviewer cannot follow to its end is a Low that says what
    it could not see. The Report's severities: personal data in a log is **High** when the project's
    rules forbid it, at least **Medium** otherwise; the Low list gains "a test that fakes the
    component whose behavior it asserts", raised to **Medium** when it is the only proof of a privacy
    or security rule; a fake of a component the test asserts nothing about is not a finding. The
    plan review gets it through "apply the step 2 bug list" for spec-folder code, unchanged
  - Impact: `extension/commands/review.md` Method step 2 (the list after "Look for real bugs in the
    changed lines") and the Report's **Findings** severities (`:112-118`); `tests/static.test.sh`
    pins neighbouring review.md wording at `:122` and `:190-208`, which must keep passing; T001 edits
    other lines of the same file (Two roles, the subagent paragraph, step 2's last sentence, the
    Report's `Copy:` line), so whichever lands second rebases; `docs/reference.md` and
    `README.md:126` where they list what the review looks for; installed copies
    `.specify/extensions/landspec/commands/review.md` and
    `.specify/extensions/landspec/.specify-dev/agent-commands/claude/speckit-landspec-review/SKILL.md`;
    the fixture `specs/003-reviewer-isolation-privacy/fixtures/leak-through-helper/make-repo.sh` is
    in the spec folder, so it reaches the base with the spec PR
  - Completed when: `bash tests/static.test.sh` passes with new checks that fail when "reaches a log,
    including inside a helper the changed lines call with it", the "open each helper" sentence, "a test
    that fakes the component whose behavior it asserts" or its Medium rule is removed from
    `extension/commands/review.md` (each seen failing on a throwaway copy with that phrase deleted);
    `tests/run.sh` passes; quickstart scenario 4: three reviews of the fixture's `feat/save-deal`
    each report `app/alerts.py:7` at High (its `AGENTS.md` forbids personal data in logs) and
    `tests/test_controller.py` at Medium, and end `Assessment: changes needed` (paste the three
    Assessment lines into `## Evidence`). The static checks are the gate that fails in CI on a
    regression; the three runs are evidence of the behavior, since a model run can vary

**Checkpoint**: both stories delivered.

---

## Dependencies & Execution Order

- **T001** is the MVP and the gate.
- **T002** is independent: it can start at once, in parallel with T001; whichever merges second
  rebases review.md.

## Parallel Example

```text
Task: "T001 Run every review in its own copy … (guard, prompts, record, pr.sh, branch.sh)"
Task: "T002 Report personal data that reaches a log through a helper … (review.md step 2 and severities)"
```

## Implementation Strategy

1. **MVP**: T001. After it, a review cannot write to the author's work, a copy left behind never
   stops the author, and recording removes it. Isolation and cleanup ship together: isolation alone
   would leave copies that refuse the author's next PR.
2. T002: the privacy findings, shippable at any point.
