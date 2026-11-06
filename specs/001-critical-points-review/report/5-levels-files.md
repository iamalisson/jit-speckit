Reviewed at: 172f8c5 (v1.7.2)

## 5. Levels, setup and the user's files

Every `file:line` is at tag `v1.7.2`, except where a line says `v1.3.0`. Reproductions run in
throwaway repositories: `tests/helpers.sh` for the level and remove checks, and plain `mktemp`
repositories with a local bare origin for the two `bin/setup.sh` runs. Those need the real
`specify` CLI (spec-kit v1.2.5, installed here). The older release is read from its own worktree,
`git worktree add "$(mktemp -d)" v1.3.0`.

| id | promise | verdict | evidence |
|---|---|---|---|
| P18 | Levels size the flow, the constitution and the CI; changeable any time; going down never deletes files | holds | `level.sh` only adds (`put`, `level.sh:123-127`) and rewrites the jit block of the constitution (`level.sh:103-112`); section A: up lite → standard → full, then down to lite: 13 files at full, 13 after going down, 0 deleted; `tests/level.test.sh` |
| P19 | Nothing of the user's is overwritten: managed files carry a marker, unmarked ones are written only when missing | limit | unmarked files are kept (`level.sh:124`, and the upgrade below prints `kept:` for each); an edit inside a marked file is replaced silently (F5.1); files written before the marker existed are kept forever (F5.3) |
| P20 | `remove` deletes only what still matches what jit wrote | broken | `bin/remove.sh:39-46` deletes every file that still has the marker; section C: a managed file with an uncommitted edit is removed and the edit is gone: F5.2 |
| P21 | `init` refreshes the project's extension copy, keeps the level, changes no code and commits nothing | broken | the extension is refreshed and the level kept (`skills/init/SKILL.md` step 2, upgrade run below); but projects from before 1.4.0 never get their generated files refreshed (F5.3), an older plugin copy downgrades a newer project without a word (F5.4), and since 1.7.1 `init` offers to commit (F5.5) |
| P22 | No AI attribution lines in commits or PRs by default | holds | `extension/scaffold/lite/.claude/settings.json` is `"attribution": { "commit": "", "pr": "" }`, written by `put` only when the project has no `.claude/settings.json` (`level.sh:316-321`); the upgrade run prints `kept:    .claude/settings.json` for an existing one; `docs/reference.md` "AI attribution" says the same |
| P24 | Runs on Linux and macOS (bash 3.2, BSD tools) | limit | every PR runs Linux with bash 5 and a bash 3.2 + busybox job (`.github/workflows/test.yml:16,37`); the real macOS job runs only weekly or by hand, and v1.7.2 never ran on it: F5.6 |

### F5.1 · Low · P19 · an edit inside a managed file is replaced by the next `level` or `init`, with only `updated:` printed

- **verdict**: limit
- **evidence**: `put` rewrites any file whose first lines still hold the marker (`level.sh:124-127`).
  Section B: a committed `# my own step` line in `.github/workflows/ci.yml` is gone after
  `level.sh standard` (`updated: .github/workflows/ci.yml`, `my line still there: 0`). The docs
  say so: the marker means "/jit-speckit:level re-creates it while this line stays; delete the
  line to keep your own edits" (the marker text itself, and `docs/design.md:57-58`). The edit is
  still in git history when it was committed.
- **reproduction**: section B of the script below.
- **exposure**: public.
- **note**: `put` could keep the old content in `.git/jit-backup/<path>` and print where, when the
  file differs from what jit last wrote.

### F5.2 · High · P20 · `remove` deletes a managed file the user edited, uncommitted edits included

- **verdict**: broken
- **evidence**: `docs/reference.md:127-129` says `/jit-speckit:remove` "deletes the files
  jit-speckit created and you never edited". `remove.sh:39-46` (`ours`) treats any file whose
  first two lines hold the marker as jit's, whatever is below it, and `rm`s it (`remove.sh:51`).
  Section C: with `# uncommitted step` added to `.github/workflows/ci.yml` (marker kept),
  `remove.sh` prints `removed: .github/workflows/ci.yml`, and the line is in no commit and no stash
  (`0`, `0`). A file whose marker the user deleted is kept, as documented (`security.yml (taken
  over) exists: yes`). The skill does warn: `skills/remove/SKILL.md:15-16` says "Deleted files
  that were never committed cannot be recovered: ask once before running", so through
  `/jit-speckit:remove` the user is asked once; `bin/remove.sh` itself asks nothing and checks
  nothing.
