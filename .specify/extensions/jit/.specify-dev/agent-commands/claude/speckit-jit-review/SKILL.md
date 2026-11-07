---
name: speckit-jit-review
description: Independent review of the branch (or of the plan, before issues) by a fresh reader grounded in the whole repository
compatibility: Requires spec-kit project structure with .specify/ directory
metadata:
  author: iamalisson
  source: jit:commands/review.md
---

# Independent review

A fresh reader, not the author. It starts from the diff, then reads the repository around it, and
reports few findings, each verified and tied to a line that already exists. This is how the best
automated reviewers work (GitHub's Copilot code review gathers repository context with tools before
it comments), and it is why they catch what a review inside the author's own session misses: that
session shares the author's assumptions and tests the same path the author tested.

**Two roles.** If you are the author's session (`/speckit-jit-pr`, `/speckit-jit-issues`, or the
user ran `/speckit-jit-review`): launch one subagent of type `jit-speckit:reviewer` whose prompt
starts with the line `jit-speckit review: independent reviewer`, then this whole file plus the
facts below, and nothing else: no summary of what you built, no "I already checked X". Pass the
call's `model`: `review_model:` from `.specify/extensions/jit/jit-config.yml` when it is `sonnet`,
`opus` or `fable`, `opus` when the key is absent or empty. If `review_model:` holds any other
value, print `jit: review_model must be sonnet, opus or fable` and stop.
Never run the review on `haiku`, and never in a fork of this session. If the call refuses the type `jit-speckit:reviewer`
(the plugin is not installed), launch a `general-purpose` subagent with the same prompt and the
same `model`. The plugin's hook blocks a review launch without one of those models, or in a fork.
Wait for its report, save it as it came to a file outside the repository (`mktemp`), and record it:
`bash .specify/extensions/jit/scripts/review.sh record <file>` (`record --plan <file>` for a plan
review, `record --delta <file>` for a fix round). The record is tied to the exact diff (or `tasks.md`): `pr.sh` and `issues.sh` refuse to
open anything without a recorded review that said `ready` for the current state, at every level,
so a commit after the review means another review. If you are that subagent: follow the method
and return only the report.

Facts the author passes:
- the base branch and the branch under review, or, for a plan review, the feature folder
  `specs/NNN-*/`;
- the task's line from `tasks.md` with its sub-bullets, or "plan review";
- the path of the PR body draft, if there is one;
- the project's test command (the constitution's **Commands** line or its jit block);
- for a fix round (a **delta**): the `REVIEWED=<sha>` the last `record` printed and the path of
  that round's report.

**A delta** reads `git diff <sha>..HEAD` only: it checks that each previous finding is fixed and
applies steps 2 to 6 to the fix commits alone, and it never widens. A bug it notices outside those
commits is reported at its true severity and does not change the assessment. `record --delta` refuses it unless a round was
recorded on this branch, `<sha>` is still on the branch, something was committed since, and the fix
changes at most 20 lines outside the previous findings' files (test files aside); otherwise run a
new full review.

## Method

1. **Read the rules first**, from the branch: `.specify/memory/constitution.md`, `AGENTS.md`,
   `CLAUDE.md`, `.github/copilot-instructions.md` where they exist, and the feature's `spec.md`,
   `plan.md` and the task's line (*Comes from*, *Impact*, *Completed when*).
2. **Map the risk, then start from the diff and end in the repository.** Run
   `bash .specify/extensions/jit/scripts/review.sh risk` (for a delta, `review.sh risk <sha>`).
   Every `RISK=` path is deep. Then rank the other hunks for what a path cannot show: data loss,
   secrets, authorization, money, a migration, a branch or CI change, a deletion, a skipped gate,
   a write to the user's files. Those are deep too. Deep means steps 2 to 7 in full. Everything
   else is sampled (read the hunk and its callers once) or proven (an existing test fails if it
   breaks: name it as `file:line`). Steps 4 and 5 still cover the whole diff.
   `git diff origin/<base>...HEAD`. For every changed file, open what it calls and what calls it (search each symbol). For every new file of a kind
   the repository already has (migration, workflow, endpoint, model, job, script), open the newest
   two siblings and list every guard they have: existence checks, idempotent writes, timeouts,
   authorization, refusal to run against production. A guard the siblings have and the new file
   lacks is a finding, with the sibling's `file:line` as evidence.
3. **Feed it what the tests don't.** For every validator, parser or form changed, try the shapes
   its tests do not list: empty, whitespace only, wrapped in braces or quotes, too long, mixed
   case, a duplicate, unicode. Compare each answer with the contract, including how many messages
   come back: one failure, one message, in the contract's words. A second message from a
   framework default (a length or required check the framework adds by itself) is a finding.
4. **Check every claim.** Each line of the PR body's *Evidence* and the task's *Completed when*:
   re-run the command when it takes under a minute; otherwise read the test and say what it
   proves. Each *Impact* item: is it handled in this diff? A claim you cannot reproduce is
   reported as unverified, never assumed.
5. **Run the tests, then break the code once.** Run the test command. For the task's main
   behavior, make one small change that should break it (invert a condition, drop a guard, return
   early), run the tests again, and restore the file. A suite that stays green is a finding.
6. **Walk the real path, not the fresh one.** For each change ask what happens where state already
   exists: a table the models already created, a half-applied earlier run, a retry, two requests
   at once, a missing optional config, an empty result. The happy path on a clean machine is the
   one the author already tested. **Then walk the failure path**: when this fails, does the caller
   get a status and a code and nothing internal, is the failure logged exactly once with the
   request ID and without personal data, and is each refused case (wrong user, bad input, replay)
   tested? A swallowed error, a silent failure or a log line with personal data is a finding.
7. **Security at the boundaries** of what changed: input validation, authorization taken from the
   authenticated context, secrets, injection, what the error messages leak.

**Plan review** (before the issues are created): apply steps 1, 2 and 6 to every task in
`tasks.md`. *Impact* names every reference the task touches (search each symbol) and the newest
sibling of each file it adds; *Completed when* is a command that proves the real path, not only a
fresh state, at the level the behavior demands (logic: unit; through the interface: integration
against the real database or in-memory HTTP; a user-visible flow: one end-to-end); a step that writes data names its target and refuses production; every task names its failure
path (what the caller gets, the one log line, who is refused), and no task is a bare "error
handling", "logging" or "hardening" layer; no task deletes what another task still uses. **Shape:** a task is a vertical slice with an observable result. A
task that is one layer of a behavior another task completes (a model here, its migration there,
the endpoint in a third) is a finding: name the tasks to merge. So is a task whose diff would
clearly pass about 400 lines with its tests: name the behaviors to split it by.

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
  no nits: they are what gets reviews ignored. A **security** finding is listed last, and the PR
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