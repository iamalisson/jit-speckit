# Implementation Plan: Fix what the critical-points review found (release 1.8.0)

**Branch**: `002-review-fixes` | **Date**: 2026-11-05 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-review-fixes/spec.md`

## Summary

Deliver the 26 public High and Medium fixes of feature 001's `report.md` plus #41, each with the
check that proves it, and ship them as 1.8.0. Each fix's change and check come from its 001 entry,
as corrected by [research.md](research.md) (C1); the user's three decisions (U1 merges, U2 Semgrep,
U3 constitution) are applied. The code stays bash 3.2-safe with no new dependency; new state is
three files: a diff record per kind in `.git/`, a written-file record in the project's
`.specify/`, and an old-file manifest shipped with the extension ([data-model.md](data-model.md)).
The exact lines users see are in [contracts/output-lines.md](contracts/output-lines.md); each fix's
check is in [contracts/checks.md](contracts/checks.md).

## Technical Context

**Language/Version**: bash, floor 3.2 (macOS) and bash 5 (Linux); Markdown prompts and docs; GitHub Actions YAML

**Primary Dependencies**: `git`, `gh` (with its built-in `--jq`), `specify` (v1.2.5, `bin/setup.sh`); no new dependency. Semgrep's official image by digest replaces its `uvx` install in the generated full-level workflow (U2)

**Storage**: files only: `<git-common-dir>/jit-{review,mutants,security}/<diff id>`, `.specify/jit-files.sha256`, `extension/scripts/old-files.sha256`

**Testing**: `tests/run.sh` (one `tests/<script>.test.sh` per script, "when …, then …", `tests/helpers.sh` throwaway repos and fake `gh`); each fix's check seen failing first (constitution, no bash mutation tool)

**Target Platform**: Linux (bash 5, GNU), Linux bash 3.2 + busybox (`bash32` job), macOS (stock bash 3.2, BSD tools; now on script PRs and tags, F5.6)

**Project Type**: Claude Code plugin + spec-kit extension and preset (bash scripts and prompts)

**Performance Goals**: `next` makes one GraphQL call per feature instead of one search per feature; `pr.sh task` adds the project's own test run (its cost is the project's suite)

**Constraints**: no AI attribution; nothing about F2.1 beyond its id (FR-024); no runnable guard bypass in any committed text (F2.3 tests cut prefixes at run time); tests run offline (scans with no scanners on `PATH`)

**Scale/Scope**: 26 fixes + #41 + the release; about 20 scripts, 6 prompts, 4 docs, 3 workflows, 12 test files

## Constitution Check

*Gate before Phase 0, re-checked after Phase 1: passes, with the constitution change made in its
own PR first (U3).*

| Rule | How this plan meets it |
|---|---|
| bash 3.2 is the floor | No `sort -V` (pure-bash `version_newer`), no `mapfile`, no associative arrays; the `bash32` job and the macOS workflow run every new check. |
| One shared library | New helpers live once in `lib.sh` (`diff_id`, `diff_record`, `version_newer`, `branch_feature`, `test_path_re`); `review.sh`'s patch-id code moves there; `bin/setup.sh` sources `lib.sh` for `version_newer` instead of a copy. |
| Nothing of the user's is overwritten | This feature makes it true where it was not: `remove` keeps edited files (F5.2), `put()` keeps newer pins (F4.7), old releases' files are named or replaced only when byte-identical (F5.3). |
| Scripts refuse, prompts explain | Four gates move from prompt to script (F3.3, F3.4, F3.6, F3.8), each with one `die` that names what to run. |
| Tests are bash and prove themselves | Every fix has a check ([contracts/checks.md](contracts/checks.md)) seen failing first; the PR's `## Evidence` says so. New script `bin/check-tools.sh` gets `tests/check-tools.test.sh`. |
| Pins and versions agree in one place | `SEMGREP_DIGEST` joins `pins.sh`; every `PIN_*` is used by `pins.yml`, so Dependabot sees it; the drift check in `static.test.sh` covers the new workflows. |
| Docs are the source of truth | Each task changes the docs of the behavior it changes, in the same PR (FR-023), except the constitution line (U3). |
| Amendments in their own PR | The 2.1.275 → 2.1.295 line goes through `/speckit-constitution` (1.0.1) before the F2.4 task (U3). |
| Simplicity | Each fix is its 001 entry's smallest change; no option nobody asked for. The two new files (`pins.yml`, `check-tools.sh`) exist only because Dependabot reads workflows and tests run offline (research R8). |
| One task = one issue = one branch = one PR | One task per fix or per pair that edits the same lines; dependencies order the tasks that share a file. |
| No AI attribution | None in commits or PR bodies. |

