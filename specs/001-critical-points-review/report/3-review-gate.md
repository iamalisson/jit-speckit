Reviewed at: 172f8c5 (v1.7.2)

## 3. Review gate and tests as evidence

Every `file:line` is at tag `v1.7.2`. Local reproductions run in a throwaway repository made by
`tests/helpers.sh`. The Copilot request was sent for real on the private sandbox
`iamalisson/jit-speckit-sandbox` (PR #15, `[001 review T003]`), from its clone, with the guard in
tasks.md "Rules every task follows".

| id | promise | verdict | evidence |
|---|---|---|---|
| P10 | Before every PR, at every level, a fresh agent reviews the whole repository; the PR is refused without a recorded `ready` for the exact diff | limit | the refusal holds: `pr.sh:68` → `review.sh check`, keyed to the patch id of the diff against the base (`review.sh:25-29`); `tests/pr.test.sh:21,45`. What it proves is narrower than the docs say: F3.1 |
| P11 | No issue is created without a recorded plan review of the current `tasks.md` | limit | `issues.sh:18` refuses without it (`tests/issues.test.sh:20,40`); the same narrowness as P10 (F3.1), and the record covers `plan.md` and `tasks.md` only: F3.2 |
| P12 | Never opens a PR on red checks | broken | no script runs the checks before a PR; section B: `pr.sh` opens the PR while the project's check fails: F3.3 |
| P13 | Tests are evidence: a PR that changes existing tests needs `## Test changes`; mutation testing runs on the change | limit | test changes: `pr.sh:57-66` with `TEST_PATH_RE` (`lib.sh:57`) and `--no-renames`; `tests/pr.test.sh:86-111`. Mutation testing only runs when the prompt runs it, and `missing` exits 0: F3.4 |
| P14 | GitHub Copilot code review is requested on every PR when the account has it | broken | sandbox PR #15: `pr.sh`'s exact call answers `201 Created` with `"requested_reviewers":[]`, and `pr.sh` prints `copilot: code review requested` anyway: F3.5 |
| P15 | On full, `## Evidence` and `/speckit-analyze` on the current `tasks.md` are required | limit | `pr.sh:52-54` refuses a body without `## Evidence`; `branch.sh:37-42` refuses until the analysis marker matches `tasks.md` on the base; `tests/pr.test.sh:40`, `tests/branch.test.sh:63-70`. But the marker proves even less than the review record: `analyzed.sh:12` writes it with no report at all: F3.8 |
| P26 | Before each PR, the scanners run on the changed files and `/security-review` runs | limit | asked in `extension/commands/pr.md` step 4 only; `pr.sh` never checks they ran (section B), and a missing scanner is reported as `missing` and exits 0 (`security-scan.sh:32`): F3.6 |

Also checked, no finding:
- The task record is the patch id of `git diff <merge-base> HEAD` (`review.sh:25-29`): merging
  the base in keeps it, and any edit, whitespace included, changes it (`--verbatim`, with a
  `--stable` fallback for git older than 2.39, `review.sh:28`). Uncommitted tracked changes are refused
  at record time (`review.sh:41`).
- Only an exact `Assessment: ready` or `Assessment: changes needed` line counts, and the last one
  decides (`review.sh:38`).
- spec-kit's `optional: false` hooks (`.specify/extensions.yml`) are prompts, not processes: the
  installed `/speckit-implement` skill (spec-kit v1.2.5) emits `EXECUTE_COMMAND:` and says
  "Emitting the block alone does not run the hook" (`.claude/skills/speckit-implement/SKILL.md:57,209`).
  So the review, the issues and the PR steps run only when the agent follows that line. The
  scripts' refusals (`pr.sh`, `issues.sh`, `branch.sh`) are what hold when it does not.
- The plan-review refusal itself: `issues.sh:18` (section 1 left it here). `tests/issues.test.sh:20`
  shows "no independent review" and no issue created.

**Script refuses / prompt asks** (research R4):

| gate | script refuses | prompt asks | docs say |
|---|---|---|---|
| task review | `pr.sh:68`: no recorded `ready` for this diff; `pr.sh:55-56`: no `## Review` | `extension/commands/pr.md` step 4: a fresh general-purpose subagent with `review.md` and the facts only | "an **independent review** by a fresh agent" (`README.md:108`); "The review is a gate, not a prompt" (`docs/design.md:44`) |
| plan review | `issues.sh:18`: no recorded `ready` for this `plan.md` + `tasks.md` | `extension/commands/issues.md` step 2 | "reviewed by a fresh agent (plan review, recorded; no issue is created without it)" (`docs/reference.md:83`) |
| red checks | nothing | `pr.md` step 2: "If anything fails, stop and report it. Never open a PR on red checks." | "never open a PR on red checks" (`.specify/memory/constitution.md:11`) |
| test changes | `pr.sh:63-66`: an edited or deleted existing test needs `## Test changes` | `pr.md` step 2 | "refused unless the body has a `## Test changes` section" (`docs/reference.md:89`) |
| mutation testing | nothing (`mutants.sh` always exits 0) | `pr.md` step 2 | "mutation testing on the change" (`docs/reference.md:87`) |
| pre-PR scanners, `/security-review` | nothing | `pr.md` step 4 | "scanners on the changed files, `/security-review`" (`README.md:108`) |
| full: evidence, analysis | `pr.sh:52-54`; `branch.sh:37-42` (a marker `analyzed.sh` writes on request, F3.8) | `pr.md` step 5, `/speckit-analyze` | "required before any task" (`README.md:126`) |

### F3.1 · Medium · P10, P11 · the review gate proves a report exists, not that a fresh reader wrote it

- **verdict**: limit (the docs mislead)
- **evidence**: `review.sh record` accepts any file whose last `Assessment:` line says `ready`
  (`review.sh:36-43`). Section A: a one-line file `Assessment: ready` records `REVIEW=ready`, and
  `review.sh check` passes. `docs/design.md:38-46` says the review "runs in a fresh agent that
  gets only facts" and "The review is a gate, not a prompt". The gate is real for *some* recorded
  report on *this* diff; who wrote it, and whether it read anything, is only asked by the prompt.
  The report also lives in `.git/jit-review/`, so nobody else can see it. (The full-level
  analysis marker is weaker still: F3.8.)
- **reproduction**: section A of the script below.
- **exposure**: public (the operator, or their own agent, can skip it; FR-013).
- **fix**: make the record visible and say what it proves. `pr.sh task` puts the recorded
  report's *What changed* and *Findings* headings, and its `Assessment:` line, into the PR body,
  folded in `<details><summary>Independent review</summary>`, so a human merging can see it.
  Nothing marks a security finding today (`extension/commands/review.md:78-79` only ranks
  "security" under High), so the same change makes `review.md` report each security finding as one
  line, `Security: reported privately (<id>)`, with its detail kept in the recorded file only, and
  `pr.sh` copies no line that follows such a marker. That keeps the constitution's "never put … a
  security finding into a public place" (`.specify/memory/constitution.md:12`). `docs/design.md` then says the gate proves "a recorded report that said
  ready for this exact diff, attached to the PR", and that who wrote it is asked by the prompt.
  Check for `tests/pr.test.sh`: when a review is recorded and `pr.sh task` opens the PR, then the
  body sent to `gh pr create` contains the recorded report's text, and when the recorded report
  holds a security finding, then the body does not contain that finding's text. The first fails
  today; the second guards the fix.

### F3.2 · Low · P11 · editing `spec.md`, `research.md` or `quickstart.md` after the plan review keeps it valid

- **verdict**: limit
- **evidence**: the plan state hashes `plan.md` and `tasks.md` without the issue links
  (`review.sh:19-21`). Section C: after a `ready` plan review, a changed `spec.md` and
  `research.md` still pass `check --plan`, and only a changed `plan.md` is refused. This review's
  own plan used that on 2026-11-05: a fix to `research.md` after the last plan review kept it
  `ready`.
- **reproduction**: section C of the script below.
- **exposure**: public.
- **docs**: `docs/reference.md:83` says the plan is "reviewed by a fresh agent (plan review, recorded; no
  issue is created without it)", and does not say which files the record covers.
