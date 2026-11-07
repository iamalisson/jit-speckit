Reviewed at: 172f8c5 (v1.7.2)

## 4. CI gate and supply chain

Every `file:line` is at tag `v1.7.2`. The workflows were generated for standard and full in a
throwaway repository (`tests/helpers.sh`, a Node project), and quoted below. Branch protection was
applied for real on the private sandbox `iamalisson/jit-speckit-sandbox`, on a branch made for
it (`review-001-t004-protected`), from its clone, with the guard in tasks.md "Rules every task
follows". The pins were checked against GitHub on 2026-11-05.

| id | promise | verdict | evidence |
|---|---|---|---|
| P16 | Every PR, push and week the CI gate runs Gitleaks on full history, OSV-Scanner, zizmor (Semgrep on full, trivy with infra); pinned and checksum-verified; not skippable with branch protection | limit | generated `security.yml` (below) runs on `pull_request`, pushes to the base branches and weekly; gitleaks with `fetch-depth: 0`; every action pinned by SHA and every binary checked with `sha256sum -c`, each SHA and checksum matching upstream. On the sandbox, protection with `init`'s check names blocked a red PR. On lite none of it exists: F4.4. Semgrep is not checksum-pinned: F4.5 |
| P17 | Every action pin is in one place; Dependabot proposes updates; generated workflows use `persist-credentials: false` and read-only permissions | limit | one place: `extension/scripts/pins.sh:6-25`, and every generated `uses:` comes from it; `persist-credentials: false` on every checkout; `contents: read` at the top of `ci.yml` and `security.yml` (`release.yml` needs `contents: write`, and `close-linked-issues.yml` needs `issues: write`). Dependabot reaches 2 of the 9 action pins (F4.1), and a refresh with `init` undoes a project's own bumps (F4.7) |
| P25 | Security findings are never put in a public place | broken | the audit report stays in `.git` (`skills/security/SKILL.md:82`), but its private advisory call is refused (F4.2), and the PR prompt copies security findings into the public PR body (F4.3) |
| P27 | Before a release, `/landspec:security` runs the full audit | limit | the audit is a command the user runs (`docs/security.md:32`, "On demand, before releases"); nothing checks it ran before a release: F4.6 |
| P28 | `/landspec:init` offers secret scanning with push protection and branch protection requiring CI | limit | `skills/init/SKILL.md` step 4 offers them on standard and full, with check names taken from the job names, and the sandbox run shows those names match the real check runs. On lite nothing is offered: F4.4 |

Also checked, no finding:
- **Pins are what they say.** For each action pin, `gh api repos/<action>/git/ref/tags/<tag>`
  resolves to the pinned SHA: `actions/checkout@v7.0.1`, `actions/setup-node@v4.4.0`,
  `zizmorcore/zizmor-action@v0.8.1`, `astral-sh/setup-uv@v10.3.3` (all `ok`). The release
  checksum files list the pinned values: gitleaks 8.30.1 `551f6fc8…f2470eb  gitleaks_8.30.1_linux_x64.tar.gz`
  and osv-scanner 2.7.0 `160c6253…cc2e4218b  osv-scanner_linux_amd64`.
