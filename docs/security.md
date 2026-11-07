# Security in jit-speckit

Most security tooling fails one of two ways: it runs too late (a yearly pentest), or it is so noisy
that people learn to skip it. jit-speckit puts a cheap check where mistakes are made (each commit),
a stronger one where code is reviewed (each pull request), and a deep one where risk is decided
(before a release). Every layer catches what the one before it can miss.

## Why it matters

| | |
|---|---|
| **48,185** | CVEs published in 2025, a record, up 20.6% on 2024 ([The Stack](https://www.thestack.technology/cves-in-2025-analysis/), [J. Gamblin](https://jerrygamblin.com/2026/01/01/2025-cve-data-review/)) |
| **20%** | of breaches started by exploiting a vulnerability, up 34% in a year ([Verizon DBIR 2025](https://www.infosecurity-magazine.com/news/verizon-dbir-jump-vulnerability/)) |
| **454,600** | new malicious open-source packages in 2025, 1.23 million known in total ([Sonatype](https://www.sonatype.com/state-of-the-software-supply-chain/2026/open-source-malware)) |
| **23.8 M** | secrets leaked on public GitHub in 2024; 70% of those leaked in 2022 were still valid ([GitGuardian](https://blog.gitguardian.com/the-state-of-secrets-sprawl-2025/)) |
| **45%** | of tasks where AI-generated code chose the insecure option ([Veracode, 2025](https://www.veracode.com/press-release/ai-generated-code-poses-major-security-risks-in-nearly-half-of-all-development-tasks-veracode-research-reveals/)) |
| **75 of 76** | version tags of a popular security action silently replaced by attackers, March 2026 ([The Hacker News](https://thehackernews.com/2026/03/trivy-security-scanner-github-actions.html?m=1)) |

The categories that matter most are public: the [OWASP Top 10:2025](https://owasp.org/Top10/2025/)
and the [2025 CWE Top 25](https://cwe.mitre.org/top25/archive/2025/2025_cwe_top25.html). Broken
access control leads OWASP, and missing authorization jumped to #4 in the CWE list.

## The layers

| When | Where | What it checks | Bypassable? |
|---|---|---|---|
| Every commit | git `pre-commit` (`.githooks/`, or the repo's pre-commit framework or husky config) | `.env`, keys and credential files; provider tokens and passwords in added lines (Gitleaks too, when installed). Under a second. | locally, `--no-verify` |
| Every command Claude runs | plugin `PreToolUse` guard (the plugin's own copy; the repo only supplies config) | refuses `--no-verify` (and `commit -n`), hooks switched off with `-c core.hooksPath`, `git add -A`, commits on base branches, pushes to base branches. It sees through chains, `env`/`command`/`VAR=` prefixes, `sh -c '…'`, git's global options and bundled flags; on Claude Code 2.1.295 or newer it also blocks when the guard times out or crashes | best effort: an unusual shell trick can get past it, which is why CI and branch protection back it up |
| Every review Claude launches | plugin `PreToolUse` hook on the subagent tool (`hooks/guard-review.sh`) | refuses a launch of `jit-speckit:reviewer`, or of any agent whose prompt holds the reviewer line, without `model` set to `sonnet`, `opus` or `fable`, and in a fork of the author's session | only where the plugin is installed; `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` still forces one model (the record warns) |
| Every push | git `pre-push` (`.githooks/`, or the repo's pre-commit framework or husky config) | re-scans every commit leaving the machine (catches `--no-verify` commits); base branches are PR-only (standard, full) | locally |
| Before a PR opens | after `/speckit-implement` | the independent review (`/speckit-jit-review`: a fresh agent, the whole repository, claims re-run, one mutation), scanners on the changed files (`pr.sh` refuses the PR until `security-scan.sh --changed` ran on its exact diff; a missing scanner is reported, not refused), `/security-review` | — |
| Every PR, push and week | `security.yml` CI | Gitleaks over the full history, OSV-Scanner on every lockfile, zizmor on workflows; Semgrep with the OWASP rules on full, run from its official image pinned by sha256 digest, its rule sets fetched from the Semgrep registry at run time (their license forbids shipping them; a local `security-scan.sh` fetches them too). Weekly, because new CVEs hit dependencies nobody touched. | **no**, with branch protection |
| On demand, before releases | `/jit-speckit:security` | the full audit below | — |
| On GitHub | offered by `/jit-speckit:init` | every level: rebase merges off (on lite, merge commits off too: squash only), and on a public repo secret scanning with push protection and private vulnerability reporting; standard and full: branch protection requiring CI | **no** |

The local layers are fast feedback. **The CI gate plus branch protection is the boundary**: it
cannot be skipped from a laptop. On lite there is no CI gate: the hooks, the guard and the review
before each PR are all that check the code, and nothing on GitHub re-checks a push. Move to
standard (`/jit-speckit:level standard`) when that matters.

The git hooks are enabled only where they really run: `/jit-speckit:level` prints "enabled" only
when the `pre-commit` and `pre-push` that git will run are executable and call the checks. Otherwise
it says so. An own `.githooks`, hooks already in `.git/hooks` (`core.hooksPath` is not set) and a
machine-wide `core.hooksPath` (kept, and named as machine-wide) get the lines to add. Husky gets the
lines, and "not active in this clone yet" until `core.hooksPath` reaches `.husky`.

## The audit: `/jit-speckit:security`

`quick` checks the current branch's changes, `full` (the default) the whole repository, `deep`
adds parallel reviewers and adversarial verification.

1. **Attack surface map.** Entry points, trust boundaries, how identity and authorization work,
   the assets at stake, the infrastructure. Everything after this is guided by the map.
2. **Scanners**, used where each is best:
   - **Gitleaks**: secrets in files and git history.
   - **OSV-Scanner**: known vulnerabilities in dependencies, every ecosystem.
   - **Semgrep**: injection, XSS, SSRF, path traversal and crypto misuse.
   - **zizmor**: GitHub Actions weaknesses.
   - **Trivy**: Docker, Terraform and Kubernetes misconfiguration.

   Each finding is triaged as reachable or false positive, and a false positive needs a reason.
3. **Category sweep** over every OWASP Top 10:2025 and CWE Top 25 group, plus what scanners
   cannot see:
   - business logic (skipped steps, negative amounts, client-trusted prices);
   - races and double-spends;
   - resource exhaustion;
   - failing open;
   - prompt injection in AI features.
4. **Logic bugs** with `/code-review high`, and `/security-review` on branches.
5. **Adversarial verification.** Every high and critical finding is attacked by an agent that
   tries to prove it wrong. Only exploit paths that survive are reported.
6. **Report** with severity, `file:line`, exploit steps, impact, fix, and the regression test that
   proves the fix. It is stored inside `.git`, so it is never committed or published.
7. **Safe tracking:**
   - private repos get `security` issues with no exploit detail in the title;
   - public repos get private draft security advisories, never public issues; an advisory with
     the same summary is reused, else one is sent with the summary, description, severity and
     affected package GitHub requires;
   - a leaked secret is rotated first.

## Supply chain hygiene in generated files

- Every GitHub Action is pinned to a full commit SHA, never a movable tag.
- Downloaded scanner binaries are verified against their published SHA-256.
- `actions/checkout` runs with `persist-credentials: false`.
- Workflows default to `permissions: contents: read`.
- Every pin lives in [`extension/scripts/pins.sh`](../extension/scripts/pins.sh). Dependabot
  proposes updates for every pinned action: jit-speckit's own
  [`pins.yml`](../.github/workflows/pins.yml) uses each one in a job that never runs, and
  `bin/sync-pins.sh` copies a bump back into `pins.sh`. Dependabot does not see the scanner
  versions, so `pins.yml` checks them weekly against their latest releases (`bin/check-tools.sh`)
  and opens one "Tool pins behind" issue when any is behind.

## Limits

No tool proves software is secure. These layers make the common mistakes hard to ship, and the
dangerous ones likely to be found early. Deployment, runtime monitoring, incident response and
periodic human review by someone who knows the system are still needed. For anything handling
money or sensitive personal data, use level `full` and get an external review before launch.
