Reviewed at: 172f8c5 (v1.7.2)

## 1. Task chain

Every `file:line` is at tag `v1.7.2`. The local reproductions run in a throwaway repository made by
`tests/helpers.sh` (`new_repo`, `fake_gh`). The real run is on the private sandbox
`iamalisson/jit-speckit-sandbox` under feature `099-jit-review`, from its clone, with the guard in
tasks.md "Rules every task follows". The sandbox's `.specify/extensions/jit/scripts` is identical
to `v1.7.2:extension/scripts` (`diff -r`: no output).

| id | promise | verdict | evidence |
|---|---|---|---|
| P01 | Every task gets exactly one GitHub issue; an interrupted run never makes duplicates | holds | `issues.sh:54-56` writes `— #N` back right after each `gh issue create`, and `:32` skips linked lines; `tests/issues.test.sh:37` ("when run again, then no issue is created twice"); sandbox: first run `T001 → #11`, `T002 → #12`, `CREATED=2 SKIPPED=0`, second run `CREATED=0 SKIPPED=2` |
| P02 | Every task gets its own branch from the base, refused without one task, an issue, the merged spec and a clean tree; pushed at once as a claim | broken | the refusals hold (`branch.sh:17,22,24,35,50`; `tests/branch.test.sh:38,42-44,57`), but a refused claim push is silent: F1.1 |
| P03 | Every task gets one PR with `Closes #N`; a task is done when its issue closes | broken | `pr.sh:69` adds `Closes #N`; sandbox PR #14 into `develop` got it and `close-linked-issues.yml` closed #11 within ~10 s ("Closed by #14 (merged into develop)."). But `next` decides "done" by a title search, so a renamed closed issue stays "open": F1.2 |
| P04 | `/jit-speckit:next` is resumable, never offers a task in progress twice (worktrees too), holds a task until its dependencies close | broken | resume, in progress, worktrees and blocked hold (`next.sh:39-51`; `tests/next.test.sh:26-63`); sandbox: after the claim T001 showed `resume`, after #11 closed `done T001` and T002 went from `blocked` to `open` within ~17 s. Broken through the same title search: F1.2. The dependency hold is in `next` only: F1.3 |
| P05 | The spec is its own PR; the spec folder is never lost while switching branches | holds | `pr.sh:84-91` copies the folder out and puts it back on any exit (`trap … EXIT`); `tests/pr.test.sh:121`; real runs: this repository's PR #28 (the untracked folders of features 002 and 003 stayed in place) and sandbox PR #13 |
| P23 | Never commits or pushes for the user outside the documented flows | holds | every commit or push in the shipped scripts: the claim push `branch.sh:56`, the task push `pr.sh:70`, the spec commit and push `pr.sh:94,97`, `develop`/`staging` creation `level.sh:56` (offered with `--no-branches` in `skills/init/SKILL.md` step 3); the prompts commit only in `extension/commands/pr.md` step 3 and in `skills/init/SKILL.md` step 7, which asks first |

Also checked, no finding:
- `/speckit-converge`: the `after_converge` hook (`extension/extension.yml:44-47`) runs the issues
  command, and a later spec PR starts fresh from the base after a squash-merged one
  (`pr.sh:79-90`, `tests/pr.test.sh:72-74`).
- `add_meta` (`lib.sh:185-200`): each failed assignee, milestone or project edit prints
  `jit: warning: could not set …` with `gh`'s own error (`tests/issues.test.sh:57`), so a user can
  tell it never worked (FR-006).
- The `"$num in:title"` search (`next.sh:31`) matching other features' issues does no harm: a task
  is done only when its own issue number is in the result (`next.sh:39`), and numbers are unique.

### F1.1 · Medium · P02, P04 · a refused claim push is silent, so the task is not claimed and nobody is told

- **verdict**: broken
- **evidence**: `branch.sh:56` runs `git push … 2>/dev/null` inside an `if` with no `else`: on
  failure it prints nothing and exits 0. `docs/reference.md:73-74` says "A task is **claimed** the
  moment it starts: its branch is pushed to origin … `next` in every clone and worktree shows it as
  in progress and never picks it". No test covers a failed push (`tests/branch.test.sh:18` covers
  only the success).
- **reproduction**: section A of the script below. An origin `pre-receive` hook refuses the push,
  and `branch.sh T001` prints `BRANCH=…`, `rc=0`, no `claim:` line, and origin has 0 `feat/`
  branches. A second clone's `next` would offer T001 as `open`.
