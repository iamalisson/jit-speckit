#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # checks are strings evaluated by check()
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
fake_gh
l="$SCRIPTS/level.sh"
blocks() { grep -c '^<!-- jit:start' .specify/memory/constitution.md; }

new_repo lite
cp "$ROOT/preset/templates/constitution-template.md" .specify/memory/constitution.md 2>/dev/null \
  || { mkdir -p .specify/memory; cp "$ROOT/preset/templates/constitution-template.md" .specify/memory/constitution.md; }
printf '[workspace]\n' > Cargo.toml; printf '{"packageManager":"pnpm@9.0.0","scripts":{"lint":"x","test":"y"}}\n' > package.json
# An install from before these keys existed: level.sh must add them.
sed -i.bak '/^milestone:/d; /^project:/d' .specify/extensions/jit/jit-config.yml

"$l" lite >/dev/null
check "when set to lite, then only the PR template is scaffolded" \
  '[[ -f .github/pull_request_template.md && -f .github/copilot-instructions.md && ! -f .github/workflows/ci.yml && ! -f .github/dependabot.yml ]]'
check "then the constitution has one jit block for lite" '[[ "$(blocks)" == 1 ]] && grep -q "level: lite" .specify/memory/constitution.md'
check "then the branch flow targets main" 'grep -qF "feat/* → main" .specify/memory/constitution.md'
check "then an older config gains empty milestone and project keys (nothing is guessed)" \
  'grep -qx "milestone: \"\"" .specify/extensions/jit/jit-config.yml && grep -qx "project: \"\"" .specify/extensions/jit/jit-config.yml'
check "then Claude settings drop AI attribution from commits and PRs" 'grep -q "\"attribution\"" .claude/settings.json'
check "then every file it wrote is recorded with its SHA-256 (what remove.sh compares against)" \
  'h="$(sha256sum < .githooks/pre-commit 2>/dev/null || shasum -a 256 < .githooks/pre-commit)"; grep -qxF "${h%% *} .githooks/pre-commit" .specify/jit-files.sha256 && [[ "$(grep -c " .githooks/pre-commit$" .specify/jit-files.sha256)" == 1 ]] && "$l" lite >/dev/null && [[ "$(grep -c " .githooks/pre-commit$" .specify/jit-files.sha256)" == 1 ]]'

mkdir -p .github/workflows; echo "# mine" > .github/workflows/ci.yml
echo '{}' > .claude/settings.json
check "when Claude settings exist without attribution (a team that discloses AI use), then they are kept and nobody nags" \
  'out="$("$l" lite)"; [[ "$(cat .claude/settings.json)" == "{}" && "$out" != *"attribution"* ]]'
"$l" standard >/dev/null
check "when going up to standard, then CI is never overwritten if it already exists" '[[ "$(cat .github/workflows/ci.yml)" == "# mine" ]]'
check "then every Dependabot entry waits 7 days before proposing a release (zizmor dependabot-cooldown)" \
  'n=$(grep -c "package-ecosystem:" .github/dependabot.yml); [[ $n -gt 0 && "$(grep -c "default-days: 7" .github/dependabot.yml)" == "$n" ]]'
check "then dependabot covers the detected stacks and targets develop" \
  'grep -q "package-ecosystem: cargo" .github/dependabot.yml && grep -q "package-ecosystem: npm" .github/dependabot.yml && grep -q "target-branch: develop" .github/dependabot.yml'
check "then the stack idioms and test command come from the manifests" \
  'grep -q "cargo clippy" .specify/memory/constitution.md && grep -qF "\`cargo test --all && pnpm test\`" .specify/memory/constitution.md'
check "then the block is replaced, not duplicated" '[[ "$(blocks)" == 1 ]] && grep -q "level: standard" .specify/memory/constitution.md'

rm .github/workflows/ci.yml
"$l" standard >/dev/null
check "when there is no Dockerfile or Terraform, then the security CI has no infra scan" '! grep -q "trivy" .github/workflows/security.yml'
check "when CI is missing, then it is generated with rust and pnpm jobs" \
  'grep -q "cargo clippy --all-targets" .github/workflows/ci.yml && grep -q "pnpm install --frozen-lockfile" .github/workflows/ci.yml && grep -q "pnpm run lint" .github/workflows/ci.yml'
