---
description: "Tasks for the review fixes and release 1.8.0"
---

# Tasks: Fix what the critical-points review found (release 1.8.0)

**Input**: Design documents from `specs/002-review-fixes/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/output-lines.md](contracts/output-lines.md), [contracts/checks.md](contracts/checks.md), [quickstart.md](quickstart.md)

**Tests**: every task ships its checks in the same PR, from [contracts/checks.md](contracts/checks.md).

**Organization**: one phase per user story; one task per area of the code, each covering several
fixes (user, 2026-11-05: 9 tasks instead of 25). Each task lists its fixes as parts; each part keeps
its own *What*, *Impact* and *Completed when*. Shared helpers are added by the first task that needs
them.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependencies)
- `(depends on T00n)`: needs that task merged first (same lines of a shared file, or a helper it adds)
- One task = one issue = one branch = one pull request; ` — #N` is appended automatically.

## Rules every task follows

- **Before any task**: the constitution PR #45 (1.0.1) and the 001 entry corrections PR are merged,
  then this spec PR.
- **Where they differ, `tasks.md` wins**, then [research.md](research.md), then the 001 entry: the
  tasks carry what the plan reviews corrected after the entries were written (for example T003
  copies no findings, T002 logs per branch, T005 matches the full open title).
- **The fix entry is the source of the problem.** Each task builds its entry in
  `specs/001-critical-points-review/report.md` *Fixes* (as corrected, research C1) with the design in
  [research.md](research.md) (R1–R9, U1–U3). The lines it prints are the ones in
  [contracts/output-lines.md](contracts/output-lines.md), exactly.
- **Seen failing first** (FR-022): run each "fails first" check of
  [contracts/checks.md](contracts/checks.md) on the unchanged code and paste the FAIL line into
  `## Evidence` as "seen failing before the change: <label>", then the passing run. Guard halves are
  listed apart and never presented as failing-first.
