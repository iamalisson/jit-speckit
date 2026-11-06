# Feature Specification: Fix what the critical-points review found (release 1.8.0)

**Feature Branch**: `002-review-fixes`

**Created**: 2026-11-05

**Status**: Draft

**Input**: User description: "Fix what the critical-points review found, for release 1.8.0. Input: specs/001-critical-points-review/report.md, its *Fixes* list: every public High and Medium finding (F5.2, F5.4, F1.1, F1.2, F1.6, F1.8, F2.3, F2.4, F3.1, F3.3, F3.4, F3.5, F3.6, F3.8, F3.9, F4.1, F4.2, F4.3, F4.4, F4.7, F5.3, F5.6), each with the change, the promise it restores, and its "when …, then …" check in the named tests/<script>.test.sh, which must fail before the fix and pass after. Plus GitHub issue #41: /jit-speckit:init offers squash-only merges (allow_squash_merge=true, allow_merge_commit=false, allow_rebase_merge=false) at every level so one revert removes one task, with its tests/static.test.sh check. The docs (README.md, docs/*.md) are corrected in the same change as the behavior they describe. Out of scope: the private finding F2.1 (fixed in its own advisory, never described publicly), the Low findings (notes only), and the core-model changes D1–D3 from report/7-core-model.md (a separate feature). The release is 1.8.0: the three version files bumped together, per the constitution."

## Where this comes from

Feature 001 reviewed jit-speckit 1.7.2 against its own promises and wrote one fix per public High
and Medium finding in [`specs/001-critical-points-review/report.md`](../001-critical-points-review/report.md),
section *Fixes*. Each entry there names the change, the promise (P01–P28) it restores, and a check
written as "when …, then …" in a named `tests/<script>.test.sh`. That entry is the source of truth
for its requirement below; this spec does not restate the detail, it commits to delivering it.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing of mine disappears without a word (Priority: P1)

As a jit-speckit user, when I update, change level or remove jit-speckit, I never lose an edit, a
newer pin or a protection without being told, and an old plugin copy never quietly takes my project
backwards.

**Why this priority**: The two High findings live here (F5.2, F5.4). Losing a user's uncommitted
work, or silently removing the review gate, is the worst thing the tool can do.

**Independent Test**: In a throwaway project: edit a managed file without committing and run
remove; run an older plugin copy's setup on a newer project; refresh a project set up before 1.4.0;
bump a managed workflow pin and refresh. Each prints what it kept or refused, and nothing is lost.

**Acceptance Scenarios**:

1. **Given** a managed file with an uncommitted edit, **When** I remove jit-speckit, **Then** the
   file is kept and the output says `kept (edited)` (F5.2).
2. **Given** a project at a newer jit-speckit version than the plugin copy running setup, **When**
   setup runs, **Then** it refuses, says which versions are involved and how to reload the plugin
   (F5.4).
3. **Given** files an earlier release wrote before the managed-file marker existed, **When** I
   refresh, **Then** each is replaced or named with the release that wrote it (F5.3).
4. **Given** a managed workflow whose action pin is newer than the plugin's, **When** I refresh,
   **Then** the newer pin is kept and the output says so (F4.7).

---

### User Story 2 - Every gate does what the docs say it does (Priority: P1)

As a user, when the docs say a step refuses a pull request, it refuses it; when a step is only
asked of the agent, the docs say so.

**Why this priority**: Most Medium findings are a gate that is presented as enforced and is only a
prompt, or that proves less than the docs claim. A user who trusts a gate stops checking.

**Independent Test**: In a throwaway project, open a task PR with failing tests, with no mutation
run, with no scan recorded, with an edited test in a common layout and no `## Test changes`, and on
full with no analysis report: each is refused with the reason. The recorded review appears in the
PR body. The guard refuses the two forms the review found.

**Acceptance Scenarios**:

1. **Given** the project's test command fails, **When** the task PR is opened, **Then** it is
   refused with the failing output and nothing is pushed (F3.3).
2. **Given** no mutation result or no scan result recorded for this diff, **When** the task PR is
   opened, **Then** it is refused and names the step to run (F3.4, F3.6).
