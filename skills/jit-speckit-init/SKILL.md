---
name: jit-speckit-init
description: "Set up the current project (new or existing) with spec-kit and jit-speckit: one task = one issue = one branch = one PR, plus best-practice defaults sized by complexity level (lite, standard, full). Use when the user says /jit-speckit-init or asks to set up spec-kit / jit-speckit in a project."
argument-hint: "[lite|standard|full]"
---

# Set up a project with jit-speckit

1. **Pick the level.** If the arguments name one (`lite`, `standard` or `full`), use it.
   Otherwise ask the user with these three options, recommending one from what the repo shows:
   - **lite**: prototype or solo. `feat/*` → `main`, a PR template, core defaults.
   - **standard** (default): a product, maybe a small team. `feat/*` → `develop` → `main`, CI for
     the detected stack, Dependabot, security baseline.
   - **full**: production with several environments. Adds `staging`, CODEOWNERS, SECURITY.md,
     a release workflow, a threat model per feature, and required analysis before implementing.

   Recommend **full** when the repo has deploy or infra code (Terraform, Dockerfiles with
   environments) or several active contributors (`git shortlog -sn --since=6.months | wc -l` > 2);
   **lite** when it is empty or a single-file experiment; otherwise **standard**.
2. **Run the setup** from the project root:
   `bash "<base directory of this skill>/../../bin/setup.sh" . --level <level>`
   - It creates `develop`/`staging` on `origin` when the level needs them. If the user doesn't
     want branches pushed, add `--no-branches`.
   - On failure, show the message and stop.
3. **Next step:**
   - If the repo already has code: run the `/jit-speckit-adopt` skill now, so the constitution
     describes this project.
   - If it is a new project: tell the user to run `/speckit-constitution`.
4. Summarize in three lines: the level, the files created or kept, and the next command.
   Nothing is committed; the user reviews and commits the setup.
