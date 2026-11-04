---
name: jit-speckit-adopt
description: "Adopt jit-speckit in an existing codebase: read the repo and fill the spec-kit constitution (project, stack, commands, project principles) from what is really there, merging any constitution that already exists. Use when the user says /jit-speckit-adopt or wants spec-kit/jit-speckit on a project that already has code."
---

# Adopt jit-speckit in an existing project

1. If `.specify/extensions/jit/` does not exist, run the `/jit-speckit-init` skill first, then
   come back here.
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
   - `[PROJECT_PRINCIPLES]`: only rules specific to this codebase that you can point to (layer
     boundaries, where auth lives, how migrations run), each backed by a file path.

   Never edit between `<!-- jit:start` and `<!-- jit:end -->`. If that block still shows
   `[STACK_IDIOMS…]` or `[TEST_COMMAND]`, re-run
   `bash .specify/extensions/jit/scripts/level.sh <current level> --no-branches` after the
   manifests are in place.
4. **If a constitution already existed** (not the jit template): keep its principles and wording.
   Only add what is missing. List every place where it contradicts a jit default, and ask the
   user which one wins. Don't decide alone.
5. Fill the version line: `1.0.0`, with today's date as ratified and amended (or bump the
   existing version: MINOR when adding sections).
6. Show a short summary: what was filled and from which file, contradictions found, docs that
   look stale. Leave everything uncommitted for the user to review.
