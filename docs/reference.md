# jit-speckit reference

The details behind the [README](../README.md): updating, what `new` sets up, stack detection
and managed files, what runs automatically, the Claude Code tools that fit, every setting, AI
attribution, and uninstalling. For why things work the way they do, see [design.md](design.md).

## Update

Plugins don't update themselves. From a terminal, one line:

```
claude plugin marketplace update jit-speckit && claude plugin update jit-speckit@jit-speckit
```

Inside a Claude Code session, the same line with a `!` in front runs it there. Then
`/reload-plugins`, or restart Claude Code. **In every project that already uses jit-speckit, run
`/jit-speckit:init` once**: each project keeps its own copy of the extension (hooks, scripts,
review method, scaffold) under `.specify/`, and only `init` refreshes it. It keeps the project's
level and touches nothing else. Skip it and the project keeps running the old version, whatever
the plugin says.

From 1.8.0 on, `init` refuses to take a project back to an older version (`this plugin copy is
<plugin>, the project is at <project>; run /reload-plugins (or setup.sh --downgrade)`), for
example from a session still running the old copy. An older copy's own `setup.sh` has no such
check, so after an update run `/reload-plugins` first, then `init`.

## What `new` does

`new` doesn't decide the critical things for you. It asks who the project is for, whether it
handles personal data or money, where it runs, and so on. Then it recommends the simplest option
that fits, and lets you argue. If your plan skips something important (tests, logging, error
handling, backups) or takes a known risk (secrets in files, weak password storage,
microservices for an MVP), it tells you why and offers the fix. For the serious risks it won't
continue until you explicitly accept them.

`new` writes **no application code**: in a spec-driven project, even the foundations arrive
through a spec. It sets up the tooling, for any stack, with today's versions:
- the stack's own project tool;
- formatter, linter, type checker, tests and mutation testing;
- a lockfile with a release cooldown, and CI;
- a dev container, plus a locked-down container for a service.

