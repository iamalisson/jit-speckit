---
description: "Independent review of the branch (or of the plan, before issues) by a fresh reader grounded in the whole repository"
---

# Independent review

A fresh reader, not the author. It starts from the diff, then reads the repository around it, and
reports few findings, each verified and tied to a line that already exists. This is how the best
automated reviewers work (GitHub's Copilot code review gathers repository context with tools before
it comments), and it is why they catch what a review inside the author's own session misses: that
session shares the author's assumptions and tests the same path the author tested.

**Two roles.** If you are the author's session (`/speckit-jit-pr`, `/speckit-jit-issues`, or the
user ran `/speckit-jit-review`): launch one general-purpose subagent whose prompt is this whole
file plus the facts below, and nothing else: no summary of what you built, no "I already checked
X". Wait for its report. If you are that subagent: follow the method and return only the report.

Facts the author passes:
- the base branch and the branch under review, or, for a plan review, the feature folder
  `specs/NNN-*/`;
- the task's line from `tasks.md` with its sub-bullets, or "plan review";
- the path of the PR body draft, if there is one;
- the project's test command (the constitution's **Commands** line or its jit block).

## Method

1. **Read the rules first**, from the branch: `.specify/memory/constitution.md`, `AGENTS.md`,
   `CLAUDE.md`, `.github/copilot-instructions.md` where they exist, and the feature's `spec.md`,
   `plan.md` and the task's line (*Comes from*, *Impact*, *Completed when*).
2. **Start from the diff, end in the repository.** `git diff <base>...HEAD`. For every changed
   file, open what it calls and what calls it (search each symbol). For every new file of a kind
   the repository already has (migration, workflow, endpoint, model, job, script), open the newest
   two siblings and list every guard they have: existence checks, idempotent writes, timeouts,
   authorization, refusal to run against production. A guard the siblings have and the new file
   lacks is a finding, with the sibling's `file:line` as evidence.
3. **Check every claim.** Each line of the PR body's *Evidence* and the task's *Completed when*:
   re-run the command when it takes under a minute; otherwise read the test and say what it
   proves. Each *Impact* item: is it handled in this diff? A claim you cannot reproduce is
   reported as unverified, never assumed.
4. **Run the tests, then break the code once.** Run the test command. For the task's main
   behavior, make one small change that should break it (invert a condition, drop a guard, return
   early), run the tests again, and restore the file. A suite that stays green is a finding.
5. **Walk the real path, not the fresh one.** For each change ask what happens where state already
   exists: a table the models already created, a half-applied earlier run, a retry, two requests
   at once, a missing optional config, an empty result. The happy path on a clean machine is the
   one the author already tested.
6. **Security at the boundaries** of what changed: input validation, authorization taken from the
   authenticated context, secrets, injection, what the error messages leak.

**Plan review** (before the issues are created): apply steps 1, 2 and 5 to every task in
`tasks.md`. *Impact* names every reference the task touches (search each symbol) and the newest
sibling of each file it adds; *Completed when* is a command that proves the real path, not only a
fresh state; a step that writes data names its target and refuses production; no task deletes
what another task still uses. **Shape:** a task is a vertical slice with an observable result. A
task that is one layer of a behavior another task completes (a model here, its migration there,
the endpoint in a third) is a finding: name the tasks to merge. So is a task whose diff would
clearly pass about 400 lines with its tests: name the behaviors to split it by.

## Report

Written for the author, who fixes it, and for the human who merges:
- **What changed**: three lines at most, in your own words from the code, not from the PR body.
- **Findings**, ranked: **High** (wrong result, data loss, a broken upgrade on existing state,
  security), **Medium** (a guard the siblings have, a test that cannot fail, an unhandled
  real-path case), **Low** (worth a line, not a block). Each one: `file:line`, one concrete
  scenario of what goes wrong ("on a database built by `create_all` and stamped at the previous
  revision, `flask db upgrade` stops with 'already exists'"), and the evidence (the sibling's
  `file:line`, the command output). A finding you could not verify says so. No style, no naming,
  no nits: they are what gets reviews ignored.
- **Assessment**: `ready`, or `changes needed` when there is any High or Medium.
