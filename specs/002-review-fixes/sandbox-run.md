# Sandbox run: 1.8.0 end to end (T008)

Run on 2026-11-06 against `iamalisson/jit-speckit-sandbox` (private; default branch `master`,
base branch `develop`), with jit-speckit from this repository's `main` at `26c3606` (all of
T001–T007, T010–T012 merged), Claude Code 2.1.319. Live sessions are headless:
`claude -p --plugin-dir <main worktree> …` run from the sandbox clone, so the plugin, its hooks
and its skills are `main`'s. The version files still say 1.7.2 (T009 bumps them), which is why
`init` printed "1.7.2": every installed script was compared with `main`'s and is identical.

Every command ran after `[ "$(git remote)" = origin ] && [ "$(gh repo view --json nameWithOwner
-q .nameWithOwner)" = iamalisson/jit-speckit-sandbox ] || exit 1`; direct `gh` writes pass
`-R iamalisson/jit-speckit-sandbox`. No guard-bypass form was run or written.

**Result: every step holds.** Nothing needs a fix task before T009. The observations at the end
are Lows for a later feature.

## Before step 1: what was recorded, to be put back

```
$ gh api repos/iamalisson/jit-speckit-sandbox --jq '{allow_rebase_merge, allow_merge_commit, allow_squash_merge, squash_merge_commit_title, squash_merge_commit_message, security_and_analysis, delete_branch_on_merge}'
{"allow_merge_commit":true,"allow_rebase_merge":true,"allow_squash_merge":true,"delete_branch_on_merge":false,"security_and_analysis":null,"squash_merge_commit_message":"COMMIT_MESSAGES","squash_merge_commit_title":"COMMIT_OR_PR_TITLE"}
$ gh api repos/iamalisson/jit-speckit-sandbox/private-vulnerability-reporting
{"message":"Not Found",…,"status":"404"}
$ gh api repos/iamalisson/jit-speckit-sandbox/branches/{master,develop,staging}/protection
master: "Branch not protected" · develop: "Branch not protected" · staging: "Branch not found"
```

The restore commands: `gh api -X PATCH repos/iamalisson/jit-speckit-sandbox -F allow_rebase_merge=true
-F allow_merge_commit=true -F allow_squash_merge=true -f squash_merge_commit_title=COMMIT_OR_PR_TITLE
-f squash_merge_commit_message=COMMIT_MESSAGES -F delete_branch_on_merge=false`, and
`gh api -X DELETE …/branches/<b>/protection` for `master` and `develop` (both unprotected);
`staging` did not exist, so a `staging` the run creates is deleted. Private vulnerability reporting stays as it was: 404, never changed.

## Step 1. Install from `main`, `init` at lite, then `level standard`, then `level full`

On a branch `sandbox-002-t008-setup` from `origin/develop`:

```
$ claude -p --plugin-dir <main> "/jit-speckit:init  (answers up front: level lite, yes to every GitHub setting)"
$ gh api -X PATCH repos/{owner}/{repo} -F allow_rebase_merge=false
{"allow_rebase_merge":false}
$ gh api -X PATCH repos/{owner}/{repo} -F allow_merge_commit=false -F allow_squash_merge=true -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY
{"allow_merge_commit":false,"allow_rebase_merge":false,"allow_squash_merge":true,"squash_merge_commit_message":"PR_BODY","squash_merge_commit_title":"PR_TITLE"}
(the session) The repo is PRIVATE: secret scanning with push protection needs GitHub Secret Protection, and private vulnerability reporting only works on public repos.
$ for f in <main>/extension/scripts/*.sh; do cmp -s $f .specify/extensions/jit/scripts/$(basename $f) || echo DIFF; done
(no output: identical)
```

```
$ claude -p --plugin-dir <main> "/jit-speckit:level standard  (yes to every offer)"
$ gh api -X PUT …/branches/{master,develop}/protection --input -
{"required_status_checks":{"strict":true,"contexts":["python","Secrets (gitleaks, full history)","Dependencies (osv-scanner)","Workflows (zizmor)"]},"enforce_admins":true,"required_pull_request_reviews":{"required_approving_review_count":0},"restrictions":null}
read back: {"allow_merge_commit":false,"allow_rebase_merge":false,"allow_squash_merge":true}
master: {"admins":true,"approvals":0,"checks":["python","Secrets (gitleaks, full history)","Dependencies (osv-scanner)","Workflows (zizmor)"],"strict":true}
develop: (the same)
```