It runs the checks on the empty project, then suggests the first spec: the **foundation**
(validated config, one error type whose 500s carry an `error_id`, JSON logs with request IDs,
limits, a health check, tests at three levels). It follows three short files:
- **[GUIDELINES.md](GUIDELINES.md)**: start simple, well done and secure, and add
  complexity only when a real need shows up. Its
  [Starter checklist](GUIDELINES.md#starter-checklist) lists what `new` sets up and what
  the foundation spec covers.
- **[GUARDRAILS.md](GUARDRAILS.md)**: the common, costly mistakes and how to catch them,
  each backed by evidence.
- **[references.yaml](references.yaml)**: the primary source to check for each topic,
  so choices follow current practice, not habits from five years ago.

## Stack detection and managed files

Your stack (Rust, Node with npm/pnpm/yarn, Python with uv/pip, Go) is detected and shapes the CI
and the constitution; the constitution's **Commands** line, once `/jit-speckit:adopt` fills it,
is what the generated CI runs. A repo whose workflows already check pull requests gets no second
CI. Your files are never overwritten: the ones jit-speckit generates carry a
`# jit-speckit: managed file` first line and are re-created on `/jit-speckit:level`; delete that
line to make one yours. Repos that run hooks through the pre-commit framework or husky get jit's
two checks added there.

## Several features at once

Every feature is its own folder (`specs/001-login/`, `specs/002-reports/`), and everything jit
creates carries its number: issues `[001] T003: ...`, branches `feat/001-t003-...`, the spec PR
`spec/001-login`. They never collide. The **active feature** is per clone (`.specify/feature.json`,
git-ignored): `/speckit-specify` sets it to the new feature, and `/jit-speckit:next 002` or
`/speckit-implement 002 T001` set it explicitly. With no argument, `next` serves the active
feature; when more than one feature has tasks to start, it lists them and asks. On a task branch
the branch name decides, for `next` too, so a worktree never follows the main checkout. A task is
done when the issue number on its line is closed: `next` reads every task's issue by number in one
query per feature, so a renamed issue still counts, and a number it cannot read stops it with
GitHub's error. GitHub closes a PR's `Closes #N` issues only on a merge into the default branch;
on standard and full, the managed `close-linked-issues.yml` closes them on a merge into `develop`
or `staging`, and its job fails, naming `could not close: #N`, when one of them cannot be closed.

A task whose line says `(depends on T003)` is **blocked** until T003's issue closes, so `next`
never offers work whose prerequisite has not merged.

A task is **claimed** the moment it starts: its branch is pushed to origin, empty. From then on
`next` in every clone and worktree shows it as in progress and never picks it; the clone that
started it sees it as `resume` and picks it first. When origin refuses that push (no network, no
write access, a server hook), the task still starts and `branch.sh` warns `could not claim <branch>
on origin: <git's error>`: other clones may start the same task until the branch is pushed. Teammates need nothing but `/jit-speckit:init`
once in their clone: the shared state is `tasks.md` on the base branch, the issues, and the
branches on origin.

## What happens automatically

| After / before | jit-speckit |
|---|---|
| after `/speckit-tasks` | the plan is **grounded in the real code** (every symbol a task removes is searched for, every quickstart command is read, every data write names its target), then reviewed by a fresh agent (plan review, recorded; no issue is created without it), then one issue per task, `— #N` written on each task line, the spec PR opened |
| after `/speckit-analyze` | records the analysis from its report: `analyzed.sh <report-file>` refuses a file without the report's "Specification Analysis Report" and "Coverage Summary Table", and keeps the report next to the record (level `full` needs it, for the current `tasks.md`, before tasks start) |
| after `/speckit-converge` | the new tasks it found get grounded, get issues, and reach the base branch through a spec PR |
| before `/speckit-implement` | refuses without exactly one task, an issue, the merged spec and a clean tree; otherwise switches to `feat/<feature>-t00x-<slug>` and pushes it to origin at once (the claim). spec-kit's implement command is told to build only that task and not tick it (the issue closing is "done") |
| after `/speckit-implement` | checks, commit, `/security-review`, the independent review (recorded for the exact diff, fixed until `ready`), mutation testing and the security scan on the change after the last commit, push, PR with `Closes #N` and `## Review`, Copilot code review asked for (`copilot: code review requested` only when GitHub lists it as a reviewer, else `copilot: not requested`). The PR is refused without a recorded `ready` review for the diff, at every level, and when the constitution's test command fails (it runs before the push; with no test command, a warning says the tests were not run). With a `mutate` command in the constitution, it is also refused without a `mutants.sh` result for the diff, or on surviving mutants that `## Evidence` does not explain; without one, the body says mutation testing was not run. It is refused without a `security-scan.sh --changed` result for the diff (missing scanners and findings do not refuse) |
| every issue and PR | assigned to you; given the milestone and project if configured (a failure only warns); no AI attribution lines; long output folded into `<details>` |
| a task PR that changes existing tests | refused unless the body has a `## Test changes` section saying why. New tests need no explanation; weakening one does. Tests are files under `tests/`, `test/`, `Tests/`, `__tests__/`, `spec/`, `e2e/`, `cypress/` or a `*.Tests/` folder, and files named `*.test.*`, `*.spec.*` (or with `_`, `-`), `*.cy.*`, `tests.py`, `test_*.py` or `FooTests.swift` (case-sensitive). For any other layout, add a line `tests: <regex>` (`grep -E`) to the constitution; an invalid one makes `pr.sh`, `mutants.sh` and `review.sh record` refuse. The same files are what a review's `- proven:` line may name, and what a fix round (`review.sh record --delta`) may change beyond its 20-line limit outside the previous findings |

These are spec-kit hooks, so you never type them. If you skip one, run it yourself:
`/speckit-jit-issues`, `/speckit-jit-pr`.

## Using Claude Code well

| Tool | Where it fits |
|---|---|
| **Plan mode** (`Shift+Tab`) | thinking out loud before `/speckit-specify` or during `/speckit-clarify`. Not for `/speckit-plan`, which writes files that plan mode blocks. |
| **`/code-review ultra`** | yourself, before merging a large or risky change (cloud, billed). The review before each PR is jit's own `/speckit-jit-review`: a fresh agent grounded in the whole repository, so it is not anchored on the session that wrote the code. |
| **`/security-review`** | before each PR, automatically, and inside `/jit-speckit:security` |
| **Worktrees** | `/jit-speckit:next` lists the other `[P]` tasks that can start now and, on yes, gives each its own worktree beside the repo (`<repo>-<feature>-<task>`) and claims its branch on origin, one after another. Open a Claude Code session in each and run `/speckit-implement <feature> <task>`. Each task keeps its own branch and PR. Blocked tasks and tasks without `[P]` right after their ID are never offered. A claim that cannot be pushed only warns, so another clone may still start the same task. When you're done, remove each worktree with `git worktree remove <path>`. The active feature, the `/speckit-analyze` record and the security reports are shared by every worktree, so `full` works there too. |

## Configuration

`.specify/extensions/jit/jit-config.yml`:

| Key | Default | Meaning |
|---|---|---|
| `level` | `standard` | `lite`, `standard` or `full`; set it with `/jit-speckit:level` |
| `base_branch` | `auto` | the branch task PRs target: `main` on lite, `develop` otherwise |
| `branch_prefix` | `feat` | task branches are named `<prefix>/<feature>-<task>-<slug>` |
| `issue_labels` | `type:task` | comma-separated labels for task issues |
| `milestone` | *(empty)* | milestone for task issues and PRs, by name; empty means none |
| `project` | *(empty)* | GitHub project (title) to add task issues and PRs to; needs `gh auth refresh -s project` |
| `review_model` | *(empty: `opus`)* | the model of the independent and plan reviews, run in the plugin's `jit-speckit:reviewer` agent: `sonnet`, `opus` or `fable`; never `haiku`, any other value is refused. It is passed on every launch, so on a cheap session the review costs more than the session. `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` overrides it (the record then warns). The plugin's hook that blocks a review launch on another model, or in a fork, exists only where the plugin is installed |

## AI attribution

`.claude/settings.json` turns off the "Generated with Claude Code" and
`Co-Authored-By` lines for everyone on the project. jit-speckit writes it only when the
project has no `.claude/settings.json` yet; to get the same in an existing one, add
`"attribution": { "commit": "", "pr": "" }`. If your team or a policy requires AI
disclosure, delete its `attribution` block: jit-speckit then keeps those lines, and never asks
for the block back.

## Uninstall

From one project, `/jit-speckit:remove`: it unregisters the spec-kit extension and preset,
deletes the files jit-speckit created and you never edited (hooks, workflows, Dependabot, PR
template, `SECURITY.md`, `CODEOWNERS`), undoes its git hook setup and strips its block from the
constitution. A managed file that changed since jit-speckit wrote it (against the SHA-256 it
recorded in `.specify/jit-files.sha256`; for a project set up before 1.8.0, any file not committed
or with uncommitted edits) is kept and named `kept (edited): <file>`, and the record stays
while it names a kept file, so a second run keeps it too (`--with-speckit` deletes the record with
`.specify`, so that protection ends there). With no record, a marked file is kept only while its edit is uncommitted:
an edit you commit between two runs looks like jit's own file, and the second run deletes it. The constitution is deleted only when it is jit's
untouched template; any other text stays, without jit's block. A damaged block refuses before
anything is deleted. Your specs, commits and edits stay; `develop`/`staging` and the GitHub protections
are listed for you to remove by hand. `/jit-speckit:remove --with-speckit` also removes spec-kit's
own files, for a reinstall from zero with `/jit-speckit:init`.

From Claude Code: `/plugin uninstall jit-speckit`.
