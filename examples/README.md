# Example: one feature, from idea to merged PRs

This walks through **price search**, a small feature with 3 tasks, on a `standard` project
(`feat/*` → `develop` → `main`). Every file named here is in this folder, in the exact shape
jit-speckit produces, so you can open each one and see what you'll get.

**Your job:** plan the feature, review each PR, merge it. **Claude:** writes the spec, plan,
tasks and code. **jit-speckit:** does everything in between (issues, branches, checks, PRs), the
same way every time.

## 1. Plan the feature (once)

| You run | What appears | What you do |
|---|---|---|
| `/speckit-specify "shoppers filter products by max price"` | [`spec.md`](specs/001-price-search/spec.md): stories, requirements, success criteria | read it, fix what's wrong |
| `/speckit-plan` | [`plan.md`](specs/001-price-search/plan.md): stack, design, constitution check | read it |
| `/speckit-tasks` | [`tasks.md`](specs/001-price-search/tasks.md), one GitHub issue per task ([#21](github/issue-T001.md), #22, #23) with `— #N` written on each line, and the **spec PR** ([#20](github/spec-pr.md)) | review and **merge the spec PR** |

Each issue is assigned to you. If `jit-config.yml` sets a `milestone:` or a `project:`, the
issue gets it too.

## 2. Build it (once per task)

| You run | What happens | What you do |
|---|---|---|
| `/jit-speckit:next` | shows `0/3 done`, then starts T001: branch `feat/001-t001-add-the-price-query` from `develop`, code, tests, security scan, the independent review, commit, push, and [PR #24](github/task-pr-T001.md) with `Closes #21` | review PR #24, merge it (issue #21 closes) |
| `/jit-speckit:next` | `1/3 done`, then T002 → PR #25, `Closes #22` | review, merge |
| `/jit-speckit:next` | `2/3 done`, then T003 → PR #26, `Closes #23` | review, merge |
| `/jit-speckit:next` | `3/3 done`, and it suggests `/speckit-converge` | run it: it compares the merged code with the spec. Nothing left, so the feature is finished; `/jit-speckit:security` before you release |

T003 is marked `[P]` (parallel), so when it can start, `next` prints a `parallel` line for it beside
T002 and offers to start it in its own worktree.

The PR timeline on GitHub:

```
#20  docs(specs): 001-price-search            spec/001-price-search  → develop   merged first
#24  feat(products): add price search query   feat/001-t001-…        → develop   Closes #21
#25  feat(products): add max price endpoint   feat/001-t002-…        → develop   Closes #22
#26  feat(web): add max price field           feat/001-t003-…        → develop   Closes #23
```

## Why two kinds of PR?

The spec PR (#20) holds only documents. The task PRs (#24 to #26) hold only code. They are split
on purpose:

- **Task branches start from the base branch and need `tasks.md` there.** That's where each task
  finds its issue number, and where `/jit-speckit:next` counts progress. Until the spec PR is
  merged, `/speckit-implement` refuses to start: "merge the spec PR first".
- **Every task PR stays small and independent.** If the spec rode along with the code, each task
  PR would carry its own copy of `specs/001-price-search/`. They would conflict with each other,
  or the spec would only reach `develop` in one big PR at the end.
- **You review the design before any code exists.** Changing your mind costs one edit to a doc,
  not a rewrite of three PRs.
- **One task = one issue = one PR**, so `Closes #N` closes exactly the right issue when each PR
  merges, and the history reads one task at a time.

## Reading a PR

Task PRs keep what a reviewer needs visible (what changed, a one-line evidence summary, and
`Closes #N`). Long output, such as test logs and scan details, is folded into `<details>` blocks
that you click open. See [`github/task-pr-T001.md`](github/task-pr-T001.md).

## Starting from zero

This example adds a feature to an existing project. To start from an empty folder, run
`/jit-speckit:new`. You choose the stack together with Claude; it sets up the tooling (no
application code) by following the [Starter checklist](../docs/GUIDELINES.md#starter-checklist),
then suggests a foundation spec as your first `/speckit-specify`.

Stuck? `/jit-speckit:help`, or `/jit-speckit:help <your question>`.
