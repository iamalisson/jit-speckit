# Research: Fix what the critical-points review found (release 1.8.0)

Phase 0 for [plan.md](plan.md). Nine researchers took one open question each (2026-11-05), reading
the repository at `main` (`a8fd384`) and primary sources only. A completeness critic then checked
their answers against [spec.md](spec.md), feature 001's `report.md` and the repository. Every
decision below names its source. Anything not confirmed is listed under **Unverified**, with what
would confirm it. Each fix's detail stays in its entry in
[`../001-critical-points-review/report.md`](../001-critical-points-review/report.md) *Fixes*; the
decisions here say how to build it and correct the entry where the research proved it wrong (C1).

## Decisions taken with the user (2026-11-05)

- **U1, merges (#41, FR-021).** Turning off merge commits on standard and full would also squash the
  promotion PRs (`develop → main`, `README.md:122`). `main` would then carry commits `develop` never
  has, and later promotions would conflict. Decision: every level offers to turn off **rebase**
  merges (a task never becomes several commits); lite also turns off merge commits (squash only);
  standard and full keep merge commits for promotions, and their docs say task PRs are squashed.
- **U2, Semgrep (F4.5, FR-027).** The Semgrep Rules License forbids redistributing the registry
  rules, so "rules kept in the extension" cannot be done. Decision: run Semgrep from its official
  image pinned by sha256 digest (the tool is checksum-verified), keep `p/default` and
  `p/owasp-top-ten`, and have the README and security doc say the rules come from the registry at
  run time.
- **U3, constitution (F2.4, FR-011).** The constitution's amendment rule (its own PR, semantic
  versioning) wins over FR-023's "same PR". A `/speckit-constitution` PR bumps it to 1.0.1 with the
  new minimum first; the F2.4 task changes the README and `docs/security.md`.

## R1 · `next` by issue number, and on a task branch (F1.2, F1.9)

- **Decision (F1.2).** In `next.sh` `scan()`, replace `gh issue list --search "$num in:title"` with
  one `gh api graphql` call per feature that asks every issue number linked in that feature's
  `tasks.md` (aliases `i11: issue(number: 11) { number state }`). `--jq` prints the numbers whose
  state is `CLOSED`, so the space-joined `closed` set and the lines that use it do not change. No
  call when no task has an issue (an empty `repository { }` is invalid). A failed call dies with
  gh's message, which names the bad number. Comment: `shortcut: one query per feature, fine for
  hundreds of tasks; split into batches of ~100 if a feature ever nears GitHub's 10 s timeout`.
- **Decision (F1.9).** Move `feature_dir`'s branch parsing into a new `lib.sh` function
  `branch_feature()` (prints the folder for a `<prefix>/NNN-tNNN-…` branch with exactly one match,
  else nothing). `feature_dir` calls it first, so its behavior is unchanged. `next.sh` with no
  argument uses it before the `CHOOSE` scan; an explicit argument still wins; it writes no
  `.specify/feature.json` (the branch decides on every call).