check "then the Node CI uses the current LTS, not a hard-coded major" 'grep -q "node-version: lts/\*" .github/workflows/ci.yml'
check "when the project pins Node, then CI uses that file" \
  '(echo 26 > .node-version; rm .github/workflows/ci.yml; "$l" standard >/dev/null; grep -q "node-version-file: .node-version" .github/workflows/ci.yml; s=$?; rm .node-version; exit $s)'

rm -f .github/workflows/security.yml .github/dependabot.yml
mkdir -p services/api terraform/envs/prod
printf 'FROM scratch\n' > Dockerfile; printf 'FROM scratch\n' > services/api/Dockerfile.prod
echo 'terraform {}' > terraform/envs/prod/main.tf
"$l" standard >/dev/null
check "when a Dockerfile and Terraform exist, then the security CI scans them with checksum-verified trivy" \
  'grep -q "trivy config --exit-code 1 --severity HIGH,CRITICAL" .github/workflows/security.yml && grep -q "sha256sum -c" .github/workflows/security.yml'
check "then Dependabot updates every folder with a Dockerfile, and every folder with Terraform" \
  '[[ "$(grep -A1 "package-ecosystem: docker" .github/dependabot.yml | grep -c "directory:")" == 2 ]] && grep -q "directory: \"/\"" .github/dependabot.yml && grep -q "directory: \"/services/api\"" .github/dependabot.yml && grep -A1 "package-ecosystem: terraform" .github/dependabot.yml | grep -q "directory: \"/terraform/envs/prod\""'
rm -rf Dockerfile services terraform

"$l" full >/dev/null
check "when going up to full, then staging is created on origin" 'git ls-remote --exit-code origin staging'
check "then SECURITY.md, CODEOWNERS and the release workflow exist" '[[ -f SECURITY.md && -f .github/CODEOWNERS && -f .github/workflows/release.yml ]]'

cp .specify/memory/constitution.md "$TMP/const.bak"
sed -i.bak '/<!-- jit:end -->/d' .specify/memory/constitution.md; echo "my own principle" >> .specify/memory/constitution.md
check "when the jit:end marker is missing, then it refuses and keeps the user's text" \
  'fails_with "no '"'"'<!-- jit:end -->'"'"'" "$l" lite && grep -q "my own principle" .specify/memory/constitution.md'
cp "$TMP/const.bak" .specify/memory/constitution.md

out="$("$l" lite)"
check "when going back down to lite, then no file is deleted and it says so" \
  '[[ -f SECURITY.md && -f .github/workflows/ci.yml && "$out" == *"were kept"* ]] && grep -q "level: lite" .specify/memory/constitution.md'
check "then the level is stored in the config" 'grep -qx "level: lite" .specify/extensions/jit/jit-config.yml'
check "when given an unknown level, then it refuses" '! "$l" huge'

printf '# Custom constitution\n\n## Governance\n\nRules.\n' > .specify/memory/constitution.md
"$l" standard --no-branches >/dev/null
check "when the constitution has no jit block, then it is inserted before Governance and the rest is kept" \
  '[[ "$(blocks)" == 1 ]] && grep -q "^# Custom constitution" .specify/memory/constitution.md && awk "/jit:end/{e=NR} /^## Governance/{g=NR} END{exit !(e<g)}" .specify/memory/constitution.md'

rm Cargo.toml package.json .github/workflows/ci.yml
"$l" standard --no-branches >/dev/null
check "when no stack is detected, then CI is a clearly marked placeholder" 'grep -q "no stack detected" .github/workflows/ci.yml'

# Security scaffolding, pinning and git hooks (fresh repo).
rm -rf "$TMP/repo" "$TMP/origin.git"; cd "$TMP"
new_repo lite
printf '{"scripts":{"test":"x"}}\n' > package.json
"$l" lite >/dev/null
check "when set to lite, then the git hooks are installed, executable and enabled" \
  '[[ -x .githooks/pre-commit && -x .githooks/pre-push && "$(git config core.hooksPath)" == .githooks ]]'
check "then lite has no security workflow yet" '[[ ! -f .github/workflows/security.yml ]]'
"$l" standard >/dev/null
check "when set to standard, then the security workflow scans secrets, dependencies and workflows" \
  'grep -q "gitleaks git --redact" .github/workflows/security.yml && grep -q "osv-scanner scan source" .github/workflows/security.yml && grep -q "zizmorcore/zizmor-action@" .github/workflows/security.yml'