- **Dependabot in a generated project works**: the sandbox has two open Dependabot PRs, "bump
  actions/checkout from 4.4.0 to 7.0.1" (#1) and "bump astral-sh/setup-uv from 5.4.2 to 10.3.3"
  (#2), opened on 2026-11-04 from the sandbox's first generated `dependabot.yml` on `master`
  (from before its PRs #8 and #10, with no cooldown). That shows a generated config proposing
  action bumps; it does not show 1.7.2's config (`level.sh:301-328`, with a 7-day cooldown) at work.
- **Check names**: `init` step 4 says to take the jobs' `name:` (or key) and never `CI` or
  `Security`. On the sandbox, the four names (`python`, `Secrets (gitleaks, full history)`,
  `Dependencies (osv-scanner)`, `Workflows (zizmor)`) were the four check runs on the probe PRs,
  so no PR waits for a check that never reports.
- **The pins the Node project did not generate**, checked the same way (an annotated tag,
  `pnpm/action-setup` and `Swatinem/rust-cache`, was dereferenced with
  `gh api repos/<action>/git/tags/<sha>` before comparing): `pnpm/action-setup@v4.4.0`,
  `Swatinem/rust-cache@v2.9.3`, `actions/setup-python@v5.6.0` and `actions/setup-go@v5.6.0` all
  `ok`; `dtolnay/rust-toolchain`'s pin is `master`'s current SHA (`683b588c…`), as its comment
  says; trivy 0.76.0's `trivy_0.76.0_checksums.txt` lists `e24b1c51…3562c993e145fe7
  trivy_0.76.0_Linux-64bit.tar.gz`, the pinned value. The trivy job itself (`level.sh:251-260`)
  is only written for a project with infrastructure files and was not generated here.
- **Private repositories**: the advisory API answers 404 on the sandbox (private), even to a list,
  and the skill sends private repositories to issues instead (`skills/security/SKILL.md:101-103`),
  which is consistent.

### F4.1 · Medium · P17 · Dependabot updates only 2 of the 9 pinned actions, and none of the 4 pinned tools

- **verdict**: limit (the docs mislead)
- **evidence**: `docs/security.md:76-77` says "Every pin lives in `extension/scripts/pins.sh`, and
  Dependabot proposes updates." Dependabot in this repository watches this repository's own
  workflows only (`.github/dependabot.yml`), and `bin/sync-pins.sh:13-17` copies into `pins.sh`
  only the pins those workflows use. Counting `uses: <action>@` in `.github/workflows/`:
  `actions/checkout` 3 and `astral-sh/setup-uv` 1; `setup-node`, `pnpm/action-setup`,
  `rust-toolchain`, `rust-cache`, `setup-python`, `setup-go` and `zizmor-action` 0. The
  tool versions (gitleaks, osv-scanner, semgrep, trivy) sit in `run:` lines that Dependabot does
  not read at all. So a new project always starts on those 7 actions and 4 tools as they were
  pinned by hand. A project's own Dependabot proposes action bumps afterwards (sandbox PRs #1, #2),
  but not the tool versions, and the next `init` undoes the action bumps it merged (F4.7).
- **reproduction**: `for p in $(grep -oE '^PIN_[A-Z_]+="[^@]+' extension/scripts/pins.sh | sed 's/.*="//'); do echo "$p $(grep -rhoE "uses: $p@" .github/workflows | wc -l)"; done`, run in the `v1.7.2` worktree: only checkout and setup-uv are non-zero.
- **exposure**: public.
- **fix**: add `.github/workflows/pins.yml` to this repository, `on: workflow_dispatch` only, with
  one job that `uses:` every action in `pins.sh`, so Dependabot proposes each one and
  `sync-pins.sh` carries it over; for the tools, a weekly job that compares each `*_VERSION` with
  the latest release and opens an issue. Check for `tests/static.test.sh`: when `pins.sh` has a
  `PIN_*` action, then some file in `.github/workflows/` uses it. It fails today for 7 pins.

### F4.2 · Medium · P25 · the audit's private-advisory call is refused by GitHub

- **verdict**: broken
- **evidence**: for a public repository, `skills/security/SKILL.md:104-107` says to file "a private
  draft security advisory" with `gh api -X POST …/security-advisories -f summary=... -f description=...`.
  GitHub refuses that body. Run on this repository on 2026-11-05: `"Invalid input: object is
  missing required key: vulnerabilities."`, status `422`, and nothing was created (the advisory
  list afterwards held only the two that existed before). The body that works also needs
  `severity` and `vulnerabilities: [{"package": {"ecosystem": "other", "name": …}}]`
  (research R6, verified the same day). The skill offers "or keep the report local" as the other
  choice, so the finding stays private, but the documented private place cannot be reached as written.
- **reproduction**: the call above, as the skill writes it, on any public repository.
- **exposure**: public (no finding is published; the path to file one privately fails).
- **fix**: in `skills/security/SKILL.md`, send JSON with `--input -`, with `severity` and a
  `vulnerabilities` entry (ecosystem `other`), and look up existing advisories by summary first, so a retry makes no duplicate.
  Check for `tests/static.test.sh`: when the skill's advisory call is read, then the JSON after
  `--input -` names `summary`, `description`, `severity`, `vulnerabilities` and `ecosystem`, and a
  `--paginate` lookup comes before the `-X POST`. A file-wide grep for `vulnerabilities` and `severity` already passes
  today, so the check reads the call only. It fails today. (Corrected 2026-11-05 from feature 002's
  research, `specs/002-review-fixes/research.md` C1).

### F4.3 · Medium · P25 · the PR prompt copies a security finding from the review into the public PR body

- **verdict**: broken
- **evidence**: `extension/commands/pr.md:54-56` tells the agent that `## Review` carries "each High
  and Medium finding and the commit that fixed it", and `extension/commands/review.md:78-79` ranks
  "security" as High. So when the independent review finds a security problem, the prompt puts its
  description into the PR body, which is public on a public repository. The constitution says
  "never put … a security finding into a public place" (`.specify/memory/constitution.md:12`).
  Nothing in `pr.md` or `review.md` treats a security finding differently. Found while reviewing
  section 3 (F3.1) and handed over on issue #22, by reading; then run through an agent on
  2026-11-05 (T010): a fresh general-purpose subagent given v1.7.2's whole `pr.md`, the two review
  rounds below, a made-up fix SHA and a body path, and told nothing about this finding, wrote a
  `## Review` that names the file (`src/probe_t010.py:42`), the injected value and "every row of
  `users`, password hashes included, to any logged-in user". The finding is made up; the
  behavior is the prompt's. One run of a prompt-dependent behavior: another run may word it
  differently, but nothing in the prompt asks for less.
- **reproduction**: the agent run in the block below. It runs in no repository, an exception to
  "Reproductions are scripts" (tasks.md) and to FR-003's throwaway repository: what is tested is
  the text the agent writes, so the subagent was told there is no repository, to read no file and
  to run nothing, and `git status --porcelain` of this checkout was the same before and after.
  To repeat it: give a fresh general-purpose subagent `git show v1.7.2:extension/commands/pr.md`,
  the two reports, the facts line and the instruction quoted below, and read the body it writes.

<details>
<summary>F4.3 agent run: inputs and the body it wrote</summary>

Instruction given, in full; the agent's prompt was this text, then `=== The prompt (extension/commands/pr.md) ===` and the whole v1.7.2 `pr.md`, then `=== Review report, round 1 ===` and `=== Review report, round 2 ===` with the two reports below:

```text
There is no repository for you to work in. Do not read any file and do not run any command. Your only action is to write one file with the Write tool: /tmp/tmp.CzkeSqlozS/body.md

You are the author's session at step 5 of the prompt below (steps 1–4 are already done). Write the PR body that step 5 asks for, to /tmp/tmp.CzkeSqlozS/body.md, and nothing else. Then reply with one line: "written".

Facts from steps 2–4: tests 14/14 pass; lint clean; build ok; mutants.sh: missing (no `mutate` command); security-scan.sh --changed: no findings; /security-review: no findings after the fix. The independent review ran twice; both reports are below as they came. The fix commit for round 1's High finding is `3f9c2ab`. The task adds a lookup by name for the admin search page.
```

Review report, round 1:

```markdown
**What changed**
- `src/users.py` adds `find_user(name)`, a lookup by name for the admin search page, and `routes/admin.py` calls it from `GET /admin/search`.
- `tests/test_users.py` adds two cases for an existing and a missing name.

**Findings**

**High**
1. `src/probe_t010.py:42`: SQL injection. `find_user` builds the query with an f-string from `request.args["name"]`, so a request to `/admin/search?name=x' OR '1'='1` returns every row of the `users` table, password hashes included, to any logged-in user. Evidence: the query string at `src/probe_t010.py:42`; the sibling `src/orders.py:30` uses a bound parameter.

**Low**
2. `tests/test_users.py:12`: the missing-name case asserts only the status, not the empty body.

Assessment: changes needed
```

Review report, round 2:

```markdown
**What changed**
- The fix commit replaces the f-string in `find_user` with a bound parameter, and `tests/test_users.py` adds a case with a quote in the name that returns no row.

**Findings**
None.

Assessment: ready
```

The body the subagent wrote:

```markdown
Adds `find_user(name)`, a lookup by name for the admin search page, and calls it from `GET /admin/search`. The query uses a bound parameter.

## Review

**What changed** (round 1): `src/users.py` adds `find_user(name)`, a lookup by name for the admin search page, and `routes/admin.py` calls it from `GET /admin/search`. `tests/test_users.py` adds two cases, one for an existing name and one for a missing name.

**High**
- SQL injection in `find_user`: the query was built with an f-string from `request.args["name"]`, so `?name=x' OR '1'='1` returned every row of `users`, password hashes included, to any logged-in user. The reviewer gave the location as `src/probe_t010.py:42`. Fixed in `3f9c2ab`: the query now uses a bound parameter, and a new test checks that a name containing a quote returns no row.

**Medium**
- None.

**Low (open)**
- `tests/test_users.py:12`: the missing-name case checks only the status, not that the body is empty. `3f9c2ab` did not fix this, and round 2 did not raise it again. It is still open.

**Assessment:** round 1 asked for changes. Round 2 reviewed `3f9c2ab`, found nothing new and said **ready**.

## Evidence

tests 14/14 · lint clean · build ok · security-scan.sh --changed: no findings · /security-review: no findings after the fix
mutation testing: not run. `mutants.sh` reports `missing` because the constitution has no `mutate` command. Run `/landspec:adopt` to add one.

<details>
<summary>Review reports</summary>

Round 1: one High (SQL injection in `find_user`), one Low (missing-name test checks only the status). Assessment: changes needed.

Round 2: reviewed the fix commit (bound parameter, plus a test with a quote in the name). Findings: none. Assessment: ready.

</details>
```

</details>

- **exposure**: public (it is about where the prompt puts findings, not a way to attack the user).
- **fix**: `review.md` reports each security finding as one line, `Security: reported privately
  (<id>)`, with its detail only in the recorded file, and `pr.md` step 5 says a security finding
  goes into `## Review` as that line only. Check for `tests/static.test.sh`: `pr.md` step 5 and
  `review.md`'s report section both say security findings are one line. It fails today. (The same
  change backs F3.1's fix.)

### F4.4 · Medium · P16, P28 · on lite there is no CI gate and no GitHub protection, while the docs call them the boundary

- **verdict**: limit (the docs mislead)
- **evidence**: the levels table says CI, security CI and Dependabot are added from standard on
  (`README.md:124`), and `init` offers GitHub protections on "standard and full" only
  (`skills/init/SKILL.md` step 4). But "Security, built in" lists "every PR, and weekly | CI
  gate: …" with no level (`README.md:109`), and `docs/security.md:33-36` lists branch protection as
  "offered by `/landspec:init`" and says "The CI gate plus branch protection is the boundary".
  On lite that boundary does not exist: the local hooks and the command guard are all there is,
  and both can be bypassed locally (`docs/security.md:27-29`). Step 4 also offers private
  vulnerability reporting "(full, or any public repo)", yet step 4 runs only on standard and
  full, so a public lite repository is never offered it. This repository is one: lite, public, with
  private vulnerability reporting `{"enabled":false}` and secret scanning and push protection
  `disabled` (`gh api` on 2026-11-05).
- **reproduction**: generate lite in a throwaway repo (`level.sh lite`): no `.github/workflows/` is
  written; read `skills/init/SKILL.md` step 4's "(standard and full)".
- **exposure**: public.
- **fix**: say it where people read it: the "every PR, and weekly" row in `README.md` gets
  "(standard and full)", and `docs/security.md` says that on lite the boundary is only the local
  hooks; and `init` offers secret scanning with push protection and private vulnerability
  reporting on every level for a public repository (they cost nothing there). Check for
  `tests/static.test.sh`: the README CI row names its levels. It fails today.

### F4.7 · Medium · P17 · a refresh with `init` puts a project's newer action pins back to the plugin's older ones

- **verdict**: limit (the docs mislead)
- **evidence**: a Dependabot PR in a project bumps the SHA inside the managed `security.yml` and
  keeps its `# landspec: managed file` line. `level.sh` rewrites every file that still has that
  line (`level.sh:124`, `put`), and the documented update path runs it (`init` → `bin/setup.sh:71`
  → `level.sh`, `docs/reference.md` "Update"). So after an update the plugin's `pins.sh` SHA is
  back, older than the one the project merged, and only `updated: .github/workflows/security.yml`
  is printed. Script below: three `v7.1.0` lines after the bump, and after `level.sh standard`
  again, `0 lines at v7.1.0; 3 at v7.0.1`. `docs/security.md:76-77` presents Dependabot as what
  keeps the pins current.
- **reproduction**: the re-pin script below.
- **exposure**: public.
- **fix**: before rewriting a managed workflow, keep each `uses: <action>@<sha> # <version>` line
  whose version is newer than `pins.sh`'s (compared by a pure-bash `version_newer` in `lib.sh`,
  not `sort -V`, which BSD and busybox may lack), and print `kept newer pin: <action> <version>`.
  Check for `tests/level.test.sh`: when a managed workflow carries a newer checkout pin than
  `pins.sh`, then `level.sh` keeps it and prints `kept newer pin`. It fails today. (Corrected 2026-11-05 from feature 002's research, `specs/002-review-fixes/research.md` C1).

### F4.5 · Medium · P16 · Semgrep is version-pinned but not checksum-verified, and its rules are fetched at run time

- **verdict**: limit (the docs mislead)
- **evidence**: the generated full `security.yml` runs
  `uvx --from semgrep==1.183.0 semgrep scan --config p/default --config p/owasp-top-ten …`. The
  package comes from PyPI by version with no hash, and `p/default` and `p/owasp-top-ten` are
  downloaded from the Semgrep registry on each run, so the rules change without a commit.
  "all pinned and checksum-verified" (`README.md:109`) is true of the binaries, not of these, so a
  user reading it is misled about Semgrep (FR-009 Medium).
- **reproduction**: `level.sh full` in a throwaway repo, then read the Semgrep step of the written
  `security.yml`.
- **exposure**: public.
- **fix**: run Semgrep in the full-level `security.yml` from `semgrep/semgrep@sha256:<digest>`,
  with the digest next to its version in `pins.sh`, instead of `uvx --from semgrep==<version>`;
  the README and `docs/security.md` say its rule sets come from the Semgrep registry at run time.
  Rules are not vendored: the Semgrep Rules License forbids redistributing them. Check for
  `tests/level.test.sh`, `tests/static.test.sh`: when `level.sh full` writes `security.yml`, then
  its Semgrep job runs `semgrep/semgrep@sha256:<64 hex>` equal to `pins.sh`'s digest and nothing
  installs Semgrep by version alone; and when the README CI row and `docs/security.md` are read,
  then they say the rules come from the Semgrep registry. It fails today. (Corrected 2026-11-05
  from feature 002's research, `specs/002-review-fixes/research.md` C1).

### F4.6 · Low · P27 · a release goes out on any version tag, with no audit or CI requirement

- **verdict**: limit
- **evidence**: the full `release.yml` runs on `push: tags: ["v*"]` and calls `gh release create
  "$TAG" --generate-notes --verify-tag`, with no check that CI passed on the tagged commit or that
  `/landspec:security` ran. `docs/security.md:32` says "On demand, before releases", which is
  accurate; the README's "before a release" row reads more like an automatic step. It stays Low:
  that row names a command, `/landspec:security`, in a table whose other rows also name what to
  run, not a CI step, and the security doc it points to says "On demand".
- **note**: `release.yml` could require a passing `Security` run on the tagged commit (`gh run
  list --commit "$GITHUB_SHA" --workflow security.yml`) before creating the release.

### Generated files and runs

<details>
<summary>Generation script and the generated full <code>security.yml</code>, <code>ci.yml</code>, <code>release.yml</code></summary>

```bash
# T004: generate the workflows level.sh writes, run as: bash t004-gen.sh <v1.7.2 worktree> <out dir>
source "$1/tests/helpers.sh"
fake_gh; new_repo standard
[ "$(git rev-parse --show-toplevel)" != /home/admin/Documents/workstation/personal/landspec ] || exit 1
ln -s "$1/extension/scaffold" .specify/extensions/landspec/scaffold 2>/dev/null || true
printf '{"name":"x","version":"1.0.0"}\n' > package.json; printf '{"lockfileVersion":3}\n' > package-lock.json
for l in standard full; do
  bash "$SCRIPTS/level.sh" $l --no-branches > "$2/level-$l.log" 2>&1 || echo "level $l rc=$?"
  mkdir -p "$2/$l"; cp -r .github "$2/$l/" 2>/dev/null; ls .github/workflows | sed "s/^/$l: /"
done
```

Files written: standard `ci.yml`, `close-linked-issues.yml`, `security.yml`; full adds
`release.yml`, plus `SECURITY.md` and `.github/CODEOWNERS`.

```yaml
# landspec: managed file. /landspec:level re-creates it while this line stays; delete the line to keep your own edits.
# Security gate: runs on every pull request, on pushes to long-lived branches, and weekly
# (new CVEs land in dependencies nobody touched). Tools are pinned and checksum-verified.
name: Security

on:
  pull_request:
  push:
    branches: [main, develop, staging]
  schedule:
    - cron: "17 6 * * 1"
  workflow_dispatch:

permissions:
  contents: read

jobs:
  secrets:
    name: Secrets (gitleaks, full history)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          fetch-depth: 0
          persist-credentials: false
      - name: Install gitleaks 8.30.1 (checksum-verified)
        run: |
          curl -sSfL -o gitleaks.tgz https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz
          echo "551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb  gitleaks.tgz" | sha256sum -c -
          tar -xzf gitleaks.tgz gitleaks
      - run: ./gitleaks git --redact --verbose --no-banner .

  dependencies:
    name: Dependencies (osv-scanner)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - name: Install osv-scanner 2.7.0 (checksum-verified)
        run: |
          curl -sSfL -o osv-scanner https://github.com/google/osv-scanner/releases/download/v2.7.0/osv-scanner_linux_amd64
          echo "160c6253e2922e9e0a6a9771c5c4c40a4b3c6090b34a3cdd5e80c96cc2e4218b  osv-scanner" | sha256sum -c -
          chmod +x osv-scanner
      - name: Scan every lockfile (exit 128 = no lockfiles)
        run: ./osv-scanner scan source -r . || { s=$?; [ "$s" = 128 ] || exit "$s"; }

  workflows:
    name: Workflows (zizmor)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: zizmorcore/zizmor-action@45d7276c9ca790aabd705e31ca99c6185c3e76dd # v0.8.1
        with:
          advanced-security: false

  code:
    name: Code (semgrep, OWASP rules)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: astral-sh/setup-uv@68559e99cc807c1eb7e9238fd43a15bba460eec2 # v10.3.3
      - run: uvx --from semgrep==1.183.0 semgrep scan --config p/default --config p/owasp-top-ten --error --metrics off
```

```yaml
# landspec: managed file. /landspec:level re-creates it while this line stays; delete the line to keep your own edits.
# Commands come from the constitution (**Commands** line); stack defaults fill the gaps.
name: CI

on:
  push:
    branches: [main, develop, staging]
  pull_request:

permissions:
  contents: read

jobs:
  node:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020 # v4.4.0
        with:
          node-version: lts/*
          cache: npm
      - run: npm ci
      - run: npm test
```

```yaml
# landspec: managed file. /landspec:level re-creates it while this line stays; delete the line to keep your own edits.
# Push a tag like v1.2.3 to publish a GitHub release with generated notes.
name: Release

on:
  push:
    tags: ["v*"]

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - env:
          GH_TOKEN: ${{ github.token }}
          TAG: ${{ github.ref_name }}
        run: gh release create "$TAG" --generate-notes --verify-tag
```

</details>

<details>
<summary>Re-pin script (F4.7) and its output</summary>

```bash
# T004: does a re-run of level.sh (what init does) keep a newer pin a project's Dependabot wrote?
source "$1/tests/helpers.sh"
fake_gh; new_repo standard
[ "$(git rev-parse --show-toplevel)" != /home/admin/Documents/workstation/personal/landspec ] || exit 1
ln -s "$1/extension/scaffold" .specify/extensions/landspec/scaffold 2>/dev/null || true
printf '{"name":"x","version":"1.0.0"}\n' > package.json; printf '{"lockfileVersion":3}\n' > package-lock.json
bash "$SCRIPTS/level.sh" standard --no-branches >/dev/null 2>&1
sed -i 's/actions\/checkout@[0-9a-f]\{40\} # v7.0.1/actions\/checkout@1111111111111111111111111111111111111111 # v7.1.0/' .github/workflows/security.yml
echo "after a Dependabot-style bump: $(grep -c 'v7.1.0' .github/workflows/security.yml) lines at v7.1.0"
bash "$SCRIPTS/level.sh" standard --no-branches 2>&1 | grep 'security.yml'
echo "after level.sh again: $(grep -c 'v7.1.0' .github/workflows/security.yml) lines at v7.1.0; $(grep -c 'v7.0.1' .github/workflows/security.yml) at v7.0.1"
```

```text
after a Dependabot-style bump: 3 lines at v7.1.0
updated: .github/workflows/security.yml
after level.sh again: 0 lines at v7.1.0; 3 at v7.0.1
```

</details>

<details>
<summary>Sandbox: branch protection with <code>init</code>'s check names</summary>

```bash
# T004 on the sandbox: branch protection with the check names init would require. Run from the sandbox clone.
set -u
[ "$(git remote)" = origin ] && [ "$(gh repo view --json nameWithOwner -q .nameWithOwner)" = iamalisson/jit-speckit-sandbox ] || exit 1
R=iamalisson/jit-speckit-sandbox; REC="$(git rev-parse --git-common-dir)/landspec-repro/t004-created.txt"; P=review-001-t004-protected; C=review-001-t004-change
git fetch -q origin
git push -q origin "origin/develop:refs/heads/$P" 2>&1 | grep -v '^remote:' || true; echo "branch $P" >> "$REC"
echo "== protection before (restore command recorded first)"
gh api "repos/$R/branches/$P/protection" 2>&1 | head -1
echo "restore: gh api -X DELETE repos/$R/branches/$P/protection" >> "$REC"
echo "== apply, as /landspec:init step 4 says (job names, enforce_admins, PR required, 0 approvals on standard)"
printf '%s' '{"required_status_checks":{"strict":false,"contexts":["python","Secrets (gitleaks, full history)","Dependencies (osv-scanner)","Workflows (zizmor)"]},"enforce_admins":true,"required_pull_request_reviews":{"required_approving_review_count":0},"restrictions":null}' \
  | gh api -X PUT "repos/$R/branches/$P/protection" --input - --jq '"contexts: " + (.required_status_checks.contexts|join(", ")) + " | enforce_admins: " + (.enforce_admins.enabled|tostring)'
echo "== a direct push to the protected branch"
git switch -q -c "$C" "origin/$P"; echo "t004 probe" > docs/001-review-t004.md; git add docs/001-review-t004.md; git commit -q -m "docs: 001 review T004 probe"
git push origin "HEAD:refs/heads/$P" 2>&1 | grep -E 'protected|rejected|GH006' | head -3
echo "== a PR into it"
git push -q -u origin "$C" 2>&1 | grep -v '^remote:' || true; echo "branch $C" >> "$REC"
url=$(gh pr create -R $R --base "$P" --head "$C" --title "[001 review T004] branch protection probe" --body "Probe for the landspec 001 review, T004. Closed after."); n=${url##*/}; echo "pr $n" >> "$REC"; echo "PR #$n"
sleep 60
gh pr view "$n" -R $R --json mergeStateStatus,statusCheckRollup -q '"mergeStateStatus: " + .mergeStateStatus, (.statusCheckRollup[] | "  " + .name + ": " + (.conclusion // .status))'
gh pr merge "$n" -R $R --squash 2>&1 | head -2
```

```text
== protection before (restore command recorded first)
{"message":"Branch not protected","documentation_url":"https://docs.github.com/rest/branches/branch-protection#get-branch-protection","status":"404"}gh: Branch not protected (HTTP 404)
== apply, as /landspec:init step 4 says (job names, enforce_admins, PR required, 0 approvals on standard)
contexts: python, Secrets (gitleaks, full history), Dependencies (osv-scanner), Workflows (zizmor) | enforce_admins: true
== a direct push to the protected branch
remote: error: GH006: Protected branch update failed for refs/heads/review-001-t004-protected.        
 ! [remote rejected] HEAD -> review-001-t004-protected (protected branch hook declined)
== a PR into it
PR #16
mergeStateStatus: CLEAN
  python: SUCCESS
  Secrets (gitleaks, full history): SUCCESS
  Dependencies (osv-scanner): SUCCESS
  Workflows (zizmor): SUCCESS
```

The green probe PR #16 merged into `review-001-t004-protected` only (its checks passed in under a
minute); `develop` was not touched. Then a red one:

```bash
# T004 on the sandbox, part 2: a PR with a failing test into the protected branch. Run from the sandbox clone.
set -u
[ "$(git remote)" = origin ] && [ "$(gh repo view --json nameWithOwner -q .nameWithOwner)" = iamalisson/jit-speckit-sandbox ] || exit 1
R=iamalisson/jit-speckit-sandbox; REC="$(git rev-parse --git-common-dir)/landspec-repro/t004-created.txt"; P=review-001-t004-protected; C=review-001-t004-red
git fetch -q origin; git switch -q -c "$C" "origin/$P"
printf '\n\ndef test_001_review_t004_red():\n    assert False\n' >> tests/test_convert.py
git add tests/test_convert.py; git commit -q -m "test: 001 review T004 red probe"
git push -q -u origin "$C" 2>&1 | grep -v '^remote:' || true; echo "branch $C" >> "$REC"
url=$(gh pr create -R $R --base "$P" --head "$C" --title "[001 review T004] red check probe" --body "Probe for the landspec 001 review, T004. Closed after."); n=${url##*/}; echo "pr $n" >> "$REC"; echo "PR #$n"
for i in $(seq 1 12); do sleep 15; s=$(gh pr view "$n" -R $R --json statusCheckRollup -q '[.statusCheckRollup[] | select(.name=="python") | (.conclusion // .status)] | .[0]'); [ "$s" = FAILURE ] || [ "$s" = SUCCESS ] && break; done
gh pr view "$n" -R $R --json mergeStateStatus,statusCheckRollup -q '"mergeStateStatus: " + .mergeStateStatus, (.statusCheckRollup[] | "  " + .name + ": " + (.conclusion // .status))'
echo "== merge attempt"; gh pr merge "$n" -R $R --squash 2>&1 | head -2; echo "rc=$?"
gh pr view "$n" -R $R --json state -q '"state: " + .state'
```

```text
PR #17
mergeStateStatus: BLOCKED
  python: FAILURE
  Secrets (gitleaks, full history): SUCCESS
  Dependencies (osv-scanner): SUCCESS
  Workflows (zizmor): SUCCESS
== merge attempt
X Pull request iamalisson/jit-speckit-sandbox#17 is not mergeable: the base branch policy prohibits the merge.
To have the pull request merged after all the requirements have been met, add the `--auto` flag.
rc=0
state: OPEN
```

The `rc=0` after the merge attempt is `head`'s, not `gh`'s. Cleanup: PR #17 closed with
`[001 review T004] cleanup`; the protection removed with the recorded
`gh api -X DELETE repos/iamalisson/jit-speckit-sandbox/branches/review-001-t004-protected/protection`
(afterwards `Branch not protected`); branches `review-001-t004-protected`, `review-001-t004-change`
and `review-001-t004-red` deleted on origin and locally. Left in place: PR #16, merged into the
deleted side branch. The record is the sandbox clone's `.git/landspec-repro/t004-created.txt`.

</details>
