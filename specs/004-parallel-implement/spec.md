# Feature Specification: Implement a whole feature in parallel

**Feature Branch**: `spec/004-parallel-implement`

**Created**: 2026-11-13

**Status**: Draft

**Input**: User description: "I want landspec to work with worktree/multi tasks solving BY DEFAULT. 1 main agent gets the spec/plan, creates the tasks, then when I run it on tasks, instead of going 1 to 1, it goes multitasking to deliver EXTREMELY FAST any solution. On single-thread execution it waits for the user to approve the PR of each task to keep moving. The agent must develop a lot of tasks in parallel and at the end validate them together to see if the final problem was properly solved and there is nothing left to be addressed. And after this, deliver a nice release." Decisions (user, 2026-11-13): one PR per task, stacked on its dependency when it has one; it is the default after the tasks are created; the command is `/landspec:implement`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Start every task of a feature at once (Priority: P1)

A developer has a feature whose spec PR is merged: its tasks and their issues are on the base
branch. Today they implement one task, open its PR, wait for it to be merged, and start the next.
With this feature they run one command, and landspec starts every task that can start now, each in
its own working copy, all at the same time. Each task goes through the same steps a single task
goes through today (implement, its own tests, the independent review, fixes, scans, its PR) without
the developer stepping in between tasks.

**Why this priority**: it is the speed the feature exists for: the wall-clock time of a feature
becomes roughly the time of its longest chain of tasks, not the sum of all of them.

**Independent Test**: on a feature with three independent tasks, run the command once and see
three PRs open, each with its own recorded `ready` review, without any input between them.

**Acceptance Scenarios**:

1. **Given** a feature whose spec PR is merged and whose tasks are all independent, **When** the
   developer runs `/landspec:implement`, **Then** every open task starts at once, each in its own
   working copy and branch, and each ends with its own reviewed PR, with no question asked between
   tasks.
2. **Given** a task that fails (its tests stay red, its review keeps raising a High), **When** the
   others are running, **Then** they carry on; the failed task is reported with what stopped it,
   and its branch is kept for the developer.
3. **Given** two tasks that would edit the same lines, **When** they run at once, **Then** each
   still ends in its own PR, and the clash is found at the latest by the whole-feature check
   (User Story 3), never by a silent overwrite.
4. **Given** the developer's own checkout, **When** the run starts and ends, **Then** nothing in it
   changed: the work happens in separate working copies only.

---

### User Story 2 - Dependent tasks start without waiting for a merge (Priority: P1)

A task that depends on another one today waits until the other one's PR is merged. With this
feature it starts as soon as the task it depends on has a reviewed branch, built on top of that
branch, and its PR is stacked on that task's PR. The developer gets the order to merge them in:
merge one, run the command (which moves the next onto the base and makes it mergeable), merge the
next. The implementing never waits for a merge; only the merging is in order.

**Why this priority**: without it, any feature with a chain of tasks waits for a merge before each
task can even start, which is the wait this feature removes.

**Independent Test**: on a feature where T002 depends on T001, run the command and see T002's PR
open on top of T001's, before T001 is merged, each with its own review of only its own changes.

**Acceptance Scenarios**:

1. **Given** T002 depends on T001, **When** T001's branch has a recorded `ready` review, **Then**
   T002 starts from T001's branch, and its PR targets T001's branch and shows only T002's changes.
2. **Given** a stack of PRs, **When** the run ends, **Then** it prints the order to merge them in.
3. **Given** the developer merged T001 (squashed into the base), **When** the command runs again,
   **Then** the PRs stacked on it are moved onto the base and show only their own changes; a task
   whose own changes are the same keeps its review, one whose changes moved gets a new review.
4. **Given** a task that depends on a task that failed, **When** the run continues, **Then** it does
   not start, and the report says which task it waits for.

---

### User Story 3 - Check the whole feature together before calling it done (Priority: P1)

Each task passing alone does not prove the feature works. With this feature, once the tasks are
done, landspec combines all their branches in one more working copy, runs the whole test suite on
the combination, and has an independent reviewer check the result against the spec: every
requirement, scenario and success criterion is met, and nothing is left. A gap becomes new tasks,
and the run goes on with them until the check passes.

**Why this priority**: it is what makes "fast" safe. The developer asked for "validate them together
to see if the final problem was properly solved and there is nothing left to be addressed".

**Independent Test**: on a feature where one requirement is covered by no task, run the command and
see the check name that requirement, append a task for it, run it, and pass on the next check.

**Acceptance Scenarios**:

1. **Given** every task has a reviewed PR, **When** the whole-feature check runs, **Then** it
   combines all branches, runs the project's full test command on the combination, and reports per
   requirement and success criterion whether it is met, with the evidence.
2. **Given** the branches do not combine cleanly, or the combined tests fail, **When** the check
   runs, **Then** it names the tasks involved and the run fixes them in their own branches (each
   fix reviewed as a fix round), never in the combined copy.
