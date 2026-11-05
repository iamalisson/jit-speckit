Reviewed at: 172f8c5 (v1.7.2)

## 7. The core model (D1–D3)

Each part of the core model gets the problem it solves, its cost per task (from the per-level table in
[6-own-rules-cost.md](6-own-rules-cost.md), not measured again), each source `docs/design.md`
cites and whether it supports the claim as written, the simplest model that keeps the same
promises, and a verdict. The sources were opened on 2026-11-05.

### D1 · One task = one issue = one branch = one PR into the base

- **Problem it solves**: small changes get read closely; a failure points at one task; "done" has
  an outside definition (the issue closed by the merged PR), which is what makes `/jit-speckit:next`
  resumable and gives the review something to check against (`docs/design.md:6-22`).
- **Cost per task**: one issue, one claimed branch, one independent review until `ready`, one PR, one
  CI run and one merge (section 6, per-level table). Measured on T001–T005: 5.8 to 24.2 minutes of
  review per task, and 5 merges into `main` for 5 tasks. On standard and full each task PR lands on
  `develop` on its own; on lite, each one lands on `main`, the only long-lived branch lite has
  (`README.md:120`).
- **Sources cited** (`docs/design.md:8-17`):
  - SmartBear, "Best practices for peer code review": **partly**. The page says "developers should
    review no more than 200 to 400 lines of code (LOC) at a time" and "beyond 400 LOC, the ability to
    find defects diminishes", which supports the range and the fall-off. But it calls it "A SmartBear
    study of a Cisco Systems programming team", not a Cisco study, and has no "2,500" anywhere.
  - Google eng-practices, "Small CLs": **supports**. "100 lines is usually a reasonable size for a
    CL, and 1000 lines is usually too large, but it's up to the judgment of your reviewer."
  - DORA, "Working in small batches": **partly**. The page says it "predicts software delivery
    performance and organizational performance", and argues that it is "a critical countermeasure"
    to the delivery instability AI adoption brings. That is the page's argument, not a stated
    research link to stability. On AI it says small batches "amplifies the positive impact of AI
    adoption on product performance". The claim that "the 2025 model lists it among the
    capabilities" is **unverified**: `dora.dev/ai/capabilities-model/report/` mentions "the seven
    capabilities that amplify the benefits of AI" without naming them on the page. The list is in a
    PDF on cloud.google.com that was not opened.
- **Simplest model that keeps the same promises**: what the sources support is small *reviews*,
  not small *deploys*. Keep one task = one issue = one branch = one small reviewed PR, and have
  those PRs merge into one branch per feature, with one PR from it into the base. The review stays at
  task size (Google's ~100 lines, SmartBear's 200–400), and a failure still points at one task PR.
  Two promises only survive with two conditions, which the model must carry:
  - **"done" = the issue closed by its merged PR**: GitHub closes `Closes #N` issues only on a merge
    into the default branch, and a feature branch is not one. On standard and full,
    `close-linked-issues.yml` already closes them on any other branch (its condition is
    `base.ref != default_branch`), but lite writes no workflows (section 4, F4.4). Without that
    workflow at every level, or the PR script closing the issue itself, `next.sh:39` would never see
    a task as done on lite, and a task that depends on it would stay blocked for good: the feature
    PR's merge into `main` would not close the task issues either, because `Closes #N` is only in
    each task PR's body (`extension/scripts/pr.sh:69`) and task commits carry `Refs #N`
    (`extension/commands/pr.md:30`). Two exceptions: the feature PR's body lists every `Closes #N`,
    or the repository sets its merge commit message to the PR's title and description, so the task
    PRs' `Closes #N` lines travel into the default branch inside their merge commits (GitHub's
    documented closing-keyword behavior; not tested here).
  - **"one revert removes one task"** (`docs/design.md:18-19`): reverting the feature PR takes the
    whole feature. A single task can still be reverted from the base if each task stays one unit
    there: no rebase merge for task PRs (it makes one task several commits) and no squash for the
    feature PR (it folds every task into one commit). A squash or a merge commit for task PRs both
    work: `git revert <the task's squash commit>`, or `git revert -m 1 <the task PR's merge
    commit>` (a plain `git revert` refuses a merge commit). jit-speckit sets no merge method today
    (no `gh pr merge` or merge setting under `extension/`), so the model has to.

  With both, the base gets each feature once, which matches DORA's batches better than ten partial
  merges into it. The user chose this on
  2026-11-05 (draft spec 004, "One feature branch, one feature PR", not merged).