```
$ claude -p --plugin-dir <main> "/jit-speckit:level full  (yes to every offer; staging may be pushed)"
level.sh: git push origin refs/remotes/origin/master:refs/heads/staging
$ gh api -X PUT …/branches/staging/protection --input -   (the same body; 0 approvals: one contributor)
read back: {"allow_merge_commit":false,"allow_rebase_merge":false,"allow_squash_merge":true}
master, develop, staging: {"admins":true,"approvals":0,"checks":["python","Secrets (gitleaks, full history)","Dependencies (osv-scanner)","Workflows (zizmor)"]}
```

- Expected: lite turns merge commits off (squash only); standard and full keep that and add
  branch protection on their branches, with the real job names; on a private repo the public-repo
  offers are one line. **Holds.**

The setup was committed by name and merged into `develop` as sandbox PR #18 (squash, all five
checks green). Two files there were not managed (`security.yml` came from the project's own
setup, `close-linked-issues.yml` from an old release), so `level` kept them; they were deleted
and `level.sh full --no-branches` re-created both as managed files (see observation O2).

## Step 2. Every setting `init` offered, read back against contracts/output-lines.md

| Setting | Offered | Read back | Contract |
|---|---|---|---|
| `allow_rebase_merge` | every level | `false` | "rebase merges off" |
| `allow_merge_commit`, `allow_squash_merge`, squash title/message | lite | `false`, `true`, `PR_TITLE`, `PR_BODY` | "on lite, merge commits off too" |
| secret scanning, push protection | not offered: private | `security_and_analysis: null` | "on a PRIVATE repo, say in one line" |
| private vulnerability reporting | not offered: private | 404 (unchanged) | same |
| branch protection | standard, full | as in step 1 | job names, not workflow names; 0 approvals on standard, and on full with one contributor |

**Holds.**

## Step 3. One feature, `098-t008-run`, through the real path

```
$ claude -p --plugin-dir <main> "/speckit-jit-issues"
(plan review) Agent jit-speckit:reviewer opus 'jit-speckit review: independent reviewer\n\n…'
$ bash .specify/extensions/jit/scripts/review.sh record --plan /tmp/tmp.0Y07tMIvIN
REVIEW=ready
$ bash .specify/extensions/jit/scripts/issues.sh
T001 → #19
T002 → #20
T003 → #21
CREATED=3 SKIPPED=0
```

Full requires the analysis (F3.8, step 4). Then `/speckit-analyze`, `analyzed.sh <report>`
(`ANALYZED=098-t008-run`), `pr.sh spec` (sandbox PR #22, merged; the three task issues stay
open). T001:

```
$ claude -p --plugin-dir <main> "/speckit-implement T001"
$ bash .specify/extensions/jit/scripts/branch.sh 098 T001
claim: feat/098-t001-add-docs-098-note pushed to origin
BRANCH=feat/098-t001-add-docs-098-note ISSUE=19 TASK=T001 BASE=develop
$ bash .specify/extensions/jit/scripts/review.sh record /tmp/jit-review-U2McbQ.md
REVIEWED=ecd6a6934561f9ca09401dcdb070d8fd70368d48
REVIEW=ready
$ bash .specify/extensions/jit/scripts/pr.sh task T001 "docs(098): add docs/098-note.md with one line" <body>
copilot: not requested (GitHub did not add the reviewer)
PR=https://github.com/iamalisson/jit-speckit-sandbox/pull/23
```

Merged (squash) into `develop`; the `close-linked-issues` job closed #19
(`✓ Closed issue iamalisson/jit-speckit-sandbox#19`), then:

```
$ bash .specify/extensions/jit/scripts/next.sh 098
done T001 #19 Add docs/098-note.md with one line
in-progress T002 #20 Make `tempconv --version` print the package version,
open T003 #21 Extend docs/098-note.md with a second line (depends on T001)
DONE=1/3 IN_PROGRESS=1 NEXT=T003
```

