# Research: Critical-points review

## R1. Where the promises come from

- **Decision**: the inventory is built from `README.md`, `docs/security.md` ("The layers",
  "Supply chain hygiene"), `docs/reference.md` ("What happens automatically"), `docs/design.md`
  and the constitution's "Project" section. Each promise is numbered P01–P28 in the contract with
  where it is stated.
- **Rationale**: FR-001 names those documents; `/landspec:help` answers from them, so they are
  what users believe.
- **Alternatives considered**: deriving promises from the code (rejected: that checks the code
  against itself); including `GUIDELINES.md`/`GUARDRAILS.md` (rejected as promises: they are advice
  to generated projects, not guarantees of landspec; they enter only through section 6).

## R2. How a verdict is proven

- **Decision**: everything is read at the tag `v1.7.2` (`172f8c5`), from a worktree of it. "holds" cites the code line and the test in `tests/` that proves it (or a command
  run now and its output). "Broken" and "limit" carry a reproduction on a throwaway repository made
  like `tests/helpers.sh` `new_repo` (a local bare origin, a fake `gh`), pasted with its output.
  Behavior the fake `gh` cannot show (issues, PRs, the Copilot request, branch protection,
  auto-merge) is run for real on the private sandbox `iamalisson/jit-speckit-sandbox`, only from its clone, after
  checking it has one remote and `gh repo view --json nameWithOwner -q .nameWithOwner` prints `iamalisson/jit-speckit-sandbox`;
  direct `gh` writes name the sandbox and carry the task id (`[001 review Tnnn]`, `review-001-tnnn-*`), landspec's own
  scripts run under the highest free sandbox feature number from `099` down, each task closes and deletes only what it
  recorded creating (the record is a file in `.git/landspec-repro/`, appended as each item is made, so an interrupted run
  can still be cleaned up), merges stay and are listed, and each changed setting
  is put back with the command recorded before it changed (tasks.md, "Rules every task follows").
- **Rationale**: the fake `gh` keeps most checks offline and is the harness the fixes will use
  (FR-010); but it answers whatever it was written to answer, so it cannot prove what GitHub does.
  The user asked on 2026-11-05 for real runs with real output.
- **Alternatives considered**: fake `gh` only (rejected: it already hid a 422 and a kept file that
  real runs found, research R6 and T005); the public repository (rejected: writes there are public).

## R3. Third-party behavior

- **Decision**: three behaviors are not in this repository and are checked against official
  documentation, then marked verified or unverified:
  1. Claude Code `PreToolUse` hooks: what exit codes block, what happens on timeout or error, and
     whether `onFailure` in `hooks/hooks.json` is a field Claude Code reads.
  2. GitHub's REST API for requesting a Copilot code review on a PR (the reviewer name `pr.sh`
     sends), and what it returns when the account has no Copilot.
  3. spec-kit v1.2.5 hook execution: whether `optional: false` hooks in `.specify/extensions.yml`
     run by themselves or rely on the agent following the prompt.
- **Rationale**: each one carries a promise (the guard blocks; a second reviewer is asked; the
  issues and PR steps always run). If the outside behavior differs, the promise is broken without
  any bug in this code.
- **Alternatives considered**: trusting the comments in the code (rejected: those are the claims
  under review).

## R4. Gates: mechanical versus asked

- **Decision**: for each gate the report has two columns: what a script refuses (exit non-zero) and
  what only a prompt asks Claude to do. The documentation's wording is quoted next to them.
- **Rationale**: FR-005. Users trust "refuses" more than "asks"; a gap between the two is a
  Medium finding at least.

## R5. Ranking and design verdicts

- **Decision**: defects ranked High / Medium / Low per FR-009; design verdicts (FR-008a) are
  "keep", "simplify" or "replace", each with the problem it solves, its cost per task, the evidence
  the docs cite (and whether that source supports the claim), and the simpler alternative weighed.
- **Rationale**: keeps opinions apart from reproducible defects (clarification 2026-11-05).

## R6. Reporting security-relevant findings

