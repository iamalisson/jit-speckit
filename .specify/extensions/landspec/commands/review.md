---
description: "Independent review of the branch (or of the plan, before issues) by a fresh reader grounded in the whole repository"
---

# Independent review

A fresh reader, not the author, in one fast pass, the way GitHub's Copilot code review works: it
reads the diff and the code around it, and reports few findings, each tied to a changed line. It
catches what the author's own session misses, because that session shares the author's assumptions.

**Two roles.** If you are the author's session (`/speckit-landspec-pr`, `/speckit-landspec-issues`, or the
user ran `/speckit-landspec-review`): launch one subagent of type `landspec:reviewer` whose prompt
starts with the line `landspec review: independent reviewer`, then this whole file plus the
facts below, and nothing else: no summary of what you built, no "I already checked X". Pass the
call's `model`: `review_model:` from `.specify/extensions/landspec/landspec-config.yml` when it is `sonnet`,
`opus` or `fable`, `sonnet` when the key is absent or empty. If `review_model:` holds any other
value, print `landspec: review_model must be sonnet, opus or fable` and stop.
Never run the review on `haiku`, and never in a fork of this session. If the call refuses the type `landspec:reviewer`
(the plugin is not installed), launch a `general-purpose` subagent with the same prompt and the
same `model`. The plugin's hook blocks a review launch without one of those models, or in a fork.
Wait for its report. The reviewer writes it to a file itself and names it on its first line,
`Report file: <path>`: record that file as it is, never a copy you typed or edited:
`bash .specify/extensions/landspec/scripts/review.sh record <file>` (`record --plan <file>` for a plan
review, `record --delta <file>` for a fix round). The record is tied to the exact diff (or `tasks.md`): `pr.sh` and `issues.sh` refuse to
open anything without a recorded review that said `ready` for the current state, at every level,
so a commit after the review means another review. If you are that subagent: follow the method,
write the report to a new file outside the repository (`mktemp`), and return `Report file: <path>`
on the first line, then the report exactly as written there.

Facts the author passes:
- the base branch and the branch under review, or, for a plan review, the feature folder
  `specs/NNN-*/`;
- the task's line from `tasks.md` with its sub-bullets, or "plan review";
- the path of the PR body draft, if there is one;
- the project's test command (the constitution's **Commands** line or its landspec block);
- for a fix round (a **delta**): the `REVIEWED=<sha>` the last `record` printed and the path of
  that round's report;
- for a plan review after a `changes needed` round: the path of that round's report and the
  author's one-line answer to each of its findings.

**A delta** reads `git diff <sha>..HEAD` only: it checks that each previous finding is fixed and
applies step 2 to the fix commits alone, and it never widens. A bug it notices outside those
commits is reported at its true severity and does not change the assessment. `record --delta` refuses it unless a round was
recorded on this branch, `<sha>` is still on the branch, something was committed since, and the fix
changes at most 20 lines outside the previous findings' files (test files aside); otherwise run a
new full review.

## Method

One pass. A review should take a couple of minutes, so read, do not run: CI runs the tests.

1. **Read the rules**, from the branch: `.specify/memory/constitution.md`, `AGENTS.md`, `CLAUDE.md`
   and `.github/copilot-instructions.md` where they exist, and the task's line in `tasks.md`.
2. **Read the diff and what it touches.** Run `bash .specify/extensions/landspec/scripts/review.sh risk`
   (for a delta, `review.sh risk <sha>`), then read `git diff origin/<base>...HEAD` once, and open
   what each changed function calls and what calls it. Look for real bugs in the changed lines:
   a wrong result, data loss, a crash, a broken upgrade on existing state, a write to the user's
   files, a secret, an injection, a check that lets through what it should refuse, an interface
   some people cannot use (text under 4.5:1 contrast, 3:1 for large text and icons: compute it from
   the colours in the diff and the background they sit on; a focus that is not visible; a control
   or image without an accessible name). Run a command
   only to settle whether a suspected bug is real, and only in a throwaway copy.

