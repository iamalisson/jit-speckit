<!-- Issue #21, created by /speckit-tasks (issues.sh). Assignee: you. Milestone and project: only if set in jit-config.yml. -->
**[001] T001: Add the price query and its index**

**Feature:** `001-price-search` · **Task:** T001 in [`tasks.md`](../specs/001-price-search/tasks.md)

**Task:** Add the price query and its index in `src/products/search.ts`

**Comes from:** FR-001, SC-001

**Impact:** new table index in `db/migrations/`; `tests/schema.test.ts` lists every index and needs the new one

**Completed when:** `pnpm test` passes for search, including an empty catalog and equal prices

---
**Done** = closed by the merged PR (`Closes #N`). Start it with `/speckit-implement T001`.
