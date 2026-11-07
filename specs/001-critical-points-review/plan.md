# Implementation Plan: Critical-points review against the project's purpose

**Branch**: `001-critical-points-review` | **Date**: 2026-11-05 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-critical-points-review/spec.md`

## Summary

Produce one review report, split into one file per section under
`specs/001-critical-points-review/report/` with `report.md` as its summary, that takes every promise
landspec makes (inventory in [contracts/report-format.md](contracts/report-format.md)), checks
the code that keeps it, and gives a verdict with evidence; then weighs the core model (task = PR,
spec PR, levels) and ends with a ranked list of fixes. The review changes no behavior (FR-011):
its only output is Markdown. Reproductions run on throwaway repositories built the way
`tests/helpers.sh` builds them (a local bare origin and a fake `gh`), so most need no network.
Behavior only GitHub can show (issues, PRs, the Copilot request, branch protection, auto-merge)
is run for real on the private sandbox `iamalisson/jit-speckit-sandbox`, guarded and cleaned up (research R2).

## Technical Context

**Language/Version**: Markdown report; reproductions in bash, runnable on bash 3.2 and 5 like the project's tests

**Primary Dependencies**: `git`, the project's own scripts in `extension/scripts/`, `tests/helpers.sh` for throwaway repositories; `shellcheck` and `tests/run.sh` as already used in CI

**Storage**: N/A (Markdown files in the feature folder)

**Testing**: no new code, so no new tests. Each section's evidence is a command and its output; `tests/run.sh` must still pass unchanged (proves FR-011)

**Target Platform**: the maintainer's Linux machine; macOS-only behavior is reported as unverified unless the weekly macOS CI run shows it

**Project Type**: review of a Claude Code plugin + spec-kit extension (bash and prompts)

**Performance Goals**: each reproduction runs in under a minute (SC-002: under 10 minutes to reproduce by hand)

**Constraints**: no working secret and no step-by-step bypass in the report (FR-012); third-party behavior (Claude Code hooks, GitHub Copilot review API, spec-kit hook execution) is checked against its primary documentation (`docs/references.yaml` style: official docs only), or marked unverified

**Scale/Scope**: 28 promises (P01–P28), 8 report sections, about 25 scripts and 15 prompt files read

## Constitution Check

*Gate before Phase 0, re-checked after Phase 1: passes.*

| Rule | How this plan meets it |
|---|---|
| Simplicity (KISS, YAGNI) | One Markdown report (a file per section, so parallel PRs never conflict). No new script, tool or test harness: reproductions reuse `tests/helpers.sh`. |
| Secrets | FR-012: findings name the class of a bypass and its fix, never a working secret or a recipe. Fake secrets are built at run time inside throwaway repos and never committed (research R7). Exploitable findings go to a private draft advisory, never to the repo or a public issue (FR-013, research R6). |
| Tests | No logic is added, so nothing needs a new test. `tests/run.sh` passing unchanged is the evidence that no behavior changed. Proposed fixes each name the failing check they need (FR-010), in the project's "when …, then …" form. |
| Docs are the source of truth | The review reads the docs as the promise; a mismatch between doc and code is a finding. It edits no doc (fixes do, later). |
| One task = one issue = one branch = one PR | One task per report section; each PR adds one section, reviewable on its own. |
| No AI attribution | Commits and PR bodies carry none. |
| bash 3.2 floor | Reproduction snippets avoid bash-4-only features, so they run where the tests run. |

No violations; Complexity Tracking is empty.

## Design

The report is built section by section, each section a task:

| Section | Promises (see contract) | Main files read |
|---|---|---|
| 1. Task chain | P01–P05, P23 | `extension/scripts/issues.sh`, `branch.sh`, `next.sh`, `pr.sh`, `lib.sh`, `extension/scaffold/standard/.github/workflows/close-linked-issues.yml` |
| 2. Secrets and the command guard | P06–P09 | `extension/scripts/secrets.sh`, `prepush.sh`, `guard.sh`, `hooks/guard-git.sh`, `hooks/hooks.json`, `extension/scaffold/lite/.githooks/*` |
| 3. Review gate and tests as evidence | P10–P15, P26 | `extension/scripts/review.sh`, `pr.sh`, `mutants.sh`, `analyzed.sh`, `extension/commands/review.md`, `pr.md`, `issues.md` |
| 4. CI gate and supply chain | P16, P17, P25, P27, P28 | `extension/scripts/level.sh` (generated workflows), `pins.sh`, `bin/sync-pins.sh`, `security-scan.sh`, `skills/security/SKILL.md` |
| 5. Levels, setup and the user's files | P18–P22, P24 | `extension/scripts/level.sh`, `bin/setup.sh`, `bin/remove.sh`, `skills/init`, `adopt`, `level`, `remove` |
| 6. The project against its own rules, and cost per level | FR-007, FR-008 | `.specify/memory/constitution.md`, `.github/workflows/test.yml`, `tests/`, `extension/levels/*.md` |
| 7. The core model | FR-008a | `docs/design.md`, `README.md`, section 6's cost table |
| 8. Prompts against context-engineering guidance | FR-014, SC-003b, research R8 | `skills/*/SKILL.md`, `extension/commands/*.md`, `preset/commands/*.md`, `extension/levels/*.md`, `preset/templates/*.md`, `docs/GUIDELINES.md`, `docs/GUARDRAILS.md`, `docs/references.yaml` |
| Summary (`report.md`) | FR-009, FR-010, FR-013, US3 | sections 1–8 |

Each section is its own file, `report/<n>-<name>.md` (`1-task-chain.md`, `2-secrets-guard.md`,
`3-review-gate.md`, `4-ci-supply-chain.md`, `5-levels-files.md`, `6-own-rules-cost.md`,
`7-core-model.md`, `8-context-engineering.md`). Sections 1–6 are independent. Section 7 cites section 6's per-level cost
table instead of redoing it, so it follows section 6. `report.md` (the ranked summary, the fix
list and the unverified list) is written last, from all eight. Each section file starts with the
commit SHA it reviewed.

## Project Structure

### Documentation (this feature)

```text
specs/001-critical-points-review/
├── spec.md
├── plan.md              # this file
├── research.md          # how the review is done (Phase 0)
├── data-model.md        # promise, finding, design verdict (Phase 1)
├── quickstart.md        # how to check the report (Phase 1)
├── contracts/
│   └── report-format.md # the report's shape and the promise inventory P01–P28
├── checklists/requirements.md
├── report.md            # summary, ranked fixes, unverified list (written last)
├── report/              # one file per section 1–8
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

No source changes. The review reads `extension/`, `hooks/`, `bin/`, `preset/`, `skills/`,
`docs/`, `README.md`, `.github/` and `tests/`.

**Structure Decision**: the tasks create only `report.md` and `report/*.md` in the feature folder.

## Complexity Tracking

None.