**Plan review** (before the issues are created): apply step 1 and read every task in `tasks.md`,
asking what happens where state already exists. *Impact* names every reference the task touches (search each symbol) and the newest
sibling of each file it adds; *Completed when* is a command that proves the real path, not only a
fresh state, at the level the behavior demands (logic: unit; through the interface: integration
against the real database or in-memory HTTP; a user-visible flow: one end-to-end); a step that writes data names its target and refuses production; every task names its failure
path (what the caller gets, the one log line, who is refused), and no task is a bare "error
handling", "logging" or "hardening" layer; no task deletes what another task still uses. **Shape:** a task is a vertical slice with an observable result. A
task that is one layer of a behavior another task completes (a model here, its migration there,
the endpoint in a third) is a finding: name the tasks to merge. So is a task whose diff would
clearly pass about 400 lines with its tests: name the behaviors to split it by (generated files,
lockfiles, and markup or data copied as is from an existing file do not count). **Inputs:** every
file, data set, URL or credential a task reads exists on `origin/<base>` (`git cat-file -e
origin/<base>:<path>`), in the spec folder, or in the task text; one that exists only in the
author's working tree (untracked, ignored) is a finding, since the next person starts from a
clean clone. **Commands** in *Completed when* run from any clone and directory: a `gh` call
without `--repo`, or a path relative to somewhere other than the repository root, is a finding.
**Earlier round:** when the author passes the last round's report, a finding it raised keeps its
severity unless the text it was about changed or you name a fact that round did not have. **Ships dark:**
each task is safe to reach production alone; a task that makes the feature visible to users
before its last task (a tab, route or menu entry with no flag off by default), a feature with no
last task that turns the flag on, or a migration the production code can't run against, is a
finding.

## Report

Written for the author, who fixes it, and for the human who merges:
- **What changed**: three lines at most, in your own words from the code, not from the PR body.
- **Risk map**, before the findings, one line per path you went deep on or skipped as proven:
  `- deep: <path> — <why risky>: <what you checked>`
  `- proven: <path> by <test file>:<n> — <what it asserts>`
  Write each line exactly as shown, from the start of the line, path first. Every `RISK=` path
  needs one; `review.sh record` refuses the report otherwise, and accepts `- proven:` only when
  `<test file>` is a test file at HEAD with a line `<n>`; gate, delete and test paths take
  `- deep:` only. Anything not listed was sampled. The PR shows these paths, never the text after
  them, and only paths in the diff.
- **Findings**, ranked: **High** (wrong result, data loss, a broken upgrade on existing state,
  security), **Medium** (a real bug: a guard the siblings have, an unhandled real-path
  case, a silent failure path), **Low** (worth a line, not a block: a test gap where the code
  behaves correctly, a test that cannot fail, wording). Each one: `file:line`, one concrete
  scenario of what goes wrong ("on a database built by `create_all` and stamped at the previous
  revision, `flask db upgrade` stops with 'already exists'"), and the evidence (the sibling's
  `file:line`, the command output). A finding you could not verify says so. No style, no naming,
  no nits: they are what gets reviews ignored. Accessibility is not style: a contrast, focus or
accessible-name failure is at least **Medium**, with the computed ratio as evidence. Matching a
sibling is not a defense: a defect copied from an existing file is still a defect in this diff. A **security** finding is listed last, and the PR
  shows it as one line, `Security: reported privately (<id>)`: its detail goes to the author only,
  never into a public PR.
- Before the last line, each on its own line: `Reviewed: <from>..<head>`, the full shas you
  reviewed (`git merge-base HEAD origin/<base>`, the local `<base>` only without an origin copy, and `git rev-parse HEAD`; for a delta, `<sha>` and
  `git rev-parse HEAD`), and `Model: <your model id>`. A delta report also has `Delta from: <sha>`. A plan report
  has only `Model:`. `review.sh record` refuses a report without them, a range that is not the
  branch's (or the delta's), and a commit made after the review started.
- The last line, exactly: `Assessment: ready`, or `Assessment: changes needed` when there is a
  High or Medium in the lines this review covers (the branch's diff, or a delta's commits). `review.sh record` reads that line; without it the report cannot be recorded.

The PR never shows this report: its "Independent review" block holds only the recorded facts (a
review of this diff, by patch id, the `Assessment:` line, the model and any warning about it, and
the risk map's paths, round 1 and the fix round). The summary is the author's `## Review`, a
security finding as one line.
