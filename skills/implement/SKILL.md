---
name: implement
description: "Run every startable task of a spec-kit feature at once: each in its own copy as a background implementer, then through the independent review, fix rounds, the scan and its PR (stacked on its parent's PR when it depends on one). Never merges. Use for /landspec:implement, or when the user asks to run a feature's tasks in parallel."
argument-hint: "[feature]"
---

# Implement a feature's tasks in parallel

You are the main session: you start every agent, and no agent starts another. `I` below is
`bash .specify/extensions/landspec/scripts/implement.sh <feature>`, with the feature the user named
(or the one `next.sh` serves). If `.specify/extensions/landspec/` does not exist, tell the user to
run `/landspec:init` first, and stop. Make sure the working tree is clean; if it isn't, stop and say
so: never stash or discard. Ask nothing while the loop runs: every question waits for the end.

Keep, for the whole run, the tasks whose agents (implementers and reviewers) are in flight (`in flight`), and for each task its
copy (`Copy:`) and branch (`BRANCH=`).

## The loop

Each pass:

1. `I restack`. Show its `RESTACKED=`, `RESTACK_SKIPPED=`, `RESTACK_CONFLICT=`, `RESTACK_NOT_READY=` and
   `RETARGETED=` lines as they come; a conflict waits for the end (step "End").
2. `I status --running <the in-flight tasks, comma separated>` (`--running` with nothing in flight
   is left out). It prints one `TASK=` line per task, then `START=`, `REVIEW=`, `FIX=`, `OPEN=`,
   `ORDER=` and `DONE=`.
3. One step per listed task, in the order printed:
   - **`START`** → launch an implementer: the Agent tool with `subagent_type: "landspec:implementer"`,
     `isolation: "worktree"`, `run_in_background: true`, and `model` from `implement_model:` in
     `.specify/extensions/landspec/landspec-config.yml` (`sonnet`, `opus` or `fable`; left out when
     empty, so it is the session's; any other value: say `implement_model must be sonnet, opus or
     fable` and stop). Its prompt: the feature, the task id, its line with the sub-bullets from
     `tasks.md`, the project's test command, and `--from <parent branch>` when the task's line in
     `status` has `PARENT=` other than `-`. Add the task to `in flight`.
   - **`REVIEW`** → the independent review, exactly as `.specify/extensions/landspec/commands/review.md`
     says (its copy, its model, its record), in the background, with the facts: `commit:` the branch's
     head, `checkout:` the task's copy, `branch:` its branch, and `base: <base_ref <branch>>`
     (`bash -c 'source .specify/extensions/landspec/scripts/lib.sh; base_ref "$0"' <branch>`), so a
     stacked task is reviewed against its parent. It is a full review every time, a fix round's too
     (`review.sh record`, never `--delta`). Add the task to `in flight`, so the next pass does not
     review it again. When it returns, remove it from `in flight`, then: `review.sh record --branch
     <branch> <report>`, then `I mark <task> ready <report>` or `I mark <task> changes <report>` from
     its Assessment.
   - **`FIX`** → a fix round with the review that asked for it, the file
     `$(git rev-parse --git-common-dir)/landspec-run/<feature dir name>/<task>.report` (`mark … changes`
     keeps it there): if the task's
     implementer is still in flight, SendMessage it the report; if SendMessage is not available, or the
     agent is gone, launch a new implementer as in `START`, on the existing branch, with the report.
     Either way the task is in flight again until it returns.
   - **`OPEN`**, parents first (in `ORDER`): in the task's copy, `git switch <branch>` (copies are
     left detached, so the branch is free), then the scan and `pr.sh task` exactly as
     `.specify/extensions/landspec/commands/pr.md` says. On a draft PR that already exists and now
     targets the base (its `landspec-parent` setting is gone), run `gh pr ready <pr>` after
     `pr.sh task`; never while `landspec-parent` is set. Then `I mark <task> pr` and `git switch
     --detach` in that copy.
4. Wait for the next agent to return, then go back to 1. Stop when `status` lists nothing in
   `START`, `REVIEW`, `FIX` and `OPEN`, and nothing is in flight (no implementer and no reviewer).

## When an implementer returns

Run `I mark <task> implemented` before anything else, then remove it from `in flight`.

- Its `Copy: <path>` is the task's copy from now on. A missing `Copy:` (or a path that is gone) is
  recreated: `git worktree add --detach <repo>-<feature>-<task> <branch>`, beside the repository.
- `branch.sh` exit 3 (it says the task was claimed elsewhere): the task is `elsewhere`; leave it,
  and start the next one.
- `worktree_setup` failed: `I fail <task> "worktree_setup: <its output>"`, and go on with the
  others.
- Any other failure it reports: `I fail <task> "<what it said>"`.

## End

Show the run report, then only what is left for the developer:

- each task's state from the last `status`, and `DONE=`;
- the PRs to merge, in `ORDER` (parents first: a child's draft becomes ready once its parent is
  merged and `/landspec:implement` runs again), then "run `/landspec:implement` again";
- each `failed` task with its reason (`I retry <task>` lifts it), each `RESTACK_CONFLICT=`, each
  skipped task.

Last line: `the whole-feature check is not built yet: check the feature with /speckit-converge after
merging`.

The skill never merges a PR: the developer merges, in `ORDER`.