3. **Given** an edited existing test in a layout the review listed (for example `app/tests.py`,
   `Tests/AppTests/AppTests.swift`), **When** the PR body has no `## Test changes`, **Then** it is
   refused; an edited source file whose name merely contains "test" is not (F3.9).
4. **Given** level full and no analysis report, **When** the analysis marker is recorded, **Then**
   it is refused and the task branch still cannot start (F3.8).
5. **Given** a recorded review, **When** the task PR opens, **Then** the PR body carries the
   review's text, and a security finding appears only as one `Security: reported privately` line
   (F3.1, F4.3).
6. **Given** the two command forms the review found inside the guard's documented scope, **When**
   Claude runs them, **Then** the guard refuses them (F2.3).
7. **Given** the docs state a minimum Claude Code version, **When** I read them, **Then** it is the
   version the guard needs to block on a failure, and no install path is offered below it (F2.4).

---

### User Story 3 - The task chain never fails silently (Priority: P2)

As a user working across clones and teammates, when a claim, a close, a lookup or a review request
fails, I am told; and a task's "done" never depends on its issue's title.

**Why this priority**: These failures do not lose data on their own, but they make `next` offer the
wrong task, or overwrite a teammate's spec commit, and nobody notices.

**Independent Test**: In a throwaway project with the fake `gh`: refuse the claim push, rename a
closed task issue, fail one close in the linked-issues workflow, fail the open-PR lookup during a
spec PR, and answer the Copilot request with no reviewer. Each is reported, and `next` shows the
renamed issue's task as done.

**Acceptance Scenarios**:

1. **Given** origin refuses the claim push, **When** a task starts, **Then** it still starts and
   warns that other clones may start it too (F1.1).
2. **Given** a closed task issue whose title no longer has the feature number, **When** `next`
   runs, **Then** the task shows as done (F1.2).
3. **Given** one issue number in a merged PR body cannot be closed, **When** the workflow runs,
   **Then** it still closes the others and the job fails (F1.6).
4. **Given** the open-spec-PR lookup fails, **When** the spec PR is pushed, **Then** it stops and
   the teammate's commit on the spec branch is untouched (F1.8).
5. **Given** GitHub answers the Copilot request with no reviewer added, **When** the PR opens,
   **Then** the output does not say a review was requested (F3.5).
6. **Given** an issue GitHub created for a task whose answer never reached the client, **When** the
   issue step runs again, **Then** it reuses that issue and creates no second one (F1.7).

---

### User Story 4 - Security findings, pins and platforms are what the docs claim (Priority: P2)

As a user, my audit can file its private advisory, my pins are all kept current, lite's docs say
what lite lacks, macOS is really tested, and merges keep one task per commit.

**Why this priority**: These are promises about the project's own supply chain and release
hygiene; each is kept today only partly.

**Independent Test**: Read the security skill's advisory example (it has the fields GitHub
requires); count the pins no workflow uses (none); read the README's CI row (it names its levels);
read the macOS job's triggers (pull requests that touch scripts, and tags); read init's offers (a
squash-only merge setting on every level).

**Acceptance Scenarios**:

1. **Given** a public repository, **When** the audit files a private advisory, **Then** the body it
   sends includes `severity` and `vulnerabilities`, and an existing advisory with the same summary is
   reused (F4.2).
2. **Given** a pin in the single pin list, **When** Dependabot runs on this repository, **Then** some
   workflow uses it, so an update can be proposed; tool versions are checked weekly (F4.1).
3. **Given** level lite, **When** I read the README and the security doc, **Then** they say the CI
   gate and branch protection exist on standard and full only, and `init` offers the free GitHub
   protections on every level for a public repository (F4.4).
4. **Given** a pull request that touches the scripts, **When** CI runs, **Then** the macOS job runs
   (F5.6).
