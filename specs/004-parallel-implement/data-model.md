# Data model: Implement a whole feature in parallel

## Task record (research R6, revised)

Plan review round 3 showed that the loop's progress cannot be derived from git and GitHub alone: a
review that said `changes needed`, the round count and a ready review whose PR is not open yet live
only in the session. So each task started by a run has one small record,
`<git common dir>/landspec-run/<feature>/<task>`, written only by `implement.sh mark`:

```
phase=implemented|changes|ready|pr     head=<sha the phase is for>
round=<n>                              report=<path of the last review report, kept beside it>
failed=<reason>                        (optional; with head= empty when there was no branch yet)
```

Everything else stays derived: claims, PRs, merges, locks, the review records.

## Task state (`implement.sh status`)

Each task is in exactly one state, checked in this order (the first that matches wins):

| State | Means | Derived from | In |
|---|---|---|---|
| `merged` | done | issue closed | — |
| `elsewhere` | another clone or session works on it | branch on origin, no local branch | — |
| `failed` | stopped by R7's limits | record `failed=` and its `head=` is the branch head (an empty head always matches); `retry` clears it | — |
| `running` | an implementer works on it | in the `--running` list the skill passes (the agents it has in flight), or its branch checked out in a **locked** worktree (another session's agent) | — |
| `pr` | PR open and mergeable in order, its review valid | open PR whose head = branch head, record `phase=pr`, and the PR not a draft or targeting a parent (a draft on the base falls to `reviewed`) | — |
| `reviewed` | ready, PR still to open (or a draft on the base to mark ready) | `review.sh check --branch <b>` passes, and for a draft on the base `landspec-parent` is unset (else `waiting`, `REASON=restack pending`) | `OPEN=` |
| `fix` | review said changes needed, rounds left | record `phase=changes`, `head=` the branch head, `round` < 3 | `FIX=` |
| `implemented` | review pending | record `phase=implemented`, `head=` the branch head | `REVIEW=` |
| `resume` | started, interrupted mid-work | a local branch, none of the above | `START=` |
| `startable` | can start | no branch; every dependency `reviewed`, `pr`, `merged`, at most one unmerged (R5) | `START=` |
| `waiting` | a dependency is not ready | otherwise | — |

**Invariant 2**: a task is in `START` only when nothing works on it and nothing is pending on it:
`running`, `implemented`, `fix`, `reviewed`, `pr`, `failed`, `elsewhere` and `merged` are
checked before `resume` and `startable`, so each of them excludes it. Every state names the one step
that moves it on: `START` → an implementer, `REVIEW` → a review, `FIX` → a fix round with `report=`,
`OPEN` → the scan and `pr.sh task`. A `fix` whose `round` reaches 3 is written `failed`.

All of it is read **by branch name, from any HEAD**: `base_ref`, `diff_base`, `diff_id` and
`review.sh check` take `--branch <b>` (T002), so `status` and `restack` never switch branches.

## Stack

- `git config branch.<b>.landspec-parent <parent branch>` while the parent is unmerged.
- `<common git dir>/landspec-review/parent-head-<b>`: the parent's head when `<b>` started, or when it
  was last restacked (R4).

**Invariant**: a task branch's own diff, `<base_ref <b>>...<b>`, holds only that task's commits;
every review, scan and PR of the task is taken against `base_ref <b>`.

Orderings checked against the invariant:
- **Out of order**: a stacked PR is a draft until it targets the base with a valid review: `restack`
  runs `gh pr ready` on a `REVIEW=kept` move, the OPEN step after a new review; so the developer
  cannot merge a child before its parent.
- **Moved on GitHub** (someone pushed to a task branch): `status` and `restack` compare the local
  branch with origin; behind and checked out nowhere → fast-forwarded by `update-ref`; behind and checked out somewhere →
  `elsewhere`, `REASON=checked out in <path>`; diverged → `elsewhere`, with
  `REASON=diverged from origin`, until the developer resolves it.
- **Twice** (`restack` run twice): the second finds no merged parent with a setting left; no-op.
- **Chains**: `restack` goes parents first, in `ORDER`, so a grandchild is moved after its parent.
- **Replayed** (a parent's fix round after the child started): the child is rebased `--onto` the
  parent's new head from its recorded `parent-head`, and `parent-head` is updated; review kept when
  its patch id is unchanged.
- **Replayed, then merged**: the child is rebased `--onto origin/<base>` from the parent's **final**
  head read from its merged PR (`headRefOid`), never the stale `parent-head`.
- **Both pending** (two sessions on one feature): each start is a claim push that expects the branch
  absent on origin; the loser's `branch.sh` exits 3 and that session marks the task `elsewhere`.
- **Reviewed in a copy**: a stacked task's reviewer runs detached (spec 003), so it gets the base as a
  fact (`base: origin/<parent>`) and states `Reviewed:` from the merge base with it, the same `from`
  that `review.sh record --branch <b>` computes.
- **Conflict found by the check**: when two unstacked task branches conflict, the later one in
  `ORDER` is stacked on the earlier (`implement.sh stack`: setting, rebase, push, PR base, `phase=
  implemented`), so its fix round sees the other's code; when it already has a parent, the check
  stops and the report names both.

## Where the run writes (invariant 1)

- The developer's checkout: never.
- An implementer: only its Claude Code copy; its last step, after pushing, is `git switch --detach`.
- The main session's PR step for a task: in the implementer's copy (or `<repo>-<feature>-<task>`
  when that copy is gone), then `git switch --detach` there.
- The PR step and every script that needs a branch checked out (`pr.sh`, `review.sh` without
  `--branch`): `git switch <branch>` in the copy (free, since every copy is left detached), the step,
  then `git switch --detach`.
- `restack`, `stack`, gap tasks (`pr.sh spec`) and the release (`pr.sh fix`): in `<repo>-<feature>-run`,
  each step ending with `git switch --detach origin/<base>`.
- The whole-feature check: in `<repo>-<feature>-check`, detached, removed after.

So after every step **no task, spec or release branch stays checked out** anywhere the run made; a
branch checked out in the developer's own checkout is skipped with `SKIPPED=<b> (checked out in
<path>)`, never forced. `base_ref` never decides "merged": only `restack` (online) removes the setting.

## Audit record (T010)

`<git common dir>/landspec-security/audit`: `commit=<origin/<base> sha audited>`, `report=<path>`,
`hold=<n confirmed critical or high>`; written only by `implement.sh audit-record`, read by
`audit-plan`. A new base commit means a new audit; `hold` above 0 stops the release until the
developer fixes the findings (through `/landspec:security`) and they are merged.

## Run report (the final summary)

One line per task: `Tnnn <state> <PR url or reason>`; then `ORDER=`, the whole-feature check's
result per round, and what it could not verify.

## Config keys (landspec-config.yml)

| Key | Default | Meaning |
|---|---|---|
| `parallel_tasks` | `4` | implementers running together (1-16) |
| `feature_rounds` | `3` | whole-feature check rounds that may still find gaps |
| `worktree_setup` | *(empty)* | one command each implementer's copy runs first |
| `implement_model` | *(empty: the session's)* | the implementers' model: `sonnet`, `opus` or `fable` |
| `version_files` | *(empty)* | files carrying the version, for the release |
| `release_notes` | *(empty)* | folder for `X.Y.Z.md` release notes |
