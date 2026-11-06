---
description: "Tasks for the critical-points review"
---

# Tasks: Critical-points review against the project's purpose

**Input**: Design documents from `specs/001-critical-points-review/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/report-format.md](contracts/report-format.md), [quickstart.md](quickstart.md)

**Tests**: this feature adds no code (FR-011), so no task adds a test. Every task proves itself
the same way: its section file has a verdict with evidence for each of its promises, every
`broken` or `limit` verdict has a reproduction that was run, and `tests/run.sh` still passes with
nothing changed outside `specs/001-critical-points-review/`.

**Organization**: one task per report file. No setup or foundational phase: the project and its
test harness (`tests/helpers.sh`) already exist.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependencies)
- `(depends on T00n)`: needs that task merged first
- One task = one issue = one branch = one pull request; ` — #N` is appended automatically.

## Rules every task follows

- Verdicts per [data-model.md](data-model.md): `holds`, `limit`, `broken`, or `unverified`.
  **Failure path:** a claim that cannot be reproduced, or a third-party fact with no official
  documentation found, is `unverified` with what would check it, never `broken` or `holds`.
- **What is reviewed is the tag `v1.7.2` (`172f8c5`)**, read from its own worktree:
  `git worktree add "$(mktemp -d)" v1.7.2`. Every `file:line` cites that tree, so a later merge to
  `main` (feature 002, a fix) never changes what a section describes.