- The issue `CLOSED`, `next` prints `done`. **Holds.**
- **F1.2**, a renamed closed issue: `gh issue edit 19 --title "[002 sandbox T008] renamed after close"`,
  then `next.sh 098` printed `done T001 #19 …` again (the title was put back after). **Holds.**
- **F1.9**, `next` on a task branch: on `feat/098-t002-…` with `.specify/feature.json` pointing at
  `specs/099-jit-review`, `next.sh` (no argument) printed feature 098's tasks
  (`resume T002 #20 …`, `DONE=1/3 … NEXT=T002`). **Holds.**

## Step 4. Each new refusal, for real

| Check | Command and real output | Expected (contracts/output-lines.md) | |
|---|---|---|---|
| F3.8 | `analyzed.sh` → `jit: usage: analyzed.sh <report-file> (the /speckit-analyze report, saved as it came)`, exit 1; an empty file → `jit: … is not a /speckit-analyze report (no "Specification Analysis Report" or "Coverage Summary Table")`, exit 1 | refused without a report | **holds** |
| F1.1 | a second clone pushed `feat/098-t002-make-tempconv-version-print` with its own commit first; this clone's `branch.sh 098 T002` (its fetch made to see nothing, as when the other push lands right after it) → `jit: warning: could not claim feat/098-t002-make-tempconv-version-print on origin: … ! [rejected] … (non-fast-forward) …; other clones may start this task`, exit 0 | `jit: warning: could not claim <branch> on origin: <git's error>; other clones may start this task` (exit 0) | **holds** |
| FR-036 | `next.sh 098` → `parallel T002 (git worktree add --quiet --detach …/jit-speckit-sandbox-098-t002 origin/develop && cd … && bash .specify/extensions/jit/scripts/branch.sh 098 T002)`; that line, run as printed, started T002 (`BRANCH=feat/098-t002-… ISSUE=20 TASK=T002`) | a ready-to-run start line per other startable `[P]` task | **holds** |
| F3.9 | a commit editing `app/tests.py` (added to `develop` by sandbox PR #24), body without `## Test changes` → `jit: existing tests were changed: app/tests.py` / `add a '## Test changes' section …`, exit 1 | today's message, naming the file | **holds** |
| FR-030 | a commit touching `.github/workflows/ci.yml`: `review.sh risk` → `RISK=ci .github/workflows/ci.yml`; a report without a line for it → `jit: the report does not check .github/workflows/ci.yml (ci): add '- deep: .github/workflows/ci.yml' or '- proven: .github/workflows/ci.yml by <test file:line>'`, exit 1 | refused | **holds** |
| FR-032 | real round 1 (full, `/speckit-jit-review`) on T002: `Assessment: changes needed` (one Medium: the README and CLI contract did not document `--version`), recorded `round: full`; fix commit `83d60e8`; real delta round: `review.sh record --delta …` → `REVIEWED=83d60e8… REVIEW=ready`, recorded `round: delta` | a delta after a recorded full review is accepted | **holds** |
| F3.4 | `constitution` with `mutate \`uv run mutmut run\``, no `mutants.sh` run → `jit: no mutants.sh result for this diff; run bash .specify/extensions/jit/scripts/mutants.sh after the last commit`, exit 1 | refused | **holds** |
| F3.6 | after `mutants.sh` (`mutants ok …`), no scan → `jit: no security-scan.sh --changed result for this diff; run bash .specify/extensions/jit/scripts/security-scan.sh --changed after the last commit`, exit 1 | refused | **holds** |
| F3.3 | after the scan, a failing test file (git-excluded, so the reviewed diff is unchanged) → pytest's `1 failed, 52 passed` tail, then `jit: the test command failed (uv run pytest); fix it before opening the PR`, exit 1; no PR opened (`gh pr list --head …` → 0) | refused | **holds** |
| F3.1 | PR #23's body: `<details><summary>Independent review</summary>` with `Independent review recorded for this diff (patch id e5bc32753d96)` / `Assessment: ready` / `Model: claude-opus-5-5` and nothing of the report | the recorded facts only | **holds** |
| F3.5 | `pr.sh task T001` → `copilot: not requested (GitHub did not add the reviewer)`; `gh api …/pulls/23/requested_reviewers` → `[]` | says what really happened | **holds** |
| FR-034 | the Agent calls the sessions made, from a `PreToolUse` capture hook: `/speckit-jit-issues`, `/speckit-implement T001` and both T002 rounds each launched `Agent jit-speckit:reviewer opus 'jit-speckit review: independent reviewer\n…'` | `jit-speckit:reviewer`, `model: opus`, the sentinel | **holds** |
| FR-034 | `review_model: haiku` (uncommitted, reverted after) → the session printed `jit: review_model must be sonnet, opus or fable` and launched no reviewer | refused | **holds** |
| FR-034 | probes: `jit-speckit:reviewer` on `haiku` → `jit: the review must run on sonnet, opus or fable (review_model:), not haiku`; `general-purpose` with the sentinel and no model → `… not the session's model`; `fork` with the sentinel on `opus` → `jit: the review must run in a fresh agent, not a fork of this session`; `jit-speckit:reviewer` on `opus` → ran (`PONG`) | blocked, blocked, blocked, allowed | **holds** |