5. **Given** any level, **When** `init` offers its GitHub settings, **Then** it offers to turn off
   rebase merges (and on lite, merge commits too, so task PRs are squashed), and the design doc says
   the one-revert promise relies on one commit per task PR (#41).
6. **Given** level full, **When** the security workflow is written, **Then** Semgrep runs from an
   image pinned by digest, and the README and security doc say its rules come from the Semgrep
   registry at run time (F4.5).

---

### User Story 5 - The fixes ship as release 1.8.0 (Priority: P3)

As a user, I update once and get every fix above, with the docs matching the behavior.

**Why this priority**: The value of the fixes reaches users only through a release.

**Independent Test**: The three version files say `1.8.0`, the release notes name each finding
fixed, and `tests/run.sh` passes on Linux, bash 3.2 and macOS.

**Acceptance Scenarios**:

1. **Given** every fix above merged, **When** the release is cut, **Then** the plugin, extension and
   preset versions all say `1.8.0` and `tests/static.test.sh` passes.

### User Story 6 - The review goes deep where it matters, stays cheap on fix rounds, and runs on a strong model (Priority: P2)

As a user, the independent review checks in depth every path a script marks as risky, a fix round
re-reads only what changed since the last recorded review without letting unreviewed code through,
the review runs on a strong model whatever my session runs on, and I can start every task that is
ready in parallel.

**Why this priority**: the review is the costliest step of every task (feature 001, section 6); the
user asked on 2026-11-05 for jit-speckit itself to work this way in 1.8.0.

**Independent Test**: in a throwaway project, a diff touching a migration is refused at record time
without a deep check of it; a second round recorded as a delta from the last reviewed commit is
accepted, one from another commit is refused; the review prompts launch the plugin's reviewer agent
with a pinned model; `next` prints a ready-to-run line for every other startable task.

**Acceptance Scenarios**:

1. **Given** a diff that deletes a file or touches a migration, auth, secrets, money, CI or a
   swallowed failure, **When** the review is recorded, **Then** it is refused unless the report has a
   `- deep:` line for that path, or a `- proven:` line naming the test that covers it (FR-030).
2. **Given** a recorded full review and one fix commit, **When** a delta report from that commit is
   recorded, **Then** it is accepted and the gate still covers the whole diff; from any other commit,
   after a rebase, with nothing committed, or with a large change outside the previous findings, it
   is refused (FR-032, FR-033).
3. **Given** any session model, **When** a review runs, **Then** it runs in the plugin's reviewer agent
   on the configured strong model (FR-034).
4. **Given** several startable `[P]` tasks, **When** `next` runs, **Then** it prints a line per other
   task that makes its worktree and starts it (FR-036).

---

### Edge Cases

- A fix whose check cannot be made to fail on 1.7.2 as written: the check is corrected first (it is
  evidence), and the change says why in `## Test changes`.
- A new refusal (red checks, mutation, scan, analysis) on a project that has no such command: it
  says so and lets the PR through, as `mutants.sh` already does for `missing`; it never refuses for
  a tool the project does not have.
- A plugin copy at 1.8.0 or later run on a project at a newer version: refused by the F5.4 fix,
  with the reload hint. A copy older than 1.8.0 cannot refuse (its own `setup.sh` predates the
  check); the docs say to run `/reload-plugins` first.
- A user who removed the managed-file marker on purpose: the file stays theirs, as today.
- A security finding in a review report on a private repository: still one line in the PR body; the
  rule does not depend on visibility.
- A later full review of feature 001's report confirms a defect in one of the fix entries: that entry
  is corrected in 001's report first, and this feature follows the corrected entry.

## Requirements *(mandatory)*

### Functional Requirements

Each requirement delivers the fix entry of the same id in feature 001's `report.md` *Fixes*: its
change, the promise it restores, and its check, which fails on 1.7.2 and passes after.

**User's files and setup (US1)**
- **FR-001**: Removing jit-speckit MUST keep a managed file that has uncommitted edits or differs
  from what jit-speckit wrote, and say so (F5.2, P20). "What jit-speckit wrote" is the SHA-256 it
  recorded when it wrote the file; a file with no record is removed only when it is committed and
  unchanged.
- **FR-002**: Setup MUST refuse to take a project to an older jit-speckit version than it is at,
  unless the user asks for a downgrade explicitly, and say how to reload the plugin (F5.4, P21, P10).
- **FR-003**: Refresh MUST recognize files an earlier release wrote without the marker: replace them,
  or name each with the release that wrote it (F5.3, P19, P21).
- **FR-004**: Refresh MUST keep a managed workflow's action pins that are newer than the plugin's,
  and say so (F4.7, P17).

**Gates (US2)**
- **FR-005**: Opening a task PR MUST run the project's test command first and refuse on failure
  (F3.3, P12).
- **FR-006**: Opening a task PR MUST refuse without a recorded mutation result for this diff when
  the project has a mutate command, and without a recorded scan for this diff (F3.4, F3.6, P13, P26).
- **FR-007**: The test-change rule MUST recognize the test layouts the review listed, leave source
  files alone, and let the constitution add a pattern (F3.9, P13).
- **FR-008**: On full, recording the analysis MUST require the analysis report (F3.8, P15).
- **FR-029**: The hint for a missing task review MUST name the task record command, not the plan
  one (F3.7, P10).
- **FR-009**: The task PR body MUST carry the recorded review, and a security finding MUST appear in
  the review report and the PR body as one `Security: reported privately (<id>)` line only (F3.1,
  F4.3, P10, P11, P25).
- **FR-010**: The command guard MUST refuse the two forms the review found inside its documented
  scope (F2.3, P08).
- **FR-011**: Every place the docs give the plugin's minimum Claude Code version MUST give the
  version the guard needs to block on failure, with no install path below it (F2.4, P08). The
  constitution's line changes first, in its own `/speckit-constitution` PR (version 1.0.1), as its
  amendment rule requires; this feature's task then changes the README and `docs/security.md`
  (decision 2026-11-05).

**Task chain (US3)**
- **FR-012**: A refused claim push MUST print a warning and let the task start (F1.1, P02, P04).
- **FR-013**: `next` MUST decide each task's state by its issue number, not by title search (F1.2,
  P03, P04).
