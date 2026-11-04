---
name: help
description: "Explain jit-speckit: the commands, the once-per-feature and once-per-task loop, levels, configuration, security checks, and why the spec PR is separate from the task PRs. Use for /jit-speckit:help, or when the user asks how jit-speckit works or what a command does."
argument-hint: "[question]"
---

# jit-speckit help

The docs are the source of truth. Read them, don't answer from memory:
`${CLAUDE_PLUGIN_ROOT}/README.md`, `${CLAUDE_PLUGIN_ROOT}/examples/README.md` and, for security
questions, `${CLAUDE_PLUGIN_ROOT}/docs/security.md`; for starting a project, architecture and
"is this a good idea?", `${CLAUDE_PLUGIN_ROOT}/docs/GUIDELINES.md` and `docs/GUARDRAILS.md`. For
"what's the current way to do X?", open the matching source in `docs/references.yaml`.

1. **No argument**: show a short overview.
   - The loop: what you run once per feature, and what you run once per task.
   - The commands in one table: `/jit-speckit:new`, `init`, `adopt`, `level`, `next`,
     `security`, `help`, and the spec-kit commands they hook into.
   - The levels in one line each.
   - The config keys in `.specify/extensions/jit/jit-config.yml`.
   - If the current directory is a jit project (`.specify/extensions/jit/` exists), add one line
     about where it stands: its level, and "run `/jit-speckit:next` to see progress".
2. **With a question**: answer it directly, in a few sentences, from the docs above. Quote the
   command to run when there is one. If the docs don't cover it, say so instead of guessing.
3. End with: "Worked example: `examples/` in the jit-speckit repo (one feature, from spec to
   merged PRs)."
