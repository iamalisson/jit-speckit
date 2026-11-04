---
name: jit-speckit-level
description: "Change a jit-speckit project's complexity level (lite, standard, full): updates the branch flow, the constitution defaults block and the scaffolded files. Use when the user says /jit-speckit-level or wants more or less process in a jit-speckit project."
argument-hint: "<lite|standard|full>"
---

# Change the complexity level

1. The level is the argument. If it is missing or not `lite`/`standard`/`full`, show the
   current one (`level:` in `.specify/extensions/jit/jit-config.yml`) and the three options
   with one line each, then ask.
2. Run `bash .specify/extensions/jit/scripts/level.sh <level>`. Add `--no-branches` if the user
   doesn't want `develop`/`staging` created on `origin`.
3. Bump the constitution's version line (MINOR going up a level, PATCH going down) and set
   *Last Amended* to today.
4. Report what the script printed:
   - the level change;
   - branches created;
   - files created, and files kept (going down a level never deletes files; list the ones the
     user may want to delete by hand).

   Nothing is committed.
