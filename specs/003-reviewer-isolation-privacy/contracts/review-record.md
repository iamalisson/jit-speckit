# Contract: the reviewer's copy and `review.sh record`

## Reviewer (commands/review.md, "If you are that subagent")

These steps are in `agents/reviewer.md` (shipped with the plugin, the same version as the guard)
as well as in review.md, so a project copy older than the plugin cannot drop them.

0. Before any command that writes: `git rev-parse --show-toplevel` must be an `agent-*` folder
   directly under a `.claude/worktrees/` and differ from `<checkout>`; and the facts must carry
   `commit:` and `checkout:`. Otherwise run no command except read-only ones (`git rev-parse`,
   `git status`, reading files) and `mktemp` for the report, report `Copy: none (<reason>)`, and end
   `Assessment: changes needed` with the reason: "the isolation was asked for but not given" (a
   client that ignored it, a copy that could not be made), or "the project's landspec copy predates
   the plugin: run /landspec:init" (no `commit:` fact).
1. `git checkout --quiet --detach <commit>` in its own copy; `git rev-parse HEAD` must equal
   `<commit>`, else the report says why and ends `Assessment: changes needed`.
2. Plan review: read `<checkout>/specs/NNN-*/` in place; copy a spec-folder script into the copy
   only to run it.
3. Never write to `<checkout>`: no editing command, no `git checkout`, `reset`, `clean`, `stash` or
   `restore` there, no lock or temp files there. A command that would write outside its copy is
   not run; the one exception is `mktemp` for the report file, which lives outside every repository.
4. Header line `Copy: <git rev-parse --show-toplevel>`, before `Reviewed:`.

## `review.sh record [--plan|--delta] <report>`

Unchanged checks, then, after the record is written:
- with a `Copy:` path that passes every data-model validation rule and still exists:
  `git worktree remove --force <path>`, then `git branch -D <its worktree-agent-* branch>`; prints
  `landspec: removed the reviewer's copy <path>`;
- a rule that fails, or a removal git refuses: prints `landspec: left the reviewer's copy <path>
  (<reason>)` and still succeeds: the record is what matters;
- no `Copy:` line, a `Copy: none (…)` line, or a path that no longer exists: nothing is printed or
  removed.

## `pr.sh` and `branch.sh`

Their "uncommitted changes" refusals read `git status --porcelain -- . ':(exclude).claude/worktrees'`.