No violations; Complexity Tracking is empty.

## Before the tasks

1. **Constitution 1.0.1** (U3): `/speckit-constitution` changes "Claude Code 2.1.275" to 2.1.295,
   pointing at `hooks/hooks.json` `onFailure`; its own PR.
2. **001's entries corrected** (research C1): one small-fix PR to
   `specs/001-critical-points-review/report.md` and its section files, so every task reads a
   correct entry.
3. **#41** gets a comment with U1 (rebase off everywhere, squash only on lite).

## Task groups and order

The groups below became 9 tasks (user, 2026-11-05: fewer, larger tasks; each PR fixes High and
Medium findings, lists Lows, at most 2 review rounds, the second a delta on the fix commit):
T001 = A; T002 = B's first four (F3.3, F3.4, F3.6, F3.9); T003 = the rest of B (F3.1/F4.3, F3.7,
F3.5, F1.8); T004 = C's F3.8 and F2.3 with E's F2.4; T005 = C's F1.1 with D; T006 = E's F4.2,
F4.5, F4.4/#41; T007 = F; T008 = the sandbox proof; T009 = the release.
Added on 2026-11-05 (US6, research Part 2): T010 = risk map and delta rounds (after T003); T011 =
the pinned reviewer agent (after T010); T012 = parallel start lines in `next` (after T005).

Tasks that edit the same lines of a file run in sequence (`depends on`); the rest are parallel.
Appends to `tests/static.test.sh` from parallel tasks are merged in order (each under its own
comment line), not made into dependencies.

| Group | Fixes | Main files | Depends on |
|---|---|---|---|
| A. User's files | F5.2 | `level.sh` `put()` (written-file record), `bin/remove.sh`, `tests/remove.test.sh` (new) | — |
| | F4.7, F5.3 | `level.sh` `put()`, `lib.sh` `version_newer`, `old-files.sha256`, `tests/level.test.sh`, fixture | F5.2 |
| | F5.4 | `bin/setup.sh` (sources `lib.sh`), `tests/setup.test.sh` | F4.7/F5.3 |
| B. PR gates (`pr.sh task`) | F3.3 | `pr.sh`, `pr.md` step 2, `tests/pr.test.sh` | — |
| | F3.4 | `lib.sh` `diff_id`/`diff_record`, `review.sh`, `mutants.sh`, `pr.sh` | F3.3 |
| | F3.6 | `security-scan.sh`, `pr.sh` | F3.4 |
| | F3.9 | `lib.sh` `TEST_PATH_RE`/`test_path_re`, `pr.sh:62`, `mutants.sh` | F3.6 |
| | F3.1, F4.3 | `review.sh report`, `pr.sh`, `review.md`, `pr.md` step 5, `docs/design.md` | F3.9 |
| | F3.7 | `review.sh:45`, `tests/review.test.sh` | F3.1/F4.3 |
| | F3.5 | `pr.sh` `open_pr`, fake `gh` `api -X` | F3.1/F4.3 |
| | F1.8 | `pr.sh` spec, fake `gh` `pr list` failure | F3.5 |
| C. Other gates | F3.8 | `analyzed.sh`, `analyzed.md`, `tests/branch.test.sh` | — |
| | F1.1 | `branch.sh:56`, `tests/branch.test.sh` | F3.8 |
| | F2.3 | `guard.sh`, `tests/guard.test.sh` | — |
| D. Task chain | F1.2, F1.9 | `next.sh`, `lib.sh` `branch_feature`, fake `gh` `api graphql`, `tests/next.test.sh`, `docs/reference.md` | — |
| | F1.7 | `issues.sh`, fake `gh` create failure, `tests/issues.test.sh` | F1.2/F1.9 (fake `gh`) |
| | F1.6 | scaffold `close-linked-issues.yml`, `tests/static.test.sh` | — |
| E. Docs and settings | F2.4 | `README.md:44`, `docs/security.md:28`, `tests/static.test.sh` | constitution 1.0.1 |
| | F4.2 | `skills/security/SKILL.md`, `tests/static.test.sh` | — |
| | F4.5 | `pins.sh`, `level.sh` `security_yaml`, `README.md:109`, `docs/security.md:31`, `tests/level.test.sh` | F4.7/F5.3 (`level.sh`), F3.6 (adjacent README and security doc lines) |
| | F4.4, #41 | `skills/init/SKILL.md` steps 4–5, `README.md:109`, `docs/security.md`, `docs/design.md` | F4.5 (README row), F3.1/F4.3 (`design.md`) |
| F. CI | F5.6 | `.github/workflows/macos.yml`, `test.yml`, `tests/static.test.sh` | — |
| | F4.1 | `.github/workflows/pins.yml`, `bin/check-tools.sh`, `tests/check-tools.test.sh`, fake `gh` `api repos/*` | F5.6, F4.5 (pins) |
| G. Proof and release | sandbox run | `sandbox-run.md` (new): the merged `main` end to end on `iamalisson/jit-speckit-sandbox`, guarded as in 001 | every task above |
| | 1.8.0 | three version files, the version-agreement check, release notes listing every fixed id | the sandbox run |