- **note**: hashing the whole feature folder (without the issue links) would cover what the task
  lines point at.

### F3.3 · Medium · P12 · nothing stops a PR from opening while the checks fail

- **verdict**: broken
- **evidence**: the constitution's "Project" promise is "never open a PR on red checks"
  (`.specify/memory/constitution.md:11`). Only `extension/commands/pr.md:10-11` asks for it, and
  `pr.sh` never runs the test, lint or build command (section B: 0 mentions). Section B: with the
  project's check exiting 1, `pr.sh task` prints `PR=…`. CI runs afterwards, on the open PR.
- **reproduction**: section B of the script below.
- **exposure**: public.
- **fix**: `pr.sh task` runs the constitution's `test` command (`constitution_cmd test`, already
  in `lib.sh`) before the push, and refuses with its last lines when it fails; with no test command
  it says so and goes on. Check for `tests/pr.test.sh`: when the constitution's test command exits
  1, then `pr.sh task` exits non-zero, prints that output and pushes nothing. It fails today.

### F3.4 · Medium · P13 · mutation testing runs only if the prompt runs it

- **verdict**: limit (the docs mislead)
- **evidence**: `mutants.sh` always exits 0 (`mutants.sh:17`), with `missing`, `skipped`,
  `survivors` or `ok` on its first line, and `pr.sh` never calls it. Section E: with no `mutate`
  command, `mutants missing …`, `rc=0`. `pr.md` step 2 asks to put the result in *Evidence*, and
  `docs/reference.md:87` lists "mutation testing on the change" among the steps after
  `/speckit-implement`, in the same row as the review that *is* refused. Ranked Medium like F3.6:
  research R4 makes any gap between "script refuses" and "prompt asks" Medium at least, and the
  docs list both in the same breath.