- **Docs in the same PR** (FR-023): the docs that describe the changed behavior (`README.md`,
  `docs/*.md`, the command prompts), except the constitution (changed in #45).
- **bash 3.2**: no `sort -V`, `mapfile`, associative arrays or `${x,,}`; `tests/run.sh` passes and
  the `bash32` job is green.
- **Fake `gh`** (`tests/helpers.sh` `fake_gh`): new cases are added beside the existing ones; the
  `issue list` case stays. A task that adds one names it in *Impact*.
- **Offline tests**: a test that runs `security-scan.sh` uses a `PATH` with no scanners on it.
- **Nothing private** (FR-024): F2.1 only by id; F2.3's tests build prefixes at run time; no PR body
  lists a bypass form.
- **Shared blocks** (`tests/static.test.sh` checks, `fake_gh` cases in `tests/helpers.sh`, helpers
  in `lib.sh`): each task inserts at its own place, not at the end: static checks under a `# Fxx`
  comment, `fake_gh` cases in alphabetical order by their `case` pattern, and `lib.sh` functions next
  to a named neighbor: `branch_feature` just before `feature_dir`, `diff_id` and `diff_record` just
  after `base_ref`, `version_newer` and `test_path_re` just after `constitution_cmd`. Parallel tasks
  then rebase without overlapping hunks.
- **Every PR body names the fix ids it delivers** (for example `Fixes: F3.3, F3.4`), so quickstart
  step 2 and the release notes can find them.
- **Review loop for this feature** (user, 2026-11-05): each PR fixes every High and Medium finding
  and lists Lows with a reason; at most 2 review rounds, the second on the fix commit only (a
  delta review).
- The common check, in every *Completed when*: `tests/run.sh` passes; `bash
  .specify/extensions/jit/scripts/secrets.sh staged` is clean on the staged files; the PR's
  `## Evidence` has the seen-failing lines (T008 and T009 have no failing-first check: their
  evidence is the run itself and the version check).

---

## Phase 1: User Story 1 - Nothing of mine disappears without a word (Priority: P1) 🎯 MVP

**Goal**: remove, refresh and setup never lose an edit, a newer pin or a newer version silently.

**Independent Test**: FR-001 to FR-004 in [contracts/checks.md](contracts/checks.md) pass.

- [ ] T001 [P] [US1] Keep everything of the user's on remove, refresh and setup, in bin/remove.sh, extension/scripts/level.sh and bin/setup.sh — #47
  - Comes from: FR-001–FR-004; F5.2 (High), F5.4 (High), F5.3, F4.7; US1
  - Impact: the union of the parts' *Impact* below; build the parts in the order listed (each
    later part edits lines the earlier one left), one commit per part, so a revert of one part stays
    possible
  - Completed when: every part's *Completed when* below holds; plus the common check
  - **Part a**: Keep a managed file that changed since jit wrote it, on remove, in bin/remove.sh and extension/scripts/level.sh
    - Comes from: FR-001, F5.2 (High), US1 scenario 1; research R9 F5.2; data-model "Written-file record"
    - What: `put()` writes `<sha256> <path>` for each file it writes to `.specify/jit-files.sha256`
      (replacing that path's line); `remove.sh` deletes a marked file only when its SHA-256 matches its
      line, or with no line only when tracked and `git diff --quiet HEAD`; else `kept (edited): <file>`.
      `remove.sh` also deletes `.specify/jit-files.sha256` last
    - Impact: `level.sh` `put()` (`:123-127`), `bin/remove.sh` `ours()` and its loop (`:39-51`),
      `lib.sh` `sha256()` (reused), `skills/remove/SKILL.md` and `docs/reference.md` "Uninstall"
      (say what is kept), `tests/setup.test.sh` (its remove scenario must still remove unchanged files
      and its `! git status | grep -qi jit` check must still hold), `tests/level.test.sh` (the record is
      written), a new `tests/remove.test.sh` (one test file per script; it runs on every CI job with a
      stub `specify` on `PATH`, since `remove.sh:29` only checks that `specify` exists, so the record
      reading and `shasum -a 256` run on bash 3.2 and BSD too; `setup.test.sh` skips without
      `specify`)
    - Completed when: FR-001's row of contracts/checks.md passes in `tests/remove.test.sh`, on the
      `bash32` and macOS jobs as well (the macOS job via `gh workflow run test.yml --ref <branch>`
      until T007 part a moves it): a managed workflow committed alone
      then edited is kept with `kept (edited)`; an untracked managed file whose content differs from
      its record is kept; an unchanged one is removed; plus the common check
  - **Part b**: Keep newer pins and recognize old releases' files on refresh, in extension/scripts/level.sh
    - Comes from: FR-003, FR-004, F5.3, F4.7, US1 scenarios 3–4; research R8 F4.7, F5.3; data-model "Old-file manifest", "Version"
    - What: `version_newer` in `lib.sh`; `put()`'s `keep_pins` keeps an old `uses: <action>@<sha> #
      <version>` line newer than `pins.sh`'s and prints `kept newer pin: <action> <version>`; the new
      data file `extension/scripts/old-files.sha256` (the six lines in research R8) makes `put()`
      replace the two old hooks and name the old workflows and, after an old hook matched, the
      generated files, with the lines in contracts/output-lines.md
    - Impact: `level.sh` `put()` (after T001 part a's record), `lib.sh` (new `version_newer`),
      `extension/scripts/old-files.sha256` (new), `tests/fixtures/` (new: v1.3.0's `.githooks/pre-commit`
      and v1.3.1's `close-linked-issues.yml`, copied from `git show`), `tests/level.test.sh`,
      `docs/design.md` "Nothing of yours is overwritten" (newer pins kept; a `container.image` digest is
      not), `bin/remove.sh` (an `old-files` match is not "ours" for removal: unchanged)
    - Completed when: FR-003 and FR-004 rows of contracts/checks.md pass, including `version_newer`
      cases `v1.10.0 > v1.9.9`, `v7.0.1` not newer than `v7.1.0`, `v2` = `v2.0.0`, `master` never
      newer; plus the common check
  - **Part c**: Refuse to take a project to an older jit-speckit version, in bin/setup.sh
    - Comes from: FR-002, F5.4 (High), US1 scenario 2, edge case "a plugin copy at 1.8.0 or later run on a project at a newer version"; research R9 F5.4
    - What: `setup.sh` sources `lib.sh` for `version_newer`, reads the project's and the plugin's
      `version:` from `extension.yml` (the indented `version:` line, not `schema_version` or
      `speckit_version`), and refuses without `--downgrade` with the line in contracts/output-lines.md;
      the usage line names `--downgrade`
    - Impact: `bin/setup.sh` (usage at `:3`, before `specify extension add` at `:50`), `skills/init/SKILL.md`
      (show the refusal as is; suggest `/reload-plugins`), `docs/reference.md` "Update" (says the refusal works from 1.8.0 on: an older copy's own `setup.sh` has no check, so `/reload-plugins` first),
      `tests/setup.test.sh` (the new check sits before the file's `specify` skip and uses a stub
      `specify` on `PATH`, since the refusal comes before `setup.sh:50` and `:35` only checks the
      command exists, so it runs on the `bash32` and macOS jobs; macOS via `gh workflow run` until T007
      part a)
    - Completed when: FR-002's refusal half passes on every CI job (stub `specify`, and the stub run
      with `--downgrade` is not refused with the downgrade line); its success halves (`--downgrade`
      sets up, a fresh project sets up) pass after the file's `specify` skip, on Linux where `specify`
      is installed; a fresh project (no `extension.yml`) still sets up; plus the
      common check

## Phase 2: User Story 2 - Every gate does what the docs say it does (Priority: P1)

**Goal**: the gates the docs present as refusing are refused by a script; the guard covers its documented scope.

**Independent Test**: FR-005 to FR-011 and FR-029 in [contracts/checks.md](contracts/checks.md) pass.

- [ ] T002 [P] [US2] Make the task PR refuse what the docs say it refuses, in extension/scripts/pr.sh — #48
  - Comes from: FR-005–FR-007; F3.3, F3.4, F3.6, F3.9; US2 scenarios 1–3
  - Impact: the union of the parts' *Impact* below; build the parts in the order listed (each
    later part edits lines the earlier one left), one commit per part, so a revert of one part stays
    possible
  - Completed when: every part's *Completed when* below holds; plus the common check
  - **Part a**: Run the project's test command before opening a task PR, in extension/scripts/pr.sh
    - Comes from: FR-005, F3.3, US2 scenario 1; research R9 F3.3
    - What: in `pr.sh task`, after the cheap refusals and before the push, run `constitution_cmd test`
      (logged to `<git-common-dir>/jit-test/${branch//\//__}.log`, one per branch (the `/` flattened as
    `review.sh` does), so parallel worktrees never
      share a log); on failure its last 20 lines then the refusal in
      contracts/output-lines.md; with no test command the warning line and go on
    - Impact: `pr.sh` task block (`:45-71`), `lib.sh` `constitution_cmd` (placeholder `[NAME]` = unset,
      unchanged), `extension/commands/pr.md` step 2 and `:11` "Never open a PR on red checks" (the
      script now runs the tests; the only place that wording is), `docs/reference.md` "What happens
      automatically" (add the test run), `tests/pr.test.sh` (existing PR opens: their constitution has no
      test command, or one that passes)
    - Completed when: FR-005's row passes, with nothing pushed on failure (`git ls-remote` unchanged);
      plus the common check
  - **Part b**: Record the mutation result per diff and require it on the task PR, in extension/scripts/mutants.sh and pr.sh
    - Comes from: FR-006, F3.4, US2 scenario 2; research R9 shared helpers and F3.4; data-model "Diff record"
    - What: `lib.sh` gets `diff_id()` (moved from `review.sh` `state()`, `:25-30`) and `diff_record DIR`;
      `review.sh` task state calls `diff_id`; `pr.md` moves the `mutants.sh` run to after the last
      commit (after the review fix rounds), as T002 part c does for the scan; `mutants.sh` writes its result line to
      `diff_record jit-mutants`; `pr.sh task` refuses as in contracts/output-lines.md when a mutate
      command is set; with none it adds "Mutation testing: not run (no mutate command in the
      constitution)" to the body
    - Impact: `lib.sh` (new helpers), `review.sh` (`state()`, existing records must still match:
      `tests/review.test.sh` unchanged and passing), `mutants.sh` `finish()`, `pr.sh` task block,
      `extension/commands/pr.md` step 2, `docs/reference.md` (mutation testing is now required when
      configured), `tests/pr.test.sh`
    - Completed when: FR-006's mutation row passes (refused without a record, accepted after
      `mutants.sh`, refused again after a new commit); `tests/review.test.sh` passes unchanged; plus
      the common check
  - **Part c**: Record the pre-PR scan per diff and require it on the task PR, in extension/scripts/security-scan.sh and pr.sh
    - Comes from: FR-006, F3.6, US2 scenario 2; research R9 F3.6
    - What: `security-scan.sh --changed` copies its summary lines to `diff_record jit-security` on both
      exits; `pr.sh task` refuses without one (contracts/output-lines.md); `missing` and findings do not
      refuse
    - Impact: `security-scan.sh` `report()` and its two exits, `pr.sh` task block,
      `extension/commands/pr.md` step 4 (run it after the last commit; the script now checks),
      `README.md:108` and `docs/security.md:30` ("before each PR": now enforced), `tests/pr.test.sh`
      (a `scanned()` helper next to `reviewed()`, run with a `PATH` holding no scanners; every existing
      PR open records a scan: list under `## Test changes`), `tests/security-scan.test.sh`
    - Completed when: FR-006's scan row passes; the suite makes no network call (no scanner on
      `PATH`); plus the common check
  - **Part d**: Recognize common test layouts in the test-change rule, in extension/scripts/lib.sh
    - Comes from: FR-007, F3.9, US2 scenario 3; research R9 F3.9
    - What: `TEST_PATH_RE` becomes 001 F3.9's pattern; `test_path_re()` adds the constitution's
      `tests: <regex>` line and dies on an invalid one; `pr.sh` and `mutants.sh` read it once in a
      plain assignment (`re="$(test_path_re)" || exit 1`) before using it at `pr.sh:62` and
      `mutants.sh:24`, since `mutants.sh` runs without `set -e` and a `die` inside `$(…)` only ends the
      subshell (an empty pattern would drop every file and record `skipped`)
    - Impact: `lib.sh:57`, `pr.sh:62`, `mutants.sh:24`, `docs/reference.md:89` (which layouts count, and
      the `tests:` line), `preset/templates/constitution-template.md` (mention the optional `tests:`
      line), `tests/pr.test.sh`, `tests/mutants.test.sh` (the invalid-regex refusal)
    - Completed when: FR-007's row passes for each of the 9 test paths and 13 source paths in 001 F3.9;
      an invalid `tests:` regex makes both `pr.sh task` and `mutants.sh` refuse (exit non-zero, no
      `skipped` record); plus the common check

