# Research: Reviewer isolation and privacy findings

## R1. Where does a worktree-isolated subagent start?

- **Decision**: the reviewer runs with `isolation: "worktree"` and, as its first step, moves its own
  copy to the reviewed commit (`git checkout --quiet --detach <sha>`), then checks
  `git rev-parse HEAD` equals that sha, and stops with a one-line message when it does not.
- **Rationale**: the docs say the worktree "is branched by default from your default branch rather
  than the parent session's HEAD" (`worktree.baseRef`, default `"fresh"`). A probe on 2026-11-12
  (Claude Code 2.1.322) confirmed it: the author's checkout was on `d24a328` (a feature branch),
  the subagent's copy started at `7824f75`, which is `origin/HEAD`. The copy is a `git worktree` of
  the same repository (`git worktree list` showed both), so the author's commits, pushed or not,
  and `origin/<base>` resolve inside it. Without the switch the reviewer would read the default
  branch and review nothing.
- **Alternatives**: set `worktree.baseRef: "head"` in the project's settings. Rejected: it changes
  every worktree the user's Claude Code creates in that project, and landspec cannot tell whether
  the setting is in force, so the reviewer would have to check the commit anyway.

## R2. What the reviewer can still read from the author's checkout

- **Decision**: the author passes its checkout's absolute path as a fact. The reviewer may read
  there, never write, and runs every command in its own copy. A plan review reads the feature
  folder (`specs/NNN-*/`, maybe not committed yet) in the author's checkout; it copies a spec-folder
  script into its own copy only when it has to run it. Copying the whole folder would leave every
  plan review's copy changed, so never removed by Claude Code (plan review round 1).
- **Rationale**: `review.sh record --plan` hashes the working tree's `plan.md` and `tasks.md`, so a
  plan review legitimately reads uncommitted files; a task review needs only the commit
  (`record` already refuses uncommitted work).

## R3. Can the launch guard see `isolation`?

- **Decision**: `hooks/guard-review.sh` refuses a review launch whose `tool_input.isolation` is not
  `worktree`, after the fork and model checks.
- **Rationale**: a PreToolUse hook gets the call's input; the docs' example table lists only
  `prompt`, `description`, `subagent_type` and `model`, so the field's presence is not documented.
  The rule fails closed: if a client dropped the field, every review would be refused at once,
  visibly, never run in the author's checkout. The quickstart's first scenario proves it on a real
  launch before the feature ships.
- **Alternatives**: `isolation: worktree` in `agents/reviewer.md` frontmatter only. Kept as a second
  layer, not the gate: the docs don't say plugin agents honour it, and the `general-purpose`
  fallback has no frontmatter.

## R4. Leftover copies

- **Decision**: two parts, shipped together.
  - `pr.sh` and `branch.sh` leave `.claude/worktrees/` out of their "uncommitted changes" checks
    (`git status --porcelain -- . ':(exclude).claude/worktrees'`): a nested worktree shows there as an
    untracked folder, and would otherwise stop the author's next PR or task, even when `record` is
    never reached (a killed reviewer, a refused report).
  - The reviewer names its copy in the report (`Copy: <path>`). `review.sh record` removes it only
    when all of these hold: its folder is `agent-*` directly under `.claude/worktrees/` of the
    author's repository (the checkout's top level, or the main worktree's, for a checkout that is
    itself a linked worktree); it is listed by `git worktree list --porcelain`; its branch is
    `worktree-agent-*`; its HEAD is the reviewed commit (`Reviewed:`'s head for a task review, the
    author's HEAD for a plan review); and it is not the current checkout. Then it deletes the copy's
    branch. A `claude --worktree` session, another agent's copy at another commit, or a path the
    report got wrong is never removed. No rule relies on Claude Code locking a running copy.
- **Rationale**: Claude Code removes an unchanged copy itself; a copy with changes (a killed run that
  left a mutant) stays until a periodic sweep that skips changed copies. While it stays it is an
  untracked `.claude/worktrees/` folder in the author's checkout. Removing it in `record` is
  deterministic and touches only the reviewer's copy.
- **Alternatives**: add `.claude/worktrees/` to the project's `.gitignore`. Rejected for this
  feature: it hides the folder but keeps the mutant on disk, and edits a user file.

## R5. Client support

- **Decision**: no version bump. The Agent tool accepted `isolation: "worktree"` on 2.1.322; the
  docs give no version for it, and no older client was probed: one may reject the parameter or
  ignore it. Rejected: the user sees the call fail and the guard's message says to update. Ignored:
  the reviewer's first step checks it is in an `agent-*` copy, not `<checkout>`, before any write,
  and stops (contracts/review-record.md step 0), so the guard's trust in the parameter never
  becomes a write to the author's checkout (plan review round 4).
- **Rationale**: a fallback to the author's checkout is what this feature removes.

## R6. The two missed findings (#120)

- **Decision**: in `commands/review.md` step 2, the bug list gains "personal data or a secret that
  reaches a log, including inside a helper the changed lines call with it", and the step says to
  open the helpers a changed line passes such a value to. The severity list gains "a test that
  fakes the component whose behavior it asserts": Low, Medium when it is the only proof of a
  privacy or security rule. Personal data in a log is at least Medium where the project's rules
  are silent, High when they forbid it.
- **Rationale**: step 2 already says "open what each changed function calls", but its list names
  only "a secret", so the reviewer read the call and not what the helper did with the e-mail.

## R8. Plugin and project copy on different versions

- **Decision**: the guard always requires `isolation: "worktree"` on a review launch; it reads no
  project file. The checks that make isolation safe (step 0: in an `agent-*` copy, not the
  checkout; the facts carry `commit:`; then the switch to `commit:`) are in `agents/reviewer.md`,
  which ships with the plugin together with the guard. A project copy older than the plugin
  passes no `commit:`, so the reviewer stops with "the project's landspec copy predates the plugin:
  run /landspec:init", and the guard's refusal line says the same.
- **Rationale**: plan reviews 2, 4 and 5 each found a way the earlier design (require isolation only
  when the project's own review.md asked for it) failed open: a field it could not read, a
  directory it could not resolve, a session in another repository. The gate existed only to keep
  old project copies running unchanged. Refusing them with a one-command fix is fail-closed and
  has no lookup to get wrong.
- **Alternatives**: the gate (rejected above); the `#110` pattern (wait for the project's script)
  works for `gh pr create` because a wrong guess there opens a PR without a review, never writes to
  the author's files.

## R7. Lock files outside the repository

- **Decision**: out of scope. A command the reviewer runs in its copy can still write outside it
  (`/tmp`, a lock in `$HOME`). `review.md` keeps the rule that commands are few and only to settle a
  suspected bug, and says a command that writes outside its copy is not run.
