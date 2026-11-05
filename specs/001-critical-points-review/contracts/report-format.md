# Contract: the report (`report.md` and `report/*.md`)

## Shape

```text
report.md                     # written last, from sections 1–8
  # Critical-points review — jit-speckit 1.7.2
  ## Summary      ranked table: id · rank · promise · one line · proposed fix; links to sections
  ## Fixes        one entry per High/Medium finding: the change, the promise, the failing check
  ## Unverified   every claim that could not be checked, and what would check it
report/1-task-chain.md        # ## 1. Task chain                          P01–P05, P23
report/2-secrets-guard.md     # ## 2. Secrets and the command guard       P06–P09
report/3-review-gate.md       # ## 3. Review gate and tests as evidence   P10–P15, P26
report/4-ci-supply-chain.md   # ## 4. CI gate and supply chain            P16, P17, P25, P27, P28
report/5-levels-files.md      # ## 5. Levels, setup and the user's files  P18–P22, P24
report/6-own-rules-cost.md    # ## 6. The project against its own rules, and cost per level
report/7-core-model.md        # ## 7. The core model (D1–D3)
report/8-context-engineering.md # ## 8. Prompts against context-engineering guidance (C1–C11)
```

Section 8 has one table, `| id | principle | verdict | files | evidence |`, one row per principle
(`| C01 |` … `| C11 |`), verdict `follows`, `departs (reason written)`, `departs` or `unverified`.

Every section file starts with `Reviewed at: <commit SHA>`. Sections 1–5 then have one table, `| id | promise | verdict | evidence |`, one row per
promise (`| P01 | ...`), then one block per non-"holds" finding with the fields in
[data-model.md](../data-model.md). An exploitable finding (spec FR-013) keeps its promise row and nothing else:
`| P08 | <promise> | reported privately (F2.3, GHSA-xxxx-xxxx-xxxx) | see advisory |`; its text
lives in the private draft advisory whose summary starts with `[001 F2.3]`. A promise with several
private findings lists each pair, separated by `; `: `reported privately (F2.3, GHSA-…; F2.5, GHSA-…)`;
a finding that touches several promises carries the same pair on each of their rows (one advisory).

Each public finding block starts with the heading `### F<section>.<n> · <High|Medium|Low> · <promise ids> · <one line>`,
and each entry under *Fixes* in `report.md` with `### Fix F<section>.<n> · <the change>`, so both can be counted.

Each gate in sections 2–3 also gets the two-column table from research R4: *script refuses* /
*prompt asks*, with the doc's wording quoted.

## Promise inventory

| id | Promise | Stated in | Section |
|---|---|---|---|
| P01 | Every task gets exactly one GitHub issue; an interrupted run never makes duplicates | README "The loop"; `issues.sh` | 1 |
| P02 | Every task gets its own branch from the base, refused without one task, an issue, the merged spec and a clean tree; pushed at once as a claim | reference "What happens automatically" | 1 |
| P03 | Every task gets one PR with `Closes #N`; a task is done when its issue closes | README; constitution | 1 |
| P04 | `/jit-speckit:next` is resumable, never offers a task in progress twice (worktrees too), holds a task until its dependencies close | README; reference "Using Claude Code well" | 1 |
| P05 | The spec is its own PR; the spec folder is never lost while switching branches | README; design "The spec is its own PR" | 1 |
| P06 | Every commit refuses `.env`, keys, credential files and token- or password-like lines, in under a second | README "Security, built in"; security "The layers" | 2 |
| P07 | Every push re-checks every outgoing commit, including `--no-verify` ones; base branches are PR-only on standard and full | README; security | 2 |
| P08 | Every command Claude runs is refused for `--no-verify`, `commit -n`, hooks switched off, `git add -A`, commits on and pushes to base branches; the guard is the plugin's own copy | README; security | 2 |
| P09 | Findings never print the secret itself | `secrets.sh` header; constitution "Project" | 2 |
| P10 | Before every PR, at every level, a fresh agent reviews the whole repository; the PR is refused without a recorded `ready` for the exact diff | README; design "The review is independent"; reference | 3 |
| P11 | No issue is created without a recorded plan review of the current `tasks.md` | reference "What happens automatically" | 3 |
| P12 | Never opens a PR on red checks | constitution "Project"; `extension/commands/pr.md` | 3 |
| P13 | Tests are evidence: a PR that changes existing tests needs `## Test changes`; mutation testing runs on the change | reference; `pr.md` | 3 |
| P14 | GitHub Copilot code review is requested on every PR when the account has it | README; design | 3 |
| P15 | On full, `## Evidence` and `/speckit-analyze` on the current `tasks.md` are required | README "Levels" | 3 |
| P16 | Every PR, push and week the CI gate runs Gitleaks on full history, OSV-Scanner, zizmor (Semgrep on full, trivy with infra); pinned and checksum-verified; not skippable with branch protection | README; security | 4 |
| P17 | Every action pin is in one place; Dependabot proposes updates; generated workflows use `persist-credentials: false` and read-only permissions | security "Supply chain hygiene" | 4 |
| P18 | Levels size the flow, the constitution and the CI; changeable any time; going down never deletes files | README "Levels" | 5 |
| P19 | Nothing of the user's is overwritten: managed files carry a marker, unmarked ones are written only when missing | design "Nothing of yours is overwritten" | 5 |
| P20 | `remove` deletes only what still matches what jit wrote | design; reference "Uninstall" | 5 |
| P21 | `init` refreshes the project's extension copy, keeps the level, changes no code and commits nothing | README "Update", "Start" | 5 |
| P22 | No AI attribution lines in commits or PRs by default | README "Levels"; reference "AI attribution" | 5 |
| P23 | Never commits or pushes for the user outside the documented flows | constitution "Project" | 1 |
| P24 | Runs on Linux and macOS (bash 3.2, BSD tools) | README badge; constitution "Stack" | 5 |
| P25 | Security findings are never put in a public place | constitution "Project"; `skills/security/SKILL.md` | 4 |
| P26 | Before each PR, the scanners run on the changed files and `/security-review` runs | README "Security, built in" (before each PR); security "The layers" | 3 |
| P27 | Before a release, `/jit-speckit:security` runs the full audit | README "Security, built in" (before a release); security "The audit" | 4 |
| P28 | `/jit-speckit:init` offers secret scanning with push protection and branch protection requiring CI | security "The layers" (On GitHub) | 4 |