- [ ] T003 [US2] Put the recorded review in the PR and report what really happened, in extension/scripts/pr.sh and review.sh (depends on T002, T005) — #49
  - Comes from: FR-009, FR-015, FR-016, FR-029; F3.1, F4.3, F3.7, F3.5, F1.8; US2 scenario 5, US3 scenarios 4–5
  - Impact: the union of the parts' *Impact* below; build the parts in the order listed (each
    later part edits lines the earlier one left), one commit per part, so a revert of one part stays
    possible
  - Completed when: every part's *Completed when* below holds; plus the common check
  - **Part a**: Put the recorded review in the PR body, with security findings as one line, in extension/scripts/review.sh and pr.sh
    - Comes from: FR-009, F3.1, F4.3, US2 scenario 5, edge case "a security finding … on a private repository"; research R9 F3.1+F4.3
    - What: `review.sh report` prints only facts from the record, never reviewer prose (user,
      2026-11-06: filtering findings out of prose by wording cannot be made leak-proof):
      `Independent review recorded for this diff (patch id <12 chars>)` and its `Assessment:` line;
      `pr.sh task` adds them to the body in
      `<details><summary>Independent review</summary>`. Findings are never copied by the script (a
      report that put a security finding's detail anywhere would otherwise go public): they reach the
      PR only through the agent's `## Review`, where `review.md`'s Report section and `pr.md` step 5
      say a security finding is one `Security: reported privately (<id>)` line; `docs/design.md` says
      what the gate proves
    - Impact: `review.sh` (new action), `pr.sh` task block, `extension/commands/review.md` Report,
      `extension/commands/pr.md` step 5, `docs/design.md` "The review is independent" (`:35`),
      `tests/pr.test.sh`,
      `tests/review.test.sh`, `tests/static.test.sh` (`# F3.1/F4.3`)
    - Completed when: FR-009's row passes (the patch-id line and `Assessment:` in the body, nothing
      from the report's text;
      a recorded finding's text, security or not, never copied by the script, even when the report
      puts detail before or without the marker; both prompts say one line); plus the common check
  - **Part b**: Name the right record command in the missing-review hint, in extension/scripts/review.sh
    - Comes from: FR-029, F3.7; research R9 F3.7
    - What: `review.sh:45` builds the hint with `$($plan && echo ' --plan')`
    - Impact: `review.sh:45`, `tests/review.test.sh`
    - Completed when: FR-029's row passes (task hint has no `--plan`; plan hint keeps it); plus the
      common check
  - **Part c**: Print the Copilot line from GitHub's answer, in extension/scripts/pr.sh
    - Comes from: FR-016, F3.5, US3 scenario 5; research R2
    - What: `open_pr` reads `--jq '.requested_reviewers[].login'`; a case-insensitive `copilot` →
      `copilot: code review requested`, else `copilot: not requested (GitHub did not add the
      reviewer)`; the stale 422 comment (`pr.sh:26-27`) goes
    - Impact: `pr.sh` `open_pr` (`:25-31`), fake `gh` (an `api -X` case printing `$GH_REVIEWERS`),
      `README.md`, `docs/design.md` and `docs/reference.md:87` ("Copilot code review requested",
      now only when GitHub lists it) where they describe the Copilot request, `tests/pr.test.sh`
      (the request assertion at `:30-31` anchors the whole logged line, so adding `--jq` changes it:
      update it to the new call and list it under `## Test changes`)
    - Completed when: FR-016's row passes, both halves; plus the common check
  - **Part d**: Stop the spec PR when it cannot ask whether one is open, in extension/scripts/pr.sh
    - Comes from: FR-015, F1.8, US3 scenario 4; research R9 F1.8
    - What: `pr.sh:79` drops `2>/dev/null || true` and dies with `could not check for an open spec PR`
      after gh's error, before the trap and the switch
    - Impact: `pr.sh` spec (`:79`), fake `gh` (`GH_FAIL_PR_LIST`), `tests/pr.test.sh` (a second clone
      pushes to `spec/<feature>`; the local clone fetches before the run)
    - Completed when: FR-015's row passes with the fetch (without it the check proves nothing); plus the
      common check