- **reproduction**: section C of the script below.
- **exposure**: public.
- **fix**: `put()` records the SHA-256 of every file it writes in `.specify/jit-files.sha256`;
  `bin/remove.sh` deletes a marked file only when its hash matches that record, or, with no record
  (a project set up before the fix), only when it is tracked and `git diff --quiet HEAD` says it
  is unchanged; otherwise it prints `kept (edited): <file>`. Check for `tests/setup.test.sh`: when
  a managed workflow (committed alone) has an uncommitted edit, then `remove.sh` keeps it and
  prints `kept (edited)`. It fails today. (Corrected 2026-11-05 from feature 002's research,
  `specs/002-review-fixes/research.md` C1).

### F5.3 · Medium · P19, P21 · a project set up before 1.4.0 keeps every generated file at its old version, including hooks that let a commit through

- **verdict**: limit (the docs mislead)
- **evidence**: the marker line arrived in 1.4.0 (`git log -S'jit-speckit: managed file'` →
  `75de174 fix: 1.4.0 …`). Files written by an older release have no marker, so `put` treats them
  as the user's. Upgrade run below (v1.3.0's `bin/setup.sh`, then v1.7.2's, both `--level standard`):
  every generated file is `kept:`: `.githooks/pre-commit`, `.githooks/pre-push`,
  `.github/workflows/ci.yml`, `security.yml`, `close-linked-issues.yml`, `.github/dependabot.yml`
  and `.github/pull_request_template.md`. jit's own old workflows are also taken for the
  project's CI (`already checks pull requests; no ci.yml generated`). The kept 1.3.0 hooks print
  "secret check skipped (CI still checks)" and `exit 0` when the script is missing
  (`v1.3.0:extension/scaffold/lite/.githooks/pre-commit:5`), where 1.7.2's `exit 1`. A probe of
  that case printed `commit with .env: ACCEPTED`; the probe script is kept outside the repository,
  in `$(git rev-parse --git-common-dir)/jit-repro/t005-upgrade-with-hook-bypass.sh`. The sandbox showed the same
  hooks being kept when it went from 1.3.0 to 1.7.2 (its PR #10). `docs/reference.md:16-20` says
  that running `init` once per project is how a project gets the new version.
- **reproduction**: the upgrade script below.
- **exposure**: public (it needs the project's own copy of the script to be missing).
- **fix**: `put` treats a file byte-identical to a hook an earlier release wrote (a list of
  SHA-256s kept in the extension) as jit's, and names the others it recognizes: `kept (written by jit-speckit <versions>, no marker): <file> — delete it to get
  the current one` (and `<versions> or older` for generated files). Check for
  `tests/level.test.sh`, with v1.3.0's hook as a committed fixture, since CI's checkout has no tags: when `.githooks/pre-commit` is v1.3.0's exact file, then `level.sh` replaces it and it carries the marker; and when
  `close-linked-issues.yml` is v1.3.1's exact file, then it is kept and
  named in a `kept (written by jit-speckit 1.3.1` line (replacing it would
  undo a take-over, since 1.4.0+'s copy without its marker has the same bytes). It fails today. (Corrected 2026-11-05 from feature 002's research,
  `specs/002-review-fixes/research.md` C1).

### F5.4 · High · P21, P10 · an older plugin copy downgrades a newer project, without a word, and takes the review gate with it

- **verdict**: broken
- **evidence**: `bin/setup.sh` has no version check (only spec-kit's, `setup.sh:7,35`). Downgrade
  script below: a project set up with 1.7.2 (`version: "1.7.2"`), then v1.3.0's `setup.sh`, is at
  `version: "1.3.0"`, `rc=0`, and the log has no warning (the one line that matched the search is
  "PLACEHOLDERS"). The downgrade also removes what 1.3.0 did not have: `review gate after the
  older setup: review.sh missing; speckit-jit-review skill missing`. So the gate that refuses a PR
  without a recorded review (P10) is gone, and nothing says so. Ranked High: a gate stops existing
  without the user being told (FR-009). In this session's own run, on 2026-11-05: Claude Code's `/jit-speckit:init` skill
  pointed at the 1.7.0 plugin cache while this repository was at 1.7.1, so running it as given
  would have downgraded the repository. The user ran `/reload-plugins` first, which fixed it.
- **reproduction**: the downgrade script below.
- **exposure**: public.
- **fix**: `setup.sh` reads the project's current `version:` from
  `.specify/extensions/jit/extension.yml` and refuses to go below it without `--downgrade`,
  saying "this plugin copy is <old>, the project is at <new>; run /reload-plugins". Check for
  `tests/setup.test.sh`: when the project's extension is at a newer version than the plugin, then
  `setup.sh` exits non-zero and prints `/reload-plugins`. It fails today.

### F5.5 · Low · P21 · the README says `init` commits nothing; since 1.7.1 it offers to

- **verdict**: limit
- **evidence**: `README.md:67`: "It changes nothing in your code and commits nothing". In
  `skills/init/SKILL.md`, step 7 is "Offer to commit it" and, on yes, commits, pushes and opens a
  PR. It asks first, so nothing is committed without a yes, but the README sentence is out of date.
- **rank**: Low, checked against FR-009 on 2026-11-05 (T011). The sentence is out of date, but it
  cannot lead a user into a commit they did not agree to: step 7 asks one explicit question that
  names the branch and the PR ("Commit this on `chore/jit-speckit-<version>` and open the PR?"),
  and on no it leaves everything uncommitted and says so. The question corrects the sentence at
  the one moment it matters.
- **reproduction**: read the two lines.
- **exposure**: public.
- **note**: "It commits nothing unless you say yes to its one question".

### F5.6 · Medium · P24 · v1.7.2 was never tested on macOS

- **verdict**: limit (the docs mislead)
- **evidence**: `.github/workflows/test.yml:57-62`: the macOS job runs only
  `if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'`, so no PR or
  push to `main` tests macOS. `gh run list --workflow test.yml --limit 100` on 2026-11-05 has no
  `schedule` run at all, and two `workflow_dispatch` runs, the latest on `4b1f26b`. (The repository's
  first commit is from 2026-11-04 and the cron runs on Mondays, `test.yml:7-8`, so it has simply
  not fired yet; the gap is that PRs never run the job.) `4b1f26b` is the v1.3.0 commit
  (`git rev-list -n1 v1.3.0`), and it is 17 commits and `27 files changed, 750 insertions(+), 75 deletions(-)` (in `extension/scripts`,
  `bin`, `hooks`, `tests`) before v1.7.2. Every PR does run a bash 3.2 + busybox job on Linux
  (`test.yml:37-56`), which covers the shell but not BSD `sed`, `find` or `stat`. The README
  promises Linux and macOS (the badge, and the constitution's "Stack").
- **reproduction**: `gh run list --workflow test.yml --limit 100 --json event,headSha,conclusion`,
  and `git log --oneline 4b1f26b..172f8c5`.
- **exposure**: public.
- **fix**: move the `macos` job from `test.yml` into its own `.github/workflows/macos.yml`, run on
  pull requests touching `extension/scripts/`, `bin/`, `hooks/` or `tests/` (a path filter is per
  workflow) and on every tag. Check for `tests/static.test.sh`: when `macos.yml` is read, then it
  runs on pull requests touching `extension/scripts/`, `bin/` or `hooks/`, and on every tag;
  and `test.yml` has no `runs-on: macos` left. It fails today. (Corrected 2026-11-05 from feature 002's research,
  `specs/002-review-fixes/research.md` C1).

### Reproductions

<details>
<summary>Level, edited-file and remove script (sections A–C) and its output</summary>

```bash
# T005 reproductions, run as: bash t005-repro.sh <v1.7.2 worktree>
source "$1/tests/helpers.sh"
fake_gh; new_repo lite
[ "$(git rev-parse --show-toplevel)" != /home/admin/Documents/workstation/personal/jit-speckit ] || exit 1
ln -s "$1/extension/scaffold" .specify/extensions/jit/scaffold 2>/dev/null || true
printf '{"name":"x","version":"1.0.0"}\n' > package.json; printf '{"lockfileVersion":3}\n' > package-lock.json
L="$SCRIPTS/level.sh"; files() { git ls-files --others --cached --exclude-standard | grep -vE '^(package|specs/)' | sort; }
echo "== A. up lite -> standard -> full, then down to lite: files before and after going down"
bash "$L" lite --no-branches >/dev/null; bash "$L" standard --no-branches >/dev/null; bash "$L" full --no-branches >/dev/null
files > "$TMP/at-full"; bash "$L" lite --no-branches >/dev/null; files > "$TMP/at-lite"
echo "files at full: $(wc -l < "$TMP/at-full"), after going down to lite: $(wc -l < "$TMP/at-lite"), deleted: $(comm -23 "$TMP/at-full" "$TMP/at-lite" | wc -l)"
git add -A >/dev/null; git commit -q -m "setup at full"
echo "== B. a managed file the user edited, keeping the marker line"
echo "# my own step" >> .github/workflows/ci.yml; git commit -q -am "my edit"
bash "$L" standard --no-branches | grep ci.yml || true; echo "my line still there: $(grep -c 'my own step' .github/workflows/ci.yml)"
echo "== C. remove, with an uncommitted edit in a managed file (marker kept), and a file taken over (marker deleted)"
git checkout -q -- .github/workflows/ci.yml; echo "# uncommitted step" >> .github/workflows/ci.yml
sed -i '1d' .github/workflows/security.yml; echo "# mine now" >> .github/workflows/security.yml
bash "$1/bin/remove.sh" . 2>&1 | grep -E 'ci.yml|security.yml' || true
echo "ci.yml exists: $([ -f .github/workflows/ci.yml ] && echo yes || echo no); security.yml (taken over) exists: $([ -f .github/workflows/security.yml ] && echo yes || echo no)"
echo "the uncommitted line anywhere in git: $(git grep -c 'uncommitted step' $(git rev-list --all) -- .github 2>/dev/null | wc -l); in the stash: $(git stash list | wc -l)"
```

```text
== A. up lite -> standard -> full, then down to lite: files before and after going down
files at full: 13, after going down to lite: 13, deleted: 0
== B. a managed file the user edited, keeping the marker line
updated: .github/workflows/ci.yml
my line still there: 0
== C. remove, with an uncommitted edit in a managed file (marker kept), and a file taken over (marker deleted)
removed: .github/workflows/ci.yml
ci.yml exists: no; security.yml (taken over) exists: yes
the uncommitted line anywhere in git: 0; in the stash: 0
```

</details>

<details>
<summary>Upgrade from v1.3.0 to v1.7.2 (F5.3) and its output</summary>

```bash
# T005 upgrade path: set up with v1.3.0, refresh with v1.7.2. Run as: bash t005-upgrade.sh <v1.3.0 worktree> <v1.7.2 worktree>
set -u
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
git init -q --bare "$T/origin.git"; git clone -q "$T/origin.git" "$T/repo" 2>/dev/null; cd "$T/repo"
[ "$(git rev-parse --show-toplevel)" != /home/admin/Documents/workstation/personal/jit-speckit ] || exit 1
git config user.email t@t; git config user.name t; git config commit.gpgsign false
printf '{"name":"x","version":"1.0.0"}\n' > package.json; printf '{"lockfileVersion":3}\n' > package-lock.json
git add package.json package-lock.json; git commit -q -m init; git branch -M main; git push -q origin main
echo "== v1.3.0 setup"; bash "$1/bin/setup.sh" . --level standard --no-branches > "$T/old.log" 2>&1; echo "rc=$?"; tail -3 "$T/old.log"
git add -A >/dev/null 2>&1; git commit -q -m "jit 1.3.0" || true
echo "== v1.7.2 setup (the refresh /jit-speckit:init runs)"; bash "$2/bin/setup.sh" . --level standard --no-branches > "$T/new.log" 2>&1; echo "rc=$?"
grep -E '^kept' "$T/new.log"
for h in .githooks/pre-commit .githooks/pre-push; do echo "--- $h"; cat "$h"; done
```

```text
== v1.3.0 setup
rc=0
  existing code?  /jit-speckit:adopt      (fills the constitution from this repo)
  new project?    /speckit-constitution   (fills the [PLACEHOLDERS])
  then per feature: /speckit-specify → /speckit-plan → /speckit-tasks → /speckit-implement T001
== v1.7.2 setup (the refresh /jit-speckit:init runs)
rc=0
kept:    .claude/settings.json
kept:    .githooks/pre-commit
kept:    .githooks/pre-push
kept:    .github/pull_request_template.md
kept:    .github/workflows/close-linked-issues.yml
kept:    .github/workflows/ci.yml .github/workflows/close-linked-issues.yml .github/workflows/security.yml (already checks pull requests; no ci.yml generated)
kept:    .github/workflows/security.yml
kept:    .github/dependabot.yml
--- .githooks/pre-commit
#!/usr/bin/env bash
# jit-speckit: refuse commits that carry secrets (.env files, keys, tokens). Fast, local.
# Enabled per clone with: git config core.hooksPath .githooks   (/jit-speckit:init does it)
s=.specify/extensions/jit/scripts/secrets.sh
[ -f "$s" ] || { echo "jit: $s missing; secret check skipped (CI still checks)" >&2; exit 0; }
exec bash "$s" staged
--- .githooks/pre-push
#!/usr/bin/env bash
# jit-speckit: before anything leaves this machine, re-check every pushed commit for secrets
# (this also catches commits made with --no-verify), and keep base branches PR-only.
set -euo pipefail
s=.specify/extensions/jit/scripts/prepush.sh
[ -f "$s" ] || { echo "jit: $s missing; push check skipped (CI still checks)" >&2; exit 0; }
exec bash "$s" "$@"
```

</details>

<details>
<summary>Downgrade by an older plugin copy (F5.4) and its output</summary>

```bash
# T005: a stale session runs an older plugin's setup on a project already at 1.7.2. Run as: bash t005-downgrade.sh <v1.3.0 worktree> <v1.7.2 worktree>
set -u
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
git init -q --bare "$T/origin.git"; git clone -q "$T/origin.git" "$T/repo" 2>/dev/null; cd "$T/repo"
[ "$(git rev-parse --show-toplevel)" != /home/admin/Documents/workstation/personal/jit-speckit ] || exit 1
git config user.email t@t; git config user.name t; git config commit.gpgsign false
echo x > README.md; git add README.md; git commit -q -m init; git branch -M main; git push -q origin main
bash "$2/bin/setup.sh" . --level lite --no-branches >/dev/null 2>&1; echo "after 1.7.2 setup: $(grep -E '^ +version:' .specify/extensions/jit/extension.yml | head -1)"
bash "$1/bin/setup.sh" . --level lite --no-branches > "$T/old.log" 2>&1; echo "older setup rc=$?"
echo "after the older setup: $(grep -E '^ +version:' .specify/extensions/jit/extension.yml | head -1)"
echo "lines mentioning downgrad|older|newer:"; grep -iE "downgrad|older|newer" "$T/old.log" || echo "(none)"
echo "review gate after the older setup: review.sh $([ -f .specify/extensions/jit/scripts/review.sh ] && echo present || echo missing); speckit-jit-review skill $([ -d .claude/skills/speckit-jit-review ] && echo present || echo missing)"
```

```text
after 1.7.2 setup:   version: "1.7.2"
older setup rc=0
after the older setup:   version: "1.3.0"
lines mentioning downgrad|older|newer:
  new project?    /speckit-constitution   (fills the [PLACEHOLDERS])
review gate after the older setup: review.sh missing; speckit-jit-review skill missing
```

</details>