- **Reproductions are scripts**, the way the project's own tests run: a file under `mktemp -d` that
  sources `tests/helpers.sh` from the v1.7.2 worktree (`new_repo`, `fake_gh`; the repository then
  lives in helpers' own `$TMP`, removed on exit), first checks `git rev-parse --show-toplevel` is
  not this checkout, and runs every command expected to be refused as `cmd || echo "rc=$?"`, since
  helpers sets `set -euo pipefail`; run as `bash <file>`. Paste the script and its output. Running it as a file is needed because the
  command guard judges inline commands as if they ran in this repository, wherever they run (the
  false positive T002 reports); it is never used for anything in this checkout.
- **Real GitHub behavior is run for real**, not only against the fake `gh`: issues, PRs, the Copilot
  request, branch protection and auto-merge on `iamalisson/jit-speckit-sandbox` (private, on jit-speckit 1.7.2 since
  its PR #10). Only from the sandbox clone, and only after
  `[ "$(git remote)" = origin ] && [ "$(gh repo view --json nameWithOwner -q .nameWithOwner)" = iamalisson/jit-speckit-sandbox ] || exit 1`
  (one remote, so jit's own scripts, which call `gh` without `-R`, can only reach the sandbox). A direct
  `gh` write also passes `-R iamalisson/jit-speckit-sandbox` (`gh api` names `repos/iamalisson/jit-speckit-sandbox/…`
  in its path, since it has no `-R`) and carries the task's id: titled `[001 review Tnnn]`, its branches `review-001-tnnn-*`. What jit's scripts
  create (T001 only) runs under a sandbox feature numbered from `099` down: the highest number with no
  `specs/<number>-*` on the sandbox base yet, so a rerun never meets the last run's merged `tasks.md` (whose
  lines already carry `— #N`, which `issues.sh` would skip). Its issues are `[<number>] T…`, its branches
  `feat/<number>-*` and `spec/<number>-*`, none mixing with the sandbox's own `001`; the section names the number it
  quotes. Each task writes down the number of every issue and PR and the name of every branch it creates as it
  creates them, and its cleanup closes and deletes only those, so tasks running in parallel never close each
  other's PRs; PRs merged into the sandbox
  base during the run stay there and are listed in the section (the sandbox is a test repo). A setting
  is recorded before it changes, as the exact command that puts it back: branch protection that answered
  404 "Branch not protected" is put back with `gh api -X DELETE repos/iamalisson/jit-speckit-sandbox/branches/<b>/protection`;
  `allow_auto_merge` with `gh api -X PATCH repos/iamalisson/jit-speckit-sandbox -F allow_auto_merge=<saved value>`. Repository security advisories are not offered on private
  repositories (the sandbox answers 404 even to a list), so the advisory body was verified on this
  repository on 2026-11-05 (research R6). A verdict on GitHub behavior quotes the real output.
- **A bypass of a protection** (the command guard, the secret checks, the git hooks): the committed
  section gives its class, the exact output that shows it, and the `file:line` of the gap; the
  runnable script is kept outside the repository, in `$(git rev-parse --git-common-dir)/jit-repro/`,
  never pasted in a PR, issue or commit. The maintainer reproduces it from there (SC-002).
- **Exploitable findings stay private** (FR-013, research R6): only harm someone other than the
  operator can cause (a secret leaving through what jit generates or runs, a protected branch changing
  on GitHub, someone else's PR getting past the CI gate). It is filed as a private draft advisory,
  summary starting `[001 Fn.m]`, after checking no advisory with that tag exists already, with the
  JSON body research R6 gives (`summary`, `description`, `severity`, `vulnerabilities` with
  ecosystem `other`). If the call fails, the row says `unverified (advisory pending)`, nothing else
  about it is written, and the error goes to the user. The promise row stays, with the verdict
  `reported privately (Fn.m, GHSA id)`. Its fix lives in the advisory, never in a public issue.
  The same one line is all that commit messages, the PR body (`## Review`, `## Evidence`) and issue
  comments may say about it; the PR's independent reviewer is told the advisory id and keeps its
  report to that line.
  What the user or their own agent can skip or get wrong is public, as `limit` or `broken`, with no
  runnable bypass steps (FR-012).
- No token-shaped string in any committed file: fake secrets are built at run time inside the
  throwaway repo (research R7).
- Each section file starts with `Reviewed at: 172f8c5 (v1.7.2)`. T006 adds a second line for its
  constitution rows: `Constitution at: <sha>`, the squash-merge commit of PR #18 on `main`
  (`gh pr view 18 --json mergeCommit -q .mergeCommit.oid`, whatever the merge method).
- Gates get the *script refuses* / *prompt asks* table (research R4).
- The common check, in every *Completed when*: quickstart step 1, and step 2 run for the task's own
  ids only (its `for i in …` loop over them instead of `seq`; `out="$(git diff --stat "$(git merge-base HEAD origin/main)" -- ':/' ':(top,exclude)specs/001-critical-points-review')" && [ -z "$out" ]` exits 0; `tests/run.sh` passes; each of its rows has an allowed verdict and evidence), and
  `bash .specify/extensions/jit/scripts/secrets.sh staged` is clean on the staged section file.

---

## Phase 1: User Story 1 - Know which promises really hold (Priority: P1) 🎯 MVP

**Goal**: every promise P01–P28 has a verdict with evidence.

**Independent Test**: `for i in $(seq -w 1 28); do grep -qh "^| P$i |" report/*.md || echo "missing P$i"; done` prints nothing once T001–T005 are merged.

- [ ] T001 [P] [US1] Review the task chain (P01–P05, P23) in specs/001-critical-points-review/report/1-task-chain.md — #19
  - Comes from: FR-001–FR-004, FR-006, FR-009, US1 scenarios 1–3; plan "Design" section 1
  - What: one issue per task and no duplicates after an interrupted run (`extension/scripts/issues.sh`); branch refused without a task, an issue, the merged spec or a clean tree, and the claim push (`branch.sh`); one PR with `Closes #N` and "done" meaning the issue closed (`pr.sh task`, `extension/scaffold/standard/.github/workflows/close-linked-issues.yml`, `next.sh`); `next` resuming, never offering a task in progress twice across worktrees, holding `depends on` tasks, and its 500-item `gh` list limits and `"$num in:title"` search matching another feature's issues; the spec PR keeping the spec folder through the branch switch (`pr.sh spec`, its `restore` trap and `--force-with-lease`); every commit or push jit makes by itself, against the documented flows (P23); the `/speckit-converge` path, whose new tasks get issues and reach the base through a spec PR (P01, P05); and `add_meta` in `lib.sh` (assignee, milestone, project only warn), whether a user can tell it never worked (FR-006)
  - Impact: reads `extension/scripts/{issues,branch,next,pr,lib}.sh`, `extension/scaffold/standard/.github/workflows/close-linked-issues.yml`, `extension/commands/issues.md`, `skills/next/SKILL.md`, `.claude/skills/speckit-converge/SKILL.md` and the tests in `tests/{issues,branch,next,pr}.test.sh`; writes only the new file `report/1-task-chain.md`
  - Completed when: the file has the table `| id | promise | verdict | evidence |` with rows `| P01 |` to `| P05 |` and `| P23 |`; the chain was also run end to end on the sandbox (a feature numbered as in Rules, from `099` down: `issues.sh`, `branch.sh`, `pr.sh task`, `next.sh`, then cleaned up) and its output is quoted; every `broken`/`limit` row has a block with rank, a reproduction that was run and its output; plus the common check (tasks.md, "Rules every task follows")

- [ ] T002 [P] [US1] Review the secret checks and the command guard (P06–P09) in specs/001-critical-points-review/report/2-secrets-guard.md — #20
  - Comes from: FR-001–FR-005, FR-012, US1 scenarios 1–2; research R3 item 1, R4, R6
  - What: what `secrets.sh` refuses at commit and in a pushed range, and how long it takes on a large diff (the "under a second" claim); Gitleaks running too when installed; `prepush.sh` on new branches, deletions, the empty-remote exception, and when it runs through the repo's pre-commit framework or husky config; the guard (`extension/scripts/guard.sh`, `hooks/guard-git.sh`): how it reads and splits commands, where its documented best effort ends, valid commands it blocks by mistake (seen in this session: a plain read of a config key; a chain that switches branch before committing, judged by the branch it starts on; commands run in a throwaway repo elsewhere, judged as if in this repo), and whether it is really the plugin's copy that runs; from the official Claude Code hooks docs, what exit 2, exit 1, a timeout and `onFailure` in `hooks/hooks.json` do; that no finding prints the secret (P09)
  - Impact: reads `extension/scripts/{secrets,prepush,guard,lib}.sh`, `hooks/`, `extension/scaffold/lite/.githooks/*`, `tests/{secrets,guard,setup}.test.sh`, `docs/security.md`, `README.md`; writes only `report/2-secrets-guard.md` (and, for an exploitable finding, a private advisory: see Rules)
  - Completed when: rows `| P06 |` to `| P09 |` exist with verdicts; each gate has the refuses/asks table with the doc wording quoted; the hooks-doc facts cite the official page or are `unverified`; no bypass written as runnable steps; plus the common check (tasks.md, "Rules every task follows")

- [ ] T003 [P] [US1] Review the review gate and tests as evidence (P10–P15, P26) in specs/001-critical-points-review/report/3-review-gate.md — #21
  - Comes from: FR-001–FR-006, US1 scenario 2–3; research R3 items 2–3, R4
  - What: what `review.sh record`/`check` proves (a report with the right last line for this patch id) against what `docs/design.md` says (a fresh, independent reader); that the plan-review state hashes `plan.md` and `tasks.md` but not `spec.md`; whether "never opens a PR on red checks" (P12) is enforced by any script or only asked in `extension/commands/pr.md`; `## Test changes` detection (`TEST_PATH_RE` in `lib.sh`, `--no-renames`) and what `mutants.sh` does when `mutate` is missing; the Copilot request in `pr.sh` `open_pr` (reviewer name against GitHub's REST docs, and that a failure is silent); on full, `## Evidence` and `analyzed.sh`; whether the pre-PR scanners on the changed files (`security-scan.sh --changed`) and `/security-review` (P26) are enforced by a script or only asked in `extension/commands/pr.md`; from spec-kit v1.2.5 docs or source, whether `optional: false` hooks run by themselves or depend on the agent following the prompt
  - Impact: reads `extension/scripts/{review,pr,mutants,analyzed,issues,lib}.sh`, `extension/commands/{review,pr,issues}.md`, `preset/commands/speckit.implement.md`, `docs/design.md`, `docs/reference.md`, `tests/{review,pr,mutants,branch}.test.sh`; writes only `report/3-review-gate.md` (and, for an exploitable finding, a private advisory: see Rules)
  - Completed when: rows `| P10 |` to `| P15 |` and `| P26 |` exist with verdicts; the Copilot request was sent on a sandbox `[001 review T003]` PR (head `review-001-t003-copilot`) with `pr.sh`'s exact call and the API's answer is quoted (`unverified` only with that answer showing the account has no Copilot); the refuses/asks table covers the task review, the plan review, red checks, test changes, the pre-PR scanners and `/security-review`; third-party facts cite their source or are `unverified`; plus the common check (tasks.md, "Rules every task follows")

- [ ] T004 [P] [US1] Review the CI gate and the supply chain (P16, P17, P25, P27, P28) in specs/001-critical-points-review/report/4-ci-supply-chain.md — #22
  - Comes from: FR-001–FR-004, FR-006; plan "Design" section 4
  - What: the workflows `level.sh` writes for standard and full (Gitleaks on full history, OSV-Scanner, zizmor, Semgrep on full, trivy with infra), each pinned by SHA and each download checked against `pins.sh`; `persist-credentials: false` and read-only permissions in every generated and scaffold workflow; `bin/sync-pins.sh` and Dependabot keeping one source of pins; that the "not skippable" claim depends on branch protection that `lite` never offers; where `/jit-speckit:security` puts its findings (P25), including its advisory call in `skills/security/SKILL.md` (verified 2026-11-05: GitHub refuses that body with 422, "missing required key: vulnerabilities", research R6) and what it does on a private repository, where the advisory API answers 404 (seen on the sandbox), and what its full audit covers before a release (P27); what `/jit-speckit:init` really offers for secret scanning with push protection and branch protection requiring CI, and that the required check names match the generated jobs (P28); private vulnerability reporting, which `SECURITY.md` relies on, was off on this repository on 2026-11-05
  - Impact: reads `extension/scripts/{level,pins,security-scan}.sh`, `bin/sync-pins.sh`, `extension/scaffold/`, `.github/`, `skills/security/SKILL.md`, `skills/init/SKILL.md`, `README.md`, `docs/security.md`, `tests/{level,security-scan,static}.test.sh`; generates the workflows into a throwaway repo only; writes only `report/4-ci-supply-chain.md` (and, for an exploitable finding, a private advisory: see Rules)
  - Completed when: rows `| P16 |`, `| P17 |`, `| P25 |`, `| P27 |`, `| P28 |` exist with verdicts; branch protection with the check names `init` would require was applied on a branch `review-001-t004-protected` made from the sandbox base (never the base itself, so T001 and T003 running in parallel are not blocked), a `[001 review T004]` PR from `review-001-t004-change` into it showed what it waits for, then the protection and the branch were removed, all output quoted; the generated workflows for standard and full were produced in a throwaway repo and the evidence quotes their pinned lines; plus the common check (tasks.md, "Rules every task follows")

- [ ] T005 [P] [US1] Review levels, setup and the user's files (P18–P22, P24) in specs/001-critical-points-review/report/5-levels-files.md — #23
  - Comes from: FR-001–FR-004; spec edge case "kept only on some platforms"; plan "Design" section 5
  - What: changing level up and down (`level.sh`) and that going down deletes nothing; the managed-file marker and "written only when missing" for unmarked files, including a user who edits a marked file without removing the line; files jit-speckit wrote before the marker existed (seen 2026-11-05 updating the sandbox from 1.3.0 to 1.7.2: `.githooks/pre-commit` and `pre-push` were "kept", so they still `exit 0` with "secret check skipped" when the script is missing, where 1.7.2's refuse; sandbox PR #10); `bin/remove.sh` deleting only what still matches; `init` keeping the level and committing nothing, and the stale-session case seen in this repo (a running session pointing at an older plugin copy whose `setup.sh` would downgrade the project); no AI attribution by default (P22); bash 3.2/BSD coverage from `.github/workflows/test.yml` (P24)
  - Impact: reads `extension/scripts/level.sh`, `bin/{setup,remove}.sh`, `skills/{init,adopt,level,remove}/SKILL.md`, `extension/scaffold/lite/.claude/settings.json`, `tests/{level,setup}.test.sh`; writes only `report/5-levels-files.md` (and, for an exploitable finding, a private advisory: see Rules)
  - Completed when: rows `| P18 |` to `| P22 |` and `| P24 |` exist with verdicts; the up-and-down level change and a `remove` after a user edit were run in a throwaway repo with their output; and the upgrade path: a throwaway repo set up with `v1.3.0`'s `bin/setup.sh` (from `git worktree add "$(mktemp -d)" v1.3.0`), then refreshed with `v1.7.2`'s, both with `--level standard` like sandbox PR #10, with every `kept:` line and the kept hooks' content pasted (if v1.3.0's setup cannot run with today's spec-kit, the sandbox PR #10 output is quoted instead, saying why); plus the common check (tasks.md, "Rules every task follows")

**Checkpoint**: every promise has a verdict.

---

## Phase 2: User Story 2 - Know whether the design fits the purpose (Priority: P2)

**Goal**: where the project departs from its own rules, what each level costs per task, and a verdict on the core model.

**Independent Test**: `report/8-context-engineering.md` has C01–C11 each with a verdict and files; `report/6-own-rules-cost.md` lists each constitution rule with followed / exception written / exception missing, and a per-level step table; `report/7-core-model.md` has D1–D3 each ending in keep, simplify or replace.

- [ ] T006 [P] [US2] Review the project against its own rules, and the cost per level, in specs/001-critical-points-review/report/6-own-rules-cost.md — #24
  - Comes from: FR-007, FR-008, US2 scenarios 1–2
  - What: each rule in `.specify/memory/constitution.md` as it stands on `main` once the 1.7.2 setup PR #18 is merged (cited at its squash-merge commit) (project principles and the jit block), plus one row on the lag itself: at `v1.7.2` the repo's own constitution and installed extension were still 1.7.1's and how this repo follows it, with evidence (the `mutate` placeholder and its replacement rule "a check seen to fail when the behavior is disabled", the bash 3.2 floor against `shellcheck` and the `bash32` job, docs-as-truth against the 1.7.2 changes); then, per level, the steps and waits one task goes through (issue, branch, checks, review rounds, scans, PR, CI, merge), and which are disproportionate for that level's audience, with a reason
  - Impact: reads `.specify/memory/constitution.md`, `extension/levels/*.md`, `extension/commands/pr.md`, `.github/workflows/test.yml`, `tests/`, `git log`; writes only `report/6-own-rules-cost.md` (and, for an exploitable finding, a private advisory: see Rules)
  - Completed when: every constitution rule has a row with followed / exception written / exception missing and evidence; the per-level table has lite, standard and full; plus the common check (tasks.md, "Rules every task follows")

- [ ] T007 [US2] Weigh the core model (D1 task = PR, D2 spec PR, D3 levels) in specs/001-critical-points-review/report/7-core-model.md (depends on T006) — #25
  - Comes from: FR-008a, SC-003a, clarification 2026-11-05; data-model "Design verdict"
  - What: for each of D1–D3, the problem it solves, its cost per task (cited from the per-level table in `report/6-own-rules-cost.md`, not measured again), each source `docs/design.md` cites and whether that source supports the claim as written (open it), the simplest model that keeps the same promises, and the verdict keep / simplify / replace with its reason
  - Impact: reads `docs/design.md`, `README.md`, `examples/`, `extension/levels/*.md`, `report/6-own-rules-cost.md`; writes only `report/7-core-model.md` (and, for an exploitable finding, a private advisory: see Rules)
  - Completed when: D1, D2 and D3 each have the five fields and end in `keep`, `simplify` or `replace`; every cited source is marked supports / partly / does not support, or `unverified` if it could not be opened; plus the common check (tasks.md, "Rules every task follows")

- [ ] T009 [P] [US2] Review every shipped prompt against the context-engineering guidance (C1–C11) in specs/001-critical-points-review/report/8-context-engineering.md — #26
  - Comes from: FR-014, SC-003b, US2 scenario 3, research R8, clarification 2026-11-05
  - What: for each principle C1–C11 in research R8, a verdict per file group with `file:line` evidence: rigid rules where a goal would do and whether each kept rule has its reason next to it (C1, C7); instructions that conflict across files (C2); examples where an interface or script would do (C3); what each command loads before doing any work, in lines and words, and whether that detail could load later (C4: `/jit-speckit:new` reads `GUIDELINES.md`, `GUARDRAILS.md` and `references.yaml` first); the same instruction repeated in several files (C5); what in the constitution template or `copilot-instructions.md` the model could see in the repo (C6); skill length and split (C7); prose where a test or rubric would carry the rule (C8); each subagent launch and what it hands back (C9, `extension/commands/review.md`); C10 and C11 as research R8 says (`/doctor` output pasted in if the user runs it, else `unverified`). Each `departs` says what the prompt would look like following the principle.
  - Impact: reads `skills/*/SKILL.md`, `extension/commands/*.md`, `preset/commands/*.md`, `extension/levels/*.md`, `preset/templates/*.md`, `extension/scaffold/lite/.github/{copilot-instructions,pull_request_template}.md`, `docs/GUIDELINES.md`, `docs/GUARDRAILS.md`, `docs/references.yaml`; writes only `report/8-context-engineering.md` (and, for an exploitable finding, a private advisory: see Rules); its findings also feed `specs/002-faster-review` (the review prompt)
  - Completed when: rows `| C01 |` to `| C11 |` exist with a verdict from the contract and files named; a table of words loaded per command exists; every `departs` names the change it suggests; quickstart step 7 passes; every shipped prompt file is named in the section: `for f in skills/*/SKILL.md extension/commands/*.md preset/commands/*.md preset/templates/*.md extension/levels/*.md extension/scaffold/lite/.github/copilot-instructions.md extension/scaffold/lite/.github/pull_request_template.md docs/GUIDELINES.md docs/GUARDRAILS.md docs/references.yaml; do grep -qF "$f" report/8-context-engineering.md || echo "missing $f"; done` (run from the v1.7.2 worktree, the report path absolute) prints nothing; plus the common check (tasks.md, "Rules every task follows")

---

## Phase 3: User Story 3 - Turn the findings into work (Priority: P3)

**Goal**: one ranked page and a fix per High/Medium finding.

**Independent Test**: every High and Medium finding in `report/` appears once in `report.md` *Fixes* with a "when …, then …" check.

- [ ] T008 [US3] Write the ranked summary, the fix list and the unverified list in specs/001-critical-points-review/report.md (depends on T001, T002, T003, T004, T005, T006, T007, T009) — #27
  - Comes from: FR-009, FR-010, SC-001–SC-005, US3 scenarios 1–2; quickstart steps 1–7
  - What: a summary table of every finding ranked High → Low with its promise and section link (a `reported privately` finding appears with its id, rank and promise only); under *Fixes*, one entry per public High/Medium: the change, the promise it restores, and a check written as "when …, then …" that names the `tests/<script>.test.sh` it belongs in; a `limit` whose doc is honest gets no fix, only a note; *Unverified* gathers every unverified claim from the sections and what would check it; private findings get no fix entry here, their fix is in the advisory
  - Impact: reads `report/*.md` (sections 1–8); writes only `report.md`
  - Completed when: every quickstart step 1–7 passes as written in [quickstart.md](quickstart.md); `diff <(grep -hoE '^### F[0-9.]+ · (High|Medium) · ' report/*.md | grep -oE 'F[0-9.]+' | sort -u) <(grep -oE '^### Fix F[0-9.]+' report.md | grep -oE 'F[0-9.]+' | sort)` prints nothing (every public High and Medium has exactly one fix entry), and `diff <(grep -hoE 'reported privately \([^)]*\)' report/*.md | grep -oE 'GHSA-[a-z0-9-]+' | sort -u) <(gh api --paginate repos/iamalisson/jit-speckit/security-advisories --jq '.[] | select(.summary | startswith("[001 ")) | .ghsa_id' | sort -u)` prints nothing (the private findings and the advisories are the same set, whatever their state); plus the common check (tasks.md, "Rules every task follows")

---

## Dependencies & Execution Order

- T001–T006 and T009 are independent: different files, nothing shared. Any order, or in parallel worktrees.
- T007 needs T006 merged (it cites the per-level cost table).
- T008 needs T001–T007 and T009 merged.
- **Before any task**: the setup PR `chore/jit-speckit-1.7.2` (#18) is merged, so `main` and every
  task branch run the 1.7.2 scripts this review describes; then the spec PR is merged.
- MVP: T001–T005 (User Story 1) already answers "which promises hold".

### Parallel example

```text
worktree 1: /jit-speckit:next   → T001
worktree 2: /jit-speckit:next   → T002
worktree 3: /jit-speckit:next   → T003
...
```

---

## Phase 4: Convergence

- [ ] T010 Reproduce F4.3 with a fresh agent, or move it to unverified, per FR-003 (contradicts) in specs/001-critical-points-review/report/4-ci-supply-chain.md, report/3-review-gate.md, report/6-own-rules-cost.md and report.md — #38
  - Comes from: FR-003, spec edge case "A finding that cannot be reproduced: reported as unverified, never as broken", data-model "Transitions"; `/speckit-converge` on 2026-11-05
  - What: F4.3 ("the PR prompt copies a security finding from the review into the public PR body") is `broken`, but its evidence says it was found by reading `extension/commands/pr.md:54-56` and `review.md:78-79` and "was not run through an agent"; `report.md` also lists it under *Unverified*. Run it as the real path produces it, with no repository and no GitHub writes (the behavior under test is the agent's text): two review reports in `review.md`'s report shape, saved outside the repository: round 1 with *What changed*, one High security finding with a harmless made-up description carrying a distinctive token (a fake `file:line` such as `src/probe_t010.py:42` and one scenario sentence) and `Assessment: changes needed`; round 2 with no findings and `Assessment: ready`. Then **a fresh general-purpose subagent** gets, in its prompt, the whole `v1.7.2:extension/commands/pr.md`, both reports, a made-up fix-commit SHA, the absolute path of a body file under `mktemp -d` (outside every repository), and one instruction: there is no repository to work in; read no file and run nothing; only write the step 5 PR body to that path. Nothing about F4.3 or this repository's constitution is said. `git status --porcelain` of this checkout is the same before and after, or the run is void. Only the body file is used, and it is quoted. Three outcomes:
    - the body describes the finding beyond one line (its subject, file or scenario, in any wording; the token is the quick check): F4.3 stays `broken` (Medium), its evidence quotes the body, its **reproduction** becomes this run (the prompt given, the two reports, the body that came back), and its *Unverified* row in `report.md` goes;
    - the body has only a `Security: …` line, a count, or no finding: F4.3 becomes `unverified` (one run of a prompt-dependent behavior), the body quoted, and its *Unverified* row says one run was made and what it returned;
    - the run cannot be made: F4.3 becomes `unverified`, with why.
    When it becomes `unverified`, its block keeps its evidence under the heading `### F4.3 · unverified · P25 · …` (no rank, data-model "rank"), and `contracts/report-format.md` gets one line allowing that unranked heading for an `unverified` finding; its row leaves the Summary table (it stays under *Unverified*) and the counts sentence becomes 35 findings, 18 Medium; `### Fix F4.3` is removed and its marker rule (`Security: reported privately (<id>)` in `review.md`, one line in `pr.md` step 5) moves into Fix F3.1's change, which already relies on it, and Fix F3.1's "(and P25, with Fix F4.3)" becomes "(and P25)"; section 3's statements of the same behavior as fact (`report/3-review-gate.md:32-35` and `:68-74`) say "by reading; see F4.3 (unverified)". P25 stays `broken` through F4.2 either way
  - Impact: writes `report/4-ci-supply-chain.md` (F4.3's block, P25's row evidence), and only in the `unverified` outcome `report/3-review-gate.md:32-35,68-74`, `report/6-own-rules-cost.md:14` (its "P25 (F4.2, F4.3)"), `contracts/report-format.md` (the one heading line); and `report.md` (F4.3's summary row, the counts sentence "36 findings: 3 High (one private), 19 Medium, 14 Low", Fix F3.1, Fix F4.3, the *Unverified* row); nothing on GitHub
  - Completed when: the subagent's body is quoted in F4.3's block (or why no run was possible); F4.3 matches one of the three outcomes above; `grep -c 'Fix F4.3' report.md` is 0 when F4.3 is `unverified`; T008's two `diff` checks print nothing; the counts sentence matches `grep -hoE '^### F[0-9.]+ · (High|Medium|Low) ' report/*.md | awk '{print $4}' | sort | uniq -c` plus one High per distinct `reported privately (F…` id (`grep -hoE 'reported privately \(F[0-9.]+' report/*.md | sort -u | wc -l`), and the Summary table has that many rows; plus the common check (tasks.md, "Rules every task follows")

- [ ] T011 Rank F2.4 and F5.5 again against FR-009, with a fix for each one that becomes Medium, per FR-009, FR-010 (partial) in specs/001-critical-points-review/report/2-secrets-guard.md, report/5-levels-files.md and report.md (depends on T010) — #39
  - Comes from: FR-009 (Medium: "a promise kept but a user could be misled about it"), FR-010, data-model "rank" (only a `limit` the docs describe honestly is always Low); `/speckit-converge` on 2026-11-05
  - What: F2.4 is Low, but `README.md:44` and the constitution's "Stack" say the plugin needs Claude Code 2.1.275 while the hooks reference says `onFailure` needs 2.1.295 (section 6 marks that rule `exception missing`). F5.5 is Low while `README.md:67` says `init` "commits nothing" and its step 7 offers to commit. For each, either rank it Medium (verdict `limit (the docs mislead)`) and add `### Fix Fn.m` to `report.md` with the change, the promise and a "when …, then …" check naming its `tests/<script>.test.sh`, or write in its block why the docs do not mislead and it stays Low. F2.4's block gets the **reproduction** "read `README.md:44`, the constitution's \"Stack\" and the hooks reference's `onFailure` line" whichever rank it ends at (data-model: required for every `limit`). A Medium F2.4 rests on the two documented version numbers, not on a run: its *Unverified* row in `report.md` ("rests on the hooks reference") stays
  - Impact: writes only `report/2-secrets-guard.md` (F2.4), `report/5-levels-files.md` (F5.5) and `report.md` (their summary rows, the counts sentence, *Fixes*)
  - Completed when: F2.4 and F5.5 each are Medium with a Fix entry, or Low with the reason written in their block; F2.4's *Unverified* row is still in `report.md`; the counts sentence and the Summary row count match the commands in T010's *Completed when*; T008's two `diff` checks print nothing; plus the common check (tasks.md, "Rules every task follows")
