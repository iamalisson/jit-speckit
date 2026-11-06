Reviewed at: 172f8c5 (v1.7.2)

## 2. Secrets and the command guard

Every `file:line` is at tag `v1.7.2`. Reproductions run in a throwaway repository made by
`tests/helpers.sh` (`new_repo`, `fake_gh`). Fake secrets are assembled at run time. Gitleaks is
not installed here, so only the built-in patterns ran. Claude Code on this machine: 2.1.318.

| id | promise | verdict | evidence |
|---|---|---|---|
| P06 | Every commit refuses `.env`, keys, credential files and token- or password-like lines, in under a second | reported privately (F2.1, GHSA-4mx7-h98x-x6hf) | see advisory |
| P07 | Every push re-checks every outgoing commit, including `--no-verify` ones; base branches are PR-only on standard and full | reported privately (F2.1, GHSA-4mx7-h98x-x6hf) | see advisory |
| P08 | Every command Claude runs is refused for `--no-verify`, `commit -n`, hooks switched off, `git add -A`, commits on and pushes to base branches; the guard is the plugin's own copy | limit | the documented forms are refused (section G below; `guard.sh:85-135`; `tests/guard.test.sh`); the plugin's own copy runs (`hooks/guard-git.sh:22`). Valid commands are refused (F2.2), and two forms inside the documented scope get through (F2.3) |
| P09 | Findings never print the secret itself | holds | `secrets.sh:73-81` hands back only line numbers and the kind; Gitleaks runs with `--redact` (`:85,88`); section B below: "secret not in the output" |

Also checked, no finding (these are parts of P06 and P07; the rows above carry F2.1 only):
- Secret-bearing files: `.env`, `config/.env.production`, `deploy/id_ed25519` and `certs/server.pem`
  are refused, and `.env.example` and the other templates are allowed (`secrets.sh:34-42`). Section A.
- Provider tokens in added lines: GitHub and AWS formats are refused, and the kind is named (section A).
- Speed: 20,000 added lines with one secret are refused in 66 ms (section C), well under "under a second".
- Push: a commit made with `--no-verify` is refused at push (section D, `prepush.sh:42`), and a
  new branch is scanned down to what no remote has (`prepush.sh:36-41`, `secrets.sh:25`). A branch
  deletion is not scanned (`prepush.sh:26`), which is right because it carries no commit.
  A push straight to `develop` on standard is refused (section E, `prepush.sh:28-35`). The
  empty-remote exception allows the first push once and says so (`prepush.sh:29-30`).
- Hook managers: a repository with `.pre-commit-config.yaml` or `.husky/` gets the two checks added
  there instead of `core.hooksPath` (`level.sh:336-369`).
- **Unverified**: with the pre-commit framework, a push of several branches at once passes only
  the last ref to `prepush.sh` (`prepush.sh:15-21`, a comment measured with pre-commit 4.7.0), so
  the other branches' commits would not be re-scanned. Not run here. What would check it: a
  pre-commit-managed throwaway repo, two branches with a token each, `git push origin a b`.