- **Rationale.** `repository { issue(number:) }` reads by number, so titles and list limits stop
  mattering. Aliases repeat a field in one query (checked live on `cli/cli`, read-only). `{owner}`
  and `{repo}` in `-F` values are filled like `gh issue list` does (`gh api --help`, gh 2.102.1).
  `--jq` is built into gh, already used by `next.sh`. With GraphQL `errors`, gh skips `--jq`,
  prints `gh: <message>` and exits non-zero (gh source, `pkg/cmd/api/api.go`, confirmed live).
  Limits: 500,000 nodes, 10 s, 5,000 points per hour
  ([rate limits](https://docs.github.com/en/graphql/overview/rate-limits-and-query-limits-for-the-graphql-api)).
- **Alternatives.** One `gh issue view` per task (N calls); `gh issue list --state closed` without
  search (only moves the limit); REST per number (N calls); duplicating the branch regex in
  `next.sh` (two copies of one rule).
- **Test.** The fake `gh` gets an `api graphql` case answering only the numbers in `$GH_CLOSED` that
  the query asks for, plus a `GH_FAIL_GRAPHQL` mode. The `issue list` case stays (F1.7 and
  `check-tools.sh` use it). F1.2: when a closed task issue is not found by title search, then
  `next` shows it done, and `GH_LOG` has no `--search`. F1.9: when the current branch is a task
  branch of one feature and another feature also has tasks to start, then `next` prints that
  feature's tasks and no `CHOOSE=`. The fake cannot model titles, so one sandbox run (renamed
  closed issue) confirms F1.2 end to end.
- **Unverified.** Point cost of many aliases (add `rateLimit { cost }` on a repo with ~100 tasks);
  placeholder filling in a clone with several remotes; how a transferred issue answers.

## R2 · Copilot review line (F3.5)

- **Decision.** Keep the request (`POST …/pulls/N/requested_reviewers` with
  `reviewers[]=copilot-pull-request-reviewer[bot]`, which GitHub documents). Decide the line from
  the answer: `--jq '.requested_reviewers[].login'`, case-insensitive match on `copilot` →
  `copilot: code review requested`; anything else (empty list, 422, 403, network) →
  `copilot: not requested (GitHub did not add the reviewer)`. Delete the stale 422 comment at
  `pr.sh:26-27`.
- **Rationale.** GitHub's Copilot docs: "request a review from Copilot through the GitHub REST API
  by requesting copilot-pull-request-reviewer[bot]"
  ([use code review](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/request-a-code-review/use-code-review)).
  The review-requests REST page documents 201 with `requested_reviewers`
  ([review requests](https://docs.github.com/en/rest/pulls/review-requests)). No dedicated Copilot
  endpoint is published. The sandbox saw 201 with `[]` (001 F3.5).
- **Test.** Fake `gh`: an `api -X` case that prints `$GH_REVIEWERS` (what `--jq` would return).
  When the answer lists no reviewer, then the output says `copilot: not requested` and not
  `code review requested` (fails today); when it lists `Copilot`, then it says
  `code review requested` (guards against a mutant that always says "not requested").
- **Unverified.** Which login GitHub returns in `requested_reviewers` for the bot, and whether
  Copilot stays there or shows up only as a review event: one call on an account with Copilot code
  review settles both. If it does not stay, the signal moves to the PR timeline.

## R3 · Semgrep (F4.5) — with U2

- **Decision.** `pins.sh` keeps `SEMGREP_VERSION` and adds `SEMGREP_DIGEST` (the OCI index digest of
  `semgrep/semgrep:<version>`, all architectures), with "bump both together" and how to read the
  digest. `level.sh` writes the full-level `code` job with
  `container: image: semgrep/semgrep@sha256:$SEMGREP_DIGEST # $SEMGREP_VERSION` and
  `semgrep scan --config p/default --config p/owasp-top-ten --error --metrics off`, dropping the
  `uvx --from semgrep==…` step (`PIN_SETUP_UV` stays for the Python CI job). README row 109,
  `docs/security.md:31` and the `security.yml` header say the rule sets come from the Semgrep
  registry at run time.
- **Rationale.** An image addressed by digest is verified by content when pulled, covering Semgrep,
  its Python dependencies and `semgrep-core` together. Semgrep's own GitHub Actions sample uses the
  `semgrep/semgrep` image ([sample CI configs](https://semgrep.dev/docs/semgrep-ci/sample-ci-configs)).
  Hash-pinning the PyPI install needs a 66-package, per-platform requirements file (measured with
  `uv pip compile --generate-hashes`), far heavier than one digest. The Rules License forbids
  redistribution (U2).
- **Alternatives.** `--require-hashes` requirements file (heavy, per platform); a pinned
  `semgrep-rules` commit (changes what is scanned); README fix only (leaves the tool unverified).
- **Test.** `tests/level.test.sh` (replaces the check at `:104`): when `level.sh full` writes
  `security.yml`, then its Semgrep job runs `semgrep/semgrep@sha256:<64 hex>` equal to
  `SEMGREP_DIGEST` and nothing installs Semgrep by version alone. `tests/static.test.sh`: when the
  README CI row and `docs/security.md` are read, then they say the rules come from the Semgrep
  registry. Both fail today.
- **Unverified.** That the image runs `semgrep --version` = the pinned version and that checkout
  v7.0.1 works inside it (one full-level run on the sandbox); whether Dependabot bumps a
  `container.image` digest (likely not: R8's weekly tool check covers it).

## R4 · macOS CI (F5.6)

- **Decision.** Move the `macos` job from `test.yml` into a new `.github/workflows/macos.yml` with
  `on: pull_request: paths: ["extension/scripts/**", "bin/**", "hooks/**", "tests/**",
  ".github/workflows/macos.yml"]`, `push: tags: ["**"]`, the weekly `schedule` and
  `workflow_dispatch`, `permissions: contents: read`. The job body moves unchanged. `test.yml` loses
  the job and its `schedule`. Docs that say "macOS weekly" say "on script PRs and on tags".
- **Rationale.** Path filters are per workflow
  ([workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax));
  no third-party action is needed (constitution: no new dependency). A path-skipped workflow stays
  Pending if it is ever made a required check
  ([troubleshooting required checks](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks));
  it is not required today (`main` is not protected). `tests/**` is added beyond the fix entry: the
  suite is what runs on macOS.
- **Test.** `tests/static.test.sh`: when `macos.yml` is read, then it runs on pull requests touching
  `extension/scripts/`, `bin/` or `hooks/`, and on every tag; and `test.yml` has no `runs-on:
  macos`. Each condition on its own line in `check` (an `&&` chain or loop hides a failing grep:
  measured). Fails today (no file). The fix entry's target (`test.yml`) is corrected (C1).
- **Unverified.** That `**` in `push.tags` matches every tag, and zizmor's verdict on the new file.

## R5 · Guard (F2.3) — classes only

- **Decision (a).** One rule in `guard.sh`: a word that is a prefix of `--no-verify`, at least 3
  characters long, is refused for `commit`, `push`, `merge`, `rebase` and `am` (git accepts a unique
  prefix and rejects ambiguous ones, so refusing every prefix costs nothing). `cherry-pick` and
  `revert` take no `--no-verify` and keep their exact-word check. Messages do not change.
- **Decision (b).** Replace the one branch read before the chain with a list that only grows: a
  `switch|checkout` in the chain adds the branch it switches to (or creates), and later commits and
  `HEAD` pushes are judged against every branch in the list. `checkout -- <path>` and
  `checkout <tree-ish> -- <paths>` restore files and add nothing. When the guard cannot tell what a
  word is, it adds it: a false refusal, never a pass.
- **Rationale.** `man gitcli` "Abbreviating long options"; `parse-options.c` `parse_long_opt`;
  `git <cmd> --help-all` (git 2.56.0); `man git-checkout` ARGUMENT DISAMBIGUATION.
- **Test.** `tests/guard.test.sh`: prefixes of `--no-verify` from length 3 to 10, cut at run time,
  are blocked for the five subcommands; `--verify`, `--no-edit`, `--no-ff`, `--no-stat`,
  `--no-tags` and a message that looks like a prefix are allowed; `git <cmd> -h` agrees on which
  subcommands take it; a switch to `main` then a commit or `HEAD` push in one chain is blocked;
  `checkout main -- README.md && commit` and `switch -c <task> main && commit` are allowed. Both
  halves fail today.
- **Also found, same class.** `git am -n` is `--no-verify`; the guard refuses `-n` only for commit.
  It goes in the same task. Branch changes through `rebase <up> <branch>`, `worktree` and others
  stay untracked; `docs/security.md` keeps calling the guard best effort.
- **Unverified.** The shortest prefix git actually accepts per subcommand (the design does not
  depend on it).

## R6 · GitHub settings in `init` (#41, F4.4) — with U1

- **Decision.** Split `skills/init/SKILL.md` step 4 into two steps and renumber the rest:
  - **4. GitHub settings (every level).** Read visibility (`gh repo view --json visibility`).
    Offer: rebase merges off on every level, and on lite merge commits off too
    (`gh api -X PATCH repos/{owner}/{repo} -F allow_rebase_merge=false` plus, on lite,
    `-F allow_merge_commit=false -F allow_squash_merge=true -f squash_merge_commit_title=PR_TITLE
    -f squash_merge_commit_message=PR_BODY`). Only on a public repo: secret scanning with push
    protection (`security_and_analysis` PATCH, arguments quoted for zsh) and private vulnerability
    reporting (`PUT …/private-vulnerability-reporting`). On a private or internal repo, one line
    says these need GitHub Secret Protection or are for public repos.
  - **5. Branch protection (standard and full).** Today's bullet, unchanged.
  - Docs: README CI row gets "(standard and full)"; `docs/security.md` "On GitHub" row lists what is
    offered on which level, and a sentence says lite has no CI gate; `docs/design.md` says the
    one-revert promise relies on one commit per task PR.
- **Rationale.** [Update a repository](https://docs.github.com/en/rest/repos/repos#update-a-repository)
  (merge fields and allowed values); secret scanning is free on public repositories
  ([about secret scanning](https://docs.github.com/en/code-security/secret-scanning/introduction/about-secret-scanning));
  [private vulnerability reporting](https://docs.github.com/en/rest/repos/repos#enable-private-vulnerability-reporting-for-a-repository).
- **Test.** `tests/static.test.sh`, plain text reads (init's calls are made by the model, so no
  script can drive them; said, not faked): the every-level step offers `allow_rebase_merge=false`,
  and on lite `allow_merge_commit=false`, and does not say "(standard and full)"; it offers push
  protection and private reporting for `PUBLIC`; the design doc's revert sentence names one commit
  per task PR; the README CI row names its levels; the security doc says lite has no CI gate.
- **Unverified.** Private vulnerability reporting on a private repo (422 or not); the push
  protection PATCH on a public user repo; no plan restriction on merge settings.

## R7 · Minimum version (F2.4) and advisory body (F4.2) — with U3

- **Decision (F2.4).** The hooks reference says `onFailure` "Requires Claude Code v2.1.295 or
  later" ([hooks](https://code.claude.com/docs/en/hooks)); 2.1.275 is the minimum of the one-line
  `/plugin install … --marketplace` command
  ([discover plugins](https://code.claude.com/docs/en/discover-plugins)). Only two places state a
  minimum: `README.md:44` and constitution line 19. After U3's constitution PR, the task changes
  `README.md:44` to "Needs Claude Code 2.1.295 or newer: from that version the command guard blocks
  a command when it times out or crashes", dropping the two-prompt fallback (every supported
  version already has the one-line command), and adds to `docs/security.md`'s guard row (line 28)
  "on Claude Code 2.1.295 or newer it also blocks when the guard times out or crashes".
- **Decision (F4.2).** `skills/security/SKILL.md`'s public-repository bullet first lists advisories
  (`gh api --paginate "repos/{owner}/{repo}/security-advisories?per_page=100" --jq …`), reuses one
  with the same summary (prints its link and stops), else sends the JSON body with `--input -`:
  `summary`, `description`, `severity`, `vulnerabilities[].package.ecosystem` (`other` when no
  registry fits) ([create an advisory](https://docs.github.com/en/rest/security-advisories/repository-advisories#create-a-repository-security-advisory)).
- **Test.** `tests/static.test.sh`. F2.4: when `hooks.json` uses `onFailure`, then every "Claude
  Code X or newer/later" in `README.md`, `docs/*.md` and the constitution is 2.1.295 or newer (at
  least one exists, compared with `IFS=. read`, no `sort -V`), and the README says nothing about
  "older versions". F4.2: the body between the `--input -` line and `EOF` names the five keys, and
  the `--paginate` lookup comes before the `-X POST`. The fix entry's file-wide grep already passes
  today, so it is scoped to the call (C1). Both fail today.
- **Unverified.** Whether `severity` is strictly required (the docs say "choose between" severity
  and a CVSS vector; 001's R6 needed one): a POST without it on a throwaway public repo.

## R8 · Pins (F4.1, F4.7) and old files (F5.3)

- **F4.1.** Add `.github/workflows/pins.yml`: an `actions` job with `if: false` and one step per
  `PIN_*` action as `pins.sh` writes it (Dependabot reads `uses:` under `jobs`, ignoring `if` and
  `on`: `dependabot-core` `uses_collector.rb`), and a weekly `tools` job running a new
  `bin/check-tools.sh`. That script compares `GITLEAKS_VERSION`, `OSV_VERSION`, `SEMGREP_VERSION`
  (and reminds that `SEMGREP_DIGEST` moves with it), `TRIVY_VERSION` with
  `gh api repos/<repo>/releases/latest`, opens one "Tool pins behind" issue when any is behind and
  none is open, and prints `BEHIND=<n>`. `bin/sync-pins.sh` needs no change (it reads every
  workflow; the Dependabot group moves all files together).
- **F4.7.** `level.sh` `put()`, when rewriting a managed file, passes the new content through
  `keep_pins`: a new `uses: <action>@<sha> # <version>` line keeps the old file's pin for the same
  action when `version_newer old new`, and prints `kept newer pin: <action> <version>` once per
  action. `version_newer` is pure bash in `lib.sh` (strip `v`, compare dotted numbers with `10#`;
  anything else is never newer), replacing the entry's `sort -V`, which BSD and busybox may lack
  (C1). A `container.image` digest is not a `uses:` line and is not kept: said in the docs.
- **F5.3.** Releases before the marker (1.0.0, 1.2.0, 1.3.0, 1.3.1) copied scaffold files byte for
  byte and generated the workflows from the project. A data file
  `extension/scripts/old-files.sha256` lists `<sha256> <path> <versions> <replace|name>` for the
  four scaffold files that carry the marker today. The two hooks are `replace` (no current file
  collides). `close-linked-issues.yml` and `release.yml` are `name` only: their 1.4.0+ versions
  with the marker deleted (the documented take-over) are byte-identical to the old hashes, so
  replacing them would undo a take-over. Generated files get only the message
  `kept (written by landspec <versions> or older, no marker): <file> — delete it to get the
  current one`, and only when an old hook matched. `sha256()` in `lib.sh` already picks
  `sha256sum` or `shasum -a 256`.
- **Test.** F4.1 (`static.test.sh`): when `pins.sh` has a `PIN_*` action, then some workflow uses
  it (fails today for 7); `check-tools.sh` with the fake `gh` (an `api repos/*` case printing
  `$GH_API`): a newer release prints `BEHIND=4` and creates one issue, equal versions create none,
  an open issue prevents a second. F4.7 (`level.test.sh`): a newer checkout pin is kept and named,
  an older one is replaced. F5.3 (`level.test.sh`, not `setup.test.sh`, which skips without the
  `specify` CLI; with a committed fixture under `tests/fixtures/`, since CI's checkout has no tags):
  when `.githooks/pre-commit` is v1.3.0's exact file, then it is replaced and marked; when
  `close-linked-issues.yml` is v1.3.1's, then it is kept and named. The entry's target is
  corrected (C1).
- **Unverified.** `version_newer` and `keep_pins` on bash 3.2 (the `bash32` and macOS jobs run
  them); Dependabot's real run on an `if: false` job.

## R9 · Gates and the task chain (F3.x, F5.2, F5.4, F1.1, F1.6, F1.7, F1.8)

- **Shared first.** `lib.sh` gets `diff_id()` (the patch-id body of `review.sh` `state()`, `:25-30`, moved) and
  `diff_record DIR` (`<git-common-dir>/DIR/<id or "empty">`); `review.sh`'s task state calls it. One
  key for review, mutation and scan records.
- **F3.3.** `pr.sh task`, after the cheap refusals and before the push: with a test command
  (`constitution_cmd test`), run it, log to `<git-common-dir>/landspec-test/<branch>.log` (one per branch: plan review), and on failure print
  its last 20 lines and die `the test command failed (<cmd>); fix it before opening the PR`; with
  none, say `tests not run before the PR (no test command in the constitution)` and go on.
  `constitution_cmd` treats a `[PLACEHOLDER]` value as unset (this repo's `mutate`).
- **F3.4.** `mutants.sh` also writes its result line to `diff_record landspec-mutants`. `pr.sh task`,
  only when a mutate command is set, dies without a record for this diff (`no mutants.sh result for
  this diff; run …`) or on `survivors` with no `## Evidence` line mentioning a survivor. With no
  mutate command it appends "Mutation testing: not run (no mutate command in the constitution)".
- **F3.6.** `security-scan.sh --changed` copies its summary lines to `diff_record landspec-security` on
  both exits. `pr.sh task` dies without one (`no security-scan.sh --changed result for this diff;
  run …`); `missing` or findings do not refuse. Tests run it with a `PATH` holding no scanners, so
  the suite needs no network (critic A7). It also scans uncommitted files, so it runs after the last
  commit (said in `pr.md`).
- **F3.1 + F4.3 (one task).** `review.sh` gets a `report` action (the checks of `check`, then the
  record's patch-id fact and `Assessment:` line only; superseded on 2026-11-06 by the user: no
  reviewer prose at all, since filtering findings out of prose cannot be made leak-proof). `pr.sh` puts those in the body
  as `<details><summary>Independent review</summary>`. The script never copies findings, so a report
  that puts a security finding's detail anywhere cannot reach the public body through it (plan
  review, 2026-11-05); findings reach the PR only through the agent's `## Review`. `review.md`'s
  Report section: each security finding is one such line, listed last. `pr.md` step 5: one line in
  `## Review`. `docs/design.md`: what the gate proves.
- **F3.7.** `review.sh:45`: `$($plan && echo ' --plan')`.
- **F3.8.** `analyzed.sh <report-file>`: refuses without a file, or a file lacking
  `## Specification Analysis Report` and `Coverage Summary Table`; writes the marker as today and
  keeps the report next to it. `analyzed.sh` is reached only on full (FR-008 holds).
- **F3.9.** `lib.sh` `TEST_PATH_RE` becomes the pattern in 001 F3.9 (tested there); a new
  `test_path_re()` adds the constitution's `tests: <regex>` and dies on an invalid one; `pr.sh` and
  `mutants.sh` use it.
- **F5.2.** `put()` records the SHA-256 of every file it writes in `.specify/landspec-files.sha256`
  (`<sha256> <path>`). `bin/remove.sh` deletes a marked file only when its hash matches its record;
  a file with no record (a project from before 1.8.0) only when it is tracked and unchanged
  (`git diff --quiet HEAD`); otherwise `kept (edited): <file>`. This meets "differs from what
  landspec wrote" without rendering (R9's open point, resolved in the plan).
- **F5.4.** `bin/setup.sh` reads both `version:` lines and refuses to go below the project's without
  `--downgrade`: `this plugin copy is <plugin>, the project is at <project>; run /reload-plugins (or
  setup.sh --downgrade)`. It sources `lib.sh` for `version_newer` (one comparator: critic A6).
- **F1.1.** `branch.sh:56`: on a failed push, `landspec: warning: could not claim <branch> on origin:
  <git's error>; other clones may start this task` to stderr, exit 0.
- **F1.6.** `close-linked-issues.yml`: `failed+=" #$n"` for each failed close, then
  `could not close:<list>` and exit 1.
- **F1.7.** `issues.sh`, once before the loop: `gh issue list --state open --limit 1000 --json
  number,title` (no `--search` or `--label`, which switch gh to the search API); a task whose full
  title, as `issues.sh:35-36` builds it, exists and is open gets that number written back (plan
  review: a prefix match over every state would link a regenerated `tasks.md` to old issues) (`<id> → #n (existing)`); a failed
  lookup dies. Comment `shortcut: 1000 issues, …`.
- **F1.8.** `pr.sh:79`: drop `2>/dev/null || true`, die `could not check for an open spec PR`.
- **Test notes.** Every check is in [contracts/checks.md](contracts/checks.md). The F1.8 check needs
  a `git fetch origin` after the teammate's push, or `--force-with-lease` refuses on its own and the
  check proves nothing (C1). The F1.6 check fails today only on the exit code. Guard halves
  (F3.1 "no security text", F3.9 "`src/latest.ts` not refused", F3.5 positive case) pass today and
  are not presented as failing-first evidence.

## Critic's points and how they are resolved

| Point | Resolution |
|---|---|
| A1 fake `gh` edits conflict | `issue list` stays; `api graphql`, `api -X`, `api repos/*` cases are added beside it. One task owns `fake_gh` first (plan, task group G0). |
| A2 promotions squashed | U1. |
| A3 Semgrep rules licence | U2. |
| A4 F5.2 half-done; check cannot pass | Hash record of what `put()` wrote (R9 F5.2); the test commits only the file it edits. |
| A5 constitution amendment rule | U3. |
| A6 three version comparators | One `version_newer` in `lib.sh`; `setup.sh` sources `lib.sh`. The static test keeps its own `IFS=. read` compare (tests do not source scripts' helpers for checks). |
| A7 real scanners in tests | Tests run the scan with a `PATH` without scanners. |
| A8 Semgrep digest vs version | `check-tools.sh` names `SEMGREP_DIGEST` with the version; a `container.image` is not a kept pin (docs say so). |
| B FR-025 release | Plan, last task: three version files (`.specify/presets/landspec/preset.yml` is the installed copy, refreshed by `init`, not bumped by hand), release notes listing ids. |
| B FR-022–FR-024 | Plan's rules for every task (seen-failing evidence, docs in the same PR, no F2.1 detail). |
| C wrong line (security.md guard row) | Line 28, used above. |
| D same lines | Plan's task groups and order. |
| E checks that cannot fail or test the wrong thing | C1 below. |

## C1 · Entries in 001's `report.md` that the research corrects

Before their tasks start (spec edge case), these *Fixes* entries are corrected in feature 001's
`report.md` (and the matching section blocks), in one small PR:

- **F1.8** check: the teammate's push is followed by `git fetch origin`.
- **F1.6** check: the failing half is the step's exit code.
- **F3.5** check: add the positive case (Copilot listed → "code review requested").
- **F4.2** check: scoped to the POST body and the lookup order.
- **F4.5** change and check: digest-pinned image; docs say rules are fetched at run time (U2).
- **F4.7** change: `version_newer` instead of `sort -V`.
- **F5.2** change: the SHA-256 record of what landspec wrote.
- **F5.3** check: `tests/level.test.sh` with a committed fixture.
- **F5.6** change and check: `macos.yml`.
- **F2.3** change: `am -n` too.
- **#41** is not in 001's report; its issue (#41) gets a comment with U1.

# Part 2: the review redesign added on 2026-11-05 (US6)

The user asked for landspec itself to review faster and smarter: depth where the risk is, delta
rounds, a strong model for judgment, and tasks in parallel. A second research workflow (facts on a
fast model, five designs on the senior model, one senior confirmation) produced R10–R12. The
confirmation kept three designs and cut two:

- **Cut: a fast-model "checker"** for the mechanical pre-PR steps. They are already scripts printing
  one line per tool; a fast model reading them adds nothing and could report a scan with findings as
  clean, hiding it from the author (the gate does not refuse on findings). Mechanical work stays in
  scripts, which need no model at all. The strong model is pinned where judgment is: the reviewer.
- **Cut: rounds per level** (core-model D3). Out of 002's scope by its own spec, and it conflicts with
  R11's enforced delta. It goes to the core-model feature.

Facts (primary sources, gathered on a fast model): a plugin ships subagents from an `agents/`
directory; a plugin agent `reviewer` is named `landspec:reviewer`; its frontmatter takes `model`
(`opus`, `sonnet`, `haiku`, `fable`, a full id or `inherit`) and `effort`; the Agent tool's `model`
parameter takes an alias and overrides frontmatter; `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` makes every
subagent run on one model and ignores both; plugin agents ignore `hooks`, `mcpServers` and
`permissionMode` ([sub-agents](https://code.claude.com/docs/en/sub-agents),
[plugins reference](https://code.claude.com/docs/en/plugins-reference)). Anthropic's guidance: a
frontier model plans and confirms, lower-cost workers do bulk work, and delegation helps only when
work is parallel or needs a clean context.

## R10 · Risk map: a script sets the minimum depth (FR-030, FR-031)

- **Decision** (as designed, then the adjustments below):

Use both: a script sets the minimum, and the reviewer adds what the script can't see. A new read-only action, `review.sh risk`, flags risky paths from the diff by fixed rules. Every path it flags must get a deep check, and `review.sh record` refuses any report that leaves one out. The reviewer (prompt) then ranks the remaining hunks for risks a path name can't reveal, gives those depth too, samples the rest, and may skip a path only by naming the test (`file:line`) that already proves it. The report shows this as a 'Risk map' block, so the human merging sees which paths were deep-checked and which were skipped because of a test.

1) extension/scripts/review.sh
- Header comment, after :5: `#   review.sh risk                          the diff's risky paths, one "RISK=<category> <path>" line each (RISK=none)`
- Inside the task-mode `else` branch, before `state()` at :25, add `risk()`. It is one awk pass over `git -c core.quotePath=false diff --no-renames --name-status $from HEAD`, with each line tagged `S<TAB>` by awk (not by sed: BSD sed has no \t), followed by `git diff --no-renames -U0 $from HEAD`. `from` is the same merge-base as `state()`; reuse T002's lib.sh helper if it lands first.
- Path rules, lowercased:
  - delete: name-status `D`
  - migration: `(^|/)(migrations?|migrate|alembic|flyway|liquibase)/` or `\.sql$`
  - ci: `^\.github/`, `^\.gitlab-ci\.yml$`, `^\.circleci/`, jenkinsfile, azure-pipelines, bitbucket-pipelines, `^\.githooks/`, `^\.husky/`, pre-commit-config
  - auth: `auth([^o]|$)`, login, permission, rbac, `(^|[^a-z])acls?([^a-z]|$)`, oauth, jwt, passw, crypt
  - secrets: `(^|/)\.env`, secret, credential, `\.pem$`, `\.key$`, id_rsa
  - money: payment, billing, invoice, checkout, pricing, refund, wallet, ledger
- Added-line rules. They apply only inside a hunk: `hunk` resets on `^diff --git` and is set on `^@@`, so an added line that starts with `++` is never read as a `+++` header.
  - delete: `rm -r`, rmtree, `unlink(`, `drop (table|column|database)`, `truncate `, `delete from`, `os.remove`, `fs.rm`
  - gate: `--no-verify`, `continue-on-error: *true`, `|| *true`, `.only(`, `.skip(`, xfail, @disabled, @ignore, `t.skip(`, `pytest.mark.skip`
- Output is `sort -u | grep . || echo RISK=none`. Only paths and categories are printed, never line content.
- In `record`, before :42, task mode only:
```
miss="$(risk | sed -n 's/^RISK=[a-z]* //p' | sort -u | while IFS= read -r p; do
  awk -v d="- deep: $p" 'index($0, d) == 1 && (length($0) == length(d) || substr($0, length(d) + 1, 1) == " ") { f = 1 } END { exit !f }' "$report" || printf '%s; ' "$p"; done)"
[[ -z "$miss" ]] || die "the risk map has no '- deep: <path>' line for: ${miss%; }; the reviewer must run review.sh risk and deep-check each path"
grep -E '^- proven: ' "$report" | grep -vqE ':[0-9]+' && die "a '- proven:' line names no test file:line"
```
- In the `case`, before :51: `risk) $plan && die "risk maps a diff; a plan review has none"; risk ;;`. Add `| review.sh risk` to the usage line.

2) extension/commands/review.md, step 2 (:35). Fold the map into step 2 so that 'Plan review: steps 1, 2 and 6' (:63) and pr.md's step references keep their numbers. New bold head: **Map the risk, then start from the diff and end in the repository.** Lead text: "Run `bash .specify/extensions/landspec/scripts/review.sh risk`. Every `RISK=` path is deep. Then rank the other hunks for what a path cannot show: data loss, secrets, authorization, money, a migration, a branch or CI change, a deletion, a skipped gate, a write to the user's files. Those are deep too. Deep means steps 2 to 7 in full. Everything else is sampled (read the hunk and its callers once) or proven (an existing test fails if it breaks: name it as `file:line` and what it asserts). Steps 4 and 5 still cover the whole diff."

3) review.md Report, after *What changed* (:77):
"- **Risk map**, before the findings, one line per path you went deep on or skipped:
`- deep: <path> — <why risky>: <what you checked>`
`- proven: <path> — <test file:line>: <what it asserts>`
Write each `- deep:` line exactly as shown, starting at the beginning of the line, path first, then a space. Every `RISK=` path needs one; `review.sh record` refuses the report otherwise. Anything not listed was sampled."

4) extension/commands/pr.md step 5, `## Review` bullet (:54): add "the reviewer's Risk map lines". They contain no finding text, so they are safe to publish; T003 part a's `review.sh report` can print them too.

5) docs/design.md, "The review is independent" (:35-46): add one sentence. Depth follows risk: a script that sees only paths names the risky ones, and those must be deep-checked. The reviewer adds risks a path cannot show and may skip a path only by naming the test that proves it. The map goes into the PR.

6) tests/review.test.sh: add 7 checks before :44 (listed under checks).

- **Adjustments from the senior confirmation**: `auth([^o]|$)` misses `authorization`/`authorize`: use `auth([^o]|$)|authori[sz]`, with a check on `src/authorization.py`; `review.sh risk` takes its starting commit, and `record --delta` checks only `<last>..HEAD`; the PR body gets only `grep -oE '^- (deep|proven): [^ ]+'` (paths, no prose: T003 part a never copies findings); reuse `diff_id` and `test_path_re` from T002.
- **Checks**: when the diff touches nothing risky, then `review.sh risk` prints exactly RISK=none: FAILS on main (no risk action; usage error); when the diff adds db/migrations/002_drop.sql containing DROP TABLE, then risk prints RISK=migration and RISK=delete for that path: FAILS on main; when an added line swallows a failure (`x || true`), then risk prints RISK=gate <file>: FAILS on main; when the report has no `- deep:` line for a risky path, then record refuses and names the path: FAILS on main (main records it); when a deep line names a longer path that only starts with the risky one (002_drop.sql.bak), then record still refuses: FAILS on main (killed the boundary mutant in the prototype); when a `- proven:` line names no test file:line, then record refuses with 'file:line': FAILS on main; when every risky path has a `- deep:` line, then record and check pass: PASSES on main (it guards against over-refusal, not a new behavior); when `review.sh risk --plan` runs, then it refuses ('a plan review has none'): FAILS on main (not in the prototype tests; add it); when the existing suites run (review 17, pr 20, issues 18, next 20, mutants 5), then all pass unchanged: PASSES on main and on the prototype (their diffs have no risky paths)
- **Risks**: False positives: path rules over-match (secret matches this repo's secrets.sh; checkout matches any checkout path; `|| true` matches this repo's own scripts, e.g. review.sh:13), so landspec's own PRs will get many deep lines. Each costs reviewer depth, never correctness. Tighten a rule only after a real false positive.; False negatives: risk in a file whose name says nothing, or a delete written in an unlisted API, is not flagged. That is by design: the prompt's ranking covers it, and nothing enforces it.; Line-format strictness: the agent must save the report as it came (review.md:16), so a reviewer that bolds or reorders a `- deep:` line forces another review round. The error names the missing paths and the format is spelled out in review.md, but expect at least one retry the first time it happens.; Merge order with feature 002: T002 moves the merge-base logic in state() into lib.sh `diff_id` (tasks.md:150), and T003 part a edits review.sh record/report and the review.md Report section. Build this after both, or rebase onto them, and reuse their base helper instead of a second merge-base.; Portability: the TAB marker must come from awk or a literal tab, not sed `\t` (BSD sed). shellcheck is not installed locally, so it was not run on the prototype; CI runs `shellcheck -S warning` (test.yml:26). The busybox/bash 3.2 and macOS jobs were not run; the prototype ran on GNU bash and awk only.; Every rename now shows up as a delete of the old path (--no-renames). That is intended (the reviewer checks callers of the old path), but it adds deep lines on pure moves.; Unverified: whether static.test.sh or reference docs must list the new `risk` action. Grepping docs/reference.md found no review.sh action list, and static.test.sh was not run against the prototype.

## R11 · Delta rounds the script enforces (FR-032, FR-033)

- **Decision** (as designed, then the adjustments below):

This design was built and tested in a scratch copy. The repository itself was not touched. The working patch is at /tmp/tmp.A29fMGg7mb/d3-delta.patch (72 lines; extension/scripts/review.sh +24/-1, tests/review.test.sh +20).

1. What the record stores. In extension/scripts/review.sh:42, every record (full or delta) adds two lines after `assessment:`: `head: <git rev-parse HEAD>` and `round: full|delta`. `state:` stays the patch id of the whole branch diff, so `check` (lines 44-50) and pr.sh:68 do not change. A delta's `ready` is therefore checked against the whole diff.

2. Flags, after review.sh:14:
`delta=false; if [[ "${1:-}" == --delta ]]; then delta=true; shift; fi`
`if $plan && $delta; then die "a plan review is always full: review.sh record --plan <report-file>"; fi`
`DELTA_LINES=20`, with a one-line why comment.

3. `record --delta <file>` refuses, in this order:
(a) There is no record for this branch, or its `round:` is not `full`. Old records have no `round:` line, so they also need a full round. Message: "a delta review follows a recorded full review of this branch; run a full one: review.sh record <report-file>". This also limits a branch to one delta per full round, which matches the plan's limit of 2 rounds.
(b) The report has no line `Delta from: <sha>` (matched with `grep -iE '^\**delta from\**: *[0-9a-f]{7,40}\**$'`, last one wins, the same way as the Assessment line), or `git rev-parse --verify "$from^{commit}"` is not the recorded `head:`. Message: "the delta must review git diff <last>..HEAD and say so in the line 'Delta from: <last>'".
(c) `git merge-base --is-ancestor <last> HEAD` fails. Message: "<last> is no longer on this branch (rebased?); run a full review".
(d) HEAD is still <last>. Message: "nothing was committed since the last review (<last>)".
(e) More than DELTA_LINES lines change outside the previous findings' files. The script sums added+deleted from `git diff --numstat --no-renames <last> HEAD`. It skips files named as `file:line` in the previous record's text from the first line containing "findings" onward (awk `tolower`, not GNU `sed /I`, which BSD sed lacks). It also skips paths matching lib.sh's existing `TEST_PATH_RE` (lib.sh:57). A binary file counts as DELTA_LINES+1. Message: "the fix changed <n> lines outside the previous findings' files (more than 20); run a full review: review.sh record <report-file>".

These run after the existing dirty-tree refusal at line 41.

4. New output. `record` prints `REVIEWED=<full sha>` before the existing `REVIEW=<verdict>` line, which stays last so callers that grep it are unaffected. The author passes REVIEWED= to the next round.

5. Prompt changes the implementer must also make (not prototyped):
- extension/commands/review.md, "Facts the author passes": for a delta round, the last REVIEWED= sha and the previous report file.
- review.md Method: a delta runs `git diff <sha>..HEAD`, checks each previous finding is fixed, and applies steps 2-6 to the delta only.
- review.md Report: a delta report has the line `Delta from: <sha>`.
- extension/commands/pr.md step 4 (lines 42-50): round 2 uses `review.sh record --delta <file>`. Its "at most three rounds" becomes the plan's 2.
- Regenerate the tracked copies under .specify/extensions/landspec/ however the repo normally syncs them.

- **Adjustments from the senior confirmation**: `pr.md` keeps "at most three rounds" for users (round 2 a `record --delta`, round 3 full if needed): the 2-round limit is this feature's own rule, not the product's; scrape only the first `path:line` per finding line for the size exemption; `data-model.md` gets `head:`/`round:`, `contracts/output-lines.md` gets `REVIEWED=`; `docs/design.md` says the PR's review block stays facts only (no reviewer prose, 2026-11-06).
- **Checks**: Setup before the new block: `git checkout --quiet -- specs; git switch --quiet -` (the plan tests leave tasks.md/plan.md edited and checked out on main). Without it, record refuses with 'commit the work first'.; When a full round is recorded, then record prints REVIEWED=<HEAD sha> (and REVIEW= stays the last line) -- FAILS on main (no REVIEWED= line); When nothing was committed since the last full round, then `record --delta` refuses with 'nothing was committed' -- FAILS on main (--delta is taken as the report path, so the usage error comes back); When the delta report's 'Delta from:' names a commit other than the recorded head, then it is refused with 'Delta from: <head>' -- FAILS on main; When the delta report has no 'Delta from:' line, then it is refused, naming 'Delta from' -- FAILS on main; When the fix changes 25 lines of a file named in the previous findings plus a 30-line new tests/search.test.ts, then a ready delta is recorded (REVIEW=ready) and `review.sh check` passes on the whole diff -- FAILS on main; kills both the findings-file and the test-path exemption mutants; When the last recorded round was a delta, then another --delta is refused with 'follows a recorded full review' -- FAILS on main; When the fix adds 21 lines to a file outside the previous findings, then --delta refuses with '21 lines outside' and `check` still refuses ('changed since') -- FAILS on main; When the last reviewed commit is no longer an ancestor of HEAD (after a full record, `git reset --hard HEAD~1; git commit --amend -m rewritten`; simpler than the prototype's lines 72-73), then --delta refuses with 'no longer on this branch' -- FAILS on main; When `record --plan --delta` is used, then it is refused with 'always full' -- FAILS on main; All 16 existing checks in tests/review.test.sh still pass, and tests/run.sh passes -- pass on main and with the patch
- **Risks**: Merging the base branch between rounds puts the base's own changes into `git diff H1..HEAD`. They count as lines outside the findings, so the result is a forced full round. This is safe but costs a round; the fix is to merge the base before round 1, not between rounds.; Findings files are scraped by regex (`[A-Za-z0-9_./-]+:[0-9]+` from the 'findings' line on). File:line evidence pointing at sibling files, or the What changed section mentioning 'Findings', widens what is exempt. Paths with spaces, or cited without a line number, are not matched and count as outside, which errs toward a full round.; Excluding test paths from the count lets a delta rewrite tests freely. The delta reviewer still sees them, and pr.sh's '## Test changes' rule (pr.sh:61-64) still catches edits to existing tests.; T002 part b (F3.4) moves `state()` into lib.sh `diff_id`, and T003 part b (F3.7) edits review.sh:45. The added lines sit at :14 and :42, but the implementer must rebase on whichever lands first. If F3.9 renames TEST_PATH_RE to `test_path_re`, update the one call.; The record format gains `head:` and `round:` lines. Records written before this change have neither, so the first delta after an upgrade is refused until a full round is recorded. That is fail-closed, by design.; Only checked here on bash 5.3 and git 2.56. The constructs are bash 3.2-safe, but this needs the repo's bash32 CI job to confirm. `git merge-base --is-ancestor` needs git 1.8+.; The prompt edits (review.md, pr.md and their tracked .specify copies) were not prototyped. Without them the agent never writes the 'Delta from:' line, so every --delta is refused (safe, but the feature is unused).

## R12 · The reviewer runs on a pinned strong model (FR-034, FR-035)

- **Decision** (as designed, then the adjustments below):

Ship two plugin subagents under a new plugin-root `agents/` directory. plugin.json needs no `agents` key: the default scan finds them, and setting the key would replace that scan (plugins-reference). The judgment (review verdicts, triage, fixes, plan grounding, commits, PR body) stays with the senior model. Only commands whose result is an exit code go to the fast model.

1. NEW agents/reviewer.md (registers as `landspec:reviewer`):
```
---
name: reviewer
description: landspec's independent reviewer, a fresh reader for a branch or a plan. Launched by /speckit-landspec-pr, /speckit-landspec-issues and /speckit-landspec-review with commands/review.md as its prompt.
model: opus
effort: high
---
You are the reviewer your prompt describes (landspec's commands/review.md plus the author's facts). Follow its Method and return only its Report, ending with the Assessment line. You did not write this code: fix nothing, and restore every file you change to break a test.
```
The body has no Method. review.md stays the only copy of it, so the two cannot drift.

2. NEW agents/checker.md (registers as `landspec:checker`):
```
---
name: checker
description: Runs landspec's mechanical pre-PR commands exactly as given and returns only their result lines. Never edits, fixes or judges.
model: haiku
effort: low
disallowedTools: Edit, Write, NotebookEdit, Agent
---
Run each command you are given, in order, from the repository root, exactly as written. Change no file, fix nothing, judge nothing.
- A project command (test, lint, build): run `<cmd> > "$log" 2>&1; echo "exit=$?" >> "$log"` with `log="$(mktemp)"`, then print one line: `<name> ok exit=0 log=<file>` or `<name> fail exit=<code> log=<file>`.
- If `test` failed, do not run mutants.sh: print `mutants skipped tests failed`.
- A landspec script (mutants.sh, security-scan.sh): print its own lines unchanged, `REPORT_DIR=` included.
Print nothing else: no summary, no advice.
```

3. extension/commands/review.md lines 13-16 ("Two roles"). Replace "launch one general-purpose subagent whose prompt is" with:
"launch one subagent of type `landspec:reviewer` (elsewhere, a general-purpose subagent) whose prompt is". Then add after line 16:
"Pass the call's `model`: `review_model:` from `.specify/extensions/landspec/landspec-config.yml` when it is `sonnet`, `opus` or `fable`, otherwise `opus`. If `review_model:` holds any other value, print `landspec: review_model must be sonnet, opus or fable` and stop. Never run the review on `haiku`."
The model is passed on every call, so the fallback general-purpose agent does not take the session's model (which may be cheap). The Agent tool's `model` parameter accepts only aliases, so `inherit` and full model IDs are refused by design (sub-agents doc).

4. extension/commands/pr.md
- Step 2 (lines 10-11): "Run the constitution's test command, plus lint and build if they exist" becomes "Launch one `landspec:checker` subagent (elsewhere, run them yourself) with the constitution's test command, lint and build if they exist, then `bash .specify/extensions/landspec/scripts/mutants.sh`. Confirm each `ok` line with `tail -n 1 <log>` (it must read `exit=0`). On any `fail`, read its log, fix the code and run the checker again."
- Lines 20-21 ("Run `mutants.sh`"): the mutants line now comes from the checker. Keep the ok/survivors/missing rules unchanged, plus: "on survivors, read REPORT_DIR yourself."
- Step 4 (lines 34-38): "one fresh general-purpose subagent" becomes "one `landspec:reviewer` subagent, with `model` as review.md says". Then: "In the same message, launch a `landspec:checker` with `bash .specify/extensions/landspec/scripts/security-scan.sh --changed`." The next bullet becomes "Read every finding in its REPORT_DIR yourself, fix the real ones, list false positives with the reason." `/security-review` stays in the author's session.

5. extension/commands/issues.md line 33: "one fresh general-purpose subagent" becomes "one `landspec:reviewer` subagent, with `model` as review.md says". Step 1 (plan grounding) stays with the author.

6. docs/reference.md
- Configuration table (after the `project` row, about line 114), new row: "| `review_model` | *(empty: `opus`)* | the model of the independent review: `sonnet`, `opus` or `fable`; never `haiku` |".
- Tools table line 98: add one clause, "the review runs on `landspec:reviewer` (Opus by default); the mechanical checks run on `landspec:checker` (Haiku) and return one line each."

7. tests/static.test.sh: add the checks listed below.

8. This repo's own tracked copies (.claude/skills/speckit-landspec-{pr,review,issues}/SKILL.md): regenerate them from extension/commands with `specify extension add --dev extension --force` (the step bin/setup.sh:50 runs). Do not hand-edit them. User projects get the new prompts on their next `/landspec:init`.

No code in bin/setup.sh, level.sh or lib.sh changes. The key is read by the prompt, the same way `level:` is (pr.md:7). An absent key means the default, so no migration is needed.

What must never go to the fast model:
- the review and its Assessment line, and the plan review;
- triage of security-scan findings (real or false positive);
- deciding that a surviving mutant "changes nothing observable";
- any fix, test change or `## Test changes` decision;
- issues.md step 1 grounding;
- the commit, the PR body and `/security-review`.

- **Adjustments from the senior confirmation**: no checker agent (see above); `review.md` launches `landspec:reviewer` and falls back to `general-purpose` with `model: opus` when the scoped id is refused; `review_model:` in `landspec-config.yml` accepts only `sonnet`, `opus` or `fable`; the docs say `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` overrides it and the review costs more on a cheap session; the tracked `.claude/skills/speckit-landspec-*` copies are regenerated with `specify extension add --dev extension --force`, said in Impact; one sandbox session shows the Agent call with the scoped id and `model: opus` before the task merges.
- **Checks**: When agents/reviewer.md is read, then it has `name: reviewer`, `model: opus` and `effort: high` — FAILS on main (no agents/ directory).; When agents/checker.md is read, then it has `name: checker`, `model: haiku` and a `disallowedTools:` line containing Edit and Write — FAILS on main.; When agents/reviewer.md exists, then it has no `## Method` heading, so review.md stays the only copy of the method (`[[ -f agents/reviewer.md ]] && ! grep -q '^## Method' agents/reviewer.md`) — FAILS on main because the file is missing.; When review.md, pr.md and issues.md launch the reviewer, then each contains `landspec:reviewer`, and neither pr.md nor issues.md contains `one fresh general-purpose subagent` — FAILS on main (review.md:14, pr.md:36, issues.md:33).; When review.md sets the reviewer model, then it names `review_model:` and contains exactly `landspec: review_model must be sonnet, opus or fable` and `Never run the review on \`haiku\`` — FAILS on main.; When pr.md step 2 runs the checks, then it names `landspec:checker` and `tail -n 1`, and agents/checker.md contains `mutants skipped tests failed` — FAILS on main.; When docs/reference.md's Configuration table is read, then it has a row starting `| \`review_model\` |` — FAILS on main.; When the plugin is loaded in a throwaway repo (`claude --plugin-dir <repo> -p '/speckit-landspec-review' --output-format stream-json`, sandbox only, not CI), then the transcript has an Agent call with subagent_type `landspec:reviewer` and model `opus` — FAILS on main (general-purpose with no model). That `--plugin-dir` and stream-json expose these fields is unverified.; When landspec-config.yml sets `review_model: haiku` (sandbox), then the session prints `landspec: review_model must be sonnet, opus or fable` and launches no reviewer — FAILS on main.; When setup runs (tests/setup.test.sh:33), then the speckit-landspec-* skills are still registered — PASSES on main and must keep passing (regression guard).
- **Risks**: Unverified: whether the Agent tool's `subagent_type` accepts the scoped id `landspec:reviewer`. The docs show scoped names only for @-mentions, --agent and hook matchers. Confirm with the sandbox check before merging. If it fails, the fallback clause still gives a general-purpose agent with `model` pinned, so the gate keeps its model.; With CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1, the docs say Claude cannot pass a model on spawn. Whether passing one errors or is silently ignored is unverified. If it errors, review.md needs one more sentence: "if the call refuses `model`, launch without it".; Whether the `opus` and `fable` aliases are available on every plan or provider (Bedrock, Vertex, Pro) is unverified. A user without Opus sets `review_model: sonnet`. A wrong value fails loudly through the `landspec: review_model` line instead of downgrading silently.; Cost goes up for users whose session runs on Sonnet or Haiku (an Opus reviewer for up to 3 rounds plus the plan review). This is intended, but the docs row should say so.; Haiku can misreport. Exit codes come from the shell-written `exit=` line in each log, and the author checks it with `tail`. The mutants and security lines are copied from the scripts, so the author reads REPORT_DIR whenever a line is not ok. CI on the PR remains the final gate.; Running the reviewer and security-scan in parallel: the reviewer's Method step 5 breaks a file for a moment while the scanner reads the changed files, so a scan can be flaky (rare). If that matters, run the scan before launching the reviewer.; Projects keep the old prompts (general-purpose, which still works) until they re-run /landspec:init. The plugin's agents only exist where the plugin is installed. Extension-only installs with other integrations use the fallback clause.; Overlap with feature 002 (release 1.8.0), which also edits review.md's Report section and pr.md step 5: implement this after 002 merges to avoid conflicts. The constitution's version bump applies (all three version files).

## R13 · Parallel tasks from `next` (FR-036)

- **Decision** (as designed, then the adjustments below):

Add no new command and no new script. next.sh prints one more kind of line, `parallel`, for every other open [P] task, and the next skill offers to run those lines before it implements NEXT in the current session.

1. extension/scripts/next.sh (prototyped and tested in /tmp/tmp.RYBIVhVdkq)
- Line 32: change `NEXT_ID=""; DONE_N=0; TOTAL=0; BUSY=0` to `NEXT_ID=""; DONE_N=0; TOTAL=0; BUSY=0; PAR=""`.
- After line 51 (`[[ "$state" != open ]] || NEXT_ID=...`), add:
  `      [[ "$state" != open || "$line" != *"[P]"* ]] || PAR+=" $id"`
- After line 81 (`scan "$fdir" true`) and before the DONE echo, add:
```
# Every other startable [P] task: one line that makes its worktree and claims it, run one at a time.
num="$(feature_key "$fdir")"
for id in $PAR; do
  [[ "$id" != "$NEXT_ID" ]] || continue
  wt="$(printf %q "$(dirname "$PWD")/$(basename "$PWD")-$num-$(tr '[:upper:]' '[:lower:]' <<<"$id")")"
  echo "parallel $id (git worktree add --quiet --detach $wt origin/$(base_branch) && cd $wt && bash .specify/extensions/landspec/scripts/branch.sh $num $id)"
done
```
- Header comment, lines 8-9: add "then a `parallel <Tnnn> (<command>)` line for each other open [P] task".
- Exact new output for repo /w/app, feature 001, base develop, open [P] task T003:
  `parallel T003 (git worktree add --quiet --detach /w/app-001-t003 origin/develop && cd /w/app-001-t003 && bash .specify/extensions/landspec/scripts/branch.sh 001 T003)`
- The `DONE=... NEXT=...` line stays last, so existing `tail -1` parsing keeps working.

2. skills/next/SKILL.md: insert after step 3 (clean tree), before "Run /speckit-implement <NEXT>":
"If it printed `parallel` lines, those [P] tasks can start now beside NEXT. Ask once: 'Also start <ids> in their own worktrees?' On yes, run each line exactly as printed, one at a time. Each one claims its task on origin before the next one runs. If a line fails, show its message and skip that task. Then list, per task: open a Claude Code session in <the path after --detach> and run `/speckit-implement <feature> <id>`. Never run two of these lines at once."
Add to step 2's legend: "parallel: an open [P] task that can start in its own worktree."

3. docs/reference.md line 101 (Worktrees row): replace with "`/landspec:next` lists the other [P] tasks that can start now and, on yes, gives each its own worktree beside the repo (`<repo>-<feature>-<task>`) and claims its branch on origin, one after another. Open a Claude Code session in each and run `/speckit-implement <feature> <task>`. Each task keeps its own branch and PR. Blocked tasks and tasks without [P] are never offered. When you're done, remove each worktree with `git worktree remove <path>`." This also drops the claim that "every worktree gets a different task" when sessions run `next` at the same time, which is false (see rationale). The same change fits docs/GUIDELINES.md lines 153-156.

4. tests/next.test.sh: add a "Parallel" block before the T004 block (prototype in /tmp/tmp.RYBIVhVdkq/tests/next.test.sh lines 79-97). It adds `T006 [P] ... (depends on T001) #9` and `T007 [P] ... #10`, then runs the 4 checks listed. The last check runs the printed line with the script path rewritten to $SCRIPTS (the test repo git-ignores .specify). Cleanup uses `|| true` so the file runs to the end even on main.

- **Adjustments from the senior confirmation**: kept as its own task after T005 (the user asked for parallel tasks in the product); after FR-012 a refused claim only warns, so the line "starts" the task, it does not guarantee the claim: the skill says so; `docs/reference.md:101` loses "so every worktree gets a different task".
- **Checks**: when open [P] tasks exist besides NEXT, then each gets a `parallel` line with the exact worktree and branch.sh command, and the DONE line stays last: FAILS on main (main prints no parallel lines); then a blocked [P] task (depends on an open T001), a task without [P] (T003) and NEXT get no parallel line: PASSES on main, trivially, because main prints no parallel lines; it guards the [P] and blocked filters, and the drop-[P]-filter mutant fails it; when NEXT itself is a [P] task (T001 closed, NEXT=T002), then T002 gets no parallel line while T007 does: FAILS on main (no T007 line); it kills the drop-NEXT-exclusion mutant; when a printed parallel line is run, then the task's branch is on origin (claimed), and the next `next` run shows it as in-progress with no parallel line for it: FAILS on main (there is no line to run); the 21 existing next.test.sh checks still pass with the patch (tail -1 is still DONE=...): PASSES on main and on the patch
- **Risks**: Two people in separate clones who run `next` at the same moment can still both pick the same NEXT, and branch.sh line 52 then quietly tracks the other clone's origin branch. This change only fixes the case of one session handing out tasks. Fully fixing the cross-clone race needs a claim that can fail (for example, an empty claim commit pushed so that a second push is rejected). That is a separate change and is unverified.; The line runs branch.sh from the new worktree's own tree, so `.specify/extensions/landspec/` and landspec-config.yml must be committed on the base branch. skills/init/SKILL.md:56-63 commits them, but this is unverified for projects that skipped that commit. There the line fails with 'No such file', and the skill skips the task.; A leftover `<repo>-<feature>-<task>` folder makes `git worktree add` fail. The skill shows the error and skips that task. Worktrees are not cleaned up automatically; the docs tell the user to run `git worktree remove`.; A new worktree has no git-ignored files (.env, node_modules). The user must install dependencies there before the pre-PR checks will pass.; [P] is only as good as the task author's marking. Two [P] tasks that really touch the same file will conflict at merge.; Not verified: shellcheck (not installed here) and a run under real bash 3.2. The prototype ran under bash 5.3. All features used (+=, printf %q, <<<) exist in bash 3.2 per its manual.

