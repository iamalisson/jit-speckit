---
name: remove
description: "Remove jit-speckit from the current project only (the plugin stays in Claude Code): unregisters the spec-kit extension and preset, deletes the files it created, undoes its git hook setup and strips its block from the constitution. Specs and user edits stay; --with-speckit also deletes .specify/, the constitution included. Use for /jit-speckit:remove or when the user wants a clean reinstall."
argument-hint: "[--with-speckit]"
disable-model-invocation: true
---

# Remove jit-speckit from a project

1. Say in three lines what goes: the spec-kit extension and preset `jit` (templates and the
   implement command go back to spec-kit's), the files jit-speckit created and the user never
   took over (`.githooks/`, its workflows, Dependabot, PR template, `SECURITY.md`, `CODEOWNERS`,
   `.claude/settings.json`), its lines in `.pre-commit-config.yaml` or `.husky/`, and its block
   in the constitution. A file it wrote that changed since (edited, committed or not) is kept and
   named `kept (edited): <file>`; with no `.specify/jit-files.sha256` (set up before 1.8.0), a
   marked file is kept only while its edit is uncommitted. With `--with-speckit`, also spec-kit's own files (`.specify/`, the
   user's constitution with it, `.claude/skills/speckit-*`); `specs/` is never touched. Deleted files that were never
   committed cannot be recovered: ask once before running.
2. Run `bash "${CLAUDE_PLUGIN_ROOT}/bin/remove.sh" .` (add `--with-speckit` when asked). On
   failure, show the output and stop.
3. Report what it printed (the `kept (edited)` files are the user's to keep or delete), and what it leaves for the user: the `develop`/`staging` branches and
   the GitHub protections, with the commands it gave. To set up again: `/jit-speckit:init`. To
   remove the plugin from Claude Code itself: `/plugin uninstall jit-speckit`.