check "then downloaded scanners are checksum-verified" '[[ "$(grep -c "sha256sum -c -" .github/workflows/security.yml)" == 2 ]]'
check "then it also runs weekly, for new CVEs in unchanged dependencies" 'grep -q "cron:" .github/workflows/security.yml'
check "then standard has no SAST job (that is full)" '! grep -q "semgrep scan" .github/workflows/security.yml'
check "then every action in generated workflows is pinned to a full commit SHA" \
  '! grep -hE "uses: [^ ]+@" .github/workflows/*.yml | grep -vE "@[0-9a-f]{40}( |$)"'
check "then every checkout says persist-credentials: false (the default keeps the token on disk)" \
  'n=$(grep -c "actions/checkout@" .github/workflows/ci.yml); [[ $n -gt 0 && "$(grep -A2 "actions/checkout@" .github/workflows/ci.yml | grep -c "persist-credentials: false")" == "$n" ]]'
rm .github/workflows/security.yml
"$l" full >/dev/null
check "when level.sh full writes security.yml, then Semgrep runs from semgrep/semgrep@sha256:<64 hex> equal to SEMGREP_DIGEST, with the default and OWASP rules" \
  'd="$(sed -nE "s/^SEMGREP_DIGEST=\"([0-9a-f]{64})\".*/\1/p" "$SCRIPTS/pins.sh")"; [[ -n "$d" ]] && grep -qE "^ +image: semgrep/semgrep@sha256:$d( |$)" .github/workflows/security.yml && grep -q "semgrep scan --config p/default --config p/owasp-top-ten --error --metrics off" .github/workflows/security.yml'
check "then nothing installs Semgrep by version alone" '! grep -qE "semgrep==|install .*semgrep|semgrep/semgrep:" .github/workflows/security.yml'

rm -rf "$TMP/repo" "$TMP/origin.git"; cd "$TMP"
new_repo standard
git config core.hooksPath .husky
out="$("$l" standard --no-branches)"
check "when the repo already uses its own hooks (husky), then they are not replaced and it says how to add ours" \
  '[[ "$(git config core.hooksPath)" == .husky ]] && grep -q "secrets.sh staged" <<<"$out"'

# `gh repo create --clone`: an origin, but no commits yet.
git init --quiet --bare "$TMP/empty-origin.git"; git clone --quiet "$TMP/empty-origin.git" "$TMP/empty" 2>/dev/null
cd "$TMP/empty"; git config user.email t@t; git config user.name t
mkdir -p .specify/extensions/jit && ln -s "$ROOT/extension/scripts" .specify/extensions/jit/scripts
check "when the repo has an origin but no commits yet, then setup succeeds and says the branches come later" \
  'out="$("$l" standard 2>&1)" && grep -q "develop not created yet (no commits)" <<<"$out" && [[ -f .specify/memory/constitution.md ]]'

# Committed locally, nothing pushed yet: setup must not push local (unscanned) commits anywhere.
git init --quiet --bare "$TMP/unpushed-origin.git"; git clone --quiet "$TMP/unpushed-origin.git" "$TMP/unpushed" 2>/dev/null
cd "$TMP/unpushed"; git config user.email t@t; git config user.name t
mkdir -p .specify/extensions/jit && ln -s "$ROOT/extension/scripts" .specify/extensions/jit/scripts
echo x > a.txt; git add a.txt; git commit --quiet --no-verify -m local
check "when the default branch isn't on origin yet, then setup pushes nothing and says to push it first" \
  'out="$("$l" standard 2>&1)" && grep -q "origin/develop not created yet" <<<"$out" && [[ -z "$(git ls-remote --heads origin)" ]]'


# ── Hooks in repos that already use the pre-commit framework or husky ──
rm -rf "$TMP/repo" "$TMP/origin.git"; cd "$TMP"
new_repo lite
printf 'repos:\n  - repo: https://github.com/x/y\n    rev: v1\n    hooks:\n      - id: a\n' > .pre-commit-config.yaml
out="$("$l" lite --no-branches)"
check "when the repo uses the pre-commit framework, then both jit hooks are appended with the file's own indentation" \
  'grep -q "^  - repo: local$" .pre-commit-config.yaml && grep -q "^      - id: jit-secrets$" .pre-commit-config.yaml && grep -q "^        stages: \[pre-push\]$" .pre-commit-config.yaml && [[ -z "$(git config core.hooksPath)" ]]'