- **Decision**: an **exploitable** finding (FR-013: harm someone other than the operator can cause) is
  filed as a private draft repository security advisory (`gh api -X POST
  repos/iamalisson/landspec/security-advisories`, the same endpoint `skills/security/SKILL.md`
  uses), with its reproduction and fix. The request body is JSON sent with `--input -`, with the
  fields GitHub's REST docs ("Create a repository security advisory", read 2026-11-05) require:
  `summary`, `description`, `severity` (`high` for a High finding, `medium` for a Medium one) and
  `vulnerabilities: [{"package": {"ecosystem": "other", "name": "landspec"}}]` (`other`: a
  plugin of prompts and scripts fits no package ecosystem). **Verified on this repository on
  2026-11-05**: `summary` + `description` alone is refused (HTTP 422, "object is missing required
  key: vulnerabilities"); this body created draft `GHSA-6w2r-c97c-h3vw`, closed right after; after
  closing, a drafts-only lookup no longer finds it, a lookup across all states does. On the private
  sandbox the endpoint answers 404, even to a list. Its summary starts with `[001 Fn.m]`. **Before creating**, list
  the advisories in every state (`gh api --paginate …/security-advisories`, no state filter) and
  reuse one whose summary starts with that tag (a retried task never makes a
  duplicate, like `issues.sh` skips a task that has an issue). **If the call fails**, the promise
  row says `unverified (advisory pending)`, nothing else about the finding is written, and the task
  reports the error to the user, who files it by hand; the row is updated once the advisory exists. The
  promise row keeps `reported privately (Fn.m, GHSA-xxxx-xxxx-xxxx)`. The maintainer reproduces it from the advisory (SC-002). Commit messages, PR bodies and issue
  comments carry only `Fn.m reported privately (GHSA id)`. A documented,
  accepted limit stays public, described by its class only, no runnable steps (FR-012).
- **Rationale**: the repository is public (`gh repo view` → PUBLIC); `skills/security/SKILL.md`
  ("Public repository: never open public issues for vulnerabilities") and the constitution
  ("never put … a security finding into a public place") forbid anything else.
- **Alternatives considered**: local notes outside the repo (rejected: nobody else can reproduce
  them, and they are lost with the machine); class-only text in the report (rejected: still tells an
  attacker where to look before the fix ships).

## R8. Context-engineering guidance for prompts

Sources, both read on 2026-11-05 (the first one's `claude.com` link redirects to `claude.dev`):
- **[A]** Thariq Shihipar (Anthropic), "The new rules of context engineering for Claude 5
  generation models", 2026-07-24, https://claude.dev/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models/
  — "We removed over 80% of Claude Code's system prompt for models like Claude Opus 5 and Claude
  Fable 5 with no measurable loss on our coding evaluations."
- **[B]** Anthropic Applied AI team, "Effective context engineering for AI agents", 2025-09-29,
  https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents

Where they disagree (examples), [A] is later and written for Claude 5 models, so it wins.

| id | Principle | Source |
|---|---|---|
| C01 | Let the model use judgement; give a goal ("match the surrounding code") instead of a rigid rule | [A] "Then: Give Claude rules / Now: Let Claude use judgement" |
| C02 | No instructions that conflict with each other across the context | [A] "several conflicting messages in a single request" |
| C03 | Design interfaces (scripts, parameters, files) instead of giving examples; examples narrow the search | [A] "giving examples actually constrains them to a certain exploration space" |
| C04 | Progressive disclosure: load detail when it is needed, as a tree of files, not one central repository of every practice | [A] "Now: Use progressive disclosure", "A common myth is that you want to make these a central repository…"; [B] just-in-time retrieval |
| C05 | Say how to use a tool once, in its description; don't repeat instructions | [A] "Then: Repeat yourself / Now: Simple tool descriptions" |
| C06 | CLAUDE.md-style files stay light: what the repo is for, then its gotchas; nothing the model can see in the repo | [A] "Avoid stating 'the obvious'…" |
| C07 | Skills are lightweight guides with opinions specific to the team or product; not over-constrained except in highly important areas; long ones split into files | [A] "Avoid making them overconstrained, except in highly important areas" |
| C08 | Rich references (tests, code, rubrics) over prose specs | [A] "Then: Simple specs / Now: Rich references" |
| C09 | Subagents for parallel exploration or a clean context, each returning a condensed summary | [B] "clean context windows", "condensed, distilled summary… (often 1,000-2,000 tokens)" |
| C10 | Start from a minimal prompt and add instructions only for failures actually observed | [B] "start by testing a minimal prompt… then add clear instructions… based on failure modes" |
| C11 | Right-size skills and CLAUDE.md with Claude Code's `/doctor` | [A] "use the command `/doctor` in Claude Code to rightsize your skills, and CLAUDE.md files" |

- **Decision**: section 8 gives each of C01–C11 a verdict per file group, with evidence: the file and
  line, and measured sizes (lines and words per prompt, and what each command reads before it does
  anything). C11 is evidence only if `/doctor` is run on the plugin's skills (a user-run command:
  its output is pasted in) — otherwise `unverified`.
- **Not in the sources**: neither page gives guidance on ALL-CAPS or MUST/NEVER wording, long
  checklists, or telling the model the reason for a rule; the review does not claim they do.
- **Rationale**: the user asked whether landspec goes against current best practice (2026-11-05);
  [A] reports the change for the same model family that runs landspec's prompts.

## R7. Fake secrets in reproductions

- **Decision**: no token-shaped string is ever written to a committed file. Reproductions build fake
  secrets at run time inside the throwaway repo (for example by joining two halves), so
  `secrets.sh` on the staged report is always clean.
- **Rationale**: one rule instead of two; `landspec:allow-secret` exceptions in a review of the secret
  checker would blur the evidence.