- **The hook's failure modes**, from Claude Code's hooks reference
  (https://code.claude.com/docs/en/hooks, read on 2026-11-05, twice, by two separate readers):
  - exit 2 blocks the tool call;
  - any other exit, a timeout, or a hook that cannot start is a non-blocking error, "except for
    hooks whose failure blocks the action, for example a hook with `onFailure` set to `"block"`";
  - `onFailure` is a documented field that "Requires Claude Code v2.1.295 or later";
  - `timeout` is in seconds.

  `hooks/hooks.json` sets `"timeout": 10` and `"onFailure": "block"`, so on 2.1.295 or later a guard
  that times out or crashes blocks the command. On older versions the command goes through, which
  `guard.sh:10-16` already plans for: it exits 2 on every refusal and keeps its parsing linear so
  it stays under the timeout. See F2.4.

**Script refuses / prompt asks** (research R4):

| gate | script refuses | prompt asks |
|---|---|---|
| commit secret check | `.githooks/pre-commit` → `secrets.sh staged`, exit 1 (people and Claude) | `extension/commands/pr.md` step 3: "If it refuses, remove the secret; never use `--no-verify`" |
| push re-scan and base branches | `.githooks/pre-push` → `prepush.sh`, exit 1 | — |
| command guard | `hooks/guard-git.sh` → `guard.sh`, exit 2, for Claude's Bash tool only, best effort | `extension/commands/pr.md` step 3: "Stage files by name, never `git add -A`" |
| a person's own `--no-verify` | nothing locally ("locally, `--no-verify`", `docs/security.md:27`); the push re-scan and CI catch it | — |

The docs present each as what it is: `docs/security.md:27-29` says the local layers can be bypassed
and the guard is "best effort", with "CI and branch protection" as the boundary.

### F2.2 · Low · P08 · the guard refuses valid commands

- **verdict**: limit
- **evidence**: section F below. Each one happened for real in the session that ran this review:
  - `git config core.hooksPath` (a read with no value) gets "switching git hooks off skips the
    secret checks", `rc=2`. `guard.sh:105` counts only `--get`, `--get-all`, `--get-regexp`,
    `--list`, `-l` and `get` as reads.
  - `git switch <task branch> && git commit …` run from `main` gets "committing on 'main' is not
    allowed", `rc=2`. `guard.sh:20` reads the branch once, before the chain runs.
  - `cd /some/other/repo && git add .` gets "stage files by name", `rc=2`. The words are checked
    whatever directory they run in (`guard.sh:17` judges by the hook's working directory).
- **note**: each costs a retry, and the third one blocks work in throwaway repositories. Fixes:
  treat `config <key>` with no value as a read; drop or follow a `cd` to another repository; and
  see F2.3 for the branch.

### F2.3 · Medium · P08 · two forms inside the guard's documented scope get through

- **verdict**: limit (the docs mislead)
- **evidence**: `docs/security.md:28` says the guard refuses `--no-verify` and "commits on base
  branches", and "sees through chains … and bundled flags". It calls itself best effort against "an
  unusual shell trick". Two forms that are not shell tricks pass `guard.sh` with exit 0:
  - **an abbreviated long option**, which git itself accepts as the full one. `guard.sh:88,111,121`
    compare whole words only.
  - **a commit after a branch switch in the same chain.** `guard.sh:20` takes the branch before
    the chain runs, so a commit on a base branch made after switching to it in the same command
    is let through. This is the other side of F2.2's second case.

  Output of the probe (the script, with the exact commands, is kept outside the repository in
  `$(git rev-parse --git-common-dir)/jit-repro/t002-private.sh`, never committed):
  `PASSES  abbreviated long option` and `PASSES  switch then commit on base`, plus a check that
  git itself takes that abbreviation as the full option (git 2.56.0).

  Three more classes pass and are the "unusual shell trick" the docs describe honestly: a git
  alias that adds the option, `eval`, and `xargs` (`guard.sh:164` knows `env`, `command`, `exec`,
  `time`, `nohup` and `sudo` as prefixes). The boundary still holds: a push to a base branch is
  refused by name (section G), by the pre-push hook on standard and full (section E) and by
  branch protection.
- **exposure**: public. It is the operator's own agent, and the documented boundary is CI plus
  branch protection (FR-013).
- **fix**: in `guard.sh`, refuse any long option that git would expand to `--no-verify`: a unique
  prefix of it among that subcommand's options (git rejects the ambiguous shorter ones, so the
  guard can refuse every prefix that is not ambiguous for `commit`, `push`, `merge`, `rebase`, `am`,
  `cherry-pick` and `revert`, each checked against its own option list). And when a word sequence in the chain is
  `git switch|checkout <branch>`, judge later commits by that branch. Check for
  `tests/guard.test.sh`: when the command is a commit with an abbreviated `--no-verify`, or a
  switch to `main` followed by a commit in one chain, then `guard.sh` exits 2. It fails today
  (exit 0).

### F2.4 · Medium · P08 · the docs give Claude Code 2.1.275 as the plugin's minimum, but the guard fails closed only from 2.1.295

- **verdict**: limit (the docs mislead)
- **evidence**: `hooks/hooks.json` relies on `onFailure: "block"`, which the hooks reference
  says requires v2.1.295 or later. On older versions a timeout, a crash or exit 1 is a
  non-blocking error and the command runs. Nothing in jit checks the Claude Code version. The
  only versions the docs give are lower: the constitution's "Stack" says "the plugin needs Claude
  Code 2.1.275 or newer" (`.specify/memory/constitution.md:19`), and `README.md:44` says of the
  one-line install command "Needs Claude Code 2.1.275 or newer; on older versions use two
  prompts". So a user on 2.1.275 to 2.1.294 is told they are supported, while there the guard
  fails open on a timeout or crash, a case `docs/security.md:28`'s "best effort: an unusual shell
  trick can get past it" does not describe. Ranked Medium on that documented mismatch (FR-009: "a
  promise kept but a user could be misled about it"), not on a run: the fail-open behavior itself
  rests on the hooks reference and `guard.sh:10-16`, and stays in `report.md`'s *Unverified*.
- **reproduction**: read `README.md:44`, the constitution's "Stack" (`.specify/memory/constitution.md:19`)
  and the hooks reference's `onFailure` line ("Requires Claude Code v2.1.295 or later",
  https://code.claude.com/docs/en/hooks), next to `hooks/hooks.json`.
- **exposure**: public (it is about which version the docs promise, not a way past the guard).
- **fix**: say 2.1.295 wherever the plugin's minimum is given: the constitution's "Stack",
  `README.md` next to the install line, and `docs/security.md`'s guard row ("fails closed on a
  timeout or crash from Claude Code 2.1.295"). Check for `tests/static.test.sh`: when
  `hooks/hooks.json` uses `onFailure`, then every "Claude Code <version> or newer" in `README.md`
  and the constitution is 2.1.295 or newer. It fails today (2.1.275).

### F2.5 · Low · P06 · secret formats the docs never list are not caught

- **verdict**: limit
- **evidence**: the built-in patterns (`secrets.sh:47-59`) cover 12 provider formats plus a
  generic assignment. A format outside them passes, for example an AWS temporary key ID
  (`ASIA…`). The probe output was `MISSED  AWS temporary key id (ASIA)`. The docs promise
  "provider tokens", not a list, and Gitleaks (when installed, and in CI on standard and full)
  covers far more (`secrets.sh:83-90`).
- **note**: listing the covered formats in `docs/security.md`, and saying Gitleaks is what makes
  the commit check broad, would set the expectation right.

### Reproductions

<details>
<summary>Public script (sections A–G) and its output</summary>

```bash
# T002 reproductions (public part), run as: bash t002-repro.sh <v1.7.2 worktree>
source "$1/tests/helpers.sh"
fake_gh; new_repo standard
[ "$(git rev-parse --show-toplevel)" != /home/admin/Documents/workstation/personal/jit-speckit ] || exit 1
s="$SCRIPTS/secrets.sh"; g="$SCRIPTS/guard.sh"
git switch -q -c feat/001-t001-x
# Fake secrets are assembled here at run time, so no token-shaped string sits in this file.
gh_tok="gh""p_$(printf 'a%.0s' $(seq 36))"; aws="AK""IA$(printf 'B%.0s' $(seq 16))"

echo "== A. commit check: secret-bearing files and provider tokens"
for f in .env config/.env.production deploy/id_ed25519 certs/server.pem; do mkdir -p "$(dirname "$f")"; echo x > "$f"; git add -f "$f"; done
printf 'token = "%s"\naws = "%s"\n' "$gh_tok" "$aws" > app.py; git add app.py
"$s" staged || echo "rc=$?"
git reset -q; rm -rf .env config deploy certs app.py

echo "== B. the finding never prints the secret"
printf 'token = "%s"\n' "$gh_tok" > app.py; git add app.py
out="$("$s" staged 2>&1 || true)"; grep -qF "$gh_tok" <<<"$out" && echo "secret printed" || echo "secret not in the output"
git reset -q; rm app.py

echo "== C. time on a large diff (20,000 added lines, 1 secret)"
seq 1 20000 | sed 's/^/line /' > big.txt; printf 'k = "%s"\n' "$aws" >> big.txt; git add big.txt
start=$(date +%s%N); rc=0; "$s" staged >/dev/null 2>&1 || rc=$?; end=$(date +%s%N); echo "rc=$rc in $(( (end-start)/1000000 )) ms"
git reset -q; rm big.txt

echo "== D. push check: a --no-verify commit is caught at push; deleting a branch is not scanned"
printf 'token = "%s"\n' "$gh_tok" > leak.py; git add leak.py; git commit -q --no-verify -m leak
sha=$(git rev-parse HEAD)
printf 'refs/heads/feat/001-t001-x %s refs/heads/feat/001-t001-x %s\n' "$sha" 0000000000000000000000000000000000000000 | "$SCRIPTS/prepush.sh" origin "$TMP/origin.git" || echo "rc=$?"
printf '(delete) 0000000000000000000000000000000000000000 refs/heads/old %s\n' "$sha" | "$SCRIPTS/prepush.sh" origin "$TMP/origin.git" && echo "delete rc=0" || echo "delete rc=$?"
echo "== E. push straight to develop (standard) is refused"
printf 'refs/heads/develop %s refs/heads/develop %s\n' "$sha" "$(git rev-parse origin/develop)" | "$SCRIPTS/prepush.sh" origin "$TMP/origin.git" 2>&1 | grep -v '^  ' || true
git reset -q --hard HEAD~1

echo "== F. guard: valid commands it refuses (false positives)"
"$g" 'git config core.hooksPath' || echo "rc=$?   <- a read of the setting"
git switch -q main
"$g" 'git switch feat/001-t001-x && git commit -m wip' || echo "rc=$?   <- judged by the branch the chain starts on"
git switch -q feat/001-t001-x
"$g" 'cd /some/other/repo && git add .' || echo "rc=$?   <- a command in another repository"
echo "== G. guard: what it refuses as documented"
for c in 'git commit --no-verify -m x' 'git commit -nm x' 'git -c core.hooksPath=/dev/null commit -m x' 'git add -A' 'git push origin develop' 'env FOO=1 git push --no-verify' "sh -c 'git add --all'"; do "$g" "$c" 2>&1 | sed "s|^|$c  ->  |" || true; done
```

```text
== A. commit check: secret-bearing files and provider tokens
jit: refusing: possible secrets
  .env: secret-bearing file
  certs/server.pem: secret-bearing file
  config/.env.production: secret-bearing file
  deploy/id_ed25519: secret-bearing file
  app.py:1: possible GitHub token
  app.py:2: possible AWS access key
  Remove them (and rotate any real credential that was ever committed or pushed).
  Load secrets from the environment and keep a .env.example with the keys only.
  A false positive can be allowed on that line with a comment containing: jit:allow-secret
rc=1
== B. the finding never prints the secret
secret not in the output
== C. time on a large diff (20,000 added lines, 1 secret)
rc=1 in 66 ms
== D. push check: a --no-verify commit is caught at push; deleting a branch is not scanned
jit: refusing: possible secrets
  leak.py:1: possible GitHub token
  Remove them (and rotate any real credential that was ever committed or pushed).
  Load secrets from the environment and keep a .env.example with the keys only.
  A false positive can be allowed on that line with a comment containing: jit:allow-secret
rc=1
delete rc=0
== E. push straight to develop (standard) is refused
jit: refusing to push straight to 'develop'; open a pull request instead
== F. guard: valid commands it refuses (false positives)
jit-speckit guard: switching git hooks off skips the secret checks
rc=2   <- a read of the setting
jit-speckit guard: committing on 'main' is not allowed; start a task with /speckit-implement Tnnn (or /jit-speckit:next)
rc=2   <- judged by the branch the chain starts on
jit-speckit guard: stage files by name (git add path/to/file), not everything at once
rc=2   <- a command in another repository
== G. guard: what it refuses as documented
git commit --no-verify -m x  ->  jit-speckit guard: --no-verify skips the secret checks; fix what the hook reports instead
git commit -nm x  ->  jit-speckit guard: commit -n is --no-verify, which skips the secret checks
git -c core.hooksPath=/dev/null commit -m x  ->  jit-speckit guard: switching git hooks off skips the secret checks
git add -A  ->  jit-speckit guard: stage files by name (git add path/to/file), not everything at once
git push origin develop  ->  jit-speckit guard: pushing to 'develop' is not allowed; it only changes through pull requests
env FOO=1 git push --no-verify  ->  jit-speckit guard: --no-verify skips the pre-push secret scan
sh -c 'git add --all'  ->  jit-speckit guard: stage files by name (git add path/to/file), not everything at once
```

</details>