## Rules every task follows

- **Seen failing first** (FR-022): before the change, run the new check on the unchanged code and
  paste its FAIL line into the PR's `## Evidence` as "seen failing before the change: <label>";
  then the passing run. Guard halves are listed separately.
- **Docs in the same PR** (FR-023): the docs that describe the changed behavior, including
  [contracts/output-lines.md](contracts/output-lines.md) wording.
- **Nothing private** (FR-024): F2.1 appears only by id; F2.3's tests build prefixes at run time and
  no PR body lists a bypass form.
- **Fake `gh`**: new cases are added beside the existing ones (`issue list` stays); a task that adds
  one says so in *Impact*.
- **Offline tests**: scans in tests run with a `PATH` holding no scanners.

## Project Structure

### Documentation (this feature)

```text
specs/002-review-fixes/
├── plan.md              # this file
├── research.md          # Phase 0: R1–R9, U1–U3, critic's points, C1 corrections to 001
├── data-model.md        # diff records, written-file record, old-file manifest, version
├── quickstart.md        # how to check the feature
├── contracts/
│   ├── output-lines.md  # every new or changed line users see
│   └── checks.md        # each FR's check, failing-first and guard halves
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
extension/scripts/   lib.sh, pr.sh, review.sh, mutants.sh, security-scan.sh, analyzed.sh,
                     branch.sh, next.sh, issues.sh, guard.sh, level.sh, pins.sh,
                     old-files.sha256 (new)
extension/commands/  pr.md, review.md, analyzed.md
extension/scaffold/standard/.github/workflows/close-linked-issues.yml
bin/                 setup.sh, remove.sh, check-tools.sh (new)
skills/              init/SKILL.md, security/SKILL.md
.github/workflows/   test.yml, macos.yml (new), pins.yml (new)
docs/                security.md, design.md, reference.md; README.md
tests/               helpers.sh, pr, review, branch, next, issues, guard, level, setup, static,
                     check-tools (new) .test.sh; fixtures/ (new)
```

**Structure Decision**: the existing layout; two new scripts' worth of files (`bin/check-tools.sh`
with its test, `old-files.sha256` as data) and two workflows.

## Complexity Tracking

Empty: no constitution violation.

## Convergence

The 1.8.0 coherence review added T013 to T021 (tasks.md, Phase 7). They merge before T009.
