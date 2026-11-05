<h1 align="center">jit-speckit</h1>

<p align="center">
  <em>Spec Kit, with the boring parts done.<br>
  Every task gets an issue, a branch and a pull request. Every commit gets checked. Every project starts with the right defaults.</em>
</p>

<p align="center">
  <a href="https://github.com/iamalisson/jit-speckit/actions/workflows/test.yml"><img src="https://github.com/iamalisson/jit-speckit/actions/workflows/test.yml/badge.svg" alt="Tests"></a>
  <img src="https://img.shields.io/badge/Claude%20Code-plugin-111111?style=flat-square" alt="Claude Code plugin">
  <img src="https://img.shields.io/badge/spec--kit-v1.2.5-111111?style=flat-square" alt="spec-kit v1.2.5">
  <img src="https://img.shields.io/badge/runs%20on-Linux%20%C2%B7%20macOS-111111?style=flat-square" alt="Linux and macOS">
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/flow-dark.svg">
    <img src="assets/flow-light.svg" width="880" alt="spec and tasks once per feature; then, once per task and automatically: issue, branch, pull request, merged and issue closed">
  </picture>
</p>

---

[GitHub Spec Kit](https://github.com/github/spec-kit) turns a feature idea into a spec, a plan and a
task list, and Claude writes the code. jit-speckit plugs into it and handles everything around
that code:

- every task gets a GitHub issue, its own branch and its own pull request;
- secrets are refused at commit and push, and every pull request passes a security gate;
- the project's constitution starts with security, testing and simplicity defaults, sized to how
  serious the project is.

You plan the feature and review the work. Claude writes the code, and jit-speckit does the rest
the same way every time.

## Install

In Claude Code:

```
/plugin install jit-speckit --marketplace iamalisson/jit-speckit
```

<sub>Needs Claude Code 2.1.275 or newer; on older versions use two prompts: `/plugin marketplace add iamalisson/jit-speckit`, then `/plugin install jit-speckit@jit-speckit`.</sub>

## Update

Plugins don't update themselves. From a terminal, one line:

```
claude plugin marketplace update jit-speckit && claude plugin update jit-speckit@jit-speckit
```

Then restart Claude Code. **In every project that already uses jit-speckit, run `/jit-speckit:init`
once**: each project keeps its own copy of the extension (hooks, scripts, review method, scaffold)
under `.specify/`, and only `init` refreshes it. It keeps the project's level and touches nothing
else. Skip it and the project keeps running the old version, whatever the plugin says.

You also need `git` and the [GitHub CLI](https://cli.github.com), logged in. `/jit-speckit:init`
installs spec-kit for you if it's missing.

## Start

| Your project | Run | Then |
|---|---|---|
| **New** (empty folder) | `/jit-speckit:new` | the foundation spec it suggests: you pick the stack together with Claude, and it sets up the project (tooling, CI, containers) and jit-speckit. To set up only jit-speckit and describe the project yourself, run `/jit-speckit:init`, then `/speckit-constitution` |
| **Existing** (has code, no spec-kit yet) | `/jit-speckit:init` | nothing: it reads your code and fills the constitution for you |

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
- **[GUIDELINES.md](docs/GUIDELINES.md)**: start simple, well done and secure, and add
  complexity only when a real need shows up. Its
  [Starter checklist](docs/GUIDELINES.md#starter-checklist) lists what `new` sets up and what
  the foundation spec covers.
- **[GUARDRAILS.md](docs/GUARDRAILS.md)**: the common, costly mistakes and how to catch them,
  each backed by evidence.
- **[references.yaml](docs/references.yaml)**: the primary source to check for each topic,
  so choices follow current practice, not habits from five years ago.

`init` asks one question: how serious the project is (**lite**, **standard** or **full**, see
[Levels](#levels)). It changes nothing in your code and commits nothing; you review the setup and
commit it.

## The loop

| How often | Run | What you get |
|---|---|---|
| **Once per feature** | `/speckit-specify "what and why"` | the spec |
| | *(optional)* `/speckit-clarify` | fewer open questions, before planning |
| | `/speckit-plan` | the technical plan |
| | `/speckit-tasks` | the task list, grounded in the real code, **one issue per task**, and a spec PR |
| | *(optional)* `/speckit-analyze` | a consistency check (required on `full`) |
| | merge the spec PR | |
| **Once per task** | `/jit-speckit:next` | progress, then the next open task: **its branch → code → checks → review → PR** |
| | merge the PR | the issue closes |
| **When every task is done** | `/speckit-converge` | compares the code with the spec; anything unbuilt becomes new tasks with issues |

### Why one task = one issue = one branch = one PR

- **Review finds bugs only in small changes.** A Cisco study of 2,500 reviews put the useful
  size at 200 to 400 lines; past that, defects found per line fall off
  ([SmartBear](https://smartbear.com/learn/code-review/best-practices-for-peer-code-review/)).
  Google's guide calls about 100 lines reasonable and 1,000 too large
  ([small CLs](https://google.github.io/eng-practices/review/developer/small-cls.html)). This
  matters more with AI-written code: a 150-line PR gets read, a 2,000-line one gets scrolled.
- **Small batches are faster and safer at once.** DORA's research links batch size to both
  delivery speed and stability
  ([working in small batches](https://dora.dev/capabilities/working-in-small-batches/)), and the
  2025 model lists it among the capabilities that make AI help instead of hurt.
- **Failures localize.** A red CI, a security finding or a production bug points at one task.
  One revert removes one task. In a one-PR feature, the revert takes everything.
- **"Done" has an external definition.** The issue says which requirement produced the code and
  closes only when the PR merges. That is what makes `/jit-speckit:next` resumable after a month,
  and what the independent review checks the PR against.

The cost is real: a CI run, a review round and a merge per task. It pays off when tasks are
**vertical slices**, one observable behavior with its test, and not layers. The tasks template
says so, and the plan review flags layer-shaped tasks before any issue exists.

**Small fixes don't need the feature loop.** A typo, a one-line bug fix or a dependency bump
goes on a normal branch with a normal PR. The hooks and the CI gate still apply. The spec, issue
and per-task flow are for features.

The spec PR and the task PRs are separate on purpose: task branches start from the base branch
and need `tasks.md` there, and each task PR stays small and closes one issue. See
**[examples/](examples/)** for one feature walked through from spec to merged PRs, with the
real issue and PR bodies.

When `/jit-speckit:next` says every task is done, run `/speckit-converge`. If it finds nothing
left to build, the feature is finished: run `/jit-speckit:security` before you release it.

> `/jit-speckit:next` picks the next task for you. `/speckit-implement T007` does the same for a
> specific task. Either way, exactly one task per run.

## Security, built in

| When | Check |
|---|---|
| **every commit** | refuses `.env`, keys and credential files, and tokens or passwords in the code. Under a second. |
| **every command Claude runs** | blocks `--no-verify`, `git add -A`, commits on base branches and pushes to them |
| **every push** | re-checks every outgoing commit, including ones made with `--no-verify` |
| **before each PR** | an **independent review** by a fresh agent that reads the whole repository, not the diff (siblings' guards, claims re-run, one mutation, the real upgrade path), scanners on the changed files, `/security-review`; then GitHub Copilot code review on the PR when the account has it |
| **every PR, and weekly** | CI gate: Gitleaks, OSV-Scanner and zizmor (Semgrep with the OWASP rules on `full`; trivy on Dockerfiles and Terraform when the project has them), all pinned and checksum-verified |
| **before a release** | `/jit-speckit:security`, the full audit |

`/jit-speckit:security` maps your attack surface, runs the best open-source scanners, then
reviews every OWASP Top 10:2025 and CWE Top 25 category by hand. That includes business logic,
race conditions and double-spends, which no scanner sees. Every serious finding is checked
against the code before it's reported; in `deep` mode a separate agent tries to disprove each
one. Findings stay private: reports live inside `.git`, and
public repos get private security advisories, never public issues.

Why each layer exists, and what it can't do: **[docs/security.md](docs/security.md)**.

## Levels

Pick one at `init`, and change it any time with `/jit-speckit:level`. Going down never deletes
files.

| | **lite** | **standard** (default) | **full** |
|---|---|---|---|
| For | prototypes, solo work | products, small teams | production, money, personal data |
| Branches | `feat/*` → `main` | `feat/*` → `develop` → `main` | `feat/*` → `develop` → `staging` → `main` |
| Constitution defaults | KISS, secrets, tests for logic, task = issue = PR | + security baseline, stack idioms, dependency policy, integration tests | + threat model per feature, data integrity, observability, releases |
| Added to the repo | git hooks, PR template, `.claude/settings.json` without AI attribution (only when the project has none yet) | + CI for your stack, security CI, Dependabot | + Semgrep in CI, CODEOWNERS, SECURITY.md, release workflow |
| Before each PR | asks first | independent review, `## Review` required in the PR | the same, and evidence is required |
| `/speckit-analyze` | optional | optional | required before any task |

Your stack (Rust, Node with npm/pnpm/yarn, Python with uv/pip, Go) is detected and shapes the CI
and the constitution; the constitution's **Commands** line, once `/jit-speckit:adopt` fills it,
is what the generated CI runs. A repo whose workflows already check pull requests gets no second
CI. Your files are never overwritten: the ones jit-speckit generates carry a
`# jit-speckit: managed file` first line and are re-created on `/jit-speckit:level`; delete that
line to make one yours. Repos that run hooks through the pre-commit framework or husky get jit's
two checks added there.

## Using Claude Code well

| Tool | Where it fits |
|---|---|
| **Plan mode** (`Shift+Tab`) | thinking out loud before `/speckit-specify` or during `/speckit-clarify`. Not for `/speckit-plan`, which writes files that plan mode blocks. |
| **`/code-review ultra`** | yourself, before merging a large or risky change (cloud, billed). The review before each PR is jit's own `/speckit-jit-review`: a fresh agent grounded in the whole repository, so it is not anchored on the session that wrote the code. |
| **`/security-review`** | before each PR, automatically, and inside `/jit-speckit:security` |
| **Worktrees** | tasks marked `[P]` can run in parallel: open another session with `claude --worktree` and run `/jit-speckit:next` there. A task with an open PR counts as in progress and is never picked twice, so every worktree gets a different task. Each one gets its own branch and PR. The active feature, the `/speckit-analyze` record and the security reports are shared by every worktree, so `full` works there too. |

## What happens automatically

| After / before | jit-speckit |
|---|---|
| after `/speckit-tasks` | the plan is **grounded in the real code** (every symbol a task removes is searched for, every quickstart command is read, every data write names its target), then reviewed by a fresh agent (plan review), then one issue per task, `— #N` written on each task line, the spec PR opened |
| after `/speckit-analyze` | records the analysis (level `full` needs it before tasks start) |
| after `/speckit-converge` | the new tasks it found get grounded, get issues, and reach the base branch through a spec PR |
| before `/speckit-implement` | refuses without exactly one task, an issue, the merged spec and a clean tree; otherwise switches to `feat/<feature>-t00x-<slug>`. spec-kit's implement command is told to build only that task and not tick it (the issue closing is "done") |
| after `/speckit-implement` | checks, commit, security scan, `/security-review`, the independent review (fixed until `ready`), push, PR with `Closes #N` and `## Review`, Copilot code review requested |
| every issue and PR | assigned to you; given the milestone and project if configured (a failure only warns); no AI attribution lines; long output folded into `<details>` |
| a task PR that changes existing tests | refused unless the body has a `## Test changes` section saying why. New tests need no explanation; weakening one does |

These are spec-kit hooks, so you never type them. If you skip one, run it yourself:
`/speckit-jit-issues`, `/speckit-jit-pr`.

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

## Help

`/jit-speckit:help` shows every command, level and setting. Ask it anything:
`/jit-speckit:help why is the spec a separate PR?`

## Notes

- **AI attribution:** `.claude/settings.json` turns off the "Generated with Claude Code" and
  `Co-Authored-By` lines for everyone on the project. jit-speckit writes it only when the
  project has no `.claude/settings.json` yet; to get the same in an existing one, add
  `"attribution": { "commit": "", "pr": "" }`. If your team or a policy requires AI
  disclosure, delete its `attribution` block: jit-speckit then keeps those lines, and never asks
  for the block back.

## Uninstall

From one project, `/jit-speckit:remove`: it unregisters the spec-kit extension and preset,
deletes the files jit-speckit created and you never edited (hooks, workflows, Dependabot, PR
template, `SECURITY.md`, `CODEOWNERS`), undoes its git hook setup and strips its block from the
constitution. Your specs, commits and edits stay; `develop`/`staging` and the GitHub protections
are listed for you to remove by hand. `/jit-speckit:remove --with-speckit` also removes spec-kit's
own files, for a reinstall from zero with `/jit-speckit:init`.

From Claude Code: `/plugin uninstall jit-speckit`.
