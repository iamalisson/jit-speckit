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
| `pr.sh task` | the mutation record says `unavailable` | `the mutate command could not run (<cmd>); install it or fix it in the constitution, then run mutants.sh again` |
| `pr.sh task` | `gh pr edit` fails on the open PR | `could not update the body of <url>: <gh's first line>`, and no `PR=` line |
| `pr.sh` | the open-PR lookup fails | gh's error, then `could not check for an open PR` |
| `pr.sh spec` | no current plan review | `review.sh check --plan`'s refusal |
| `lib.sh` `diff_id` | no merge base in a shallow clone | `this shallow clone has no merge base with <ref>; run git fetch --unshallow` |
| `lib.sh` `diff_id` | no merge base in a full clone | `this branch shares no history with <ref>, so it has no diff to review` |
| `lib.sh` `diff_id` | an empty id for a non-empty diff | `git patch-id gave no id for this diff against <ref>` |
| `pr.sh spec` | the open-spec-PR lookup fails | gh's error, then `could not check for an open spec PR` |
| `analyzed.sh` | no report file | `usage: analyzed.sh <report-file> (the /speckit-analyze report, saved as it came)` |
| `analyzed.sh` | the file lacks the analysis headings | `<file> is not a /speckit-analyze report (no "Specification Analysis Report" or "Coverage Summary Table")` |
| `bin/check-tools.sh` | a release lookup fails | `cannot read the latest <tool> release from <repo>` |
| `next.sh` | the issue-state query fails | gh's error, then `cannot read the state of feature <num>'s task issues; fix or remove the issue number it names in <tasks.md>` |
| `issues.sh` | the existing-issue lookup fails | gh's error, then `cannot list the repository's issues to avoid duplicates` |
| `lib.sh` `test_path_re` | the constitution's `tests:` regex is invalid | `the constitution's tests: regex is invalid: <regex>` |
| `guard.sh` | an abbreviation of `--no-verify`, `am -n`, or a commit or `HEAD` push after a switch to a base branch in one chain | today's messages, unchanged |
| `review.sh record` | a risky path has no `- deep:` or `- proven: … <test file:line>` line | `the report does not check <path> (<category>): add '- deep: <path>' or '- proven: <path> by <test file:line>', and run the review again`; a gate, delete or test path takes `- deep:` only: `the report does not check <path> (<category>): add '- deep: <path>' (a gate, delete or test path needs a deep read), and run the review again` |
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
| `level.sh`, `bin/remove.sh` | the constitution has one line-start start marker and no end marker | `<file> has '<!-- jit:start' but no '<!-- jit:end -->'; restore the end marker, then run again` |
| `level.sh`, `bin/remove.sh` | any other line-start markers that are not one start then one end | `<file>'s jit block is damaged: it needs one '<!-- jit:start' line followed by one '<!-- jit:end -->' line; fix the markers, then run again` |
| `review.sh record --plan` | no `Model:` line | `the report must state Model: <id> for the plan: run the review again` |
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
| `review.sh record` | `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` is set, `Model:` is not sonnet, opus or fable, or not the configured family | `jit: warning: <reason>; the review did not run on the configured model`, `<reason>` one of `CLAUDE_CODE_SUBAGENT_MODEL_FORCE is set`, `the review ran on <id>`, `the review ran on <id>, not <review_model>`, `<id>` being `unknown` when `Model:` is not shaped like a model id or names none of claude, sonnet, opus, fable and haiku; one line only, the first reason that applies in that order (stderr, and stored as `warning:` in the record; `pr.sh` prints it from there) |
| `next.sh` | other startable `[P]` tasks | `parallel <Tnnn> (<worktree and branch.sh command>)`, before the `DONE=` line |
| `pr.sh task` | an open PR's body was replaced | `PR body replaced from <file>; edits made on GitHub are gone` |
| `issues.sh` | a task's issue already exists | `<Tnnn> → #<n> (existing)` |
| `issues.sh` | the plan review's record has a `warning:` | `jit: warning: <reason>; the review did not run on the configured model` (stderr, exit 0), before the issues are created |
| `level.sh` `put()` | a managed workflow has a newer pin | `kept newer pin: <action> <version>` |
| `level.sh` `put()` | an old release's file, `name` | `kept (written by jit-speckit <versions>, no marker): <file> — delete it to get the current one` |
| `level.sh` `put()` | an unmarked `security.yml` | `kept (no marker): .github/workflows/security.yml — delete it to get the current one` |
| `level.sh` `put()` | a generated file kept after an old hook matched | `kept (written by jit-speckit <versions> or older, no marker): <file> — delete it to get the current one` |
| `bin/remove.sh` | a file changed since jit wrote it, marked or not, or with no record and jit's scaffold first line (not `.claude/settings.json` or a git hook, whose first line is generic) | `kept (edited): <file>` |
| `bin/remove.sh` | a kept file holds the record in place (never with `--with-speckit`, which deletes it) | `kept: .specify/jit-files.sha256 (it names the files kept above)` |
| `bin/remove.sh --with-speckit` | a constitution existed | `removed: spec-kit (.specify/, .claude/skills/speckit-*); the constitution went with it; specs/ kept` |
| `bin/remove.sh` | a kept hook still calls jit's scripts | `kept: .githooks still calls jit's scripts, which are gone; edit those lines out, or: git config --unset core.hooksPath` |
| `bin/check-tools.sh` | always | `BEHIND=<n>`; one issue "Tool pins behind" when n > 0 and none is open |
| `close-linked-issues.yml` | a close failed | `could not close: #<n> …`, job fails |

## PR body (changed)

- `## Review` (written by the agent, `pr.md` step 5): a security finding is one line,
  `Security: reported privately (<id>)`.
- Added by `pr.sh task`, before `Closes #N`: `<details><summary>Independent review</summary>`, the
  line `Independent review recorded for this diff (patch id <first 12 of the recorded state>)` and
  the line `Assessment: ready`; then `</details>`. The script never copies the report's text; the
  summary is the agent's `## Review`.
- Added by `pr.sh task`, from the record: `Model: <id>`, any `warning:` lines
  (`warning: <reason>; the review did not run on the configured model`), and the risk map as
  paths only (`- deep: <path>`, `- proven: <path>`) under `Risk map (round 1)` and, after a delta,
  `Risk map (fix round)`.
- Added by `pr.sh spec`, after the task issues, when the plan review's record has a warning:
  `**Plan review:** <reason>; the review did not run on the configured model`.
- Added by `pr.sh task` when no mutate command is set: `Mutation testing: not run (no mutate
  command in the constitution)`.

## What `/jit-speckit:init` offers (changed)

| Step | Level | Offer |
|---|---|---|
| 4 GitHub settings | every level | rebase merges off; on lite also merge commits off (squash only) |
| 4 GitHub settings | every level, public repo | secret scanning with push protection; private vulnerability reporting |
| 4 GitHub settings | every level, private repo | one line: these need GitHub Secret Protection, or are for public repos |
| 5 Branch protection | standard, full | unchanged |
