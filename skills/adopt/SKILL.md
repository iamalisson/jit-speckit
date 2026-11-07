---
name: adopt
description: "Adopt jit-speckit in an existing codebase: read the repo and fill the spec-kit constitution (project, stack, commands, project principles) from what is really there, merging any constitution that already exists. Run after /jit-speckit:init on a repo that already has code."
---

# Adopt jit-speckit in an existing project

1. If `.specify/extensions/jit/` does not exist, stop and ask the user to run
   `/jit-speckit:init` first (only the user can run it), then `/jit-speckit:adopt` again.
2. **Read the project; don't guess.** Look at:
   - the manifests (`Cargo.toml`, `package.json` and lockfile, `pyproject.toml`, `go.mod`, …);
   - the CI workflows and the task runner (`justfile`, `Makefile`, `package.json` scripts);
   - `README`, `CLAUDE.md`/`AGENTS.md`, `docs/`, and the infra folders;
   - `bash .specify/extensions/jit/scripts/detect-stack.sh`.

   Prefer what the code and config say over what the docs say, and note any stale docs.
3. **Fill `.specify/memory/constitution.md`:**
   - `[PROJECT_NAME]`, `[PROJECT_PURPOSE]` (one paragraph);
   - `[STACK]`, with versions from the manifests;
   - `[BUILD_COMMAND]` / `[TEST_COMMAND]` / `[LINT_COMMAND]`: the commands that really work here;
     when the project has no such step (no build, say), leave its placeholder, so CI does not run it;
   - `[MUTATE_COMMAND]`: the project's mutation-testing tool (cargo-mutants, mutmut, StrykerJS,
     gremlins; see `references.yaml`), scoped to the change where the tool allows it through
     `$JIT_DIFF_FILE` (a diff against the base) or `$JIT_CHANGED_FILES` (changed sources, space
     separated), and exiting non-zero when a mutant survives, for example
     `cargo mutants --in-diff "$JIT_DIFF_FILE"`, or for mutmut, whose own exit is 0 on a survivor,
     `mutmut run && ! mutmut results | grep -q survived`. It runs before every PR. If the project has no
     such tool, leave the placeholder and say so in the summary: adding one is a small-fix PR;
   - a **Commands** line that already exists but has no `mutate` entry gets one appended;
   - `[PROJECT_PRINCIPLES]`: only rules specific to this codebase that you can point to (layer
     boundaries, where auth lives, how migrations run), each backed by a file path.

   Never edit between `<!-- jit:start` and `<!-- jit:end -->`. Once the **Commands** line is
   filled, re-run `bash .specify/extensions/jit/scripts/level.sh <current level> --no-branches`:
   it rewrites the jit block and the generated CI (`.github/workflows/ci.yml`, while it still
   carries the `# jit-speckit: managed file` line) with the project's real commands.
4. **If a constitution already existed** (not the jit template): keep its principles and wording.
   Only add what is missing. List every place where it contradicts a jit default, and ask the
   user which one wins. Don't decide alone.
5. Fill the version line: `1.0.0`, with today's date as ratified and amended (or bump the
   existing version: MINOR when adding sections).
6. Show a short summary: what was filled and from which file, contradictions found, docs that
   look stale. Leave everything uncommitted for the user to review.