3. **Given** the check finds something not done, **When** it reports, **Then** new tasks are
   appended to `tasks.md` through a spec PR, with their issues, before anything is merged; after the
   developer merges the feature's PRs and that spec PR, the next run implements them like any task
   and runs the check again.
4. **Given** the check passes, **When** the run ends, **Then** the developer gets one summary: the
   PRs in merge order, what the check proved, and anything the check could not verify.
5. **Given** the check keeps finding new gaps, **When** it has run a set number of rounds, **Then**
   the run stops and asks the developer instead of looping.

---

### User Story 4 - A release ready when the feature is merged (Priority: P2)

When every PR of the feature is merged, the developer wants a release without writing it by hand.
With this feature, landspec prepares the release PR the project's rules call for (the version bump
in the files that carry it, and release notes written from what the feature's PRs did), reviewed
like every other PR. After the developer merges it, it tags the release and publishes its notes.

**Why this priority**: it is the last step of the developer's request, and it only matters once the
feature itself is right.

**Independent Test**: in a project with a version file and release notes, merge a feature's PRs,
run the command again, and see a release PR with the bumped version and notes that name each merged
PR; after merging it, see the tag and the published release.

**Acceptance Scenarios**:

1. **Given** every PR of the feature is merged, **When** the command runs again, **Then** it opens a
   release PR with the next version (minor for a feature, patch when every task is a fix) in every
   file that carries the version, and notes grouped by what users get.
2. **Given** the release PR is merged, **When** the command runs again, **Then** it tags that commit
   and publishes the release with its notes.
3. **Given** a project with no version file or release convention, **When** the feature is merged,
   **Then** landspec writes the notes as a draft and says which step the project has no convention
   for, instead of inventing one.

---

### User Story 5 - It is the default way to implement (Priority: P2)

After the tasks are created and the spec PR is opened, landspec points the developer to
`/landspec:implement` for the whole feature. `/speckit-implement Tnnn` stays for doing one task by
hand.

**Why this priority**: the developer asked for parallel work "by default"; the command is only the
default if the flow leads to it.

**Independent Test**: create a feature's tasks and read what landspec says next.

**Acceptance Scenarios**:

1. **Given** the tasks and the spec PR were just created, **When** landspec ends that step, **Then**
   it tells the developer to merge the spec PR and run `/landspec:implement`.
2. **Given** a developer runs `/speckit-implement T003`, **When** it runs, **Then** it does one task
   as today.
3. **Given** a developer runs `/landspec:next`, **When** tasks can start, **Then** it offers
   `/landspec:implement` for all of them alongside the next single task.

### Edge Cases

- A task depends on two tasks whose PRs are both open: a branch can stack on only one parent, so it
  waits until the developer merges one of them, and the summary says which merge it waits for.
- The spec PR is not merged yet: the command stops before starting anything and says to merge it
  (the tasks must be on the base branch for every working copy to read them).
- A task is already in progress elsewhere (claimed by another clone, or a branch with an open PR):
  the run leaves it alone and waits for it as a dependency only if another task names it.
- The run is interrupted (the session ends, the machine sleeps): running the command again picks up
  from what is on the branches, the PRs and the review records, and never redoes a task that
  already has a reviewed PR.
- More tasks can start than the machine or the account should run at once: the run starts at most a
  set number together and starts the next as one finishes.
- A task needs files git does not track (installed dependencies, a local environment file): its
  working copy is prepared the way the project documents, and a task that cannot be prepared is
  reported, not run half-ready.
- A dependency's PR changes after the dependent task started (a review fix): the dependent branch is
  moved onto the new state of its dependency, and its review is redone only if its own changes moved.
- The developer tries to merge PRs out of the printed order: a stacked PR stays a draft until its
  dependency is merged and the run has moved it onto the base, so it cannot be merged first. Where
  the repository cannot have drafts, the PR opens as a normal one with a warning, and its "Stacked on
  #N (merge it first)" line and the run's report (which lists a PR whose review is pending) are the
  only guards.
- A task's line was changed after its issue was created: the run uses the line as it is on the base
  branch, as today.
- The project is at the strictest level and requires the analysis before implementing: the command
  refuses to start until it was recorded, as `/speckit-implement` does.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `/landspec:implement` MUST start, at once, every open task of the active feature that
  can start (no unfinished dependency, not claimed elsewhere), each in its own working copy and
  branch, up to a set number running together.
- **FR-002**: Each task MUST go through the same gates a single task goes through today: its own
  tests, the independent review recorded `ready` for its exact changes, fix rounds, the security
  scan, the mutation run where the project has one, and its PR through landspec's PR step. No gate
  is skipped for speed.
- **FR-003**: One task MUST still be one issue, one branch and one PR.
- **FR-004**: A task that depends on another MUST start as soon as that task's branch has a
  recorded `ready` review, from that branch, and its PR MUST target that branch and contain only its
  own changes.
