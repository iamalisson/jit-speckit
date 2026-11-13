# Data model: Reviewer isolation and privacy findings

## Review launch (the Agent call the guard sees)

| Field | Rule |
|---|---|
| `subagent_type` | `landspec:reviewer`, or any type whose `prompt` holds the sentinel line |
| `model` | `sonnet`, `opus` or `fable` (unchanged) |
| `isolation` | must be `worktree` (new) |
| `prompt` | review.md plus the facts, which now include `commit:` and `checkout:` |

A launch that is not a review passes untouched. A fork is refused first, then the model, then
the isolation.

## Facts the author passes (additions)

- `commit: <sha>`: `git rev-parse HEAD` in the author's checkout when the review is launched.
- `checkout: <absolute path>`: the author's repository root, read-only for the reviewer.

## Report header (addition)

- `Copy: <absolute path>`: the reviewer's own worktree, from `git rev-parse --show-toplevel`.

## Reviewer's copy: lifecycle

One invariant: **the review never writes the author's work (tracked and untracked files, index,
stash, branch); its commands run only in its own copy; and `record` removes only a copy that is
provably that review's: an `agent-*` folder under `.claude/worktrees/`, on a `worktree-agent-*`
branch, at the reviewed commit.**

```
created (Claude Code, at origin/HEAD)        or not created (isolation ignored or failed):
                                                 reviewer finds its top level is <checkout> or not
                                                 an agent-* copy: runs and writes nothing,
                                                 Assessment: changes needed (no copy to clean)
  -> checked: top level is an agent-* copy, not <checkout>
  -> moved: git checkout --detach <commit>    (fails: report says so, Assessment: changes needed)
  -> verified: HEAD == <commit>               (else stop, same)
  -> plan review only: reads specs/NNN-*/ in <checkout>; copies a script in only to run it
  -> reviewing (commands run here only)
  -> finished
       unchanged: removed by Claude Code
       changed:   left; removed by review.sh record (Copy: path)
       record never reached (reviewer killed, report refused):
                  left; pr.sh and branch.sh ignore .claude/worktrees/, so the author is not
                  blocked; Claude Code's sweep removes it, or a record of that report while
                  the reviewed commit is still the one the rules check
```

Orderings checked against the invariant:
- **Out of order**: `record` runs before Claude Code's own cleanup: `record` removes the copy;
  Claude Code finds nothing to remove. Fine.
- **Twice**: `record` run twice on the same report: the second finds no worktree at `Copy:` and
  skips. Fine.
- **Replayed**: an old report whose `Copy:` path now belongs to another copy: removed only if that
  copy is at the old report's reviewed commit on a `worktree-agent-*` branch, which is then a copy
  of the same commit with nothing of the author's in it; a different commit is left.
- **Both pending**: two reviews in parallel: each report names its own copy; neither removes the
  other's.

## Validation rules

- `Copy:` is used only when its folder is `agent-*` directly under `<root>/.claude/worktrees/`
  (`<root>`: `git rev-parse --show-toplevel`, or the main worktree's top level), it is listed in
  `git worktree list --porcelain` with a `worktree-agent-*` branch, its HEAD is the reviewed commit,
  and it is not the current checkout; otherwise `record` leaves it and says why.
- A report without `Copy:` is still recorded (older reviewer prompts); nothing is removed.