- **reproduction**: section E of the script below.
- **exposure**: public.
- **fix**: `mutants.sh` writes its result line to `.git/jit-mutants/<diff patch id>`, and
  `pr.sh task` refuses when there is none for this diff, or when it says `survivors` and the body
  has no `## Evidence` line naming the survivor. `missing` stays allowed (a stack with no tool) and
  goes into the body. Check for `tests/pr.test.sh`: when the constitution has a `mutate` command and
  `mutants.sh` was not run on this diff, then `pr.sh task` refuses and names `mutants.sh`. It
  fails today.

### F3.5 · Medium · P14 · "copilot: code review requested" is printed when no review was requested

- **verdict**: broken
- **evidence**: `pr.sh:29` sends `POST …/requested_reviewers` with
  `reviewers[]=copilot-pull-request-reviewer[bot]`, and prints the line when `gh` exits 0. Its
  comment says "Without it the API refuses (422) and nothing is said" (`pr.sh:26-27`). On the
  sandbox, real output: `HTTP/2.0 201 Created` with `"requested_reviewers":[]`, and then
  `GET …/requested_reviewers` gives `{"teams":[],"users":[]}`. The login `Copilot` gives the same
  `201` and `[]`. Sandbox PRs #13 and #14 printed the line (quoted in section 1's sandbox output),
  and so did this repository's #29 and #30 when they were opened (this session's output, not quoted
  elsewhere); none of the four has a review request or a review event in its timeline. Which login
  GitHub expects for a Copilot review request was not checked against GitHub's documentation, so
  two causes remain open and both are `unverified`: this account has no Copilot code review, or
  `copilot-pull-request-reviewer[bot]` is not the login the API takes. What would settle it:
  GitHub's REST docs page on requesting a Copilot code review, or the same call on an account that
  has Copilot code review. Either way the printed line is wrong, which is the finding.
- **reproduction**: sandbox script below.
- **exposure**: public.
- **fix**: print the line only when the answer's `requested_reviewers` contains the Copilot
  login, and otherwise say `copilot: not requested (no Copilot code review on this repository)`.
  Check for `tests/pr.test.sh`: when the fake `gh` answers the request with
  `{"requested_reviewers":[]}`, then the output does not contain `code review requested`. It fails
  today.

### F3.6 · Medium · P26 · the pre-PR scanners and `/security-review` are presented as built in, and only the prompt runs them

- **verdict**: limit (the docs mislead)
- **evidence**: `README.md:108` lists, in "Security, built in", "**before each PR** … scanners on
  the change, `/security-review`", and `docs/security.md:30` puts them in "The layers". Only
  `extension/commands/pr.md` step 4 asks for them; `pr.sh` never checks they ran (section B), and
  `security-scan.sh` reports each absent scanner as `missing` and exits 0 (`security-scan.sh:32`).
  On this machine all four were `missing` for T001 and T002, and both PRs opened. A user can tell
  from the PR body only if the agent wrote it there.
- **reproduction**: section B (no check in `pr.sh`), and v1.7.2's `security-scan.sh --changed`
  run on this machine, where no scanner is installed (the `missing` lines come from
  `security-scan.sh:32`, and the script ends with `echo "REPORT_DIR=$dir"`, so it exits 0):

  ```text
  gitleaks     missing   install: https://github.com/gitleaks/gitleaks#installing (brew install gitleaks)
  osv-scanner  missing   install: https://google.github.io/osv-scanner/installation/ (brew install osv-scanner)
  semgrep      missing   install: uv tool install semgrep (or pipx install semgrep)
  zizmor       missing   install: uv tool install zizmor (or brew install zizmor)
  trivy        skipped   no Dockerfile/Terraform/Kubernetes files
  REPORT_DIR=.git/jit-security/<timestamp>
  rc=0
  ```
