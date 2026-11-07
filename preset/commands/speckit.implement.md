---
description: "Implement one task from tasks.md, on its own branch and PR (landspec: one task per run)"
strategy: append
---

## landspec: one task per run

This project uses landspec (one task = one issue = one branch = one PR). It **overrides** the
instructions above where they differ:

- Implement **only the task given** in the arguments (for example `T003`), never the others,
  even when they are open. The `before_implement` hook has already put you on its branch.
- **Do not mark tasks `[X]` in `tasks.md`.** A task is done when its issue closes, through the
  merged PR's `Closes #N`. A tick would dirty the tree or make parallel task PRs conflict.
- The completion check above ("all tasks completed") means: this one task's *Completed when* is
  met, and its tests pass.
