# Feature Specification: Reviewer isolation and privacy findings

**Feature Branch**: `spec/003-reviewer-isolation-privacy`

**Created**: 2026-11-12

**Status**: Draft

**Input**: User description: "there are 2 other issues to be addressed: https://github.com/iamalisson/landspec/issues" — issues #121 (the reviewer runs commands in the author's working tree; a killed in-place mutation run left a stale lock and a reset file) and #120 (the reviewer passes a PR whose changed lines send personal data to a log through a helper).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The reviewer can never change the author's checkout (Priority: P1)

A developer opens a PR through landspec. The independent reviewer may run a command to settle
whether a suspected bug is real: a test, a mutation harness, a migration. Today it runs that
command in the developer's own checkout, so a run that is killed halfway can leave a mutated
source file, a stale lock, or a reset the reviewer did to clean up. The developer's next run then
misbehaves, and they find out only by digging. With this feature the reviewer always works in its
own copy of the same commit, and nothing it does reaches the developer's files, locks or git
state.

**Why this priority**: it is data safety. A reviewer that writes to the author's checkout can
destroy uncommitted work, and #121 shows it already happened once (safe that time only by luck).

**Independent Test**: launch a review on a branch whose check script mutates a source file and
holds a lock, let the reviewer run it and be killed mid-run, then compare the author's checkout
before and after.

**Acceptance Scenarios**:

1. **Given** a review is launched the way landspec's commands launch it, **When** the reviewer
   runs any command, **Then** the command runs in a separate copy of the reviewed commit, and the
   author's checkout (tracked files, untracked files, ignored files, branch, index, stash) is
   unchanged afterwards.
2. **Given** a review launch that does not ask for its own copy, **When** it is about to start,
   **Then** landspec refuses it before it runs and says how to launch it correctly.
3. **Given** the reviewer's command is killed halfway, **When** the author next runs that command,
   **Then** it behaves as if the review never ran: no leftover lock, no mutated file.
4. **Given** the review finished in its own copy, **When** the author records the report,
   **Then** recording works exactly as before (the report still lives outside the repository).

---

### User Story 2 - The reviewer follows personal data and secrets into the helpers that log them (Priority: P2)

A task's changed lines pass a user's e-mail to an existing helper, and that helper, untouched by
the diff, writes the e-mail to the application log. The project's rules forbid personal data in
logs. Today the reviewer reads the changed lines and their test and returns "ready". With this
feature the reviewer follows each personal value or secret the changed lines hand on, into the
helpers they call with it, and reports one that reaches a log.

**Why this priority**: it is a privacy leak that a second reviewer caught at High after landspec's
reviewer passed it twice; it weakens the promise that the review is the gate. It is P2 because
nothing is destroyed locally, and the fix is a change to what the reviewer looks for.

**Independent Test**: rerun #120's reproduction (a helper that logs an e-mail at INFO, a new
failure path that passes the e-mail to it, a test that fakes the helper module) and read the
assessment.

**Acceptance Scenarios**:

1. **Given** changed lines pass personal data or a secret to a helper that writes it to a log,
   **When** the reviewer reviews the branch, **Then** it reports the leak with the helper's file
   and line, at the severity the project's rules give a privacy breach (High or Medium), and the
   assessment is not "ready".
2. **Given** the only test of a privacy or security rule fakes the very component whose behavior
   it asserts (here, the module that writes the log), **When** the reviewer reviews it, **Then** it
   reports the test as Medium: it cannot see the behavior it claims to prove.
3. **Given** a test fakes a component it does not assert anything about, **When** the reviewer
   reviews it, **Then** this is not reported.
4. **Given** the same rules apply to a plan review's spec-folder code, **When** a spec-folder script
   logs personal data, **Then** the plan review reports it too.

### Edge Cases

- A Claude Code version that cannot give a subagent its own copy: the launch is refused with a
  message that names the missing setting and says to update Claude Code, instead of running in the
  author's checkout.
- The author has uncommitted changes when the review starts: the reviewer reviews the committed
  diff, as today, and its copy does not include them; nothing in the author's checkout is touched.
- A command the reviewer wants to run needs files that are not committed (installed dependencies,
  a local `.env`): the reviewer does not copy them from the author's checkout. It says what it
  could not run and why, and judges from reading.
