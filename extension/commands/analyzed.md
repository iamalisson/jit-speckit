---
description: "Record that analysis ran on the current tasks"
---

# Record the analysis (after `/speckit-analyze`)

1. If the analysis report above has **CRITICAL** findings, say they must be fixed first, and stop.
   Do not record anything.
2. Otherwise run `.specify/extensions/jit/scripts/analyzed.sh`. This lets level `full` start
   tasks. If `tasks.md` changes later, the analysis has to be run again.
3. On level `full` (`level:` in `.specify/extensions/jit/jit-config.yml`), open the spec PR now:
   `.specify/extensions/jit/scripts/pr.sh spec`, and show its URL.
