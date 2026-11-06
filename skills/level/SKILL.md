---
name: level
description: "Change a jit-speckit project's complexity level (lite, standard, full): updates the branch flow, the constitution defaults block, the CI and security scaffolding and the git hooks."
argument-hint: "<lite|standard|full>"
disable-model-invocation: true
---

# Change the complexity level

1. The level is the argument. If it is missing or not `lite`/`standard`/`full`, show the current
   one (`level:` in `.specify/extensions/jit/jit-config.yml`) and the three options with one line
   each, then ask.
2. Run `bash .specify/extensions/jit/scripts/level.sh <level>`. Add `--no-branches` if the user
   doesn't want `develop`/`staging` created on `origin`.
3. Bump the constitution's version line (MINOR going up a level, PATCH going down) and set
   *Last Amended* to today.
4. Going **up** to standard or full: offer the branch protection from `/jit-speckit:init`
   step 5.
5. Report what the script printed: the level change, branches created, files created and kept.
   Going down never deletes files; list the ones the user may want to delete by hand. Nothing is
   committed.
