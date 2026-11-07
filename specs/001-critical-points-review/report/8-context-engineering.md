Reviewed at: 172f8c5 (v1.7.2)

## 8. Prompts against context-engineering guidance (C1–C11)

The principles are research R8's C01–C11, from Anthropic's "The new rules of context engineering
for Claude 5 generation models" ([A], 2026-07-24) and "Effective context engineering for AI agents"
([B], 2025-09-29). Every shipped prompt was read at `v1.7.2`. Sizes are `wc -l` and `wc -w`.

| id | principle | verdict | files | evidence |
|---|---|---|---|---|
| C01 | Let the model use judgement; give a goal instead of a rigid rule | departs (reason written) | `extension/commands/{pr,issues,review}.md`, `skills/{new,security,init}/SKILL.md` | the command prompts are numbered procedures (`pr.md` 7 steps, `review.md`'s method 7 steps), and the rigid words cluster there (`never`/`always`/`must`: `issues.md` 8, `skills/security` 7, `skills/new` 6, `pr.md` 6). Nearly every hard rule carries its reason next to it: "never use `--no-verify`" after "The git pre-commit hook checks for secrets" (`pr.md:32-33`), "No style, no naming, no nits: they are what gets reviews ignored" (`review.md:83-84`). [A] allows over-constraining "highly important areas", which these are (secrets, the review gate) |
| C02 | No instructions that conflict across the context | departs (reason written) | `preset/commands/speckit.implement.md`, the installed `.claude/skills/speckit-implement/SKILL.md` | spec-kit's implement text says "**IMPORTANT** For completed tasks, make sure to mark the task off as [X]" (`SKILL.md:177`) and "All tasks in tasks.md completed and marked `[X]`" (`:228`); landspec's preset appends "Do not mark tasks `[X]`" and "It **overrides** the instructions above where they differ" (`:235-245`). The precedence is written, but both instructions reach the model in the same prompt, in that order |
| C03 | Design interfaces (scripts, parameters, files) instead of examples | departs | `extension/scripts/*.sh`, `extension/commands/*.md`, `preset/templates/tasks-template.md` | the gates are scripts with one-line outputs (`BRANCH=… ISSUE=…`, `REVIEW=ready`, `PR=…`) that the prompts call and read, not examples to imitate, and `review.md:81-82` has one example that shows the *shape* of a finding. But `tasks-template.md` (270 lines, 1,981 words) is mostly examples: 12 sample task lines, "Example:" (`:58`), "The tasks below are SAMPLE TASKS for illustration purposes only" (`:77`), "Parallel Example" (`:222`). No reason for the examples is written in the repository (the template only says "SAMPLE TASKS for illustration purposes only", `:77`, and `preset/preset.yml:26` says it `replaces: tasks-template`). landspec ships its own copy (1,981 words against spec-kit's 1,384 at `.specify/templates/tasks-template.md`) and has changed it six times since the first commit (`git log --oneline v1.7.2 -- preset/templates/tasks-template.md`: `06804f1`, `c53e2cf`, `e888291`, `95f8e32`, `45821b0`, `d118b15`), so the examples are landspec's choice |
| C04 | Progressive disclosure: load detail when needed | departs | `skills/new/SKILL.md`, `docs/GUIDELINES.md`, `docs/GUARDRAILS.md`, `docs/references.yaml` | `/landspec:new` "Read these first" (`skills/new/SKILL.md:11`): 897 + 2,519 + 1,818 + 2,167 = **7,401 words** before the first question, though each doc is used in one to three steps (GUARDRAILS section 1 in step 2 and sections 2–3 in step 3, `references.yaml` in steps 4 and 6, GUIDELINES' "When to add what" in step 3, its checklist in step 5 and its rules in step 7). `/landspec:help` does it right: "read only what the question needs" (`skills/help/SKILL.md:9`) |
| C05 | Say how to use a tool once; don't repeat instructions | follows | all command prompts and skills | the repeated rules appear in at most 2–4 files each ("`git add -A`" 2, "at every level" 2, "fresh general-purpose subagent" 2, "Closes #" 4: `pr.md`, `extension/levels/lite.md`, `preset/commands/speckit.implement.md` and the scaffold `pull_request_template.md`), each where it is acted on: `pr.md` (task commits) and `skills/init` step 7 (setup commit) |
| C06 | CLAUDE.md-style files stay light: purpose, then gotchas | departs | `extension/scaffold/lite/.github/copilot-instructions.md`, `preset/templates/constitution-template.md`, `extension/levels/*.md`, `skills/adopt/SKILL.md` | `copilot-instructions.md` follows: 174 words of review gotchas and nothing the model can read from the code; so does `skills/adopt` step 3 ("only rules specific to this codebase … each backed by a file path"). The constitution, which `/speckit-implement` and `/speckit-tasks` load on every run (`.claude/skills/speckit-implement/SKILL.md:104`, `.claude/skills/speckit-tasks/SKILL.md:65`), does not: its template asks for "Languages, frameworks, database, hosting, with versions. Source of truth: the manifest files" (`constitution-template.md:10-11`), which the manifests already show, and the level blocks pasted into it are general advice ("Validate and sanitize every input at trust boundaries", `extension/levels/standard.md:3`). Its **Commands** line has a reason: landspec's scripts read it (`constitution_cmd`, `lib.sh:130`) |
| C07 | Skills are light guides; long ones split into files | departs | `skills/security/SKILL.md`, `skills/new/SKILL.md` | `skills/security` is one file of 110 lines and 1,146 words: scope, scanners, the OWASP/CWE sweep table, verification, report and tracking; `skills/new` is 78 lines that pull in 6,504 more words of docs (C04). The other six skills are 21–63 lines |
| C08 | Rich references (tests, code, rubrics) over prose specs | departs | `extension/commands/review.md` | the gates themselves are carried by scripts and their tests (`tests/{review,pr,issues,branch}.test.sh`), which follows. The review method is 1,083 words of prose with no example report and no rubric; this feature's reviewers' reports always had the shape (the `## Review` sections of PRs #29–#35 summarize every round; only each task's last report is recorded, in this clone's `.git/landspec-review/`), but what a "Medium" is rests on one sentence (`review.md:78-80`) |
| C09 | Subagents for parallel or clean-context work, each returning a condensed summary | follows | `extension/commands/review.md`, `extension/commands/{pr,issues}.md`, `skills/security/SKILL.md` | the review runs in "one general-purpose subagent whose prompt is this whole file plus the facts below, and nothing else" (`review.md:14-15`) and returns only its report; `security deep` runs "one read-only subagent per sweep group running in parallel" (`skills/security/SKILL.md:13`). The report is bounded by shape ("few findings", "three lines at most"), not by length; the reports behind PRs #29–#35 each fit that shape (summarized round by round in their `## Review` sections; only each task's last report is kept, in this clone's `.git/landspec-review/`, not in the repository) |
| C10 | Start minimal, add instructions only for failures observed | follows | `extension/commands/review.md`, `docs/GUARDRAILS.md`, git history | the rules arrive with the failure that caused them: `e888291` "new files follow their newest sibling, and tasks prove the real upgrade path"; `1dbb9da` "secret scanner, guard, first push and worktrees, found by review and a live run"; `GUARDRAILS.md:59-60` cite "landspec's own use" (section 6 counts those two rows against the primary-source rule) |
| C11 | Right-size skills and CLAUDE.md with `/doctor` | unverified | `skills/*/SKILL.md` | `/doctor` is a user-run command and was not run on the plugin's skills; what would check it: run `/doctor` in a session with the plugin loaded and paste its output |

### Words each command loads before it does anything

| command | loads first | words |
|---|---|---|
| `/landspec:new` | its skill + `GUIDELINES.md` + `GUARDRAILS.md` + `references.yaml` | 897 + 2,519 + 1,818 + 2,167 = 7,401 |
| `/speckit-implement Tnnn` | spec-kit's implement skill with landspec's override (`.claude/skills/speckit-implement/SKILL.md`) + the constitution + the before hook's installed skill (`.claude/skills/speckit-landspec-branch/SKILL.md`) | 1,876 + 892 + 237 = 3,005 (then `speckit-landspec-pr`, 724, after the code) |
| `/speckit-tasks` | spec-kit's tasks skill + the tasks template (landspec's) + the constitution | 1,675 + 1,981 + 892 = 4,548 |
| `/speckit-landspec-issues` | its installed skill (`.claude/skills/speckit-landspec-issues/SKILL.md`, from `issues.md`) + the constitution | 535 + 892 = 1,427 |
| independent review (subagent) | `review.md` + the facts | 1,083 + the facts |
| `/landspec:security` | its skill | 1,146 |
| `/landspec:help` | its skill, then only the doc the question needs | 260 + one of `README.md` 1,208, `docs/reference.md` 1,403, `docs/design.md` 598, `docs/security.md` 883 |
| `/landspec:init`, `adopt`, `level`, `next`, `remove` | their skill | 668, 410, 155, 344, 201 |

(The constitution is this repository's own, 892 words; a project's own constitution replaces that
number. The installed `speckit-landspec-*` skills measured here are the copies in the v1.7.2 tree,
which are landspec 1.7.1's (`v1.7.2:.specify/extensions/landspec/extension.yml` says `1.7.1`); installed
from 1.7.2 they are 567 words for `speckit-landspec-issues` (total 1,459) and 776 for `speckit-landspec-pr`.)

### What following each departure would look like

- **C01**: keep the hard rules where they guard a promise (secrets, the gate, attribution), and
  turn the step lists into goals with the one hard rule each: `pr.md` step 2 could be "the checks
  pass; never loosen a test to get there (why: …)" instead of a list of how to write tests, keeping
  the `## Test changes` rule (`pr.md:19-20`) and the mutation run (`pr.md:22-27`) as they are,
  since both carry P13.
- **C02**: the preset would replace spec-kit's implement text where it conflicts instead of
  appending an override after it, so "mark the task off as [X]" never reaches the model.
- **C03**: `tasks-template.md` gives the task line as a field list (ID, `[P]`, `[USn]`, the
  description with its file path, and the *Comes from* / *What* / *Impact* / *Completed when*
  sub-bullets) with one worked example, instead of a sample feature's worth of tasks.
- **C06**: the constitution template keeps what landspec's scripts read (the **Commands** line) and what
  only this project knows (its principles, each with a file path), and drops the stack description
  the manifests already give; the level blocks keep only rules a model would not apply by
  default, with their reason.
- **C04**: `skills/new` reads `GUARDRAILS.md` section 1 for step 2 and sections 2–3 for step 3,
  `references.yaml` entries for the chosen stack in steps 4 and 6, and GUIDELINES' "When to add
  what" for step 3, its checklist for step 5 and its rules for step 7, each when its step starts:
  about 900 words up front instead of 7,401.
- **C07**: `skills/security` keeps scope, the steps and the tracking rules in `SKILL.md`, and moves
  the sweep table and the scanner details into `skills/security/sweep.md` and `scanners.md`,
  loaded in steps 3 and 2.
- **C08**: `review.md` gets one short example report with a Medium, a Low and the last line, and a
  three-line rubric for the ranks; its method can then lose what the example shows.

### Every shipped prompt file

| file | lines | words | principles |
|---|---|---|---|
| `skills/adopt/SKILL.md` | 41 | 410 | C06 |
| `skills/help/SKILL.md` | 32 | 260 | C04 |
| `skills/init/SKILL.md` | 63 | 668 | C01, C05 |
| `skills/level/SKILL.md` | 21 | 155 | C07 |
| `skills/new/SKILL.md` | 78 | 897 | C01, C04, C07 |
| `skills/next/SKILL.md` | 32 | 344 | C07 |
| `skills/remove/SKILL.md` | 21 | 201 | C07 |
| `skills/security/SKILL.md` | 110 | 1,146 | C01, C07, C09 |
| `extension/commands/analyzed.md` | 12 | 79 | C03 |
| `extension/commands/branch.md` | 22 | 222 | C03 |
| `extension/commands/issues.md` | 52 | 552 | C01, C09 |
| `extension/commands/pr.md` | 68 | 761 | C01, C05, C09 |
| `extension/commands/review.md` | 86 | 1,083 | C01, C03, C08, C09, C10 |
| `preset/commands/speckit.implement.md` | 16 | 134 | C02 |
| `preset/templates/constitution-template.md` | 32 | 163 | C06 |
| `preset/templates/tasks-template.md` | 270 | 1,981 | C03 |
| `extension/levels/full.md` | 24 | 171 | C01 |
| `extension/levels/lite.md` | 30 | 253 | C01 |
| `extension/levels/standard.md` | 38 | 307 | C01 |
| `extension/scaffold/lite/.github/copilot-instructions.md` | 15 | 174 | C06 |
| `extension/scaffold/lite/.github/pull_request_template.md` | 15 | 62 | C06 |
| `docs/GUIDELINES.md` | 241 | 2,519 | C04 |
| `docs/GUARDRAILS.md` | 104 | 1,818 | C04, C10 |
| `docs/references.yaml` | 287 | 2,167 | C04 |