- **FR-014**: The linked-issue close MUST close every number it can and then fail if one failed
  (F1.6, P03, P04).
- **FR-015**: The spec PR MUST stop when it cannot ask whether a spec PR is open (F1.8, P05).
- **FR-016**: The Copilot line MUST reflect GitHub's answer (F3.5, P14).
- **FR-026**: A rerun of the issue step MUST reuse a task's issue that GitHub created but never
  confirmed, instead of creating a second one (F1.7, P01).
- **FR-028**: On a task branch, `next` with no argument MUST serve that branch's feature, as the
  docs say (F1.9, P04).

**Security, pins, platforms, merges (US4)**
- **FR-017**: The audit's advisory call MUST send the body GitHub accepts and reuse an existing
  advisory with the same summary (F4.2, P25).
- **FR-018**: Every pinned action MUST be used by a workflow in this repository, and tool versions
  MUST be checked weekly (F4.1, P17).
- **FR-027**: Semgrep MUST run from its official image pinned by sha256 digest, and the README and
  security doc MUST say its rule sets come from the Semgrep registry at run time, so "all pinned
  and checksum-verified" is true as written (F4.5, P16; decision 2026-11-05: the Semgrep Rules
  License forbids redistributing the registry rules, so they cannot be kept in the extension).
- **FR-019**: The README and security doc MUST name the levels the CI gate exists on, and `init`
  MUST offer secret scanning with push protection and private vulnerability reporting on every level
  for a public repository (F4.4, P16, P28).
- **FR-020**: The macOS job MUST run on pull requests that touch the scripts and on every tag
  (F5.6, P24).
- **FR-021**: `init` MUST offer, on every level, to turn off rebase merges; on lite it MUST also
  offer to turn off merge commits (squash only). Standard and full keep merge commits for their
  promotion PRs (`develop → main`), and the docs MUST say task PRs are squashed there by convention.
  The design doc MUST say the one-revert promise relies on one commit per task PR (#41; decision
  2026-11-05: squash-only everywhere would squash promotions and make the base branches drift).

**Review redesign (US6)**
- **FR-030**: `review.sh risk` MUST flag the diff's risky paths by fixed rules (deletions,
  migrations, CI and hooks, auth and permissions, secrets, money, added lines that swallow a
  failure), and `review.sh record` MUST refuse a report without a `- deep:` line for each flagged
  path or a `- proven:` line naming the test (`file:line`) that covers it.
