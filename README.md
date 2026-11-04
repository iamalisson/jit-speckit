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
task list. jit-speckit plugs into it and handles everything around the code:

- every task gets a GitHub issue, its own branch and its own pull request;
- secrets are refused at commit and push, and every pull request passes a security gate;
- the project's constitution starts with security, testing and simplicity defaults, sized to how
  serious the project is.

You keep writing specs and code. The rest happens on its own, the same way every time.

## Install

In Claude Code:

```
/plugin install jit-speckit --marketplace iamalisson/jit-speckit
```

<sub>On older Claude Code versions, use two prompts: `/plugin marketplace add iamalisson/jit-speckit`, then `/plugin install jit-speckit@jit-speckit`. Update later from `/plugin`.</sub>

You also need `git` and the [GitHub CLI](https://cli.github.com), logged in. `/jit-speckit:init`
installs spec-kit for you if it's missing.

## Start

| Your project | Run | Then |
|---|---|---|
| **New** (empty folder or fresh repo) | `/jit-speckit:init` | `/speckit-constitution`, to describe the project |
| **Existing** (has code, no spec-kit yet) | `/jit-speckit:init` | nothing: it reads your code and fills the constitution for you |

`init` asks one question: how serious the project is (**lite**, **standard** or **full**, see
[Levels](#levels)). It changes nothing in your code and commits nothing; you review the setup and
commit it.

## The loop

| How often | Run | What you get |
|---|---|---|
| **Once per feature** | `/speckit-specify "what and why"` | the spec |
| | `/speckit-plan` | the technical plan |
| | `/speckit-tasks` | the task list, **one issue per task**, and a spec PR |
| | *(optional)* `/speckit-clarify` · `/speckit-analyze` | fewer open questions · a consistency check (required on `full`) |
| | merge the spec PR | |
| **Once per task** | `/jit-speckit:next` | progress, then the next open task: **its branch → code → checks → review → PR** |
| | merge the PR | the issue closes |

When `/jit-speckit:next` says every task is done, the feature is finished. Run
`/jit-speckit:security` before you release it.

> `/jit-speckit:next` picks the next task for you. `/speckit-implement T007` does the same for a
> specific task. Either way, exactly one task per run.

## Security, built in

| When | Check |
|---|---|
| **every commit** | refuses `.env`, keys and credential files, and tokens or passwords in the code. Under a second. |
| **every command Claude runs** | blocks `--no-verify`, `git add -A`, commits on base branches and pushes to them |
| **every push** | re-checks every outgoing commit, including ones made with `--no-verify` |
| **before each PR** | scanners on the changed files, `/security-review`, `/code-review` |
| **every PR, and weekly** | CI gate: Gitleaks, OSV-Scanner and zizmor (Semgrep with the OWASP rules on `full`), all pinned and checksum-verified |
| **before a release** | `/jit-speckit:security`, the full audit |

`/jit-speckit:security` maps your attack surface, runs the best open-source scanners, then
reviews every OWASP Top 10:2025 and CWE Top 25 category by hand. That includes business logic,
race conditions and double-spends, which no scanner sees. A second agent tries to disprove every
serious finding before it's reported. Findings stay private: reports live inside `.git`, and
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
| Added to the repo | git hooks, PR template | + CI for your stack, security CI, Dependabot | + Semgrep in CI, CODEOWNERS, SECURITY.md, release workflow |
| Before each PR | asks first | review at `/code-review medium` | review at `/code-review high`, and evidence is required |
| `/speckit-analyze` | optional | optional | required before any task |

Your stack (Rust, Node with npm/pnpm/yarn, Python with uv/pip, Go) is detected and shapes the CI
and the constitution. Existing files are never overwritten.

## Using Claude Code well

| Tool | Where it fits |
|---|---|
| **Plan mode** (`Shift+Tab`) | thinking out loud before `/speckit-specify` or during `/speckit-clarify`. Not for `/speckit-plan`, which writes files that plan mode blocks. |
| **`/code-review`** | before each PR, automatically. Run `/code-review ultra` yourself before merging a large or risky change (cloud, billed). |
| **`/security-review`** | before each PR, automatically, and inside `/jit-speckit:security` |
| **Worktrees** | tasks marked `[P]` can run in parallel: open another session with `claude --worktree` and run `/speckit-implement T00X` there. Each one gets its own branch and PR. |

## What happens automatically

| After / before | jit-speckit |
|---|---|
| after `/speckit-tasks` | one issue per task, `— #N` written on each task line, the spec PR opened |
| after `/speckit-analyze` | records the analysis (level `full` needs it before tasks start) |
| before `/speckit-implement` | refuses without exactly one task, an issue, the merged spec and a clean tree; otherwise switches to `feat/<feature>-t00x-<slug>` |
| after `/speckit-implement` | checks, commit, security scan, reviews, push, PR with `Closes #N` |

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

## Uninstall

```
/plugin uninstall jit-speckit
```

In a project, `specify extension remove jit && specify preset remove jit && git config --unset core.hooksPath`.