The hook's input, from a real 2.1.319 session (T011 deferred this):

```
{"session_id":"…","cwd":"/home/admin/Documents/workstation/temp/jit-speckit-sandbox","permission_mode":"default","hook_event_name":"PreToolUse","tool_name":"Agent","tool_use_id":"toolu_…","tool_input":{"description":"probe","prompt":"jit-speckit review: independent reviewer\nReply with the single word PONG.","subagent_type":"jit-speckit:reviewer","model":"haiku","run_in_background":false}}
```

`tool_name` is `Agent`; `subagent_type`, `model` and `prompt` are in `tool_input`, as
`hooks/guard-review.sh` reads them. The scoped id `jit-speckit:reviewer` is accepted by the
Agent tool, so the `general-purpose` fallback is not what ships.

## Step 5. On full: Semgrep by digest, and a close that fails loudly

- **F4.5**: sandbox PR #18's `Code (semgrep, OWASP rules)` job (run 42232177802):
  ```
  ##[command]/usr/bin/docker pull semgrep/semgrep@sha256:2e45517a85e13a9cca14a2a00df6bb48affd66b8ebfae1b0991cd57578362fb0
  ```
  `SEMGREP_DIGEST="2e45517a85e13a9cca14a2a00df6bb48affd66b8ebfae1b0991cd57578362fb0"` in
  `pins.sh`; the job passed. **Holds.**
- **F1.6**: just before the merge, the newest issue was #21 and the newest PR #23, so `#24` was no
  one's item. PR #23's body named `Closes #19` and `Closes #24`; merged into `develop`. The
  `close-linked-issues` run 42234396250 (conclusion `failure`):
  ```
  ✓ Closed issue iamalisson/jit-speckit-sandbox#19 ([098] T001: Add docs/098-note.md with one line)
  GraphQL: Could not resolve to an issue or pull request with the number of 24. (repository.issue)
  could not close: #24 (see the errors above); close them by hand
  ##[error]Process completed with exit code 1.
  ```
  and `gh issue view 19 --json state` → `CLOSED`. **Holds.**

## Step 6. `setup`, `remove` and refresh on a second clone (`develop`, level full)

| Check | Command and real output | Expected | |
|---|---|---|---|
| F5.4 | `extension.yml` edited to `version: "9.9.9"` (reverted after); `bin/setup.sh . --level full` → `jit: this plugin copy is 1.7.2, the project is at 9.9.9; run /reload-plugins (or setup.sh --downgrade)`, exit 1 | non-zero, names `/reload-plugins` | **holds** |
| F4.7 | `security.yml`'s `actions/checkout` pin edited to `@1111… # v99.0.0`; `level.sh full --no-branches` → `kept newer pin: actions/checkout v99.0.0` / `updated: .github/workflows/security.yml`, the v99 pin still there | `kept newer pin: <action> <version>` | **holds** |
| F5.3 | `.githooks/pre-commit` replaced by `tests/fixtures/v1.3.0-pre-commit`; `level.sh full --no-branches` → `updated: .githooks/pre-commit`, and its line 2 is now the managed-file marker | replaced, carries the marker | **holds** |
| F5.2 | `security.yml` (managed, committed) edited and not committed; `bin/remove.sh .` → `kept (edited): .github/workflows/security.yml` (the edit still in the file), while the unchanged managed files were removed | `kept (edited): <file>` | **holds** |