- **Verdict**: **simplify**. Keep the task-sized PR; change where it merges. Fix `docs/design.md:8-10`
  to say "a SmartBear study of a Cisco team" without the uncited "2,500", and drop or source the
  "2025 model lists it" sentence.

### D2 · The spec is its own PR into the base

- **Problem it solves**: task branches start from the base and read `tasks.md` there, so the spec
  must be merged first; the design is reviewed while changing it costs one edit; each task PR stays
  small and closes one issue, instead of each carrying its own copy of the spec folder
  (`docs/design.md:28-33`, `examples/README.md:43-55`).
- **Cost per task**: once per feature, not per task: one more PR to merge before any task can start
  (section 6: "spec PR merged before the first task", and on lite one more question, "Open the spec PR
  now?"). On this feature: PR #28 had to merge before T001 started. Every later change to the spec
  (a converge, a fixed task line) needs another spec PR, and when `gh pr list` fails that path can
  force-push over a teammate's commit on it (section 1, F1.8).
- **Sources cited**: none outside the project. `docs/design.md` points only at `examples/README.md`,
  which explains the mechanics, not evidence that a separate design PR improves the result.
- **Simplest model that keeps the same promises**: with a feature branch (D1's simplification),
  the spec folder is that branch's first commit. Task branches start from the feature branch and find
  `tasks.md` there, so the reason for merging into the base first disappears. Each task PR still
  carries only its own change, because the spec is already in the branch it targets. The design is
  still reviewed before code: the plan review (`issues.sh:18`, recorded and required) already gates
  every issue, and the spec, plan and tasks reach the base inside the feature PR, reviewed with the
  code they produced. What changes is who reviews the design first: today the user sees it as a PR
  before any code exists (`examples/README.md:54-55`); in this model the first reviewer is the
  agent's plan review, and the user sees the spec on GitHub in the feature branch (any time) and in
  the feature PR (after the code). The human sign-off before code becomes optional and has no gate:
  GitHub can only approve pull requests, not a commit, and nothing would make `/speckit-implement`
  wait for it, where today it refuses with "merge the spec PR first" (`examples/README.md:48-50`).
  A team that needs that gate keeps a small PR of the spec into the feature branch, approved before
  the first task.
- **Verdict**: **replace**: the spec as the feature branch's first commit, no separate spec PR into
  the base. Later spec changes go through a small PR into the feature branch.

### D3 · Three levels (lite, standard, full)

- **Problem it solves**: "A prototype and a payment service do not need the same ceremony, and a
  checklist that is too heavy gets skipped" (`docs/design.md:48-53`). Levels size the branch flow,
  the constitution's defaults, the CI and the review bar.
- **Cost per task**: section 6's table shows what each level actually changes per task: the branch
  flow, CI (none on lite), `## Evidence` and analysis on full. The most expensive step, the
  independent review until `ready` (5.8–24.2 minutes a task here), is the same at every level. So is the
  plan review before issues (36 minutes on this feature). Lite, for "prototypes, solo work", pays the
  full review bar but gets no CI and no GitHub protection behind it (section 4, F4.4).
- **Sources cited**: none. The reason is stated, not sourced.
- **Simplest model that keeps the same promises**: keep the three levels, which users choose and
  change cheaply (section 5, P18 holds), but let the review bar actually follow the level:
  - on lite, one review round per task, then delta rounds only on the fix commits (the ~1.1 minute
    rounds of section 6), and no plan-review loop beyond one round plus fixes;
  - standard and full keep rounds until `ready`.

  At the same time, give lite what it lacks for safety at no cost: secret scanning with push
  protection on public repositories (F4.4).
- **Verdict**: **simplify**. Keep the three levels; make the costliest steps scale with them, and
  make the docs say plainly what lite does not have.