- **FR-031**: The PR body MUST show the risk map as paths only (`- deep:` / `- proven:`), never the
  reviewer's prose.
- **FR-032**: `review.sh record --delta` MUST accept a fix round only when it follows a recorded full
  round of this branch, names that round's commit (`Delta from: <sha>`), that commit is still an
  ancestor of HEAD, something was committed since, and the change outside the previous findings
  stays small; otherwise it refuses and asks for a full round.
- **FR-033**: A delta's `ready` MUST still be checked against the whole branch diff, and its risk check
  MUST cover the delta's own range.
- **FR-034**: The independent and plan reviews MUST run in a plugin reviewer agent on a pinned strong
  model (default `opus`, configurable to `sonnet`, `opus` or `fable`), falling back to a
  general-purpose agent with that model; the docs MUST say an environment that forces one model
  overrides it.
- **FR-035**: The mechanical pre-PR steps (tests, mutation, scans) MUST stay scripts that print result
  lines; no model, fast or not, decides whether they passed.
- **FR-036**: `next` MUST print a ready-to-run line for every other startable `[P]` task (a worktree
  and its start), and the next skill MUST offer to run them; the claim warning of FR-012 still
  applies.

**Across all**
- **FR-022**: Each fix MUST land with its check from the 001 entry, seen to fail before the change
  and to pass after, and the PR MUST say so (the constitution's rule for bash, which has no mutation
  tool).
- **FR-023**: Each behavior change MUST correct the docs that describe it in the same pull request.
- **FR-024**: Nothing in this feature MUST describe the private finding F2.1 beyond its id.
- **FR-025**: The release MUST bump the plugin, extension and preset versions together to `1.8.0`,
  and its notes MUST list the findings fixed by id.

### Key Entities

- **Fix entry**: one item of feature 001's *Fixes*: finding id, change, promise, check.
- **Check**: a "when …, then …" test in a named `tests/<script>.test.sh`, failing before the fix.
- **Release**: version `1.8.0` across the three version files, with notes listing the fixed ids.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 26 of 26 public High and Medium findings, plus #41 and FR-030–FR-036, each have a merged change whose
  check fails on 1.7.2 and passes on 1.8.0.
- **SC-002**: Re-running feature 001's reproduction for each of those findings on 1.8.0 no longer
  shows the defect.
- **SC-003**: 0 of the user scenarios in US1 lose a file or an edit, or downgrade a project, without
  a printed line saying so.
- **SC-004**: Every gate the README or `docs/` presents as refusing is refused by a script, or the
  doc says it is asked of the agent: 0 mismatches when read side by side.
- **SC-005**: The full suite passes on Linux, bash 3.2 and macOS for the release commit.
- **SC-006**: A user can tell from the 1.8.0 release notes which finding each change fixes, in under
  5 minutes.

## Assumptions

- Feature 001's `report.md` is the source of truth for each fix's detail. A full review of that
  report on 2026-11-05 confirmed 22 defects in it; the corrections (branch
  `fix/001-report-corrections`) re-rank F1.7, F4.5, F1.9 and F3.7 to Medium, which adds FR-026 to
  FR-029 here,
  and change the wording of the F2.3, F3.5 and F3.6 fixes, which this spec follows.
- Where an entry offers an alternative (F3.6: record the scan, or say in the README that it is
  asked), the gate is chosen, because the constitution says "scripts refuse, prompts explain".
- New refusals never fire for a tool the project does not have; they say so and let the PR through,
  as `mutants.sh` does for `missing` today.
- The private finding F2.1 is fixed through its advisory, and may ship in the same release without
  being described in this feature.
- The core-model changes (D1 feature branch, D2 spec as first commit, D3 review bar per level) are a
  separate feature; the merge commit for feature PRs belongs there, not in #41's change.
- The Low findings stay notes in feature 001's report; they are not part of this release.
- On 2026-11-05 the user added the review redesign (US6): the risk map, delta rounds, a pinned strong
  reviewer model and parallel task starts. Rounds per level (core-model D3) stay in the separate
  core-model feature; a fast-model checker for the mechanical steps was considered and dropped, since
  those steps are scripts and a model reading their output could hide a finding (research Part 2).
