Reviewed at: 172f8c5 (v1.7.2)

# Critical-points review — jit-speckit 1.7.2

Built from the eight sections under [report/](report/). Each finding's evidence, reproduction and
output are in its section; this page ranks them, gives one fix per public High and Medium finding,
and collects what could not be checked.

## Summary

Of 28 promises, 4 hold (P09, P18, P22, P23), 14 are `limit`, 8 are `broken` and 2 are reported
privately. 36 findings: 3 High (one private), 24 Medium, 9 Low.

How the ranks apply FR-009. High is a broken promise of the kinds it lists (a secret can leave, a
protected branch can change, a user's file can be lost, a gate passes without what it claims), and
Medium a promise kept that a user could be misled about. FR-009 has no tier for a broken promise
without one of those harms: this report ranks those Medium (F1.1, F1.2, F1.6, F1.8, F3.3, F4.2,
F4.3). A `limit` whose docs or messages mislead is Medium. A `limit` is Low when its docs describe it
(F1.3, F5.1, and F4.6 and F5.5, whose blocks say why), and also, departing from data-model's
"always Low" only for honest docs, when the docs say nothing either way and the gap costs a retry
or a message (F1.4, F1.5, F2.2, F2.5, F3.2).

| id | rank | promise | finding | proposed fix | section |
|---|---|---|---|---|---|
| F2.1 | High | P06, P07 | reported privately (GHSA-4mx7-h98x-x6hf) | in the advisory | [2](report/2-secrets-guard.md) |
| F5.2 | High | P20 | `remove` deletes a managed file the user edited, uncommitted edits included | keep marked files that changed since jit wrote them | [5](report/5-levels-files.md) |
| F5.4 | High | P21, P10 | an older plugin copy downgrades a newer project without a word, and removes the review gate | `setup.sh` refuses to go below the project's version | [5](report/5-levels-files.md) |
| F1.1 | Medium | P02, P04 | a refused claim push is silent, so the task is not claimed | warn when the claim push fails | [1](report/1-task-chain.md) |
| F1.2 | Medium | P03, P04 | `next` finds closed issues by title search; a renamed closed issue counts as not done | look each task's issue up by number | [1](report/1-task-chain.md) |
| F1.6 | Medium | P03, P04 | on standard and full a failed close in `close-linked-issues.yml` is silent | close every number, then fail the job | [1](report/1-task-chain.md) |
| F1.7 | Medium | P01 | an issue created on GitHub whose answer never arrives is created again, while the docs say an interrupted run never makes duplicates | look for the task's title before creating | [1](report/1-task-chain.md) |
| F1.8 | Medium | P05 | when `gh pr list` fails, `pr.sh spec` force-pushes over the open spec PR's branch | stop when the PR lookup fails | [1](report/1-task-chain.md) |
| F1.9 | Medium | P04 | on a task branch, `next` with no argument asks which feature, while the docs say the branch decides | use the task branch's feature | [1](report/1-task-chain.md) |
| F2.4 | Medium | P08 | the docs give Claude Code 2.1.275 as the plugin's minimum, but the guard fails closed only from 2.1.295 | say 2.1.295 wherever the minimum is given | [2](report/2-secrets-guard.md) |
| F2.3 | Medium | P08 | two forms inside the guard's documented scope get through | refuse them in `guard.sh` | [2](report/2-secrets-guard.md) |
| F3.1 | Medium | P10, P11 | the review gate proves a report exists, not that a fresh reader wrote it | attach the recorded report to the PR; say what the gate proves | [3](report/3-review-gate.md) |
| F3.3 | Medium | P12 | nothing stops a PR from opening while the checks fail | `pr.sh task` runs the test command first | [3](report/3-review-gate.md) |
| F3.4 | Medium | P13 | mutation testing runs only if the prompt runs it | record the `mutants.sh` result; `pr.sh` requires it | [3](report/3-review-gate.md) |
| F3.5 | Medium | P14 | "copilot: code review requested" is printed when no review was requested | print it only when the answer lists Copilot | [3](report/3-review-gate.md) |
| F3.6 | Medium | P26 | pre-PR scanners and `/security-review` are presented as built in; only the prompt runs them | record the scan; `pr.sh` requires it | [3](report/3-review-gate.md) |
| F3.7 | Medium | P10 | the hint for a missing task review tells the user to record a plan review, on every refusal | `$($plan && echo ' --plan')` | [3](report/3-review-gate.md) |
| F3.8 | Medium | P15 | on full, the analysis requirement is met by running `analyzed.sh` alone | `analyzed.sh` takes the analysis report | [3](report/3-review-gate.md) |
| F3.9 | Medium | P13 | common test layouts are not seen as tests, so weakening them needs no explanation | widen `TEST_PATH_RE`, let the constitution add one | [3](report/3-review-gate.md) |
| F4.1 | Medium | P17 | Dependabot updates 2 of the 9 pinned actions and none of the 4 pinned tools | a dispatch-only workflow using every pin, a version check for tools | [4](report/4-ci-supply-chain.md) |
| F4.2 | Medium | P25 | the audit's private-advisory call is refused by GitHub (422) | send the full JSON body | [4](report/4-ci-supply-chain.md) |
| F4.3 | Medium | P25 | the PR prompt copies a security finding from the review into the public PR body | security findings are one line in `review.md` and `pr.md` | [4](report/4-ci-supply-chain.md) |
| F4.4 | Medium | P16, P28 | on lite there is no CI gate and no GitHub protection, while the docs call them the boundary | name the levels in the docs; offer free protections on every level | [4](report/4-ci-supply-chain.md) |
| F4.5 | Medium | P16 | Semgrep is version-pinned but not checksum-verified, and its rules are fetched at run time, while the README says all pinned and checksum-verified | image pinned by digest; docs say where the rules come from | [4](report/4-ci-supply-chain.md) |
| F4.7 | Medium | P17 | a refresh with `init` puts a project's newer action pins back to older ones | `put` keeps newer pins | [4](report/4-ci-supply-chain.md) |
| F5.3 | Medium | P19, P21 | a project set up before 1.4.0 keeps every generated file at its old version, hooks included | recognize past releases' files | [5](report/5-levels-files.md) |
| F5.6 | Medium | P24 | v1.7.2 was never tested on macOS | run the macOS job on PRs that touch scripts, and on tags | [5](report/5-levels-files.md) |
| F1.3 | Low | P04 | `/speckit-implement Tnnn` starts a blocked or already-done task | none (docs honest) | [1](report/1-task-chain.md) |
| F1.4 | Low | P02 | untracked files of another feature block a task from starting | name the paths in the message | [1](report/1-task-chain.md) |
| F1.5 | Low | P04 | `next` exits with no message when origin or `gh pr list` cannot be reached | `die` with the reason | [1](report/1-task-chain.md) |
| F2.2 | Low | P08 | the guard refuses valid commands | treat key reads as reads; follow `cd` and `switch` | [2](report/2-secrets-guard.md) |
| F2.5 | Low | P06 | secret formats the docs never list are not caught | list the covered formats | [2](report/2-secrets-guard.md) |
| F3.2 | Low | P11 | editing `spec.md`, `research.md` or `quickstart.md` after the plan review keeps it valid | hash the whole feature folder | [3](report/3-review-gate.md) |
| F4.6 | Low | P27 | a release goes out on any version tag, with no audit or CI requirement | require a passing Security run on the tag | [4](report/4-ci-supply-chain.md) |
| F5.1 | Low | P19 | an edit inside a managed file is replaced by the next `level` or `init` | back up the old content and say where | [5](report/5-levels-files.md) |
| F5.5 | Low | P21 | the README says `init` commits nothing; since 1.7.1 it offers to | fix the README sentence | [5](report/5-levels-files.md) |

**Design and prompts** (not ranked, sections 6–8):

| part | verdict | in one line |
|---|---|---|
| D1 one task = issue = branch = PR into the base | simplify | keep the task-sized PR; merge task PRs into one feature branch, one PR to the base ([7](report/7-core-model.md)) |
| D2 the spec is its own PR into the base | replace | the spec is the feature branch's first commit ([7](report/7-core-model.md)) |
| D3 three levels | simplify | let the review bar scale with the level; say what lite lacks ([7](report/7-core-model.md)) |
| own rules | 15 of 28 rows `exception missing` | 6 are findings above; the rest are history before the constitution, tests per script, `.env` ignore, GUARDRAILS sources, scripts outside `lib.sh`, no "seen to fail" line in PRs, and the repository running the previous release ([6](report/6-own-rules-cost.md)) |
| prompts C01–C11 | 3 follow, 7 depart (2 with reason written), 1 unverified | biggest: `/jit-speckit:new` loads 7,401 words before its first question (C04) ([8](report/8-context-engineering.md)) |

## Fixes

One entry per public High and Medium finding. Each check fails today and passes after the fix.
F2.1's fix is in its private advisory.

### Fix F5.2 · `remove.sh` keeps a marked file that has uncommitted edits or differs from what jit wrote

- **promise**: P20, `remove` deletes only what still matches what jit wrote.
- **change**: `put()` records the SHA-256 of every file it writes in `.specify/jit-files.sha256`;
  `bin/remove.sh` deletes a marked file only when its hash matches that record, or, with no
  record (a project set up before the fix), only when it is tracked and `git diff --quiet HEAD`
  says it is unchanged; otherwise it prints `kept (edited): <file>`.
- **check** (`tests/setup.test.sh`): when a managed workflow (committed alone) has an uncommitted
  edit, then `remove.sh` keeps it and prints `kept (edited)`.

### Fix F5.4 · `setup.sh` refuses to downgrade a project without `--downgrade`

- **promise**: P21 (and P10, whose gate a downgrade removes).
- **change**: `bin/setup.sh` reads `version:` from `.specify/extensions/jit/extension.yml` and
  refuses to go below it without `--downgrade`: "this plugin copy is <old>, the project is at
  <new>; run /reload-plugins".
- **check** (`tests/setup.test.sh`): when the project's extension is at a newer version than the
  plugin, then `setup.sh` exits non-zero and prints `/reload-plugins`.

### Fix F1.1 · `branch.sh` warns when the claim push is refused

- **promise**: P02, P04, a started task is claimed on origin.
- **change**: on a failed push at `branch.sh:56`, print `jit: warning: could not claim <branch>
  on origin: <git's error>; other clones may start this task` to stderr, and still exit 0.
- **check** (`tests/branch.test.sh`): when origin refuses the claim push, then `branch.sh` exits 0
  and its output contains `could not claim`.

### Fix F1.2 · `next.sh` looks up each task's issue state by number

- **promise**: P03, P04, a task is done when its issue closes.
- **change**: replace the `--search "$num in:title"` list (`next.sh:31`) with one GraphQL query for
  the issue numbers in `tasks.md`.
- **check** (`tests/next.test.sh`): when a closed task issue has no `[NNN]` in its title, then
  `next` shows it `done` (and the fake `gh` asserts no `--search`).

### Fix F1.6 · `close-linked-issues.yml` closes every number, then fails if one failed

- **promise**: P03, P04.
- **change**: replace `|| true` with `failed+=" #$n"` inside the loop and
  `[ -z "$failed" ] || { echo "could not close:$failed"; exit 1; }` after it.
- **check** (`tests/static.test.sh`, the step run with a fake `gh` failing on 12): when the body
  says "fixes #12" and "Closes #3", then the step exits non-zero (fails today: exit 0), and
  `gh issue close 3` is still called (a guard: true today too).

### Fix F1.7 · `issues.sh` reuses a task's issue that GitHub created but never confirmed

- **promise**: P01, an interrupted run never makes duplicates.
- **change**: before `gh issue create`, look for an issue (any state) titled `[NNN] Tnnn:`; when
  there is one, write its number back instead of creating another.
- **check** (`tests/issues.test.sh`): when the first `gh issue create` for a task reached GitHub but
  failed on the client, then a rerun makes no second `issue create` for that task and writes the
  existing number back.

### Fix F1.8 · `pr.sh spec` stops when it cannot ask for the open spec PR

- **promise**: P05, the spec folder and the spec PR are never lost.
- **change**: drop `2>/dev/null || true` at `pr.sh:79`; on failure `die "could not check for an
  open spec PR"` after gh's own error.
- **check** (`tests/pr.test.sh`): when `gh pr list` fails while a spec PR is open with someone
  else's commit, and the local clone has fetched origin after that commit, then `pr.sh spec`
  exits non-zero and origin's spec branch still has that commit. Without the fetch,
  `--force-with-lease` already refuses and the check proves nothing.

### Fix F1.9 · `next` on a task branch serves that branch's feature

- **promise**: P04, `next` follows the branch it runs on, so a worktree never follows the main
  checkout.
- **change**: with no argument, `next.sh` uses the current branch's feature when the branch is a
  task branch, and asks only on any other branch.
- **check** (`tests/next.test.sh`): when the current branch is a task branch of one feature and
  another feature also has tasks to start, then `next` with no argument prints that feature's
  tasks and no `CHOOSE=`.

### Fix F2.4 · the docs give 2.1.295 as the plugin's minimum Claude Code version

- **promise**: P08, the guard blocks a command when it fails, on every supported version.
- **change**: the constitution's "Stack", `README.md` next to the install line, and
  `docs/security.md`'s guard row say Claude Code 2.1.295 or newer, the version `onFailure` needs;
  the README's "on older versions use two prompts" fallback covers only versions at or above it
  (or goes).
- **check** (`tests/static.test.sh`): when `hooks/hooks.json` uses `onFailure`, then every
  "Claude Code <version> or newer" in `README.md` and the constitution is 2.1.295 or newer, and
  the README offers no install path for versions below it.

### Fix F2.3 · `guard.sh` refuses abbreviated `--no-verify` and judges a commit by the branch switched to

- **promise**: P08, the command guard within its documented scope.
- **change**: refuse any prefix of `--no-verify` (at least 3 characters) for `commit`, `push`,
  `merge`, `rebase` and `am`, and `am -n` like `commit -n` (`cherry-pick` and `revert` take no `--no-verify` and keep their
  exact-word check); and judge commits and `HEAD` pushes
  after a `git switch|checkout <branch>` in the same chain against every branch the chain may
  be on.
- **check** (`tests/guard.test.sh`): when one of those subcommands uses an abbreviated
  `--no-verify` (built at run time), or `am -n`, or a chain switches to `main` and then commits,
  then `guard.sh` exits 2.

### Fix F3.1 · `pr.sh task` attaches the recorded review to the PR, and the docs say what the gate proves

- **promise**: P10, P11 (and P25, with Fix F4.3).
- **change**: `pr.sh task` folds the recorded report's *What changed*, *Findings* and
  `Assessment:` line into the PR body in `<details><summary>Independent review</summary>`, copying
  no line after a `Security: reported privately (<id>)` marker; `docs/design.md` says the gate
  proves "a recorded report that said ready for this exact diff, attached to the PR".
- **check** (`tests/pr.test.sh`): when a review is recorded and `pr.sh task` opens the PR, then the
  body sent to `gh pr create` contains the report's text; when the report holds a security
  finding, then the body does not contain that finding's text.

### Fix F3.3 · `pr.sh task` runs the constitution's test command before pushing

- **promise**: P12, never open a PR on red checks.
- **change**: run `constitution_cmd test` before the push and refuse with its last lines on
  failure; with no test command, say so and go on.
- **check** (`tests/pr.test.sh`): when the constitution's test command exits 1, then `pr.sh task`
  exits non-zero, prints that output and pushes nothing.

### Fix F3.4 · `mutants.sh` records its result per diff, and `pr.sh task` requires it

- **promise**: P13, mutation testing runs on the change.
- **change**: `mutants.sh` writes its result line to `.git/jit-mutants/<diff patch id>`;
  `pr.sh task` refuses when there is none for this diff, or on `survivors` with no `## Evidence`
  line naming them. `missing` stays allowed and goes into the body.
- **check** (`tests/pr.test.sh`): when the constitution has a `mutate` command and `mutants.sh`
  was not run on this diff, then `pr.sh task` refuses and names `mutants.sh`.

### Fix F3.5 · `pr.sh` reports the Copilot request from GitHub's answer

- **promise**: P14.
- **change**: print `copilot: code review requested` only when the answer's `requested_reviewers`
  contains the Copilot login; otherwise `copilot: not requested (GitHub did not add the reviewer)`,
  naming no cause.
- **check** (`tests/pr.test.sh`): when the fake `gh` answers with no reviewer listed, then the
  output does not contain `code review requested` (fails today); and when it lists `Copilot`,
  then it does (a guard against a line that always says "not requested").

### Fix F3.6 · `security-scan.sh --changed` records its result per diff, and `pr.sh task` requires it

- **promise**: P26, the scanners run on the changed files before each PR.
- **change**: `security-scan.sh --changed` writes its result to `.git/jit-security/<diff patch
  id>`, and `pr.sh task` refuses when there is none for this diff.
- **check** (`tests/pr.test.sh`): when no scan was recorded for this diff, then `pr.sh task`
  refuses and names `security-scan.sh`.

### Fix F3.7 · the missing-review hint names the right record command

- **promise**: P10, the PR is refused without a recorded `ready` for the exact diff; its refusal
  should say how to record one.
- **change**: `review.sh:45` builds the hint with `$($plan && echo ' --plan')`.
- **check** (`tests/review.test.sh`): when `review.sh check` runs on a task branch with no record,
  then its hint has no `--plan`.

### Fix F3.8 · `analyzed.sh` takes the analysis report and refuses without one

- **promise**: P15, on full `/speckit-analyze` is required.
- **change**: `analyzed.sh <report-file>` refuses a file without `/speckit-analyze`'s section
  headings, and keeps the report next to the hash.
- **check** (`tests/branch.test.sh`): when `analyzed.sh` is run with no report, then it refuses
  and `branch.sh` on full still refuses.

### Fix F3.9 · `TEST_PATH_RE` covers common test layouts, and the constitution can add one

- **promise**: P13, a PR that changes existing tests needs `## Test changes`.
- **change**: the case-sensitive pattern given in section 3 (F3.9), tested there against 9 test and
  13 source paths, plus a `tests: <regex>` line the constitution can add.
- **check** (`tests/pr.test.sh`): when an existing `app/tests.py` or
  `Tests/AppTests/AppTests.swift` is edited and the body has no `## Test changes`, then
  `pr.sh task` refuses and names the file; when `src/latest.ts` is edited, then it is not refused.

### Fix F4.1 · a dispatch-only workflow uses every pin, and a weekly job checks tool versions

- **promise**: P17, Dependabot keeps the pins current.
- **change**: add `.github/workflows/pins.yml` (`on: workflow_dispatch`) with one job that `uses:`
  every action in `pins.sh`, so Dependabot proposes each and `sync-pins.sh` carries it over; a
  weekly job compares each `*_VERSION` with the latest release and opens an issue.
- **check** (`tests/static.test.sh`): when `pins.sh` has a `PIN_*` action, then some file in
  `.github/workflows/` uses it.

### Fix F4.2 · the audit's advisory call sends the body GitHub accepts

- **promise**: P25, security findings go to a private place.
- **change**: in `skills/security/SKILL.md`, send JSON with `--input -`, with `severity` and a
  `vulnerabilities` entry (ecosystem `other`), and look up existing advisories by summary first, so a retry makes no duplicate.
- **check** (`tests/static.test.sh`): when the skill's advisory call is read, then the JSON after
  `--input -` names `summary`, `description`, `severity`, `vulnerabilities` and `ecosystem`, and
  a `--paginate` lookup comes before the `-X POST`. A file-wide grep for `vulnerabilities` and `severity` already passes
  today, so the check reads the call only.

### Fix F4.3 · security findings are one line in the review report and in `## Review`

- **promise**: P25.
- **change**: `extension/commands/review.md` reports each security finding as `Security: reported
  privately (<id>)`, its detail only in the recorded file; `extension/commands/pr.md` step 5 puts
  only that line into `## Review`. Shares its marker with Fix F3.1.
- **check** (`tests/static.test.sh`): when `pr.md` step 5 and `review.md`'s report section are
  read, then both say a security finding is one line.

### Fix F4.4 · the docs name the levels the CI gate exists on, and `init` offers free protections on every level

- **promise**: P16, P28.
- **change**: the README's "every PR, and weekly" row gets "(standard and full)";
  `docs/security.md` says on lite the boundary is only the local hooks; `skills/init/SKILL.md`
  offers secret scanning with push protection and private vulnerability reporting on every level
  for a public repository.
- **check** (`tests/static.test.sh`): when the README's CI row is read, then it names its levels.

### Fix F4.5 · Semgrep runs from an image pinned by digest, and the docs say where its rules come from

- **promise**: P16, every CI tool is pinned and checksum-verified.
- **change**: run Semgrep in the full-level `security.yml` from `semgrep/semgrep@sha256:<digest>`,
  with the digest next to its version in `pins.sh`, instead of `uvx --from semgrep==<version>`;
  the README and `docs/security.md` say its rule sets come from the Semgrep registry at run
  time. Rules are not vendored: the Semgrep Rules License forbids redistributing them.
- **check** (`tests/level.test.sh`, `tests/static.test.sh`): when `level.sh full` writes
  `security.yml`, then its Semgrep job runs `semgrep/semgrep@sha256:<64 hex>` equal to
  `pins.sh`'s digest and nothing installs Semgrep by version alone; and when the README CI row
  and `docs/security.md` are read, then they say the rules come from the Semgrep registry.

### Fix F4.7 · `put` keeps a managed workflow's newer action pins

- **promise**: P17.
- **change**: before rewriting a managed workflow, keep each `uses: <action>@<sha> # <version>`
  line whose version is newer than `pins.sh`'s (compared by a pure-bash `version_newer` in
  `lib.sh`, not `sort -V`, which BSD and busybox may lack), and print `kept newer pin: <action>
  <version>`.
