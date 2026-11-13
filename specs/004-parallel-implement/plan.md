# Implementation Plan: Implement a whole feature in parallel

**Branch**: `spec/004-parallel-implement` | **Date**: 2026-11-13 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/004-parallel-implement/spec.md`

## Summary

`/landspec:implement` runs a feature's tasks together. The main session reads each task's state
from git, GitHub and the review records (`implement.sh status`), starts up to `parallel_tasks:`
implementers at once, each a background subagent in its own Claude Code worktree that creates and
claims its task branch, and drives every task through the existing gates: the independent review
(launched by the main session, since subagents cannot start subagents), fix rounds, the scan and
`pr.sh task`. A dependent task starts from its dependency's reviewed branch; one setting
(`landspec-parent`) makes `base_ref()` stack-aware, so its review and PR cover only its own commits,
and `implement.sh restack` moves it onto the base after the parent is squash-merged. When every task has
a PR, a whole-feature check merges all branches in a separate copy, runs the full suite, and a
reviewer in a new **feature review** mode checks every FR, scenario and SC; gaps become new
stacked tasks. When the feature is merged, the next run prepares the release PR and, after its
merge, tags and publishes it. The developer only merges, in the printed order.

## Technical Context

**Language/Version**: bash 3.2+ (BSD, busybox and GNU tools); markdown prompts for skills, commands and agents.

**Primary Dependencies**: git (worktrees, `rebase --onto`, branch config), gh (PRs: `--base`, `edit --base`, `release create`), Claude Code's Agent tool (`isolation: "worktree"`, background agents, SendMessage); spec 003 merged first.

**Storage**: none new: state is derived (research R6); two small files per stacked branch under `<git common dir>/landspec-review/`.

**Testing**: `tests/run.sh` with a new `tests/implement.test.sh`, plus checks in `branch`, `pr`, `review`, `next`, `static` tests; the skill itself by quickstart scenarios on a scratch repository.

**Target Platform**: Linux and macOS, where Claude Code runs.

**Project Type**: Claude Code plugin plus spec-kit extension.

**Performance Goals**: SC-001: the run's wall time is at most the slowest chain plus 20%.

**Constraints**: never merge; never write the developer's checkout; one task = one issue = one PR; every gate of a single task still applies; bash 3.2.

**Scale/Scope**: features of 2-20 tasks; `parallel_tasks:` 1-16, default 4.

## Constitution Check

| Rule | How this plan meets it |
|---|---|
| Never commit or push outside the flows it documents; never open a PR on red checks | the run's pushes are `branch.sh` claims, `pr.sh` and `restack`'s `--force-with-lease` on task branches only, all documented; `pr.sh` keeps its checks |
| Every PR gets the independent review | each task, each fix round and the release PR get it; the feature review is an extra read, not a replacement |
| Bash 3.2 with BSD or busybox tools | `implement.sh` uses the same helpers as `next.sh`; no associative arrays, no GNU flags |
| One test file per script; checks can fail | `tests/implement.test.sh` for the new script; each changed script's own test file |
| Never overwrite what the user made | implementers run in Claude Code worktrees; the check copy is detached, never pushed, removed after; `restack` refuses a branch with local commits not on origin |
| Docs are the source of truth | README, `docs/reference.md` (command, config keys, merge order), `docs/design.md` (why stacked PRs), help sources |
| Installed copy equals the source | `specify extension add --dev extension --force`; static check |

No violations. Re-checked after Phase 1: the invariant in data-model ("a task branch's own diff
holds only its commits") is what keeps "every PR gets the review" true for stacked PRs.

## Project Structure

### Documentation (this feature)

```text
specs/004-parallel-implement/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/ implement-sh.md, implement-skill.md, feature-review.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
extension/scripts/lib.sh         # base_ref() reads landspec-parent (R3)
extension/scripts/branch.sh      # --from <branch>
extension/scripts/pr.sh          # stacked --base and body line
extension/scripts/implement.sh         # new: status, mark, fail, retry, restack, stack, check-copy, check-result, release-plan, release-bump
extension/scripts/review.sh      # record --feature
extension/scripts/next.sh        # RUN= line
extension/commands/review.md     # feature review mode
extension/commands/issues.md     # step 6 points to /landspec:implement
skills/implement/SKILL.md        # new: the run
agents/implementer.md            # new: the implementer agent
skills/next/SKILL.md, README.md, docs/reference.md, docs/design.md
tests/implement.test.sh (new), tests/{branch,pr,review,next,static}.test.sh
```

**Structure Decision**: one new script, one new skill, one new agent; everything else extends what
exists.

## Slices (for /speckit-tasks)

1. **Stacked task branches**: `base_ref()` + `branch.sh --from` + `pr.sh` base and body, with tests.
   Observable alone: a branch started `--from` another gets a review and a PR of only its own diff.
2. **Run state**: `implement.sh status` and `fail`, `next.sh`'s `RUN=` line, with tests.
3. **Restack**: `implement.sh restack`, with tests on a squash-merged parent. Depends on 1.
4. **The command**: `skills/implement/SKILL.md`, `agents/implementer.md`, the config keys, issues.md
   step 6 and next's skill pointing to it, docs. Depends on 1-3 and spec 003.
5. **Whole-feature check**: `implement.sh check-copy`, review.md's feature mode, `record --feature`, the
   skill's step 5 and gap tasks. Depends on 4.
6. **Release**: `version_files:`/`release_notes:`, the bump and notes, the release PR, tag and
   publish. Depends on 4.

## Risks

- Background agents and SendMessage are Claude Code features this repo has used but not pinned to
  a version; the skill says what to do when SendMessage is missing (start a new implementer on the
  same copy with the findings).
- An implementer's copy may be removed by Claude Code when the agent ends (research R2): the work is
  pushed, and the main session recreates a worktree for the task branch.
- Many implementers at once cost tokens and CPU (mutation runs); `parallel_tasks:` bounds it.
- A conflict between two independent tasks is found by the whole-feature check, not before; the
  fix goes to a task branch as a fix round.
- `restack` force-pushes task branches: with `--force-with-lease` against the origin head its own
  fetch read, which must equal the PR's head; otherwise it skips the branch.