- **exposure**: public.
- **fix**: `security-scan.sh --changed` writes its result line to `.git/jit-security/<diff patch
  id>`, and `pr.sh task` refuses when there is none for this diff. Or, smaller, the README row
  says "asked of the agent before each PR; CI runs the scanners for real". Check for
  `tests/pr.test.sh`: when no scan was recorded for this diff, then `pr.sh task` refuses and names
  `security-scan.sh`. It fails today.

### F3.7 · Low · P10 · the hint for a missing task review tells the user to record a plan review

- **verdict**: broken
- **evidence**: `review.sh:45` builds the hint with `${plan:+ --plan}`, but `plan` is the string
  `false` or `true`, never empty, so the hint always says `review.sh record --plan <report-file>`.
  Section D: on a task branch with no record, `… record its report: review.sh record --plan
  <report-file>`. Following it records a plan review, and the task gate still refuses.
- **reproduction**: section D of the script below.
- **exposure**: public.
- **note**: `$($plan && echo ' --plan')`.

### F3.8 · Medium · P15 · on full, the analysis requirement is met by running `analyzed.sh` alone

- **verdict**: limit (the docs mislead)
- **evidence**: `README.md:126` says `/speckit-analyze` is "required before any task" on full,
  and `branch.sh:37-42` refuses until the marker matches `tasks.md` on the base. But
  `analyzed.sh:12` writes that marker whenever it is run, with no analysis report to read. Section F
  below, on level full: `branch.sh T001` is refused ("requires /speckit-analyze"), then
  `analyzed.sh` alone prints `ANALYZED=001-demo`, and `branch.sh T001` goes through.
- **reproduction**: section F below.
- **exposure**: public.
- **fix**: record the analysis like the review: `analyzed.sh <report-file>` takes the analysis
  output and refuses a file that has none of `/speckit-analyze`'s section headings, and the marker
  keeps the report next to the hash. Check for `tests/branch.test.sh`: when `analyzed.sh` is run
  with no report, then it refuses and `branch.sh` on full still refuses. It fails today.

### Reproductions

<details>
<summary>Local script (sections A–E) and its output</summary>

```bash
# T003 reproductions, run as: bash t003-repro.sh <v1.7.2 worktree>
source "$1/tests/helpers.sh"
fake_gh; new_repo lite
[ "$(git rev-parse --show-toplevel)" != /home/admin/Documents/workstation/personal/jit-speckit ] || exit 1
r="$SCRIPTS/review.sh"; p="$SCRIPTS/pr.sh"
printf '# Plan\n' > specs/001-demo/plan.md; printf 'spec v1\n' > specs/001-demo/spec.md; printf 'research v1\n' > specs/001-demo/research.md
commit_tasks '- [ ] T001 Add search — #5'
"$SCRIPTS/branch.sh" T001 >/dev/null 2>&1
printf 'echo ok\n' > app.sh; printf 'exit 1\n' > failing-check.sh; git add app.sh failing-check.sh; git commit -q -m "feat: add search"

echo "== A. what the task gate accepts: any file whose last Assessment line says ready"
printf 'Assessment: ready\n' > "$TMP/one-line.md"; "$r" record "$TMP/one-line.md"
"$r" check
echo "== B. pr.sh then opens the PR, with the project's checks failing (pr.sh never runs them)"
bash failing-check.sh || echo "the project's check: rc=$?"
printf '## Review\n\nnone\n' > "$TMP/body.md"
"$p" task T001 "feat: add search" "$TMP/body.md" | grep -E '^PR=|copilot'
echo "pr.sh mentions the test command, mutants.sh, security-scan.sh or /security-review: $(grep -cE 'constitution_cmd test|mutants\.sh|security-scan|security-review' "$SCRIPTS/pr.sh") times"
echo "== C. the plan record covers plan.md and tasks.md only"
"$r" record --plan "$TMP/one-line.md"
printf 'spec v2: a changed requirement\n' > specs/001-demo/spec.md; printf 'research v2\n' > specs/001-demo/research.md
"$r" check --plan
printf '# Plan v2\n' > specs/001-demo/plan.md; "$r" check --plan || echo "rc=$?"
git checkout -q -- specs
echo "== D. the hint when no task review is recorded"
git switch -q -c feat/001-t002-other; "$r" check || echo "rc=$?"
echo "== E. mutation testing with no mutate command"
"$SCRIPTS/mutants.sh" | head -1; echo "rc=${PIPESTATUS[0]}"
```

