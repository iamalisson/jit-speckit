# Feature Specification: Critical-points review against the project's purpose

**Feature Branch**: `001-critical-points-review`

**Created**: 2026-11-05

**Status**: Draft

**Input**: User description: "Do a review on the critical points of the project to check if it makes sense with the purpose of the project"

## Purpose being checked

landspec promises (README, constitution "Project"): every task gets an issue, a branch and a
PR; secrets are refused at commit and push; every PR passes an independent review and a security
gate; every project starts with defaults sized to its level; and it never commits or pushes
outside its documented flows, never overwrites a user's file, never opens a PR on red checks, and
never puts a secret, an AI attribution line or a security finding in a public place.

A **critical point** is a place where one of those promises is kept or broken. The review checks
each one: does the behavior really deliver the promise, and does the promise, as written, make
sense for the people the project is for?

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Know which promises really hold (Priority: P1)

As the maintainer, I get one review report that takes each promise above, finds the behavior that
is meant to keep it, and says for each: **holds**, **holds with a documented limit**, or
**broken**, with a reproducible scenario for every "broken" or "limit" verdict.

**Why this priority**: The project's value is that its guarantees are real. A guarantee that
silently does not hold is worse than none: users stop checking for themselves.

**Independent Test**: Read the report alone: every promise from the README and constitution has a
verdict, and every non-"holds" verdict comes with steps that reproduce it on a throwaway repository.

**Acceptance Scenarios**:

1. **Given** the README's "Security, built in" table, **When** the review is done, **Then** every
   row has a verdict and the evidence for it (a command run, its output, or the line that keeps it).
2. **Given** a promise phrased as a gate ("refuses the PR without a recorded review"), **When**
   the review checks it, **Then** it states what the gate actually proves (for example "a report
   with the right last line exists for this diff") versus what the docs claim it proves (for
   example "a fresh, independent reader reviewed it").
3. **Given** a behavior that fails silently by design (an optional step that only warns), **When**
   the review checks it, **Then** it says whether a user could ever notice that the step never
   worked.

---

### User Story 2 - Know whether the design fits the purpose (Priority: P2)

As the maintainer, I learn where the project's mechanisms are heavier, lighter or different from
what its stated audience (solo prototypes on "lite" up to production with money or personal data on
"full") needs.

**Why this priority**: A correct mechanism that costs more than it protects gets skipped or
removed by users, which defeats the purpose as surely as a bug.

**Independent Test**: For each level, the report lists the steps a user goes through per task and
names any step whose cost is out of proportion to what it protects at that level, with a reason.

**Acceptance Scenarios**:

1. **Given** the per-task loop (issue, branch, review, PR), **When** the review weighs it for the
   "lite" audience, **Then** it says whether each required step is justified for a prototype, and why.
2. **Given** the project's own rules (its constitution), **When** the review compares them with
   how the project itself is built and tested, **Then** every place where the project does not
   follow what it asks of its users is listed, with whether the exception is documented.
3. **Given** Anthropic's current context-engineering guidance for Claude 5 generation models,
   **When** the review reads every prompt landspec ships, **Then** each principle gets a verdict
   (follows / departs for a stated reason / departs) with the files it applies to, and every
   departure says what the prompt would look like if it followed the principle.

---

### User Story 3 - Turn the findings into work (Priority: P3)

As the maintainer, each confirmed problem becomes a small, independent fix I can plan as a task,
ranked by how much of the purpose it puts at risk.

**Why this priority**: The report only pays off when its findings get fixed; ranking keeps the
first fixes on what matters most.

**Independent Test**: Each "broken" finding in the report maps to exactly one proposed fix with
a "done when" that a test can check.

**Acceptance Scenarios**:

1. **Given** a "broken" finding, **When** the report is final, **Then** it names one fix, the
   promise it restores, and a check that would fail today and pass after the fix.
2. **Given** a finding that is a documented, accepted limit, **When** the report is final,
   **Then** it proposes no fix, only says whether the documentation describes the limit honestly.

### Edge Cases

- A promise that is only kept on some platforms (bash 3.2 / busybox / macOS versus Linux): the
  verdict says on which.
- A promise that depends on a third party (GitHub, Copilot, spec-kit, scanners): the verdict says
  what happens when that party is absent or changes, and whether the user is told.
- A promise kept by a "best effort" mechanism that is documented as such: judged against its
  documentation, not against perfection; but the review still checks the documentation says where
  the real boundary is.