## Step 7. Cleanup

Created by the run, and what happened to each. The titles `issues.sh` and `pr.sh` wrote (issues
#19–#21 `[098] T00n: …`, PRs #22, #23) do not carry `[002 sandbox T008]`, as the Impact line
asks: those scripts make their own titles. Everything else the run named itself carries it.

| Item | Now |
|---|---|
| sandbox PRs #18, #22, #23, #24 | merged (a merged PR cannot be deleted; their commits stay on `develop`, which now carries jit-speckit `main` at level full, the `098-t008-run` spec, `docs/098-note.md` and `app/tests.py`) |
| issues #19 (closed by #23), #20, #21 | closed (#20, #21 with a cleanup comment) |
| branches `sandbox-002-t008-setup`, `spec/098-t008-run`, `feat/098-t001-add-docs-098-note`, `feat/098-t002-make-tempconv-version-print`, `sandbox-002-t008-apptests`, `staging` | deleted on origin and locally |
| the worktree `jit-speckit-sandbox-098-t002`, the second clone | removed |

Every recorded setting, read back after the restore:

```
{"allow_merge_commit":true,"allow_rebase_merge":true,"allow_squash_merge":true,"delete_branch_on_merge":false,"security_and_analysis":null,"squash_merge_commit_message":"COMMIT_MESSAGES","squash_merge_commit_title":"COMMIT_OR_PR_TITLE"}
master: Branch not protected · develop: Branch not protected · staging: (deleted, as before: not found)
private-vulnerability-reporting: 404
branches: chore/jit-speckit-1.7.2, dependabot/…/checkout-7.0.1, dependabot/…/setup-uv-10.3.3, develop, master (equal to the list read before step 1)
```

Equal to what was recorded. The open PRs #1, #2 and issues #5, #6 predate the run. Nothing the
run created is left open.

## Research's unverified items

- **R2** (Copilot): still unverified. This account has no Copilot code review: `pr.sh` printed
  `copilot: not requested (GitHub did not add the reviewer)` and `requested_reviewers` is `[]`,
  so which login GitHub returns for the bot is still unknown.
- **R3** (Semgrep): confirmed that the image is pulled by digest and that checkout v7.0.1 runs in
  it (the job passed); still unverified that `semgrep --version` prints the pinned version (the
  job does not print it; the digest fixes the image either way) and whether Dependabot bumps a
  `container.image` digest.
- **R6** (`init` settings): confirmed that the merge settings apply on a private repo with no plan
  restriction. Still unverified: the private-vulnerability-reporting PUT on a private repo (422 or
  not; only the GET ran, answering 404, and `init` does not offer the PUT on a private repo), and
  the push-protection PATCH on a public user repo (the sandbox is private).
- **R8** (pins): `version_newer` and `keep_pins` on bash 3.2 are confirmed by the `bash32` and
  macOS jobs on #70, and `keep_pins` live here (F4.7); still unverified: Dependabot's real run on
  `pins.yml`'s `if: false` job (merged today; no Dependabot run yet).

## Observations (Lows, not blocking T009)

- **O1.** After lite turns merge commits off, standard and full keep them off (as specified), so a
  promotion PR (`develop` → `master`) can only be squashed. `init` says standard and full "keep
  merge commits for the promotion PRs"; that holds only for a project that starts at standard.
- **O2.** `level full` on a project whose `security.yml` has no managed marker prints only
  `kept:    .github/workflows/security.yml`: the project stays without the Semgrep job, with no
  hint to delete the file (the old-release case does name it).
- **O3.** `uv run mutmut run` exits 0 with a surviving mutant, so `mutants.sh` printed
  `mutants ok` while round 1's reviewer found one (equivalent) survivor. `mutants.sh` documents
  that the command must exit non-zero on survivors; `/jit-speckit:adopt` should pick one that
  does for mutmut.
- **O4.** On full, `pr.sh spec` opens the spec PR before an analysis is recorded; `branch.sh`
  enforces it at task start, and the docs only ask the agent to wait.
- **O5.** `issues.sh` cuts a title at its first comma (`… the package version,`).