check "then it says the hooks are not active in this clone until pre-commit install runs" \
  'grep -q "pre-commit install --hook-type pre-commit --hook-type pre-push" <<<"$out"'
check "when run again, then nothing is appended twice" '"$l" lite --no-branches >/dev/null; [[ "$(grep -c "id: jit-secrets" .pre-commit-config.yaml)" == 1 ]]'
if python3 -c "import yaml" 2>/dev/null; then
  check "then the config is still valid YAML with one local repo holding the two hooks" \
    'python3 -c "import yaml,sys; r=[x for x in yaml.safe_load(open(\".pre-commit-config.yaml\"))[\"repos\"] if x[\"repo\"]==\"local\"]; sys.exit(0 if len(r)==1 and [h[\"id\"] for h in r[0][\"hooks\"]]==[\"jit-secrets\",\"jit-prepush\"] else 1)"'
else
  echo "skip - pre-commit config YAML check (python3 with PyYAML not available here)"
fi
printf 'repos:\n-   repo: local\n    hooks:\n    -   id: jit-secrets\n        entry: bash .specify/extensions/jit/scripts/secrets.sh staged\n        language: system\n' > .pre-commit-config.yaml
"$l" lite --no-branches >/dev/null
check "when only the commit hook was added by hand (4-space style), then only the push hook is appended, in that style" \
  '[[ "$(grep -c "scripts/secrets.sh" .pre-commit-config.yaml)" == 1 ]] && grep -q "^    -   id: jit-prepush$" .pre-commit-config.yaml && grep -q "^        entry: bash .specify/extensions/jit/scripts/prepush.sh$" .pre-commit-config.yaml'
rm .pre-commit-config.yaml; mkdir -p .husky; echo "npm test" > .husky/pre-commit
"$l" lite --no-branches >/dev/null
check "when the repo uses husky, then the checks are appended to its hook files and the existing line is kept" \
  '[[ "$(head -1 .husky/pre-commit)" == "npm test" ]] && grep -q "secrets.sh staged" .husky/pre-commit && grep -qF "prepush.sh \"\$@\"" .husky/pre-push && [[ -z "$(git config core.hooksPath)" ]]'

# ── CI from the constitution's commands, managed files, existing PR gates ──
rm -rf "$TMP/repo" "$TMP/origin.git"; cd "$TMP"
new_repo standard
mkdir -p .specify/memory; cp "$ROOT/preset/templates/constitution-template.md" .specify/memory/constitution.md
printf '[project]\nname="x"\n' > pyproject.toml; touch uv.lock
"$l" standard --no-branches >/dev/null
check "when the constitution's Commands are placeholders, then CI uses the stack defaults and carries the managed-file line" \
  'grep -q "uv run pytest" .github/workflows/ci.yml && [[ "$(head -1 .github/workflows/ci.yml)" == "# jit-speckit: managed file"* ]]'
sed -i.bak 's/^\*\*Commands\*\*.*/**Commands**: build `uv build` · test `uv run pytest -q tests` · lint `uv run ruff check src \&\& uv run mypy src`/' .specify/memory/constitution.md
"$l" standard --no-branches >/dev/null
check "when adopt filled the Commands line, then the managed CI is re-created with those commands: lint, test, build" \
  '[[ "$(grep -o -- "- run: uv run ruff check src && uv run mypy src\|- run: uv run pytest -q tests\|- run: uv build" .github/workflows/ci.yml | tr "\n" "|")" == "- run: uv run ruff check src && uv run mypy src|- run: uv run pytest -q tests|- run: uv build|" ]] && ! grep -q "ruff check \.$" .github/workflows/ci.yml'
