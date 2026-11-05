Reviewed at: 172f8c5 (v1.7.2)
Constitution at: 5a06ee8a2be14c56676e5edc926d83de42826c53

## 6. The project against its own rules, and cost per level

The rules are the constitution on `main` once the 1.7.2 setup PR #18 merged (its merge commit,
`gh pr view 18 --json mergeCommit -q .mergeCommit.oid`). How the project follows them is read at
`v1.7.2` (`172f8c5`), in its own worktree, and in the merged PRs' bodies (`gh pr view`).

### Rules

| rule | status | evidence |
|---|---|---|
| "Project": never commit or push outside the documented flows; never overwrite a file the user edited; never open a PR on red checks; never put a secret, an AI attribution line or a security finding in a public place | exception missing | the parts are judged as promises in sections 1–5: P23 holds; P19/P20 (F5.1–F5.3) and P12 (F3.3) do not; P25 (F4.2, F4.3) does not; AI attribution: see the "No AI attribution" row |
| "Stack": bash 3.2 with BSD or busybox tools and bash 5; "CI runs both (`test.yml`, jobs `linux` and `bash32`)" | followed | `test.yml` has jobs `linux`, `bash32` and `macos`; `linux` and `bash32` run on every push and PR. The macOS (BSD tools) job runs only weekly or by hand, which the constitution does not claim; section 5, F5.6 |
| "Stack": "the plugin needs Claude Code 2.1.275 or newer" | exception missing | `hooks/hooks.json` uses `onFailure: "block"`, which Claude Code's hooks reference says "Requires Claude Code v2.1.295 or later" (section 2, F2.4). Between 2.1.275 and 2.1.295 the guard fails open on a timeout or crash; the constitution and `README.md:44` still say 2.1.275 |
| "Stack": the version in `.claude-plugin/plugin.json`, `extension/extension.yml` and `preset/preset.yml`, "the three are bumped together"; releases are tags on `main` | followed | all three say `1.7.2` at `v1.7.2` (`marketplace.json` carries no version); the tag is on `main` (`git branch -r --contains v1.7.2` → `origin/main`) |
| "Stack": every action pinned to a SHA, listed once in `pins.sh` | followed | section 4, P17: every `uses:` in the generated and scaffold workflows comes from `pins.sh`, and every pin resolves upstream; Dependabot coverage is F4.1 |
| **bash 3.2 is the floor** (no associative arrays, `${var,,}`, `mapfile`, `patsub_replacement`) | followed | `grep -nE 'declare -A\|local -A\|\$\{[a-zA-Z_]+,,\|\$\{[a-zA-Z_]+\^\^\|mapfile\|readarray'` over `extension/scripts`, `bin`, `hooks`, `tests` finds nothing; `level.sh:12` turns `patsub_replacement` off; the `bash32` job runs the suite on bash 3.2 on every PR |
| **One shared library**: every script sources `lib.sh` and starts with `jit_cd_root` | exception written | every `extension/scripts/*.sh` but `pins.sh` (a data file `level.sh` sources) does both; `bin/setup.sh`, `bin/remove.sh` and `bin/sync-pins.sh` do neither, by design: they run from the plugin, outside a project's `.specify/`, and the rule names `extension/scripts/lib.sh`. The exception is implied by where `lib.sh` lives, not written down |
| **Nothing of the user's is overwritten**; `bin/remove.sh` deletes only what still matches what jit wrote | exception missing | section 5: an edit inside a marked file is replaced (F5.1), `remove` deletes a marked file with uncommitted edits (F5.2, High), and files from before 1.4.0 are never refreshed (F5.3) |
| **Scripts refuse, prompts explain** | exception missing | followed where a script exists (`branch.sh`, `pr.sh`, `issues.sh`, `review.sh` each `die` with what to run); but several promised gates have no script at all, only a prompt: red checks, mutation testing, the pre-PR scanners and `/security-review` (section 3, F3.3, F3.4, F3.6) |
| **Tests are bash and prove themselves**: one `tests/<script>.test.sh` per script, through `tests/helpers.sh` | exception missing | no file of its own for `analyzed`, `detect-stack`, `prepush`, `remove`, `sync-pins` or `hooks/guard-git` (`ls tests/`); all but `detect-stack` are exercised inside other files (`branch`, `secrets`, `setup`, `static`, `guard`). `grep -l detect-stack tests/*.test.sh` finds nothing: `detect-stack.sh`, which shapes the generated CI, has no test |
| **No mutation tool for bash: a new behavior ships with a check that was seen to fail when the behavior is disabled, and the PR says so** | exception missing | the exception (no tool) is written; its replacement rule is not followed: the bodies of the feature PRs after the rule existed, #15 and #17, have no line saying a check was seen to fail (`gh pr view <n> --json body`, searched for "seen to fail", "fail when", "disabled": no match). The constitution's `mutate` is still `[MUTATE_COMMAND]`, so `mutants.sh` says `missing` on every PR (this feature's own PRs #29–#33 say so in *Evidence*) |
| **Pins and versions agree in one place**; `tests/static.test.sh` fails on any drift | followed | the action-pin check (`static.test.sh:18-25`) and the spec-kit version check both exist; on a copy of `v1.7.2` with the README badge changed to `v9.9.9`, `static.test.sh` printed `FAIL - the spec-kit version in setup.sh (v1.2.5) matches the init skill and the README badge`, and passed again once restored |
| **Docs are the product's source of truth**: a behavior change edits the doc in the same PR | exception missing | #15 (init offers to commit) changed 1 doc file of 9, but the README still says `init` "commits nothing" (section 5, F5.5); several docs present prompt-only steps as gates (F3.1, F3.6, F3.8) |
| **No AI attribution** in commits and PR bodies | exception missing | `.claude/settings.json` empties it, and #13–#17 carry none; but 8 commits on `main`, all from 2026-11-04 (before the constitution was ratified on 2026-11-05), end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`: `252a93c`, `c2f6a35`, `5bb041e`, `5bd0eb8`, `e9b0d8c`, `edcce1b`, `609eb6d`, `c3fca22` (`git log v1.7.2 -i --grep='co-authored-by: claude'`). They are public history; no exception is written |
| jit block, **Way of working**: one task = one issue = one branch = one PR; features go through specs and tasks | exception missing | at `v1.7.2` the repository has no `specs/` folder; the feature PRs #15 and #17 (after jit was set up here in #13) have no spec, no issue and no `Closes #N`. This feature (001) is the first that follows the rule |
| jit block, **Before a PR opens, a fresh reader reviews it** … "No task PR opens without it" | followed | true of every task PR so far (#29–#33, each with a recorded `ready`), and #15 and #17 were not task PRs; but see F3.1 for what the record proves |
| jit block, **Tests**: every piece of logic has a test | exception missing | `detect-stack.sh` (see the tests row) |
| **The lag**: at `v1.7.2` the repo's own installed extension and constitution were 1.7.1's | exception missing | `git show v1.7.2:.specify/extensions/jit/extension.yml` → `version: "1.7.1"`: the release that made the review a gate at every level shipped while the repository itself ran the previous version, until PR #18 (this session, 2026-11-05). Nothing says the repository runs the release it ships |

### Cost per level, per task

The steps and waits one task goes through, from `extension/commands/{branch,pr,review}.md`,
`extension/levels/*.md` and the scripts, with times measured on this feature's own tasks
(T001–T005, PRs #29–#33, 2026-11-05; reviewer times are what Claude Code reported when each
reviewer finished).

| step | lite | standard | full |
|---|---|---|---|
| issue (created with the plan) | yes | yes | yes |
| spec PR merged before the first task | yes (asks first) | yes | yes, after `/speckit-analyze` |
| branch from the base, pushed as a claim | yes | yes | yes, refused until the analysis marker matches |
| implement, then the checks (test, lint, build) | yes | yes | yes |
| mutation testing on the change | asked | asked | asked |
| commit, scanners, `/security-review` | asked | asked | asked |
| independent review until `ready` (recorded, required) | yes, after a yes to "Review and open the PR now?" | yes | yes |
| PR with `## Review` | yes | yes | yes, plus `## Evidence` |
| CI on the PR | none (lite writes no workflows) | CI and the security gate | CI, the security gate with Semgrep |
| merge | the user | the user, after required checks (if `init` set protection) | the same, with 1 approval |

Measured on T001–T005 (each a Markdown section, a few hundred lines):

| task | review rounds | reviewer time | note |
|---|---|---|---|
| T001 | 3 full | 212 + 288 + 297 s = 13.3 min | |
| T002 | 2 full | 180 + 193 s = 6.2 min | |
| T003 | 5 full + 2 delta | 308 + 342 + 240 + 182 + 277 + 52 + 53 s = 24.2 min | 4 rounds past the limit of 3, approved by the user |
| T004 | 1 full + 1 delta | 276 + 82 s = 6.0 min | |
| T005 | 1 full + 1 delta | 271 + 78 s = 5.8 min | |

Before any task, the plan review took 10 rounds, 2,179 s (36 min) and 189 tool calls (feature
002's baseline). A full round took 180–342 s; a delta round on the last fix commit, 52–82 s, and
each delta round still found what it was asked to check (T003 round 6 caught a wrong regex).

**Disproportionate for its level's audience:**
- **lite** ("prototypes, solo work", `README.md:121`): the independent review is required on every
  PR, at 3–6 minutes a full round, up to 24 minutes on one task here, with no CI behind it (lite
  writes no workflows) and no one else to merge. For a prototype the review is the most expensive
  step, and the plan review before any code is more expensive still (36 minutes here). Each round
  runs again from zero, which is what feature 002 targets: here delta rounds cut a round from ~4.5
  to ~1.1 minutes with the same catch rate on the fixes.
- **lite**: two questions per feature that a solo user always answers yes ("Open the spec PR now?",
  then "Review and open the PR now?" on every task), plus a spec PR to merge before anything starts.
- **standard and full**: the spec PR and one PR per task land on `develop` one by one; a feature
  reaches `main` only through the release PR. Proportionate for a team. The user proposed on
  2026-11-05 to gather the task PRs on a feature branch and send the feature to the base as one PR
  (feature 004); that and the spec PR are weighed in section 7.
- **all levels**: mutation testing, the scanners and `/security-review` are asked, not checked
  (section 3), so their cost is paid only when the agent follows the prompt, and nothing shows when
  it does not.
