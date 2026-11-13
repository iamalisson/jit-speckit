# Contract: feature review (a new mode of commands/review.md)

Launched by `/landspec:implement` (research R8), like every review: `landspec:reviewer`, the
configured model, `isolation: "worktree"`, prompt starting with the sentinel line, plus the facts:
`feature review`, the feature folder, `commit:` (the check copy's merge result, kept on a local
ref `refs/landspec/check/<feature>` so the reviewer's copy can reach it), `checkout:`, the base, the
test command and its output on the combination.

The reviewer reads `spec.md` (every FR, every acceptance scenario, every SC), `plan.md`, `tasks.md`
and `git diff origin/<base>...<commit>`, and reports one line per item:

```
- met: FR-004 — pr.sh:36 targets base_ref(); tests/pr.test.sh:212 "when a parent is set, then …"
- not met: SC-005 — no check covers merging in ORDER without conflicts
- not verifiable: SC-001 — needs a timed run (quickstart 2)
```

Then the usual `Copy:`, `Reviewed: <base sha>..<commit>`, `Model:` lines, and `Assessment: ready`
only when no line is `not met`. `review.sh record --feature <file>` keeps it per feature (not tied
to a branch); `pr.sh` does not read it.