- **check** (`tests/level.test.sh`): when a managed workflow carries a newer checkout pin than
  `pins.sh`, then `level.sh` keeps it and prints `kept newer pin`.

### Fix F5.3 · setup recognizes files earlier releases wrote without the marker

- **promise**: P19, P21.
- **change**: `put` treats a file byte-identical to a hook an earlier release wrote (a list of
  SHA-256s kept in the extension) as jit's, and names the others it recognizes: `kept (written by jit-speckit <versions>, no marker): <file> — delete it to get
  the current one` (and `<versions> or older` for generated files).
- **check** (`tests/level.test.sh`, with v1.3.0's hook as a committed fixture, since CI's checkout
  has no tags): when `.githooks/pre-commit` is v1.3.0's exact file, then `level.sh` replaces it and it carries the marker; and when
  `close-linked-issues.yml` is v1.3.1's exact file, then it is kept and
  named in a `kept (written by jit-speckit 1.3.1` line (replacing it would
  undo a take-over, since 1.4.0+'s copy without its marker has the same bytes).

### Fix F5.6 · the macOS job runs on PRs that touch scripts, and on tags

- **promise**: P24, runs on macOS (BSD tools).
- **change**: move the `macos` job from `test.yml` into its own `.github/workflows/macos.yml`,
  run on pull requests touching `extension/scripts/`, `bin/`, `hooks/` or `tests/` (a path
  filter is per workflow) and on every tag.
- **check** (`tests/static.test.sh`): when `macos.yml` is read, then it runs on pull requests
  touching `extension/scripts/`, `bin/` or `hooks/`, and on every tag;
  and `test.yml` has no `runs-on: macos` left.


**Low findings** get no fix entry. Those marked "none (docs honest)" in the summary, like F1.3,
need nothing; the others carry a one-line note in their section that a later task can pick up.

## Unverified

| claim | section | what would check it |
|---|---|---|
| with the pre-commit framework, a push of several branches re-scans only the last ref | [2](report/2-secrets-guard.md) | a pre-commit-managed throwaway repo, two branches with a token each, `git push origin a b` |
| on Claude Code before 2.1.295 a guard timeout or crash lets the command through (F2.4) | [2](report/2-secrets-guard.md) | rests on the hooks reference; run the guard with a forced timeout on a Claude Code older than 2.1.295 |
| why no Copilot review was requested: no Copilot code review on this account, or the wrong reviewer login (F3.5) | [3](report/3-review-gate.md) | GitHub's REST docs page on requesting a Copilot review, or `pr.sh`'s call on an account that has it |
| a task PR from a fork cannot close its issue, because its token is read-only (F1.6) | [1](report/1-task-chain.md) | a task PR from a fork of the sandbox, merged into `develop` |
| a lost answer from a real `gh issue create` duplicates the issue on rerun (F1.7) | [1](report/1-task-chain.md) | run against the fake `gh` only; cut the connection after the create on the sandbox |
| the generated trivy job | [4](report/4-ci-supply-chain.md) | its checksum pin was checked; generate it in a repo with a Dockerfile and read the job |
| DORA's 2025 model lists small batches among its capabilities (`docs/design.md`) | [7](report/7-core-model.md) | open the capabilities PDF on cloud.google.com |
| `Closes #N` in task PRs reaches the default branch through merge or squash commit messages | [7](report/7-core-model.md) | on the sandbox, set both commit messages to the PR's description, merge a feature branch, see whether the task issues close |
| review round times per task and for the plan review | [6](report/6-own-rules-cost.md) | the reports are in this clone's `.git/jit-review/` only; they cannot be re-checked from GitHub |
| skill sizes against `/doctor` (C11) | [8](report/8-context-engineering.md) | run `/doctor` with the plugin loaded and paste its output |
