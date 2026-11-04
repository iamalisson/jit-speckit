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

"$l" lite >/dev/null
check "when set to lite, then only the PR template is scaffolded" \
  '[[ -f .github/pull_request_template.md && ! -f .github/workflows/ci.yml && ! -f .github/dependabot.yml ]]'
check "then the constitution has one jit block for lite" '[[ "$(blocks)" == 1 ]] && grep -q "level: lite" .specify/memory/constitution.md'
check "then the branch flow targets main" 'grep -qF "feat/* → main" .specify/memory/constitution.md'

mkdir -p .github/workflows; echo "# mine" > .github/workflows/ci.yml
"$l" standard >/dev/null
check "when going up to standard, then CI is never overwritten if it already exists" '[[ "$(cat .github/workflows/ci.yml)" == "# mine" ]]'
check "then dependabot covers the detected stacks and targets develop" \
  'grep -q "package-ecosystem: cargo" .github/dependabot.yml && grep -q "package-ecosystem: npm" .github/dependabot.yml && grep -q "target-branch: develop" .github/dependabot.yml'
check "then the stack idioms and test command come from the manifests" \
  'grep -q "cargo clippy" .specify/memory/constitution.md && grep -qF "\`cargo test --all && pnpm test\`" .specify/memory/constitution.md'
check "then the block is replaced, not duplicated" '[[ "$(blocks)" == 1 ]] && grep -q "level: standard" .specify/memory/constitution.md'

rm .github/workflows/ci.yml
"$l" standard >/dev/null
check "when CI is missing, then it is generated with rust and pnpm jobs" \
  'grep -q "cargo clippy --all-targets" .github/workflows/ci.yml && grep -q "pnpm install --frozen-lockfile" .github/workflows/ci.yml && grep -q "pnpm run lint" .github/workflows/ci.yml'

"$l" full >/dev/null
check "when going up to full, then staging is created on origin" 'git ls-remote --exit-code origin staging'
check "then SECURITY.md, CODEOWNERS and the release workflow exist" '[[ -f SECURITY.md && -f .github/CODEOWNERS && -f .github/workflows/release.yml ]]'

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
check "then checkout never keeps the token on disk" '! grep -A2 "actions/checkout@" .github/workflows/ci.yml | grep "persist-credentials: true"'
rm .github/workflows/security.yml
"$l" full >/dev/null
check "when set to full, then semgrep with the OWASP rules is part of the security workflow" 'grep -q "semgrep==.*--config p/owasp-top-ten" .github/workflows/security.yml'

rm -rf "$TMP/repo" "$TMP/origin.git"; cd "$TMP"
new_repo standard
git config core.hooksPath .husky
out="$("$l" standard --no-branches)"
check "when the repo already uses its own hooks (husky), then they are not replaced and it says how to add ours" \
  '[[ "$(git config core.hooksPath)" == .husky ]] && grep -q "secrets.sh staged" <<<"$out"'

exit "$FAIL"