- A finding that cannot be reproduced: reported as unverified, never as broken.
- Two promises that conflict (for example "never commits for you" and a step that commits the spec):
  the report names the conflict and which documented flow allows it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The review MUST list every promise made in `README.md` (every row of "Security, built
  in"), `docs/security.md` (every row of "The layers") and the constitution's "Project" section, and give each one a verdict: holds, holds with a documented
  limit, or broken.
- **FR-002**: Every verdict MUST cite its evidence: a command and its output, a test that proves it,
  or the exact file and line that keeps the promise.
- **FR-003**: Every "broken" or "limit" verdict MUST include one concrete scenario that reproduces
  it on a throwaway repository.
- **FR-004**: The review MUST cover at least these critical points: the task-to-issue-to-PR chain
  (creation, resumption, "done" detection, dependencies between tasks); the secret checks at commit
  and push; the guard on the commands Claude runs; the independent-review gate for tasks and plans;
  the CI security gate and its pinned tools; level sizing and changing levels; never overwriting a
  user's file, including on removal; and the "tests are evidence" rule.
- **FR-005**: For each gate, the review MUST state what the gate verifies mechanically and what it
  only asks for in a prompt, and flag any place where the documentation presents the second as the first.
- **FR-006**: The review MUST check every optional step that fails silently and say whether a user
  can tell it never ran.
- **FR-007**: The review MUST compare the project's own development with its own constitution and
  list each rule it does not follow, saying whether the exception is written down.
- **FR-008**: The review MUST judge, per level, whether the required per-task steps are proportionate
  to that level's stated audience.
- **FR-008a**: The review MUST also challenge the core model itself: one task = one issue = one
  branch = one PR, the spec as its own PR, and the three levels. For each, it states the problem the
  model solves, the cost it puts on the user, the evidence the docs cite for it, and whether a
  simpler model would keep the same promises. These findings are marked **design** (not defects):
  they carry a recommendation and its reason instead of a reproduction, and sit in their own section,
  outside the High/Medium/Low ranking (FR-009, FR-010 apply to defects only).
- **FR-014**: The review MUST check every prompt landspec ships or loads (`skills/*/SKILL.md`,
  `extension/commands/*.md`, `preset/commands/*.md`, `extension/levels/*.md`, the constitution and
  tasks templates, `.github/copilot-instructions.md`, and the docs a command reads up front, such as
  `docs/GUIDELINES.md`, `docs/GUARDRAILS.md` and `docs/references.yaml` for `/landspec:new`)
  against the context-engineering principles C1–C11 in research R8, from Anthropic's primary
  sources. A rigid rule kept on purpose is acceptable where it guards a promise: the guidance itself
  allows over-constraining "highly important areas", so the finding then checks the reason is
  written next to the rule.
- **FR-009**: Findings MUST be ranked High (a promise broken: a secret can leave, a protected branch
  can change, a user's file can be lost, a gate passes without what it claims), Medium (a promise
  kept but a user could be misled about it), Low (worth a line).
- **FR-010**: Each High and Medium finding MUST come with one proposed fix and a check that fails
  before the fix and passes after.
- **FR-011**: The review MUST NOT change any behavior itself; the report is the output, and fixes
  are planned separately.
- **FR-012**: The report MUST NOT contain a working secret or a step-by-step bypass that would help
  someone defeat a user's protections.
- **FR-013**: A finding is **exploitable** when someone other than the person running landspec can
  use it to cause harm: a secret leaves through what landspec generates or runs, a protected branch
  changes on GitHub, or a pull request from someone else gets past the CI gate. A gap in the secret checks is
  exploitable when the docs say that kind of secret is refused and it is not; a secret format the
  docs never claim to catch is a public `limit`. An exploitable finding
  MUST NOT be described in the repository or in a public issue while it is unfixed, because the
  repository is public. It goes, with its reproduction and fix, into a private draft GitHub security
  advisory; the committed report keeps its promise row with the verdict `reported privately (<id>,
  <GHSA id>)` and nothing else. Everything the user or the agent in their own session can skip or get
  wrong (a gate that only checks a report exists, a prompt-only step, the best-effort guard) is not
  exploitable and gets a public `limit` or `broken` verdict.

### Key Entities

- **Promise**: one guarantee the project makes, with where it is stated.
- **Critical point**: the behavior meant to keep a promise.
- **Finding**: a defect or a design verdict on a promise, its evidence, its rank, a reproduction, and a proposed fix.
- **Report**: all findings, ranked, plus the per-level proportionality assessment.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of the promises in the README, the security doc and the constitution's "Project"
  section have a verdict with evidence.
- **SC-002**: 100% of "broken" findings are reproduced by someone else in under 10 minutes each: from
  the report for public findings, from the private advisory (by the maintainer) for exploitable ones.
- **SC-003**: Zero findings are style or naming; every finding names the promise it affects.
- **SC-003b**: Each principle C1–C11 has a verdict with the files it applies to, every shipped prompt
  file is covered by at least one verdict, and the words each command loads before doing any work
  are measured.
- **SC-003a**: Each part of the core model (task = PR, spec PR, levels) has one design verdict: keep,
  simplify or replace, with the evidence for it.
- **SC-004**: The maintainer can read the ranked summary and decide what to fix first in under
  5 minutes.
- **SC-005**: Every High finding has a fix planned before the next release: in the report's *Fixes* list,
  then in a follow-up feature, for a public finding; inside its private advisory for an exploitable one.

## Clarifications

### Session 2026-11-05

- Q: Should the review question the purpose itself, or only check delivery of it? → A: Both: it
  also challenges the core model (one task = one PR, the separate spec PR, levels) (FR-008a).
- Q: Does landspec go against current best practices for prompting Claude 5 models? → A: The
  review checks every shipped prompt against Anthropic's context-engineering guidance, after
  confirming the sources (FR-014, research R8).

## Assumptions

- The audience is the maintainer, who knows the project; the report does not explain spec-kit.
- The review is of the tag `v1.7.2` (commit `172f8c5`) only; earlier releases and upgrade paths are
  checked only where a promise is about upgrading (`/landspec:init` refreshing a project).
- "Best effort" mechanisms that are documented as best effort (the command guard) are judged against
  their documentation; their real boundary is CI plus branch protection, as `docs/security.md` says.
- The project's own exception for mutation testing (no mutation tool for bash) is accepted as long
  as it is written down; the review checks that its replacement rule is followed.
- Third-party services (GitHub, Copilot code review) are checked as far as public documentation and
  a test repository allow; anything unverifiable is reported as unverified.
- The output is a Markdown report kept in this feature's folder. Fixes for public findings are listed in
  `report.md` and planned in a follow-up feature (FR-011: this feature changes nothing); fixes for exploitable findings are tracked in their private advisory and
  never become public issues until they ship (FR-013).
