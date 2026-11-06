---
description: "Record that analysis ran on the current tasks"
---

# Record the analysis (after `/speckit-analyze`)

1. If the analysis report above has **CRITICAL** findings, say they must be fixed first, and stop.
   Do not record anything.
2. Otherwise save the analysis report as it came (from its `## Specification Analysis Report`
   heading through its Coverage Summary Table and the rest) to a file outside the repository
   (`mktemp`), and record it: `bash .specify/extensions/jit/scripts/analyzed.sh <file>`. It refuses
   a file that is not that report; never write one yourself to get past it. This lets level `full`
   start tasks. If `tasks.md` changes later, the analysis has to be run again.
3. On level `full` (`level:` in `.specify/extensions/jit/jit-config.yml`), open the spec PR now:
   `bash .specify/extensions/jit/scripts/pr.sh spec`, and show its URL.