- **exposure**: public (the operator's own clone and remote).
- **fix**: when the push fails, print `jit: warning: could not claim <branch> on origin: <git's
  error>; other clones may start this task` to stderr (still exit 0, the work can go on).
  Check for `tests/branch.test.sh`: when origin refuses the claim push, then `branch.sh` still
  exits 0 and its output contains `could not claim`. It fails today (nothing is printed).

### F1.2 · Medium · P03, P04 · `next` finds closed issues by title search, so a renamed or older closed issue counts as not done

- **verdict**: broken
- **evidence**: `next.sh:31` collects closed issues with
  `gh issue list --state closed --limit 500 --search "$num in:title"`. A task issue whose title no
  longer has the feature number, or one past the 500 newest matches, is missing from the list, and
  `next.sh:39` then never marks it done. Sandbox, real output: issue #12 (`[099] T002: …`) renamed
  to "Extend the note with a second line" and closed. `gh issue view 12` gives
  `CLOSED Extend the note with a second line`, and `next.sh 099` still prints
  `open T002 #12 …` and `NEXT=T002`. Renaming T001's issue instead would leave every task that
  depends on it `blocked` for good (`next.sh:47-49` uses the same list).
- **reproduction**: sandbox phase 3 below (rename, close, `next`). With the fake `gh`, the same:
  leave an issue number out of `$GH_CLOSED`.
- **exposure**: public.
- **fix**: get each task's state by its issue number, not by search: one
  `gh issue list --state closed --limit 1000 --json number` without `--search`, or one GraphQL query
  for the listed numbers. Check for `tests/next.test.sh`: when a closed task issue does not have
  `[NNN]` in its title, then `next` shows it `done`. It fails today, because the fake `gh` would
  have to be taught the search (assert the call has no `--search`).

### F1.3 · Low · P04 · `/speckit-implement Tnnn` starts a blocked or already-done task

- **verdict**: limit (the docs describe it honestly)
- **evidence**: `branch.sh` never calls `gh` and never reads `depends on`. Sections B and C below:
  T002 starts while T001's issue is open (`claim: feat/001-t002-…`), and T001 starts again after its
  issue closed. `docs/reference.md:70-71` promises the hold for `next` only ("so `next` never
  offers work whose prerequisite has not merged"), which is accurate.
- **note**: no fix proposed. If the hold should cover a task named by hand, `branch.sh` would need
  the same closed-issue lookup as F1.2's fix.

### F1.4 · Low · P02 · untracked files of another feature block a task from starting

- **verdict**: limit
- **evidence**: `branch.sh:50` refuses on any `git status --porcelain` output, untracked files
  included. Section D below: an untracked `specs/002-draft/` gives `jit: uncommitted changes on
  'main'; commit or stash them first`, `rc=1`. It happened for real on 2026-11-05 starting this task,
  with the drafts of features 002 and 003. The message says "uncommitted changes" and names no file,
  and stashing is the only advice. The refusal is on purpose ("Never carry uncommitted work onto
  another task's branch"), so it is a limit, not a defect, but the docs only say "a clean tree".
- **note**: the message could list the paths (`git status --porcelain | head -5`) and say that
  untracked files count too.

### F1.5 · Low · P04 · `next` exits 128 with no message when origin cannot be listed

- **verdict**: limit
- **evidence**: `next.sh:23` runs `git ls-remote … 2>/dev/null` under `set -o pipefail`, so an
  unreachable origin ends the script with git's exit code and nothing on screen. It fails closed
  (no claimed task is offered as `open`), but the user gets no reason. Section E below: `rc=128`
  after the `in-progress T001` line from the earlier run.
- **note**: `ls-remote … || die "cannot list branches on origin: …"` would say why.

### Reproductions

<details>
<summary>Local script (sections A–E) and its output</summary>

```bash
# T001 reproductions, run as: bash t001-repro.sh <v1.7.2 worktree>
source "$1/tests/helpers.sh"
fake_gh; new_repo standard
[ "$(git rev-parse --show-toplevel)" != /home/admin/Documents/workstation/personal/jit-speckit ] || exit 1
commit_tasks '- [ ] T001 First thing — #1
- [ ] T002 Second thing (depends on T001) — #2'
b="$SCRIPTS/branch.sh"; n="$SCRIPTS/next.sh"

echo "== A. claim push refused by origin: what the user sees"
printf '#!/bin/sh\necho "refused by origin" >&2; exit 1\n' > "$TMP/origin.git/hooks/pre-receive"; chmod +x "$TMP/origin.git/hooks/pre-receive"
"$b" T001; echo "rc=$?"
git ls-remote origin 'feat/*' | wc -l | sed 's/^/feat branches on origin: /'
rm "$TMP/origin.git/hooks/pre-receive"; git switch -q main

echo "== B. a task whose dependency T001 is still open (fake gh: no issue closed)"
"$n" | tail -3
"$b" T002 || echo "rc=$?"
git switch -q main

echo "== C. a task whose issue is already closed (done)"
echo 1 > "$GH_CLOSED"; "$n" | grep T001
git branch -D -q feat/001-t001-first-thing; "$b" T001 || echo "rc=$?"
git switch -q main; rm "$GH_CLOSED"

echo "== D. an untracked draft folder of another feature"
mkdir -p specs/002-draft && echo x > specs/002-draft/spec.md
"$b" T002 2>&1 || echo "rc=$?"
rm -rf specs/002-draft

echo "== E. next when origin cannot be listed, with T001 claimed by another clone"
git push -q origin main:feat/001-t001-first-thing 2>/dev/null; git branch -D -q feat/001-t001-first-thing feat/001-t002-second-thing 2>/dev/null || true
"$n" | grep T001
git remote set-url origin "$TMP/nowhere.git"
"$n" || echo "rc=$?"
```

```text
== A. claim push refused by origin: what the user sees
BRANCH=feat/001-t001-first-thing ISSUE=1 TASK=T001 BASE=develop
rc=0
feat branches on origin: 0
== B. a task whose dependency T001 is still open (fake gh: no issue closed)
resume T001 #1 First thing
blocked T002 #2 Second thing (depends on T001)
DONE=0/2 IN_PROGRESS=0 NEXT=T001
claim: feat/001-t002-second-thing-depends-on pushed to origin
BRANCH=feat/001-t002-second-thing-depends-on ISSUE=2 TASK=T002 BASE=develop
== C. a task whose issue is already closed (done)
done T001 #1 First thing
resume T002 #2 Second thing (depends on T001)
claim: feat/001-t001-first-thing pushed to origin
BRANCH=feat/001-t001-first-thing ISSUE=1 TASK=T001 BASE=develop
== D. an untracked draft folder of another feature
jit: uncommitted changes on 'main'; commit or stash them first
rc=1
== E. next when origin cannot be listed, with T001 claimed by another clone
in-progress T001 #1 First thing
resume T002 #2 Second thing (depends on T001)
rc=128
```

</details>

<details>
<summary>Sandbox run, feature 099 (real GitHub)</summary>

Phase 1, `bash sandbox-1.sh` from the sandbox clone:

```bash
# T001 real run on the sandbox, phase 1. Run from the sandbox clone: bash sandbox-1.sh
set -u
[ "$(git remote)" = origin ] && [ "$(gh repo view --json nameWithOwner -q .nameWithOwner)" = iamalisson/jit-speckit-sandbox ] || exit 1
R="$(git rev-parse --git-common-dir)/jit-repro"; mkdir -p "$R"; REC="$R/t001-created.txt"; touch "$REC"
X=.specify/extensions/jit/scripts
git fetch -q origin && git switch -q develop && git merge -q --ff-only origin/develop
git ls-tree --name-only origin/develop specs/ | grep -q '^specs/099-' && { echo "099 taken"; exit 1; }
F=specs/099-jit-review; mkdir -p $F
printf '# 099 jit review (sandbox test of the task chain)\n' > $F/spec.md; cp $F/spec.md $F/plan.md
cat > $F/tasks.md <<'T'
# Tasks: 099 jit review

- [ ] T001 Add docs/099-note.md with one line
  - Completed when: the file exists on develop
- [ ] T002 Extend docs/099-note.md with a second line (depends on T001)
  - Completed when: the file has two lines
T
printf '{ "feature_directory": "%s" }\n' $F > .specify/feature.json
echo "== issues.sh before any plan review"; bash $X/issues.sh; echo "rc=$?"
f=$(mktemp); printf 'Sandbox plan for the 001 review, T001.\n\nAssessment: ready\n' > $f
bash $X/review.sh record --plan $f
echo "== issues.sh"; bash $X/issues.sh 2>&1 | tee /dev/stderr | sed -n 's/.*→ #\([0-9]*\)$/issue \1/p' >> "$REC"
echo "== issues.sh again"; bash $X/issues.sh
echo "== pr.sh spec"; out=$(bash $X/pr.sh spec 2>&1); echo "$out"; echo "branch spec/099-jit-review" >> "$REC"
pr=$(sed -n 's#^PR=.*/pull/##p' <<<"$out"); echo "pr $pr" >> "$REC"
echo "== merge spec PR #$pr"; gh pr merge "$pr" -R iamalisson/jit-speckit-sandbox --squash --delete-branch; echo "rc=$?"
echo "merged spec PR #$pr (stays)" >> "$REC"; cat "$REC"
```

```text
T001 → #11
T002 → #12
CREATED=2 SKIPPED=0
== issues.sh again
CREATED=0 SKIPPED=2
== pr.sh spec
copilot: code review requested
PR=https://github.com/iamalisson/jit-speckit-sandbox/pull/13
== merge spec PR #13
rc=0
```

Phase 2, `bash sandbox-2.sh`:

```bash
# T001 real run on the sandbox, phase 2. Run from the sandbox clone: bash sandbox-2.sh
set -u
[ "$(git remote)" = origin ] && [ "$(gh repo view --json nameWithOwner -q .nameWithOwner)" = iamalisson/jit-speckit-sandbox ] || exit 1
REC="$(git rev-parse --git-common-dir)/jit-repro/t001-created.txt"; X=.specify/extensions/jit/scripts
git fetch -q origin && git merge -q --ff-only origin/develop
echo "== next"; bash $X/next.sh 099
echo "== branch T001"; bash $X/branch.sh T001; b=$(git branch --show-current); echo "branch $b" >> "$REC"
git ls-remote origin "$b" | sed 's/^[0-9a-f]*/<sha>/'
echo "== next after the claim"; bash $X/next.sh | tail -3
echo "one line" > docs/099-note.md 2>/dev/null || { mkdir -p docs; echo "one line" > docs/099-note.md; }
git add docs/099-note.md && git commit -q -m "docs: add 099 note" && echo committed
f=$(mktemp); printf 'What changed: one doc line.\n\nAssessment: ready\n' > $f; bash $X/review.sh record $f
body=$(mktemp); printf '## Review\n\nSandbox run for the 001 review, T001.\n' > $body
echo "== pr.sh task"; out=$(bash $X/pr.sh task T001 "docs: add 099 note" $body 2>&1); echo "$out"
pr=$(sed -n 's#^PR=.*/pull/##p' <<<"$out"); echo "pr $pr" >> "$REC"
gh pr view "$pr" -R iamalisson/jit-speckit-sandbox --json baseRefName,body -q '"base=\(.baseRefName)\n\(.body)"'
echo "== merge task PR #$pr"; gh pr merge "$pr" -R iamalisson/jit-speckit-sandbox --squash --delete-branch; echo "rc=$?"
echo "merged task PR #$pr (stays)" >> "$REC"
echo "== issue 11 right after the merge"; gh issue view 11 -R iamalisson/jit-speckit-sandbox --json state -q .state
```

```text
== next
open T001 #11 Add docs/099-note.md with one line
blocked T002 #12 Extend docs/099-note.md with a second line (depends on T001)
DONE=0/2 IN_PROGRESS=0 NEXT=T001
== branch T001
claim: feat/099-t001-add-docs-099-note pushed to origin
BRANCH=feat/099-t001-add-docs-099-note ISSUE=11 TASK=T001 BASE=develop
<sha>	refs/heads/feat/099-t001-add-docs-099-note
committed
REVIEW=ready
== pr.sh task
copilot: code review requested
PR=https://github.com/iamalisson/jit-speckit-sandbox/pull/14
base=develop
## Review

Sandbox run for the 001 review, T001.

Closes #11
== merge task PR #14
rc=0
== issue 11 right after the merge
OPEN
```

Then, polling: `issue 11: CLOSED after ~10s`, last comment `Closed by #14 (merged into develop).`
`next.sh 099` at 17:18:54 UTC: `done T001 #11 …`, `open T002 #12 …`, `DONE=1/2 IN_PROGRESS=0 NEXT=T002`.

Phase 3, the rename (F1.2):

```bash
gh issue edit 12 -R iamalisson/jit-speckit-sandbox --title "Extend the note with a second line"
gh issue close 12 -R iamalisson/jit-speckit-sandbox --comment "[001 review T001] cleanup: closed after a rename test"
sleep 20; gh issue view 12 --json state,title -q '"\(.state) \(.title)"'; bash .specify/extensions/jit/scripts/next.sh 099
```

```text
CLOSED Extend the note with a second line
done T001 #11 Add docs/099-note.md with one line
open T002 #12 Extend docs/099-note.md with a second line (depends on T001)
DONE=1/2 IN_PROGRESS=0 NEXT=T002
```

Cleanup: no `099` branch is left on origin and no `099` PR is open; local `spec/099-jit-review` and
`feat/099-t001-add-docs-099-note` deleted. Left in place on the sandbox `develop`: spec PR #13 and
task PR #14 (merged), so the next run uses `098`. Issues #11 and #12 are closed.

</details>
