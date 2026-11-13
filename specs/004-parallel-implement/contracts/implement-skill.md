# Contract: /landspec:implement (skills/implement/SKILL.md)

Loop, in the main session, until no task is `startable`, `running` or due a review:

1. `implement.sh restack`, then `implement.sh status --running <the tasks whose agents are in flight>`.
2. One step per listed task (data-model "Task state"): `START` → launch an implementer subagent
   (`agents/implementer.md`, background, `isolation: "worktree"`); `REVIEW` → launch the reviewer as
   `review.md` says (spec 003's copy; facts carry `base: <base_ref <b>>`), then `implement.sh mark`
   with its result; `FIX` → a fix round with the record's `report=` (SendMessage to the implementer if
   still in flight, else a new implementer on the branch); `OPEN` → in the task's copy, `git switch <branch>`, the scan and `pr.sh task`
   as `pr.md` says (on an existing draft PR that now targets the base: `gh pr ready` after it), parents
   first, then `mark <task> pr` and `git switch --detach`.
3. When an implementer returns: `implement.sh mark <task> implemented` before anything else; a
   missing `Copy:` is recreated detached as `<repo>-<feature>-<task>`.
4. Repeat from 1 until nothing is listed and nothing is in flight.
5. When nothing is left to start or run, and the feature has no open spec PR (gaps already filed
   wait for its merge: the report says "merge <spec PR> first"): the whole-feature check (research
   R8), at most `feature_rounds:` rounds: check copy, the test command there, `implement.sh
   check-result`, and the feature review only when the run is green; `UNCHANGED=` or
   `ROUNDS_EXHAUSTED=` from `check-copy` stops the run with a question to the developer.
6. When every task is merged: the release (T009), with the unattended security audit before the
   bump (T010).
7. End with the run report (data-model) and only what is left for the developer: the PRs to merge
   in `ORDER` (then run /landspec:implement again), the held release (T010), or `/speckit-specify`
   for the next feature.

On a later run, when every task issue is closed: the release (research R9). The skill never merges.