- The reviewer's copy is left with changes after a run: it is cleaned up without reaching the
  author's checkout; an unchanged copy is removed automatically.
- A review launched by hand with the reviewer sentinel but not through landspec's commands: the
  same isolation rule applies.
- Personal data that reaches a log only through two or more helper calls: the reviewer follows the
  value as far as the code it reads goes; one it cannot follow is a Low with what it could not see,
  not silence.
- A value redacted before the log (masked or hashed): not a finding.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every review launch (task, fix, spec and plan reviews, and delta rounds) MUST run the
  reviewer in its own isolated working copy of the reviewed commit, separate from the author's
  checkout.
- **FR-002**: landspec MUST refuse a review launch that does not request that isolated copy, before
  the reviewer starts, with a message that says what to add. This is enforced by the same
  launch guard that already refuses a review on the wrong model or in a fork.
- **FR-003**: landspec's own commands that launch a review (the PR, issues and review commands, and
  the init and level skills that open reviewed PRs) MUST request the isolated copy, so following
  them never hits the refusal.
- **FR-004**: The reviewer's instructions MUST say that it never writes to the author's checkout:
  no command that edits files there, no `git checkout`, `git reset`, `git clean` or `git stash`
  there, and no lock files.
- **FR-005**: Recording a review, delta rounds and the review's report location MUST work as before.
  A reviewer copy left on disk MUST NOT stop the author's own steps (opening a PR, starting a task),
  and recording the review MUST remove it.
- **FR-005a**: A project whose landspec copy predates this feature MUST get a clear refusal that
  says to run `/landspec:init`, never a review in the author's checkout and never a review of the
  wrong commit.
- **FR-006**: The reviewer's list of real bugs MUST include personal data or a secret that reaches a
  log, including inside a helper the changed lines call with it, and the reviewer MUST open the
  helpers a changed line passes such a value to.
- **FR-007**: The reviewer's findings MUST include a test that fakes the component whose behavior it
  asserts: Low in general, Medium when it is the only proof of a privacy or security rule.
- **FR-008**: A static check MUST fail if the isolation rule, the log-leak rule or the faked-test
  rule is removed from the reviewer's instructions, or if a launching command stops requesting the
  isolated copy.
- **FR-009**: The guard's refusal MUST be tested: a launch without isolation is refused, one with it
  passes, and launches that are not reviews are untouched.
- **FR-010**: The docs (reference, security, help sources) MUST describe where the reviewer runs and
  what the new findings are.

### Key Entities

- **Review launch**: the request that starts the reviewer: its agent type or sentinel, model,
  whether it is a fork, and now whether it gets its own copy.
- **Reviewer's copy**: a separate working copy at the reviewed commit, owned by the review and
  discarded after it.
- **Author's checkout**: the developer's working tree, index, branch, stash and local files; the
  review must leave it exactly as it was.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In #121's reproduction (a check that mutates a source file and holds a lock, killed
  mid-run), the author's tracked files, untracked files, index, stash and current branch are the
  same before and after the review once it is recorded, and the author's next run of the check
  starts normally. (The reviewer's copy lives under `.claude/worktrees/` while it runs; it is not
  part of the author's work, and the author's scripts ignore it.)
- **SC-002**: 100% of review launches without an isolated copy are refused before the reviewer
  starts; 0 launches that are not reviews are affected.
- **SC-003**: Following landspec's commands as written, no review launch is ever refused for
  missing isolation.
- **SC-004**: In #120's reproduction (`fixtures/leak-through-helper/`), the reviewer reports the
  leak and does not return "ready", in 3 of 3 runs.
- **SC-005**: Removing any one of the new rules from the reviewer's instructions makes the test
  suite fail.

## Assumptions

- The Claude Code version landspec already requires can start a subagent in its own isolated copy of
  the repository at the current commit; an older client gets the refusal, not a silent fallback to
  the author's checkout.
- The review is of committed work, as today; uncommitted changes are out of the review's scope.
- Commands the reviewer runs still need to be few and only to settle a suspected bug; this feature
  makes them safe, it does not invite more of them.
- The severity of a privacy leak follows the project's rules; where the rules are silent, personal
  data in a log is at least Medium.
- Faking a component in a test is not wrong in itself; only a fake of the component under test is a
  finding.
