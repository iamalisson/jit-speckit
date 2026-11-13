# Implementation Plan: Reviewer isolation and privacy findings

**Branch**: `spec/003-reviewer-isolation-privacy` | **Date**: 2026-11-12 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-reviewer-isolation-privacy/spec.md` (issues #121, #120)

## Summary

The independent reviewer gets its own copy of the repository. Every review launch passes
`isolation: "worktree"`, and the launch guard refuses one that does not. Claude Code starts that
copy at the default branch, not the author's (research R1, confirmed by a probe), so the reviewer
first moves its copy to the reviewed commit, a new fact, and checks it. It reads the author's
checkout only to copy an uncommitted feature folder for a plan review, and never writes there.
It names its copy in the report, and `review.sh record` removes a copy that was left with changes
(R4). Separately, the reviewer's bug list gains personal data or a secret reaching a log through a
helper, and its severity list gains a test that fakes the component it asserts about (R6).

## Technical Context

**Language/Version**: bash 3.2+ (BSD, busybox and GNU tools) for scripts and hooks; markdown prompts.

**Primary Dependencies**: git (worktrees), Claude Code's Agent tool `isolation: "worktree"` (accepted on 2.1.322; R5), python3 optional for the hook's JSON parse.

**Storage**: review records under `$(git rev-parse --git-common-dir)/landspec-review/` (unchanged).

**Testing**: `tests/run.sh`: `tests/guard-review.test.sh`, `tests/review.test.sh`, `tests/static.test.sh`.

**Target Platform**: Linux and macOS, where Claude Code runs.

**Project Type**: Claude Code plugin plus spec-kit extension (prompts, bash scripts, hooks).

**Performance Goals**: no slower review: the switch to the reviewed commit is one checkout of a shared object store.

**Constraints**: fail closed (no fallback to the author's checkout); `record` removes only the reviewer's own copy; nothing removed from the author's checkout.

**Scale/Scope**: one hook, one script action, three command prompts, the agent definition, docs.

## Constitution Check

| Rule | How this plan meets it |
|---|---|
| Bash 3.2 with BSD or busybox tools | the new hook branch reuses `field()`; `record`'s removal uses `git worktree list --porcelain` and `case` on paths, no GNU flags |
| One test file per script, "when …, then …" checks | guard checks in `tests/guard-review.test.sh`, removal checks in `tests/review.test.sh`, prompt pins in `tests/static.test.sh` |
| Never overwrite or delete what the user made | `record` removes a worktree only when it is an `agent-*` folder under `.claude/worktrees/`, on a `worktree-agent-*` branch, at the reviewed commit, listed by git, named in the report, not the checkout itself |
| Docs are the source of truth | `docs/security.md` row for the review hook, `docs/reference.md`, `docs/design.md`'s review paragraph, README's review row |
| Installed copy equals the source | `specify extension add --dev extension --force` after editing `extension/`; the static check covers it |
| Every PR gets the review | unchanged; this changes how it runs |

No violations. Re-checked after Phase 1: the data model's removal rules keep the "never delete what
the user made" rule; still no violations.

## Project Structure

### Documentation (this feature)

```text
specs/003-reviewer-isolation-privacy/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── guard-review.md
│   └── review-record.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
hooks/guard-review.sh                  # refuse a review launch without isolation: worktree
agents/reviewer.md                     # isolation: worktree; never write to the author's checkout
extension/commands/review.md           # facts commit:/checkout:, first step, Copy: line, #120 rules
extension/commands/pr.md               # step 4: pass isolation
extension/commands/issues.md           # step 2: pass isolation
extension/scripts/review.sh            # record removes the reviewer's leftover copy
extension/scripts/pr.sh, branch.sh     # dirty checks ignore .claude/worktrees/
specs/003-.../fixtures/leak-through-helper/  # #120's reproduction (make-repo.sh)
.specify/extensions/landspec/...       # synced copy
tests/guard-review.test.sh
tests/review.test.sh
tests/static.test.sh
docs/security.md, docs/reference.md, docs/design.md, README.md
```

**Structure Decision**: the existing layout; no new files outside tests.

## Slices (for /speckit-tasks)

1. **Isolated review (US1, P1)**: guard rule (always on, R8) + tests, the launch
   prompts and agent definition pass `isolation`, review.md's facts and first step, the `Copy:`
   line and `record`'s removal (R4), `pr.sh`/`branch.sh` ignoring `.claude/worktrees/`, static
   pins, docs. One slice: isolation without the cleanup would leave copies that stop the
   author's next PR (plan review round 1).
2. **Privacy findings (US2, P2)**: review.md step 2 and severity list, the committed
   `fixtures/leak-through-helper/`, static pins, docs. Independent of 1.

## Risks

- A project copy older than the plugin is refused until `/landspec:init` (R8): reviews, and so
  PRs, stop there until the user updates. The refusal says so.
- `tool_input.isolation` is not in the docs' example table (R3). The rule fails closed; the
  quickstart's first scenario proves it on a real launch before the PR merges.
- A reviewer told to `cd` elsewhere (a prompt that names another checkout) leaves its copy; the
  prompt rule forbids it, nothing enforces it.
- Commands can still write outside the copy (`/tmp`, `$HOME`); out of scope (R7).