check "then the constitution's jit block runs the suite with that test command" 'grep -qF "\`uv run pytest -q tests\`" .specify/memory/constitution.md'
sed -i.bak '1d' .github/workflows/ci.yml; echo "# edited by hand" >> .github/workflows/ci.yml
"$l" standard --no-branches >/dev/null
check "when the managed-file line is removed, then the file is the user's and is kept" 'grep -q "# edited by hand" .github/workflows/ci.yml'
rm .github/workflows/ci.yml .github/workflows/security.yml
printf 'name: Checks\non:\n  pull_request:\njobs:\n  t:\n    runs-on: ubuntu-latest\n    steps:\n      - run: make test\n' > .github/workflows/checks.yml
out="$("$l" standard --no-branches)"
check "when a workflow of the project's own already checks pull requests, then no second CI is generated and it says which" \
  '[[ ! -f .github/workflows/ci.yml && -f .github/workflows/security.yml ]] && grep -q "checks.yml" <<<"$out"'

# ── Refresh: newer pins kept, files of releases before the marker recognized ──
vn() { (source "$SCRIPTS/lib.sh"; version_newer "$@"); }
check "when versions are compared, then v1.10.0 is newer than v1.9.9 (numbers, not text)" 'vn v1.10.0 v1.9.9 && ! vn v1.9.9 v1.10.0'
check "then v7.0.1 is not newer than v7.1.0, and v2 equals v2.0.0" '! vn v7.0.1 v7.1.0 && vn v7.1.0 v7.0.1 && ! vn v2 v2.0.0 && ! vn v2.0.0 v2'
check "then a branch name like master is never newer" '! vn master v1.0.0 && ! vn v1.0.0 master'

source "$SCRIPTS/pins.sh"; co="${PIN_CHECKOUT%% *}"; co="${co%@*}"
newer="$co@1111111111111111111111111111111111111111 # v99.0.0"; older="$co@2222222222222222222222222222222222222222 # v1.0.0"
sed -i.bak "s|uses: $co@.*|uses: $newer|" .github/workflows/security.yml
out="$("$l" standard --no-branches)"
check "when a managed workflow has a newer checkout pin than pins.sh, then level.sh keeps it and prints kept newer pin" \
  'grep -qF "uses: $newer" .github/workflows/security.yml && ! grep -qF "uses: $PIN_CHECKOUT" .github/workflows/security.yml && [[ "$(grep -cxF "kept newer pin: $co v99.0.0" <<<"$out")" == 1 ]]'
sed -i.bak "s|uses: $co@.*|uses: $older|" .github/workflows/security.yml
out="$("$l" standard --no-branches)"
check "when it has an older pin, then it is replaced by pins.sh's" \
  'grep -qF "uses: $PIN_CHECKOUT" .github/workflows/security.yml && ! grep -qF "$older" .github/workflows/security.yml && ! grep -q "kept newer pin" <<<"$out"'

rm -rf "$TMP/repo" "$TMP/origin.git"; cd "$TMP"
new_repo standard
mkdir -p .githooks .github/workflows
cp "$ROOT/tests/fixtures/v1.3.0-pre-commit" .githooks/pre-commit
cp "$ROOT/tests/fixtures/v1.3.1-close-linked-issues.yml" .github/workflows/close-linked-issues.yml
printf 'version: 2\nupdates: []\n' > .github/dependabot.yml
echo "my own hook" > .githooks/pre-push
out="$("$l" standard --no-branches)"
check "when .githooks/pre-commit is v1.3.0's exact file, then level.sh replaces it and it carries the marker" \
  'head -2 .githooks/pre-commit | grep -q "^# jit-speckit: managed file" && grep -qxF "updated: .githooks/pre-commit" <<<"$out"'
check "when close-linked-issues.yml is v1.3.1's, then it is kept and named with its versions" \
  'cmp -s "$ROOT/tests/fixtures/v1.3.1-close-linked-issues.yml" .github/workflows/close-linked-issues.yml && grep -qF "kept (written by jit-speckit 1.0.0,1.2.0,1.3.0,1.3.1, no marker): .github/workflows/close-linked-issues.yml — delete it to get the current one" <<<"$out"'
check "when an old hook matched, then a generated file without the marker is named as possibly an old release's" \
  'grep -qF "kept (written by jit-speckit 1.2.0,1.3.0,1.3.1 or older, no marker): .github/dependabot.yml — delete it to get the current one" <<<"$out"'
check "then a user's own unmarked file is still kept: as before" \
  '[[ "$(cat .githooks/pre-push)" == "my own hook" ]] && grep -qxF "kept:    .githooks/pre-push" <<<"$out"'

exit "$FAIL"
