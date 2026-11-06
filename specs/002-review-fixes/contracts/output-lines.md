# Contract: what the scripts and prompts print and offer

The exact lines users and Claude see. Tests assert on these strings; a change to one changes its
test and this file in the same PR. `<…>` is filled at run time. Refusals go through `die` (stderr,
non-zero); warnings go to stderr with exit 0; results go to stdout.

## Refusals (new or changed)

| Script | When | Line |
|---|---|---|
| `bin/setup.sh` | the plugin copy is older than the project, no `--downgrade` | `this plugin copy is <plugin>, the project is at <project>; run /reload-plugins (or setup.sh --downgrade)` |
| `pr.sh task` | the test command fails | its last 20 lines, then `the test command failed (<cmd>); fix it before opening the PR` |
| `pr.sh task` | a mutate command is set and no mutation record for this diff | `no mutants.sh result for this diff; run bash .specify/extensions/jit/scripts/mutants.sh after the last commit` |
| `pr.sh task` | the mutation record says `survivors` and `## Evidence` does not mention a survivor | `mutants.sh found surviving mutants; say in '## Evidence' why each changes nothing, or add the test that kills it` |
| `pr.sh task` | no scan record for this diff | `no security-scan.sh --changed result for this diff; run bash .specify/extensions/jit/scripts/security-scan.sh --changed after the last commit` |
| `pr.sh task` | an edited existing test (wider pattern), no `## Test changes` | today's message, naming the file |
| `pr.sh spec` | the open-spec-PR lookup fails | gh's error, then `could not check for an open spec PR` |
| `analyzed.sh` | no report file | `usage: analyzed.sh <report-file> (the /speckit-analyze report, saved as it came)` |
| `analyzed.sh` | the file lacks the analysis headings | `<file> is not a /speckit-analyze report (no "Specification Analysis Report" or "Coverage Summary Table")` |
| `bin/check-tools.sh` | a release lookup fails | `cannot read the latest <tool> release from <repo>` |
| `next.sh` | the issue-state query fails | gh's error, then `cannot read the state of feature <num>'s task issues; fix or remove the issue number it names in <tasks.md>` |
| `issues.sh` | the existing-issue lookup fails | gh's error, then `cannot list the repository's issues to avoid duplicates` |
| `lib.sh` `test_path_re` | the constitution's `tests:` regex is invalid | `the constitution's tests: regex is invalid: <regex>` |
| `guard.sh` | an abbreviation of `--no-verify`, `am -n`, or a commit or `HEAD` push after a switch to a base branch in one chain | today's messages, unchanged |
| `review.sh record` | a risky path has no `- deep:` or `- proven: … <test file:line>` line | `the report does not check <path> (<category>): add '- deep: <path>' or '- proven: <path> by <test file:line>'` |
| `review.sh record --delta` | no full round recorded | `a delta follows a recorded full review of this branch: run a new full review, then record it with review.sh record <report-file>` |
| `review.sh record --delta` | the range does not start at the recorded head | `the delta must review <last>..HEAD (Reviewed: <last>..<head>): run the delta review again from <last>` |
| `review.sh record --delta` | the recorded head is no longer on the branch | `<last> is no longer on this branch (rebased?): run a new full review` |
| `review.sh record --delta` | nothing committed since the last review | `nothing was committed since the last review (<last>): commit the fixes, then run the delta review` |
| `review.sh record --delta` | too much changed outside the previous findings | `the delta changes <n> lines outside the previous findings (limit 20): run a new full review` |
| `review.sh record` | no `Reviewed:` or no `Model:` line, or a range that does not match the mode | `the report must state Reviewed: <from>..<head> and Model: <id> for <expected range>: run the review again` |
| `review.sh risk` | `--plan` | `risk maps a diff; a plan review has none` |
| `review.sh record` | `--plan` with `--delta` | `a plan review is always full: review.sh record --plan <report-file>` |
| `review.sh record --delta` | no `Delta from:` line | `a delta report names its base: Delta from: <last>; run the delta review again` |
| `review.sh record` | a `- proven:` line with no test, a non-test file, or a line past the file's end | `<path> is not proven by <file>:<n> (not a test file, or no such line): check it deep or name the test` |
| `review.sh record` | an invalid `review_model:` in `jit-config.yml` | `jit: review_model must be sonnet, opus or fable` |
| `/speckit-jit-review` prompt | `review_model:` not sonnet, opus or fable | `jit: review_model must be sonnet, opus or fable` |
| `review.sh record` | a report with `Delta from:` recorded without `--delta` | `this is a delta report: record it with --delta, or run a new full review` |
| `hooks/guard-review.sh` | a reviewer launch whose model is missing or not sonnet, opus or fable | `jit: the review must run on sonnet, opus or fable (review_model:), not <model or "the session's model">` (exit 2) |
| `hooks/guard-review.sh` | a fork carrying the reviewer sentinel | `jit: the review must run in a fresh agent, not a fork of this session` (exit 2) |
| `review.sh check` | no task record on a task branch | today's message, hint `review.sh record <report-file>` (no `--plan`) |

## Warnings and results (new or changed)

| Script | When | Line |
|---|---|---|
| `branch.sh` | the claim push fails | `jit: warning: could not claim <branch> on origin: <git's error>; other clones may start this task` (stderr, exit 0) |
| `pr.sh task` | no test command | `jit: tests not run before the PR (no test command in the constitution)` (stderr) |
| `review.sh risk` | always | one `RISK=<category> <path>` line per risky path, or `RISK=none` |
| `review.sh record` | a task review recorded | `REVIEWED=<sha>` before `REVIEW=<assessment>` |
| `review.sh record` | `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` is set, `Model:` is not sonnet, opus or fable, or not the configured family | `jit: warning: <reason>; the review did not run on the configured model`, `<reason>` one of `CLAUDE_CODE_SUBAGENT_MODEL_FORCE is set`, `the review ran on <id>`, `the review ran on <id>, not <review_model>`; one line only, the first reason that applies in that order (stderr, and stored as `warning:` in the record; `pr.sh` prints it from there) |
| `next.sh` | other startable `[P]` tasks | `parallel <Tnnn> (<worktree and branch.sh command>)`, before the `DONE=` line |
| `pr.sh` | Copilot listed in GitHub's answer | `copilot: code review requested` |
| `pr.sh` | anything else | `copilot: not requested (GitHub did not add the reviewer)` |
| `issues.sh` | a task's issue already exists | `<Tnnn> → #<n> (existing)` |
| `level.sh` `put()` | a managed workflow has a newer pin | `kept newer pin: <action> <version>` |
| `level.sh` `put()` | an old release's file, `name` | `kept (written by jit-speckit <versions>, no marker): <file> — delete it to get the current one` |
| `level.sh` `put()` | a generated file kept after an old hook matched | `kept (written by jit-speckit <versions> or older, no marker): <file> — delete it to get the current one` |
| `bin/remove.sh` | a marked file changed since jit wrote it | `kept (edited): <file>` |
| `bin/check-tools.sh` | always | `BEHIND=<n>`; one issue "Tool pins behind" when n > 0 and none is open |
| `close-linked-issues.yml` | a close failed | `could not close: #<n> …`, job fails |

## PR body (changed)

- `## Review` (written by the agent, `pr.md` step 5): a security finding is one line,
  `Security: reported privately (<id>)`.
- Added by `pr.sh task`, before `Closes #N`: `<details><summary>Independent review</summary>`, the
  recorded report's *What changed* section and its `Assessment:` line; then `</details>`. The
  script never copies findings.
- Added by `pr.sh task`, from the record: `Model: <id>`, any `warning:` lines, and the risk map as
  paths only under `Risk map (round 1)` and, after a delta, `Risk map (fix round)`.
- Added by `pr.sh task` when no mutate command is set: `Mutation testing: not run (no mutate
  command in the constitution)`.

## What `/jit-speckit:init` offers (changed)

| Step | Level | Offer |
|---|---|---|
| 4 GitHub settings | every level | rebase merges off; on lite also merge commits off (squash only) |
| 4 GitHub settings | every level, public repo | secret scanning with push protection; private vulnerability reporting |
| 4 GitHub settings | every level, private repo | one line: these need GitHub Secret Protection, or are for public repos |
| 5 Branch protection | standard, full | unchanged |