```text
== A. what the task gate accepts: any file whose last Assessment line says ready
REVIEW=ready
REVIEW=ready
== B. pr.sh then opens the PR, with the project's checks failing (pr.sh never runs them)
the project's check: rc=1
copilot: code review requested
PR=https://github.com/acme/app/pull/99
pr.sh mentions the test command, mutants.sh, security-scan.sh or /security-review: 0 times
== C. the plan record covers plan.md and tasks.md only
REVIEW=ready
REVIEW=ready
jit: the plan (specs/001-demo/plan.md and tasks.md) changed since the last review; run /speckit-jit-review again and record it
rc=1
== D. the hint when no task review is recorded
jit: no independent review recorded for this branch's diff; run /speckit-jit-review and record its report: review.sh record --plan <report-file>
rc=1
== E. mutation testing with no mutate command
mutants missing no 'mutate' command in the constitution's **Commands** line; /jit-speckit:adopt fills it
rc=0
```

</details>

<details>
<summary>Local script F (F3.8) and its output</summary>

```bash
# T003 reproduction F, run as: bash t003-repro-f.sh <v1.7.2 worktree>
source "$1/tests/helpers.sh"
fake_gh; new_repo full
[ "$(git rev-parse --show-toplevel)" != /home/admin/Documents/workstation/personal/jit-speckit ] || exit 1
commit_tasks '- [ ] T001 Add search — #5'
echo "== F. level full: the analysis marker without any analysis"
"$SCRIPTS/branch.sh" T001 2>&1 | tail -1 || true
"$SCRIPTS/analyzed.sh"
"$SCRIPTS/branch.sh" T001 2>&1 | tail -1
```

```text
== F. level full: the analysis marker without any analysis
jit: level 'full' requires /speckit-analyze on the current tasks.md before implementing
ANALYZED=001-demo
BRANCH=feat/001-t001-add-search ISSUE=5 TASK=T001 BASE=develop
```

</details>

<details>
<summary>Sandbox: the Copilot request (PR #15)</summary>

```bash
# T003 on the sandbox: the Copilot request exactly as pr.sh sends it. Run from the sandbox clone.
set -u
[ "$(git remote)" = origin ] && [ "$(gh repo view --json nameWithOwner -q .nameWithOwner)" = iamalisson/jit-speckit-sandbox ] || exit 1
REC="$(git rev-parse --git-common-dir)/jit-repro/t003-created.txt"; R=iamalisson/jit-speckit-sandbox
git fetch -q origin && git switch -q -c review-001-t003-copilot origin/develop && echo "branch review-001-t003-copilot" >> "$REC"
mkdir -p docs && echo "copilot probe" > docs/001-review-t003.md && git add docs/001-review-t003.md && git commit -q -m "docs: 001 review T003 probe"
git push -q -u origin review-001-t003-copilot 2>&1 | grep -v '^remote:' || true
url=$(gh pr create -R $R --base develop --head review-001-t003-copilot --title "[001 review T003] Copilot request probe" --body "Probe for the jit-speckit 001 review, T003. Closed after.")
n=${url##*/}; echo "pr $n" >> "$REC"; echo "PR #$n"
echo "== pr.sh's call (pr.sh:29), with the answer shown"
gh api -X POST "repos/$R/pulls/$n/requested_reviewers" -f 'reviewers[]=copilot-pull-request-reviewer[bot]' -i 2>&1 | sed -n '1p;/"requested_reviewers"/,/\]/p' | head -8; echo "rc=${PIPESTATUS[0]}"
sleep 5
echo "== requested reviewers now"; gh api "repos/$R/pulls/$n/requested_reviewers" --jq '{users:[.users[].login],teams:[.teams[].name]}'
echo "== same call with the login GitHub documents for Copilot (Copilot)"
gh api -X POST "repos/$R/pulls/$n/requested_reviewers" -f 'reviewers[]=Copilot' -i 2>&1 | sed -n '1p' ; gh api "repos/$R/pulls/$n/requested_reviewers" --jq '[.users[].login]'
```

Output, with the long PR object in the `201` answer cut down to its `requested_reviewers` field:

```text
PR #15
== pr.sh's call (pr.sh:29), with the answer shown
HTTP/2.0 201 Created
… "requested_reviewers":[],"requested_teams":[] …
rc=0
== requested reviewers now
{"teams":[],"users":[]}
== same call with the login GitHub documents for Copilot (Copilot)
HTTP/2.0 201 Created
[]
```

The probe's label "the login GitHub documents for Copilot" is the probe's wording, not a
checked fact (see F3.5).

Cleanup: PR #15 closed with `[001 review T003] cleanup`, branch `review-001-t003-copilot` deleted
on origin and locally. The record is in the sandbox clone's `.git/jit-repro/t003-created.txt`.

</details>
