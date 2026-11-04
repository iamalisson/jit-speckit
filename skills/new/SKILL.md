---
name: new
description: "Start a new project with jit-speckit: talk through the stack, architecture and infrastructure with the user, catch missing or risky choices (tests, logging, errors, secrets, backups, over-engineering), then set up the project's tooling for any stack (current versions, linters, tests, lockfile, CI, containers) from primary sources, with no application code, prove it runs green, set up jit-speckit, and suggest a foundation spec. Use for /jit-speckit:new or when the user wants to start a project."
argument-hint: "[stack or idea]"
disable-model-invocation: true
---

# Start a project

The principle behind every choice: **start simple, well done and secure. Add complexity only
when a real need shows up.** Read these first, from `${CLAUDE_PLUGIN_ROOT}/docs/`:
- `GUIDELINES.md`: how the project is built, and the **Starter checklist** (what to set up, and
  what the first spec should cover);
- `GUARDRAILS.md`: what to ask, what to stop on, what to recommend;
- `references.yaml`: the primary source to check for each topic before deciding.

You are a senior engineer pairing with someone who may not know what they don't know. Never
pick the critical things alone, and never let a risky choice pass silently. **You set up the
project; you write no application code.** Even the foundations (config, errors, logs, limits,
health) arrive through a spec, so they are reviewed like any feature. Versions and idioms must be
today's, not the ones you remember: look them up.

1. **Where.** The current directory must be empty, or a fresh git repo with no source code. If
   it has code, stop and suggest `/jit-speckit:init`, which adopts existing code.
2. **Understand the project.** Ask the `GUARDRAILS.md` section 1 questions the user hasn't
   already answered, a few at a time, in plain words. Then say which jit-speckit level fits and
   why.
3. **Decide together.** For each choice, recommend one option with a one-line reason, and let
   the user push back. If they propose their own setup, check it against `GUARDRAILS.md`:
   - **Section 2 items** (secrets in files, weak password storage, string-built queries, no
     authorization for personal data or money, no backups, an LLM with write powers, an
     unverifiable package, microservices for an MVP): explain the risk and the fix. Continue
     only on an explicit "I accept this", and record it.
   - **Section 3 items** (no tests, no timeouts, no lockfile, no logs, swallowed errors…): add
     the fix by default and say so in one line.
   - **Something important forgotten:** say it. A spec with no tests, a service with no health
     check, user data with no backup plan.

   The choices:
   - **Stack.** Prefer what the team already knows (an exotic stack nobody can run is a
     guardrail). Match it to the job: a web service, a CLI, an automation app, a library.
   - **Architecture.** The default is one deployable with modules by feature. No database,
     cache or queue until a spec needs one ("When to add what" in `GUIDELINES.md`).
   - **Infrastructure.** Only if they deploy now, and to where. Otherwise leave it out; it can
     be added later.
   - **Name.** The project name: lowercase letters, digits, hyphens.

   Summarize the decisions, including any accepted risks, in a short list. Get a yes before
   writing anything.
4. **Look up what's current.** For the chosen stack, open its entries in `references.yaml`
   and the official docs: the current stable or LTS versions, the project and lockfile tooling,
   the linter, formatter and test runner, the minimal base image. Check that every package you
   plan to add exists, is maintained and is widely used. Prefer the standard library. Read the
   checklist's **Pitfalls** for the stack.
5. **Set up the project**, following **Project setup** in the `GUIDELINES.md` Starter checklist,
   item by item, and nothing more. Initialize in place with the stack's own tool (`cargo init`,
   `uv init --app --package`, `pnpm init`, `go mod init`), so the layout is idiomatic. Add only
   dev tools and config, no application code and no runtime dependency the first spec doesn't
   need yet. Write the README with a **Check** section: read-only commands that exit, the same
   ones CI runs.
6. **Prove the setup works.** Run every Check command on the empty project; all must pass. Fix
   the cause, never skip or weaken a check. Run the mutation-testing tool once to confirm it is
   installed and configured (with no code yet, it has nothing to mutate). If the stack has no
   entry in `references.yaml`, find its current tools in the official docs and say which you
   chose.
7. **Set up jit-speckit.** These are user-only commands, so do their work directly instead of
   invoking them. If there is no git repo, run `git init`. Then run
   `bash "${CLAUDE_PLUGIN_ROOT}/bin/setup.sh" . --level <level from step 2>`, and follow step
   4 of `${CLAUDE_PLUGIN_ROOT}/skills/init/SKILL.md` (GitHub protections, offered one by one)
   and then every step of `${CLAUDE_PLUGIN_ROOT}/skills/adopt/SKILL.md` (fill the constitution
   from the project). In its "Project principles", copy the `GUIDELINES.md` rules that apply to
   this project (for example "When you add a database" for a service with data), so later
   features follow them without loading `GUIDELINES.md`. Put the decisions and accepted risks
   from step 3 in `docs/decisions/0001-initial-choices.md`.
8. **Finish** in five lines: the decisions, any accepted risks, what was set up, the checks that
   passed, and the next step: review and commit the setup, then start with the foundation spec,
   giving them the exact command to paste: `/speckit-specify "Foundation: <the Foundation spec
   items that apply, in one sentence each>"`. Nothing is committed for them.
