# Quickstart: validating /landspec:implement

Prerequisites: this branch's plugin loaded (`claude --plugin-dir .`), spec 003 merged, `gh` logged
in, a scratch GitHub repository you can push to (`gh repo create <you>/landspec-scratch --private`),
`/landspec:init lite` run there.

## 1. Stacking alone (slice 1)

In the scratch repo, write a feature with T001 and `T002 … (depends on T001)`, open and merge its
spec PR. `branch.sh T001`, commit, record a ready review; `branch.sh T002 --from <T001 branch>`,
commit. Expected: `review.sh risk` and `pr.sh task` on T002 cover only T002's commit; its PR's base
is T001's branch and its body says "Stacked on #<T001's PR>".

## 2. A whole feature (US1, US2, SC-001, SC-002)

A feature of five tasks: T001, T002 [P], T003 [P], T004 (depends on T001), T005 (depends on T004).
Run `/landspec:implement` once and time it. Expected: T001-T003 start together; T004 starts when
T001 is reviewed, T005 when T004 is; no question is asked; five PRs, T004 on T001, T005 on T004;
the report ends with `ORDER=` and the whole-feature check's result. The wall time is at most the
T001→T004→T005 chain plus 20%. `git status --porcelain` of the scratch checkout is the same as before.

## 3. Merge and restack (FR-006)

Squash-merge T001's PR on GitHub, run `/landspec:implement` again. Expected: `RESTACKED=T004
REVIEW=kept`; T004's PR now targets `main`, shows only its own changes and is no longer a draft;
T005's stays a draft on T004 until T004 is merged and the command runs again.

## 4. A gap (US3)

Add an FR to the spec that no task covers, run the command. Expected: the feature review reports it
`not met`; a spec PR adds a task line for it, with its issue; the report says to merge the PRs in
`ORDER` and the spec PR, then run again. After merging and running again: the gap task starts from
`main`, gets its PR, and the next check is `ready`.

## 5. Release (US4)

With `version_files: package.json` and `release_notes: docs/releases`, merge every PR, run
`/landspec:implement`. Expected: a release PR `chore(release): X.Y.Z` with a reviewed bump and notes;
after merging it and running again: tag `vX.Y.Z` and a published release with those notes. Before
the bump, the run audits `main` once (a second run reuses the report); plant a confirmed High (an
unauthenticated route that deletes data) and the release holds: no bump, no PR, no issue or
advisory filed, and the last line points to `/landspec:security` with the report's path. The last line
names only the PRs to merge or `/speckit-specify`.

## 6. Suite

`tests/run.sh` passes.
