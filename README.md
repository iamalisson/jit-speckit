# jit-speckit

**Spec-driven development with the boring parts done for you.**
Every task gets a GitHub issue, its own branch and its own pull request, automatically.
Every project starts with sensible defaults, sized to how serious the project is.

Built on [GitHub Spec Kit](https://github.com/github/spec-kit) for [Claude Code](https://claude.com/claude-code).
It doesn't replace spec-kit: it plugs into spec-kit's own extension and preset system.

```text
specify ─► plan ─► tasks ─► (issues created) ─► implement T001 ─► (branch ─► code ─► PR) ─► merge ─► issue closed
```

---

## Install (once per machine)

You need `git`, the [GitHub CLI](https://cli.github.com) (`gh auth login`) and spec-kit:

```bash
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
git clone https://github.com/iamalisson/jit-speckit ~/jit-speckit
~/jit-speckit/install.sh
```

This adds three skills to Claude Code: `/jit-speckit-init`, `/jit-speckit-adopt` and
`/jit-speckit-level`. Run `git pull` in `~/jit-speckit` to update them.

## How to use

Open Claude Code in your project and run these in order:

| Step | Run | How often | Needs first |
|---|---|---|---|
| 1. Set up | `/jit-speckit-init` (asks the level) | **once per project** | — |
| 2. Describe the project | existing code: `/jit-speckit-adopt` · new project: `/speckit-constitution` | **once per project** | step 1 |
| 3. Spec a feature | `/speckit-specify "what and why"` | once per feature | step 2 |
| 3b. *(optional)* | `/speckit-clarify` | once per feature | spec |
| 4. Plan it | `/speckit-plan` | once per feature | spec |
| 5. Break it down | `/speckit-tasks` → **issues and the spec PR are created** | once per feature | plan |
| 5b. *(optional; required on `full`)* | `/speckit-analyze` | once per feature | tasks |
| 6. Merge the spec PR | on GitHub | once per feature | step 5 |
| 7. Build a task | `/speckit-implement T001` → **branch → code → PR** | **once per task** | spec PR merged |
| 8. Merge the task PR | on GitHub → the issue closes | once per task | step 7 |

Repeat 7–8 for every task (T002, T003, …), and 3–8 for every feature.

> **Rule of thumb:** project setup runs once, feature steps run once per feature, and
> `/speckit-implement` runs once **per task**, always with exactly one task ID.

## Levels

Pick one at setup. Change it any time with `/jit-speckit-level <level>`; going down never
deletes files.

| | **lite** | **standard** (default) | **full** |
|---|---|---|---|
| For | prototypes, solo | products, small teams | production, several environments |
| Branches | `feat/*` → `main` | `feat/*` → `develop` → `main` | `feat/*` → `develop` → `staging` → `main` |
| Defaults in the constitution | KISS, no secrets in the repo, tests for logic, task = issue = PR | + security baseline, stack idioms, dependency policy, integration tests, Conventional Commits | + threat model per feature, data integrity, observability, releases and rollback |
| Files added | PR template | + CI for your stack, Dependabot, auto-close issues on merge | + CODEOWNERS, SECURITY.md, release workflow |
| After `/speckit-implement` | asks before opening the PR | opens the PR | opens the PR, and requires an `## Evidence` section |
| `/speckit-analyze` | optional | optional | required before any task |

The stack (Rust, Node with npm/pnpm/yarn, Python with uv/pip, Go) is detected from your
manifest files and shapes the CI and the constitution. Existing files are never overwritten.

## What happens automatically

| When | jit-speckit |
|---|---|
| after `/speckit-tasks` | creates one issue per task, writes `— #N` on each task line, opens the spec PR |
| after `/speckit-analyze` | records that the current tasks were analyzed |
| before `/speckit-implement T00X` | refuses without exactly one task, an issue, a merged spec or a clean tree; otherwise switches to `feat/<feature>-t00x-<slug>` |
| after `/speckit-implement T00X` | runs the checks, commits, pushes, opens the PR with `Closes #N` |

These run as spec-kit hooks. Spec-kit names them `/speckit-jit-*`, and you can also run them
by hand (for example `/speckit-jit-issues` if you skipped one).

## Configuration

`.specify/extensions/jit/jit-config.yml`:

| Key | Default | Meaning |
|---|---|---|
| `level` | `standard` | `lite`, `standard` or `full` (set it with `/jit-speckit-level`) |
| `base_branch` | `auto` | the branch task PRs target; `auto` = `main` on lite, `develop` otherwise |
| `branch_prefix` | `feat` | task branches are `<prefix>/<feature>-<task>-<slug>` |
| `issue_labels` | `type:task` | comma-separated labels for task issues |

## Uninstall

```bash
~/jit-speckit/install.sh --uninstall          # removes the skills
specify extension remove jit && specify preset remove jit   # inside a project
```

## License

MIT