- [ ] T004 [P] [US2] Close the guard, analysis and version gaps, in extension/scripts/guard.sh, analyzed.sh and the docs — #50
  - Comes from: FR-008, FR-010, FR-011; F3.8, F2.3, F2.4; US2 scenarios 4, 6, 7
  - Impact: the union of the parts' *Impact* below; build the parts in the order listed (each
    later part edits lines the earlier one left), one commit per part, so a revert of one part stays
    possible
  - Completed when: every part's *Completed when* below holds; plus the common check
  - **Part a**: Require the analysis report before the analysis marker, on full, in extension/scripts/analyzed.sh
    - Comes from: FR-008, F3.8, US2 scenario 4; research R9 F3.8
    - What: `analyzed.sh <report-file>` refuses without a file or without both headings
      (contracts/output-lines.md), writes the marker as today and keeps the report next to it
    - Impact: `analyzed.sh`, `extension/commands/analyzed.md` (save the report to a `mktemp` file and
      pass it), `README.md:126` and `docs/reference.md` (full's analysis requirement),
      `tests/branch.test.sh` (`:63-71` pass a fixture report: list under `## Test changes`)
    - Completed when: FR-008's row passes; `branch.sh` on full still refuses until a real report is
      recorded; plus the common check
  - **Part b**: Refuse abbreviated --no-verify and commits after a switch in the same chain, in extension/scripts/guard.sh
    - Comes from: FR-010, F2.3, US2 scenario 6; research R5
    - What: `no_verify()` (a prefix of `--no-verify`, at least 3 characters) for commit, push, merge,
      rebase and am; `am -n` refused like `commit -n`; a growing list of branches the chain may be on,
      fed by `switch|checkout` (creating forms add the new branch; `checkout -- <path>` and
      `checkout <tree-ish> -- <paths>` add nothing; unknown words add the name)
    - Impact: `guard.sh` (`:20`, `:88`, `:94-95`, `:100`, `:111`, `:121`, `:126`, `:130`),
      `tests/guard.test.sh` (before `:63`), `docs/security.md:28` (unchanged wording, now true; the
      untracked branch-changing commands stay "best effort")
    - Completed when: FR-010's row passes, prefixes built at run time (no literal list in the test);
      `git <cmd> -h` agrees on which subcommands take `--no-verify`; plus the common check
  - **Part c**: Give 2.1.295 as the plugin's minimum Claude Code version in the docs, in README.md and docs/security.md
    - Comes from: FR-011, F2.4, US2 scenario 7; research R7 F2.4, U3
    - What: `README.md:44` becomes "Needs Claude Code 2.1.295 or newer: from that version the command
      guard blocks a command when it times out or crashes" (the two-prompt fallback goes);
      `docs/security.md:28` adds "on Claude Code 2.1.295 or newer it also blocks when the guard times
      out or crashes"
    - Impact: `README.md:44`, `docs/security.md:28`, `tests/static.test.sh` (`# F2.4`); the constitution
      already says 2.1.295 (#45)
    - Completed when: FR-011's row passes (every "Claude Code X or newer/later" in `README.md`,
      `docs/*.md` and the constitution ≥ 2.1.295, at least one; no "older versions" in the README);
      plus the common check

## Phase 3: User Story 3 - The task chain never fails silently (Priority: P2)

**Goal**: claims, closes, lookups, issue creation and the Copilot line report what really happened.

**Independent Test**: FR-012 to FR-016, FR-026 and FR-028 in [contracts/checks.md](contracts/checks.md) pass.

- [ ] T005 [US3] Make the task chain report every failure and decide done by issue number, in extension/scripts/branch.sh, next.sh and issues.sh (depends on T004) — #51
  - Comes from: FR-012–FR-014, FR-026, FR-028; F1.1, F1.2, F1.9, F1.6, F1.7; US3 scenarios 1–3, 6
  - Impact: the union of the parts' *Impact* below; build the parts in the order listed (each
    later part edits lines the earlier one left), one commit per part, so a revert of one part stays
    possible
  - Completed when: every part's *Completed when* below holds; plus the common check
  - **Part a**: Warn when the claim push is refused, in extension/scripts/branch.sh
    - Comes from: FR-012, F1.1, US3 scenario 1; research R9 F1.1
    - What: `branch.sh:56` captures the push error and prints the warning line in
      contracts/output-lines.md to stderr; exit 0 stays
    - Impact: `branch.sh:56`, `docs/reference.md:73-74` (a failed claim is reported), `tests/branch.test.sh`
      (an origin `pre-receive` hook that refuses, removed afterwards)
    - Completed when: FR-012's row passes; plus the common check
  - **Part b**: Decide each task's state by issue number, and serve the task branch's feature, in extension/scripts/next.sh
    - Comes from: FR-013, FR-028, F1.2, F1.9, US3 scenario 2; research R1
    - What: one `gh api graphql` call per feature for the issue numbers in `tasks.md` (no call when none);
      a failed call dies with the line in contracts/output-lines.md; `lib.sh` `branch_feature()` (moved
      out of `feature_dir`) serves the task branch's feature with no argument; an argument still wins
    - Impact: `next.sh` `scan()` (`:31`) and the no-argument block (`:62-77`), header comment
      (`:10-11`), `lib.sh` `feature_dir` (`:97-110`, behavior unchanged for branch.sh, pr.sh, issues.sh,
      analyzed.sh, review.sh), fake `gh` (new `api graphql` case answering only asked numbers from
      `$GH_CLOSED`, and `GH_FAIL_GRAPHQL`), `skills/next/SKILL.md:13`, `docs/reference.md:66-68`,
      `tests/next.test.sh`
    - Completed when: FR-013 and FR-028 rows pass; `tests/branch.test.sh` and `tests/pr.test.sh` pass
      unchanged; one sandbox run (`iamalisson/jit-speckit-sandbox`, a renamed closed task issue, guarded
      as in 001's tasks.md Rules) shows it `done`, output quoted in `## Evidence`; plus the common check
  - **Part c**: Close every linked issue and fail the job if one could not be closed, in extension/scaffold/standard/.github/workflows/close-linked-issues.yml
    - Comes from: FR-014, F1.6, US3 scenario 3; research R9 F1.6
    - What: `failed+=" #$n"` instead of `|| true`, then `could not close: …` and exit 1
    - Impact: the scaffold workflow (`:26`), every project's copy is refreshed by `level.sh` while its
      marker stays, `tests/static.test.sh` (`# F1.6`: runs the step's `run:` block with `bash -e` and a
      fake `gh` failing on 12)
    - Completed when: FR-014's row passes (non-zero exit fails first; `issue close 3` still called is the
      guard); plus the common check
  - **Part d**: Reuse a task's issue that GitHub created but never confirmed, in extension/scripts/issues.sh
    - Comes from: FR-026, F1.7, US3 scenario 6; research R9 F1.7
    - What: once before the loop, `gh issue list --state open --limit 1000 --json number,title` (no
      `--search`, no `--label`); a task whose **full title**, exactly as `issues.sh:35-36` builds it
      (`[NNN] Tnnn: <summary>`), exists and is **open** gets that number written back (`<Tnnn> → #<n>
      (existing)`); a closed issue or one with another summary never matches, so a regenerated
      `tasks.md` gets new issues as today; a failed lookup dies; a `shortcut:` comment on the 1000
      limit
    - Impact: `issues.sh` (`:32-56`), `extension/commands/issues.md:8-9`, fake `gh` (`GH_FAIL_CREATE_ONCE`;
      the `issue list` case answers from `$GH_CLOSED`), `tests/issues.test.sh` (existing checks at
      `:37` and `:57` unchanged)
    - Completed when: FR-026's row passes; and when an issue with the same `[NNN] Tnnn:` prefix but
      another summary, or the same title but closed, exists, then a new issue is created (the
      regenerated-`tasks.md` case); plus the common check

## Phase 4: User Story 4 - Security findings, pins and platforms are what the docs claim (Priority: P2)

**Goal**: the audit files its advisory, every pin is current, lite's docs are honest, macOS is tested, merges keep one commit per task.

**Independent Test**: FR-017 to FR-021 and FR-027 in [contracts/checks.md](contracts/checks.md) pass.

