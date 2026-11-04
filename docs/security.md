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
| Every commit | git `pre-commit` (`.githooks/`) | `.env`, keys and credential files; provider tokens and passwords in added lines (Gitleaks too, when installed). Under a second. | locally, `--no-verify` |
| Every command Claude runs | plugin `PreToolUse` guard | refuses `--no-verify`, `git add -A`, commits on base branches, pushes to base branches | no |
| Every push | git `pre-push` | re-scans every commit leaving the machine (catches `--no-verify` commits); base branches are PR-only (standard, full) | locally |
| Before a PR opens | after `/speckit-implement` | scanners on the changed files, `/security-review`, `/code-review` (medium on standard, high on full) | — |
| Every PR, push and week | `security.yml` CI | Gitleaks over the full history, OSV-Scanner on every lockfile, zizmor on workflows; Semgrep with the OWASP rules on full. Weekly, because new CVEs hit dependencies nobody touched. | **no**, with branch protection |
| On demand, before releases | `/jit-speckit:security` | the full audit below | — |
| On GitHub | offered by `/jit-speckit:init` | secret scanning with push protection; branch protection requiring CI | **no** |

The local layers are fast feedback. **The CI gate plus branch protection is the boundary**: it
cannot be skipped from a laptop.

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
   - public repos get private security advisories, never public issues;
   - a leaked secret is rotated first.

## Supply chain hygiene in generated files

- Every GitHub Action is pinned to a full commit SHA, never a movable tag.
- Downloaded scanner binaries are verified against their published SHA-256.
- `actions/checkout` runs with `persist-credentials: false`.
- Workflows default to `permissions: contents: read`.
- Every pin lives in [`extension/scripts/pins.sh`](../extension/scripts/pins.sh), and Dependabot
  proposes updates.

## Limits

No tool proves software is secure. These layers make the common mistakes hard to ship, and the
dangerous ones likely to be found early. Deployment, runtime monitoring, incident response and
periodic human review by someone who knows the system are still needed. For anything handling
money or sensitive personal data, use level `full` and get an external review before launch.