- **FR-005**: The run MUST end with the PRs in the order to merge them, and MUST never merge a PR
  itself.
- **FR-006**: Running the command again MUST move every open stacked PR whose dependency was merged
  onto the base branch; a task whose own changes are unchanged keeps its review, and one whose
  changes moved MUST be reviewed again. A stacked PR MUST stay unmergeable (a draft) until it
  targets the base.
- **FR-007**: A task that fails MUST NOT stop the others; tasks that depend on it MUST NOT start; the
  report MUST say what stopped each one.
- **FR-008**: When every task has a reviewed PR, the run MUST combine all their branches in a
  separate working copy, run the project's full test command on it, and launch an independent
  whole-feature review that checks every requirement, user story and success criterion of the spec
  against the combined result, with evidence for each.
- **FR-009**: A conflict, a failing combined test, or an unmet requirement MUST be fixed in the task
  branch it belongs to (reviewed as a fix round), or become a new task appended to `tasks.md` with
  its issue, which then goes through the same run; the whole-feature check MUST run again after.
- **FR-010**: The whole-feature check MUST stop after a set number of rounds that still find gaps,
  and hand the decision to the developer.
- **FR-011**: The developer's own checkout MUST be unchanged by the run.
- **FR-012**: An interrupted run MUST resume from the state on the branches, the PRs and the review
  records, without redoing a task that already has a reviewed PR.
- **FR-013**: When every PR of the feature is merged, the command MUST prepare a release PR (version
  bump in every file that carries the version, notes written from the merged PRs), reviewed like any
  PR; after it is merged, it MUST tag that commit and publish the release. Where the project has no
  release convention, it MUST write the notes as a draft and say what is missing.
- **FR-014**: After the tasks and the spec PR are created, landspec MUST point to
  `/landspec:implement`; `/speckit-implement Tnnn` MUST keep doing one task; `/landspec:next` MUST
  offer the whole-feature run.
- **FR-015**: The command MUST refuse to start when the spec PR is not merged, and when the project's
  level requires an analysis that was not recorded.
- **FR-016**: The docs (README, reference, design, the help sources) MUST describe the command, its
  defaults and its limits.
- **FR-017**: When every task of a feature is merged, the command itself runs what the developer was
  told to run by hand before: the whole-feature check (in place of a separate converge step) and the
  project's full security audit before the release PR; a confirmed Critical or High finding holds
  the release, and the final message hands it to the security command, which tracks and fixes it
  without disclosing it. Its final message names only what is left for the
  developer: the PRs to merge, the held release, or `/speckit-specify` for the next feature.

### Key Entities

- **Run**: one invocation for one feature: the tasks it started, their state, the merge order, the
  whole-feature check rounds.
- **Task branch**: a task's branch and working copy, based on the base branch or on the branch of the
  task it depends on; its review record and its PR.
- **Stack**: the chain of PRs that target each other because their tasks depend on each other.
- **Whole-feature check**: the combined working copy, the full test run on it, and the independent
  review against the spec, per round.
- **Release**: the version bump, the notes and the tag that follow the merged feature.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For a feature of independent tasks, the time from running the command to the last PR
  being open is at most the time of the slowest task plus 20%, instead of the sum of all tasks.
- **SC-002**: For a feature with a chain of dependent tasks (each depending on at most one unmerged
  task), no task waits for a human merge before it starts; the developer is asked for nothing between the command and the final summary, apart
  from a check that ran out of rounds.
- **SC-003**: 100% of the PRs the run opens have a recorded `ready` independent review for their
  exact changes, and pass the same checks a PR opened one task at a time passes.
- **SC-004**: Before the developer merges anything, the whole-feature check has run the full test
  suite on all tasks combined and reported every requirement of the spec as met, with evidence, or
  has stopped and said what is not.
- **SC-005**: Merging the PRs in the printed order needs no conflict resolution by the developer.
- **SC-006**: After the last PR of the feature is merged, a reviewed release PR is ready on the next
  run of the command, and the tag and the published release follow its merge.
- **SC-007**: The developer's checkout is the same before and after a run.

## Assumptions

- Spec 003 (reviewer isolation, issues #124 and #125) is done first: the reviews of many tasks at
  once each need their own copy of the repository.
- The agent never merges PRs: the developer merges, in the printed order. This is landspec's rule and
  the environment's.
- Only the main session can start subagents, so it starts every implementer and every reviewer
  itself; the implementers do not start reviewers.
- The default number of tasks running together is 4, configurable per project.
- Tasks are written to be independent where they are marked as such, but code from independent
  tasks can still clash; the whole-feature check is the guard against that, not the markers.
- The whole-feature check stops after 3 rounds that still find gaps.
- A version bump is minor for a feature and patch when every task is a fix, unless the project's rules
  say otherwise.
- Out of scope: running tasks on other machines or in the cloud; merging without the developer.