- [ ] T006 [US4] Make the audit, Semgrep and init's GitHub settings what the docs say, in skills/security, extension/scripts/level.sh and skills/init (depends on T001, T002, T003) — #52
  - Comes from: FR-017, FR-019, FR-021, FR-027; F4.2, F4.5, F4.4, #41; US4 scenarios 1, 3, 5, 6
  - Impact: the union of the parts' *Impact* below; build the parts in the order listed (each
    later part edits lines the earlier one left), one commit per part, so a revert of one part stays
    possible
  - Completed when: every part's *Completed when* below holds; plus the common check
  - **Part a**: Send the advisory body GitHub accepts, after looking for an existing one, in skills/security/SKILL.md
    - Comes from: FR-017, F4.2, US4 scenario 1; research R7 F4.2
    - What: the public-repository bullet (`:104-107`) lists advisories with `--paginate` first, reuses a
      match (prints its link and stops), else POSTs the JSON body with `--input -` (summary,
      description, severity, vulnerabilities with ecosystem)
    - Impact: `skills/security/SKILL.md:104-107`, `docs/security.md` "The audit", `tests/static.test.sh`
      (`# F4.2`, reading the call only)
    - Completed when: FR-017's row passes; plus the common check
  - **Part b**: Run Semgrep from its image pinned by digest, and say where its rules come from, in extension/scripts/level.sh
    - Comes from: FR-027, F4.5, US4 scenario 6; research R3, U2
    - What: `pins.sh` adds `SEMGREP_DIGEST` beside `SEMGREP_VERSION` (bump both together); the
      full-level `code` job runs in `container: image: semgrep/semgrep@sha256:$SEMGREP_DIGEST` with
      `semgrep scan --config p/default --config p/owasp-top-ten --error --metrics off`; the README CI
      row, `docs/security.md:31` and the `security.yml` header say the rules come from the Semgrep
      registry at run time
    - Impact: `pins.sh`, `level.sh` `security_yaml` (the `uvx --from semgrep==` step goes;
      `PIN_SETUP_UV` stays for Python CI), `README.md:109`, `docs/security.md:31`,
      `tests/level.test.sh` (`:104` replaced, `:97` unchanged), `tests/static.test.sh` (`# F4.5`),
      `extension/scripts/security-scan.sh:55` (local scan, unchanged; `docs/security.md` says it also
      fetches rules)
    - Completed when: FR-027's row passes; one full-level run on the sandbox shows the Semgrep job pulling
      the pinned digest and `semgrep --version` equal to `SEMGREP_VERSION`, output quoted; plus the
      common check
  - **Part c**: Offer the free GitHub settings on every level, and say what lite lacks, in skills/init/SKILL.md
    - Comes from: FR-019, FR-021, F4.4, #41, US4 scenarios 3 and 5; research R6, U1
    - What: step 4 "GitHub settings (every level)": rebase merges off everywhere, merge commits off on
      lite (squash only), and for a public repo secret scanning with push protection and private
      vulnerability reporting (one line for private repos); step 5 "Branch protection (standard and
      full)", today's bullet; later steps renumbered (and "step 5" inside step 7 updated); README CI row
      "(standard and full)"; `docs/security.md` "On GitHub" row and "On lite there is no CI gate";
      `docs/design.md` ties the one-revert promise to one commit per task PR, squashed on lite and by
      convention on standard and full
    - Impact: `skills/init/SKILL.md` steps 4–7, `README.md:109` (after T006 part b's wording), `docs/security.md`
      (`:33` and below the table), `docs/design.md` (after `:19`, and after T003 part a's gate sentence),
      `docs/reference.md` if it cites init's step numbers, `tests/static.test.sh` (`# F4.4/#41`)
    - Completed when: FR-019 and FR-021 rows pass; #41 is closed by this PR (`Closes #41` in the body);
      plus the common check

- [ ] T007 [US4] Test macOS on every script PR and keep every pin current, in .github/workflows/ (depends on T003, T005, T006) — #53
  - Comes from: FR-018, FR-020; F5.6, F4.1; US4 scenarios 2, 4
  - Impact: the union of the parts' *Impact* below; build the parts in the order listed (each
    later part edits lines the earlier one left), one commit per part, so a revert of one part stays
    possible
  - Completed when: every part's *Completed when* below holds; plus the common check
  - **Part a**: Run the macOS job on pull requests that touch scripts, and on every tag, in .github/workflows/macos.yml
    - Comes from: FR-020, F5.6, US4 scenario 4; research R4
    - What: the `macos` job moves from `test.yml` (`:57-75`) into a new `macos.yml`, **without** its
      `if: github.event_name == 'schedule' || …` line (`test.yml:61`, which would skip every PR and tag
      run), with the paths
      filter (`extension/scripts/**`, `bin/**`, `hooks/**`, `tests/**`, the workflow itself), `push:
      tags: ["**"]`, the weekly schedule and `workflow_dispatch`, `permissions: contents: read`; `test.yml`
      loses the job and its schedule
    - Impact: `.github/workflows/test.yml` (newest sibling, the pattern: SHA pins, `persist-credentials:
      false`), `.github/workflows/macos.yml` (new), `tests/static.test.sh` (`# F5.6`; the pin, drift and
      YAML checks cover the new file through `find`), `README.md` badge/notes and any doc saying "macOS
      weekly"
    - Completed when: FR-020's row passes, including that `macos.yml` has no `if:` naming
      `github.event_name`; the PR itself runs the macOS job (it touches `tests/`) and the run is not
      skipped (`gh pr checks` shows it passed, quoted in `## Evidence`);
      plus the common check
  - **Part b**: Keep every pin current: a workflow Dependabot reads, and a weekly tool check, in .github/workflows/pins.yml and bin/check-tools.sh
    - Comes from: FR-018, F4.1, US4 scenario 2; research R8 F4.1
    - What: `pins.yml` with an `if: false` `actions` job using every `PIN_*` exactly as `pins.sh`
      writes it, and a weekly `tools` job running `bin/check-tools.sh`; the script compares
      `GITLEAKS_VERSION`, `OSV_VERSION`, `SEMGREP_VERSION` (naming `SEMGREP_DIGEST` with it) and
      `TRIVY_VERSION` with the latest releases, opens one "Tool pins behind" issue when any is behind and
      none is open, prints `BEHIND=<n>`; a failed lookup dies naming the tool and its repo
      (`cannot read the latest <tool> release from <repo>`), so the job fails instead of printing
      `BEHIND=0`; the `tools` job declares `permissions: contents: read, issues: write`
    - Impact: `.github/workflows/pins.yml` (new; pattern `macos.yml` from T007 part a), `bin/check-tools.sh`
      (new; sources `lib.sh` for `version_newer`, like `bin/setup.sh` after T001 part c), `bin/sync-pins.sh`
      (unchanged, covered), `tests/check-tools.test.sh` (new; fake `gh` `api repos/*` case printing
      `$GH_API`), `tests/static.test.sh` (`# F4.1`), `docs/security.md` "Supply chain hygiene"
    - Completed when: FR-018's rows pass (every `PIN_*` used; `BEHIND=4` and one issue for newer
      releases; none for equal versions; no second issue when one is open; a failing `api repos/*`
      lookup exits non-zero and names the tool); `tests/static.test.sh` checks the `tools` job has
      `issues: write`; plus the common check

## Phase 6: User Story 6 - The review goes deep where it matters, stays cheap on fix rounds, and runs on a strong model (Priority: P2)

**Goal**: depth where a script finds risk, fix rounds that re-read only the fix, a pinned strong reviewer, parallel task starts.

**Independent Test**: FR-030 to FR-036 in [contracts/checks.md](contracts/checks.md) pass.

- [ ] T010 [US6] Make the review deep where the risk is and cheap on fix rounds, in extension/scripts/review.sh (depends on T003, T005) — #54
  - Comes from: FR-030, FR-031, FR-032, FR-033, FR-035; US6 scenarios 1–2; research R10, R11 and Part 2
  - What: `review.sh risk [<from>]` (the fixed path and added-line rules of R10, with
    `auth([^o]|$)|authori[sz]`), `RISK=<category> <path>` lines or `RISK=none`; `record` refuses a
    report lacking `- deep: <path>` or `- proven: <path> by <test file:line>` for each flagged path,
    with the line in contracts/output-lines.md; `record --delta` per R11 (`head:` and `round:` in the
    record, `Delta from: <sha>`, the five refusals, `REVIEWED=<sha>` before `REVIEW=`), its risk check
    over `<last>..HEAD`. Gate rules added by the plan review: (1) plain `record` refuses a report that
    has a `Delta from:` line ("this is a delta report: record it with --delta, or run a new full
    review"), and every delta refusal says to **run** a new full review, not to re-record; (2) one
    `- proven:` format, `- proven: <path> by <file>:<n>`, accepted only when `<file>` exists at HEAD,
    matches `test_path_re` and has a line `<n>`; `review.md`'s Report uses this form, not R10's `—`;
    (3) **every report states its range and model**: `Reviewed: <from>..<head>` and `Model: <the
    reviewer's model id>`, each matched as an exact line (optional bold, last one wins, as
    `Assessment:`), shas resolved with `git rev-parse --verify`. Plain `record` refuses unless `<from>`
    is the merge-base with the base and `<head>` is HEAD; `record --delta` refuses unless `<from>` is
    the recorded `head:` and `<head>` is HEAD; a report with no `Reviewed:` or no `Model:` line is
    refused in both modes. So a delta report can never pass as full, and a commit made while the
    review ran is never recorded as reviewed; (4) a delta record carries over the previous full
    record's `- deep:`/`- proven:` lines, and `pr.sh` prints both maps, labeled `Risk map (round 1)`
    and `Risk map (fix round)`; (5) the record stores `model:` and any `warning:` lines, set when
    `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` is set, when `Model:` is not sonnet, opus or fable **whatever
    the config says**, or when it is not the configured `review_model` family; `review.sh` (through a
    `lib.sh` reader) refuses an invalid `review_model` with the pinned line, so the config cannot
    lower the bar; `pr.sh` prints model and warnings in the review block from the record, not from
    its own environment; plan reviews (`record --plan`) also require `Model:` and store
    `model:`/`warning:` the same way, and `issues.sh` prints a plan record's warning, which `pr.sh
    spec` copies into the spec PR body (`issues.sh` after T005 part d, `pr.sh spec` after T003
    part d); record header fields are read only from the header (up to the
    first blank line), so a line in the report body cannot add or override one; where two refusals
    match one delta, the specific delta line wins over the generic `Reviewed:` line; (6) the delta's own risk check runs over `<from>..<head>`, so a fix commit that adds
    a risky path needs its own `- deep:` line; (7) `review.sh risk --plan` is refused (`risk maps a
    diff; a plan review has none`). `review.md` folds the risk map into its method and report (`Risk map` block, `Reviewed:`,
    `Delta from:` line, what a delta reads); `pr.md` step 4: round 2 is `record --delta`, "at most
    three rounds" stays; step 5 and `pr.sh` add the risk map to the body as paths only
  - Impact: `review.sh` (after T002 part b's `diff_id` and T003's `report` action), `pr.sh` task block
    (after T003), `extension/commands/review.md` (after T003 part a), `extension/commands/pr.md` steps
    4–5, `docs/design.md` "The review is independent" (the risk map and deltas; the PR's review
    block stays facts only, as T003 part a built it: paths, model, warnings and assessment from the
    record, never reviewer prose), `docs/reference.md` (the `tests:` regex also
    widens the delta's size exemption), `tests/review.test.sh`, `tests/pr.test.sh`; the installed
    `.claude/skills/speckit-jit-*` copies regenerated with `specify extension add --dev extension
    --force`; `data-model.md` "Review record" is the format
  - Completed when: FR-030–FR-033 rows of contracts/checks.md pass, each seen failing on `main`, and
    every check of research R10 and R11 is in the suite, by name: `RISK=none`; migration +
    `DROP TABLE` → `migration` and `delete`; `src/authorization.py` → `auth`; an added `|| true` →
    `gate`; a `- deep:` for `002_drop.sql.bak` does not cover `002_drop.sql`; a missing `- deep:` is
    refused naming the path; a `- proven:` with no test, with a non-test file, and the accepted form;
    `REVIEWED=<HEAD>` on a full record; `--delta` refused with no full round, after a delta, with no
    `Delta from:`, with another base, after a rebase, with nothing committed, and with 21 changed
    lines outside the findings (25 in a findings file plus a 30-line test accepted); `--plan` with
    `--delta` refused; plain `record` of a report with `Delta from:` refused; a report with no
    `Reviewed:`, with no `Model:`, with a range not starting at the merge-base (full) or the recorded
    head (delta), or not ending at HEAD, refused; a delta whose fix commit adds `DROP TABLE` to a path
    that round 1 marked deep, with no `- deep:` for it in the delta, refused; with `review_model: opus` (or
    unset), `Model: claude-haiku-…` gives exactly one warning line, `the review ran on <id>` (the
    outside-family reason wins over the family mismatch); `review_model: haiku` is refused; `record
    --plan` without `Model:` is refused, and a plan record's warning is printed by `issues.sh` when it
    creates issues and copied into the spec PR body by `pr.sh spec`; one wrong-range delta gives
    exactly one refusal line, the delta one; a body line
    `round: full` does not change the recorded round; `risk --plan` refused; a `- proven:` naming a line past the file's end
    refused; after a delta, the PR body lists both labeled risk maps; a record made with
    `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` set, or with `Model:` outside the configured family, puts the
    warning into the PR body even when `pr.sh` runs without the variable; no risk-map prose
    reaches the PR body (a test with prose after a `- deep:` path); `tests/review.test.sh`,
    `pr.test.sh`, `issues.test.sh`, `next.test.sh` and `mutants.test.sh` pass; on bash 3.2 and BSD awk
    (the `bash32` job, and the macOS job via `gh workflow run` until T007 part a); plus the common
    check

- [ ] T011 [US6] Run every review in a plugin reviewer agent on a pinned strong model, in agents/reviewer.md (depends on T010) — #55
  - Comes from: FR-034, FR-035; US6 scenario 3; research R12 and Part 2
  - What: `agents/reviewer.md` (`name: reviewer`, `model: opus`, `effort: high`, a short body that
    defers to `review.md`, no `## Method`); `review.md`, `pr.md` step 4 and `issues.md` step 2 launch
    `jit-speckit:reviewer` with `model:` set, falling back to `general-purpose` with that model when
    the scoped id is refused; `review_model:` in `jit-config.yml` (`sonnet`, `opus` or `fable`;
    anything else refused with `jit: review_model must be sonnet, opus or fable`); no fast-model
    checker (FR-035). Seen, not only asked: the model warnings are stored and shown by T010 (rule 5);
    `review.md` requires the reviewer's prompt to carry a fixed sentinel line, `jit-speckit review:
    independent reviewer`, wherever the prompt starts, and the plugin's `PreToolUse` hook
    (`hooks/hooks.json`, `Bash` only today) gets a matcher for the subagent tool (`Agent`, and `Task`
    for older clients) that blocks a launch of `jit-speckit:reviewer`, or of any agent whose prompt
    holds the sentinel, when its `model` is missing or not `sonnet`, `opus` or `fable`, or when it is a
    fork (`subagent_type: fork` inherits the author's context, so it is not independent), with the
    line in contracts/output-lines.md
  - Impact: `agents/reviewer.md` (new; the plugin has no `agents/` yet: the default scan finds it, so
    `.claude-plugin/plugin.json` gets no `agents` key), `extension/commands/{review,pr,issues}.md`,
    `docs/reference.md` (the config row; that `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` overrides it; the
    review costs more on a cheap session), `README.md` "Security, built in" (the reviewer's model),
    `tests/static.test.sh` (`# FR-034`), `hooks/hooks.json` and a new `hooks/guard-review.sh` (the
    newest sibling, `hooks/guard-git.sh`, is the pattern: the plugin's own copy, exit 2 to block,
    `onFailure: block`), a new `tests/guard-review.test.sh` (the hook's input as JSON on stdin); the
    installed skill copies regenerated as in T010
  - Completed when: FR-034/FR-035 row passes, each check seen failing on `main`, in
    `tests/guard-review.test.sh` (the hook's input as JSON on stdin, both tool names): it blocks a
    `jit-speckit:reviewer` launch with `model: haiku` or no `model`, blocks a `general-purpose` launch
    whose prompt holds the sentinel with `model: haiku` or none, allows both with `opus`, and allows a
    `general-purpose` launch without the sentinel, and blocks a fork carrying the sentinel even with
    `model: opus`, printing the fork line; the hook input shape is checked against one real
    2.1.295+ session (quoted in `## Evidence`); the docs say the hook exists only where the plugin is
    installed; one sandbox session's
    transcript in `## Evidence` shows the Agent call with `subagent_type: jit-speckit:reviewer` and
    `model: opus`, and `review_model: haiku` refused (if the scoped id is refused, the PR says so and
    the fallback is what ships); plus the common check

- [ ] T012 [US6] Print a ready-to-run start line for every other startable task, in extension/scripts/next.sh (depends on T005) — #56
  - Comes from: FR-036; US6 scenario 4; research R13
  - What: `next.sh` collects every other open task whose line has `[P]` right after its id (anchored,
    not anywhere in the line) and prints `parallel <Tnnn> (git worktree add
    --quiet --detach <dir> origin/<base> && cd <dir> && bash .specify/extensions/jit/scripts/branch.sh
    <num> <Tnnn>)` before the `DONE=` line, which stays last; `skills/next/SKILL.md` asks once whether
    to start them, runs each line as printed, one at a time, shows a failure and skips that task, and
    says a refused claim (FR-012) only warns, and that the worktree goes beside the repository (a
    repository whose parent is not writable gets a failure line per task, shown as is)
  - Impact: `next.sh` (after T005 part b's rewrite of `scan()` and the no-argument block),
    `skills/next/SKILL.md` (a step before "Run /speckit-implement"), `docs/reference.md` "Using Claude
    Code well" (`:101` loses "so every worktree gets a different task"), `tests/next.test.sh` (every
    existing check keeps `tail -1` = `DONE=`)
  - Completed when: FR-036's row passes (seen failing on `main`); a printed line, run in the test
    repo, claims the task and the next `next` shows it in progress with no line for it; plus the
    common check

## Phase 5: User Story 5 - The fixes ship as release 1.8.0 (Priority: P3)

**Goal**: one update gives every fix, proven on real GitHub, with docs and versions agreeing.

**Independent Test**: `sandbox-run.md` says every step holds, and [quickstart.md](quickstart.md) steps 1–7 pass on the release PR.

- [ ] T008 [US5] Prove 1.8.0 end to end on the sandbox repository, in specs/002-review-fixes/sandbox-run.md (depends on T001, T002, T003, T004, T005, T006, T007, T010, T011, T012) — #57
  - Comes from: SC-002, SC-003, SC-004, SC-005, every US acceptance scenario that GitHub decides; research "Unverified" items for R2, R3, R6 and R8; the user's request on 2026-11-05 for real tests on the sandbox
  - What: run the merged `main` (all of T001 part a–T007 part b) for real on `iamalisson/jit-speckit-sandbox` and
    write what happened, with the commands and their output, to `sandbox-run.md` in this folder:
    1. install the plugin from this repository's `main` in a fresh Claude Code session (or
       `bin/setup.sh` from a `main` worktree when the plugin cannot be loaded), and `init` at lite, then
       `/jit-speckit:level standard`, then `/jit-speckit:level full` on the same sandbox clone;
       expected after each, read back: lite turns merge commits off (squash only), standard and full
       keep that setting from lite and add branch protection on their branches; the sandbox is
       private, so the public-repo offers appear only as the one-line note;
    2. read back every GitHub setting `init` offered and the user accepted (`gh api
       repos/iamalisson/jit-speckit-sandbox --jq '{allow_rebase_merge, allow_merge_commit,
       allow_squash_merge, security_and_analysis}'`, private vulnerability reporting), each against
       contracts/output-lines.md "What `/jit-speckit:init` offers";
    3. one small sandbox feature (numbered from `099` down, as in 001's Rules) through the real
       path: issues → `branch.sh` claim → `pr.sh task` → merge → the issue closes → `next` shows it
       `done`, then a renamed closed issue still `done` (F1.2) and `next` on a task branch serving
       its feature (F1.9);
    4. each new refusal, for real: red tests (F3.3), no mutation record (F3.4, with a mutate command
       set), no scan record (F3.6), an edited test in `app/tests.py` (F3.9), the recorded review in
       the PR body with no finding text (F3.1), the Copilot line (F3.5), a refused claim push (F1.1:
       a second sandbox clone first pushes the same `feat/099-t…` branch with another commit, so the
       claim is rejected as non-fast-forward; github.com has no pre-receive hooks),
       `analyzed.sh` without a report on full (F3.8), a review refused for a risky path with no deep
       check and a real delta round accepted (FR-030, FR-032), the review running in
       `jit-speckit:reviewer` (FR-034), `next`'s `parallel` lines started (FR-036);
    5. on full, one CI run of `security.yml` with the Semgrep image by digest (F4.5: the job log
       shows the pull of `semgrep/semgrep@sha256:<SEMGREP_DIGEST>`), and a task PR merged into
       `develop` (the job skips merges into the default branch) whose body also names a number one
       above the newest issue or PR, read just before, so it cannot be closed and is no one's item
       (F1.6: the job fails with `could not close: #<n>`, the task's own issue still closes);
    6. 1.8.0's `setup.sh` on a sandbox clone whose `.specify/extensions/jit/extension.yml` claims a
       higher version (an uncommitted edit, reverted after: F5.4 refusal; an older copy cannot
       refuse, it predates the check), `remove` after an edit (F5.2 keeps it), a refresh with a
       newer pin (F4.7) and a v1.3.0 hook (F5.3);
    7. then clean up only what the run created.
  - Impact: none in the repository but `sandbox-run.md` (new); on the sandbox, only items this task
    creates. Guards, as 001's tasks.md "Rules every task follows": every command runs from the
    sandbox clone after `[ "$(git remote)" = origin ] && [ "$(gh repo view --json nameWithOwner -q
    .nameWithOwner)" = iamalisson/jit-speckit-sandbox ] || exit 1`; direct `gh` writes pass `-R
    iamalisson/jit-speckit-sandbox`; titles carry `[002 sandbox T008]` and branches
    `sandbox-002-t008-*`; every issue, PR and branch created is written down as it is created and
    cleanup closes and deletes only those; every repository setting `init`, the session or a workflow may change is recorded **before
    step 1** (since `init` changes them) as the exact command that puts it back: `allow_rebase_merge`,
    `allow_merge_commit`, `allow_squash_merge`, `squash_merge_commit_title`,
    `squash_merge_commit_message`, `security_and_analysis`, private vulnerability reporting (GET,
    restored with PUT or DELETE), and branch protection on every branch `protected_branches`
    (`lib.sh:84`) gives at each level run, read before step 1 with the default branch's name (the
    sandbox's is `master`, with `develop`, and `staging` on full): each protection's current state,
    a 404 restored with `gh api -X DELETE …/branches/<b>/protection`; all put back at the end. No guard-bypass form is run or
    written (F2.3 stays covered by its local test).
  - Completed when: `sandbox-run.md` has, for each step 1–6, the commands, the real output and the
    expected result (the contracts/output-lines.md line where one exists; otherwise the one named in
    the step: the issue `CLOSED`, `next` printing `done`, the digest in the job log), and says `holds` or `does not hold` for each; any
    `does not hold` gets a fix task by `/speckit-converge` before T009; every recorded setting is read
    back after restoring and quoted equal to its recorded value; nothing the run created is left open; research's
    unverified items for R2, R3, R6 and R8 are each marked confirmed or still unverified with the
    output; plus the common check

- [ ] T009 [US5] Release 1.8.0 in .claude-plugin/plugin.json, extension/extension.yml and preset/preset.yml (depends on T008) — #58
  - Comes from: FR-025, SC-001, SC-002, SC-005, SC-006, US5; plan "Task groups" G
  - What: a new `tests/static.test.sh` check (`# FR-025`) that the versions in
    `.claude-plugin/plugin.json`, `extension/extension.yml` and `preset/preset.yml` are equal (none
    exists today: the only version check is spec-kit's, `static.test.sh:49-51`), seen failing first
    on a deliberate mismatch; the three files say `1.8.0`; the release notes, as the body of the
    GitHub release for `v1.8.0` (`gh release create v1.8.0 --notes-file`, after the tag), list each
    fixed finding id (F1.1 … F5.6, #41) and FR-030–FR-036 with its PR, are written in the PR as
    `docs/releases/1.8.0.md`, so they are reviewed and merged with it; quickstart steps 1–7 run on
    the PR's head (`HEAD` in place of the `v1.8.0` tag in steps 4 and 6), including feature 001's
    broken reproductions and the macOS workflow on the PR. Tag and release are the step right after the
    merge, by the maintainer on `main` (`git tag v1.8.0 && git push origin v1.8.0`, then `gh release
    create v1.8.0 --verify-tag --notes-file docs/releases/1.8.0.md`); they are not part of "done",
    since the task's issue closes at merge (`pr.sh` adds `Closes #N`)
  - Impact: `.claude-plugin/plugin.json:3`, `extension/extension.yml:6`, `preset/preset.yml:6`;
    `.specify/presets/jit/preset.yml` and `.specify/extensions/jit/` are the installed copies,
    refreshed by `/jit-speckit:init` after the release, not by hand; `tests/static.test.sh` version
    checks; the tag `v1.8.0` on `main` after merge
  - Completed when: the new version check fails with one file at `1.7.2` and passes with all three
    at `1.8.0`; a `tests/static.test.sh` check that `docs/releases/1.8.0.md` names every fixed id
    (F1.1 … F5.6 and #41) passes, seen failing with one id removed; quickstart steps 1–7 on the PR's
    head are in `## Evidence`; `sandbox-run.md` has no `does not hold` without a merged fix task; plus the common check

---

## Dependencies & Execution Order

- **Before any task**: #45 (constitution 1.0.1) and #46 (001 entry corrections) are merged, then
  this spec PR.
- **Start in parallel**: T001, T002, T004.
- **US6**: T010 after T003 and T005 (`issues.sh` shows a plan record's warning); T011 after T010; T012 after T005 (parallel with T010).
- **Then**: T005 after T004 (`tests/branch.test.sh`); T003 after T002 and T005 (`pr.sh`, `review.sh`,
  `fake_gh`'s `api` cases); T006 after T001, T002, T003 (`level.sh`, adjacent `README.md` and
  `docs/security.md` lines, `docs/design.md`); T007 after T003, T005, T006 (`fake_gh`, pins).
- **Last**: T008 (the sandbox proof, after T001–T007 and T010–T012), then T009 (the release).
- MVP: T001 removes both High findings.
