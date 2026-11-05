#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # checks are strings evaluated by check()
# End-to-end setup against the real spec-kit CLI. Skipped when `specify` is not installed.
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
if ! command -v specify >/dev/null; then echo "skip - specify CLI not installed"; exit 0; fi
fake_gh

# A PATH without the Claude Code CLI, as on a CI runner, even on a machine that has it.
mkdir -p "$TMP/path"
for tool in specify git; do ln -s "$(command -v "$tool")" "$TMP/path/$tool"; done
export PATH="$TMP/bin:$TMP/path:/usr/bin:/bin"
if command -v claude >/dev/null; then echo "FAIL - could not hide claude from PATH"; exit 1; fi

setup() { # setup <args...>: run setup.sh; on failure print its output and fail the test
  local out
  if ! out="$("$ROOT/bin/setup.sh" "$@" 2>&1)"; then echo "FAIL - setup.sh $* failed:"; echo "$out"; exit 1; fi
  echo "$out" > "$TMP/setup.out"
}

git init --quiet --bare "$TMP/origin.git"
git clone --quiet "$TMP/origin.git" "$TMP/app" 2>/dev/null
cd "$TMP/app"
git config user.email t@t; git config user.name t
echo '{"name":"app","scripts":{"test":"echo ok"}}' > package.json
git add -A; git commit --quiet -m init; git branch -M main; git push --quiet origin main
git remote set-head origin main >/dev/null 2>&1 || true

setup . --level standard
check "when the agent CLI is missing, then setup still succeeds and warns about it" 'grep -q "Claude Code CLI not found" "$TMP/setup.out"'
check "when set up, then the five hooks are registered" \
  'for h in after_tasks after_converge after_analyze before_implement after_implement; do grep -q "^  $h:" .specify/extensions.yml || exit 1; done'
check "then spec-kit registers the hook commands as skills" '[[ -d .claude/skills/speckit-jit-branch && -d .claude/skills/speckit-jit-issues ]]'
check "then the preset templates win over the core ones" 'out="$(specify preset resolve tasks-template)"; grep -q "from: jit" <<<"$out"'
check "then spec-kit's implement command ends with jit's one-task, no-tick override" \
  'f=.claude/skills/speckit-implement/SKILL.md; grep -q "Do not mark tasks \`\[X\]\`" "$f" && [[ "$(grep -n "mark the task off as \[X\]" "$f" | cut -d: -f1)" -lt "$(grep -n "Do not mark tasks" "$f" | cut -d: -f1)" ]]'
check "then the constitution starts from the jit template with a standard block" \
  'grep -q "\[PROJECT_NAME\] Constitution" .specify/memory/constitution.md && grep -q "level: standard" .specify/memory/constitution.md'
check "then develop exists on origin and CI was scaffolded" 'git ls-remote --exit-code origin develop && [[ -f .github/workflows/ci.yml ]]'

setup .
check "when run again without a level, then it keeps the current level" 'grep -qx "level: standard" .specify/extensions/jit/jit-config.yml'

check "when --level has no value, then it fails with the usage line" 'fails_with "Usage:" "$ROOT/bin/setup.sh" . --level'
check "when the level is unknown, then it fails and names it" 'fails_with "unknown level" "$ROOT/bin/setup.sh" . --level huge'
check "when spec-kit itself fails, then its own message is shown" \
  'fails_with "Unknown integration" "$ROOT/bin/setup.sh" "$TMP/bad" --integration not-an-agent' # spec-kit's words, not jit's

# ── Removal: the reverse of setup, then a reinstall from zero ──
remove() { local out; if ! out="$("$ROOT/bin/remove.sh" "$@" 2>&1)"; then echo "FAIL - remove.sh $* failed:"; echo "$out"; exit 1; fi; echo "$out" > "$TMP/remove.out"; }
sed -i.bak 's/\[PROJECT_NAME\]/App/' .specify/memory/constitution.md; rm -f .specify/memory/constitution.md.bak
sed -i.bak 1d .github/workflows/ci.yml; rm -f .github/workflows/ci.yml.bak # the user took ci.yml over (marker gone)
remove .
check "when removed, then nothing of jit is left in the tree (extension, preset, skills, scaffold)" \
  '! git status --porcelain --untracked-files=all | grep -qi jit && [[ ! -e .githooks && ! -e .github/workflows/security.yml && ! -e .github/dependabot.yml && ! -e .claude/settings.json ]]'
check "then spec-kit's templates and implement command are its own again" \
  'specify preset resolve tasks-template | grep -q "from: core" && ! grep -q "Do not mark tasks" .claude/skills/speckit-implement/SKILL.md'
check "then the git hooks setting is unset and a file the user took over is kept" '[[ -z "$(git config core.hooksPath)" && -f .github/workflows/ci.yml ]]'
check "then the constitution keeps the user's text without the jit block" \
  '! grep -q "<!-- jit:start" .specify/memory/constitution.md && grep -q "^# App Constitution" .specify/memory/constitution.md && grep -q "^## Governance" .specify/memory/constitution.md'
check "when run again, then it succeeds with nothing to remove" '"$ROOT/bin/remove.sh" . | { ! grep -q "^removed:"; }'

printf 'repos:\n  - repo: https://github.com/x/y\n    rev: v1\n    hooks:\n      - id: a\n' > .pre-commit-config.yaml; cp .pre-commit-config.yaml "$TMP/pc.orig"
setup . --level lite
check "when the repo uses the pre-commit framework, then remove puts its config back as it was" \
  'grep -q "id: jit-prepush" .pre-commit-config.yaml && "$ROOT/bin/remove.sh" . >/dev/null && cmp -s "$TMP/pc.orig" .pre-commit-config.yaml'
rm .pre-commit-config.yaml

setup . --level lite
remove . --with-speckit
check "when removed with --with-speckit, then spec-kit is gone too and setup starts from zero again" \
  '[[ ! -e .specify && ! -e .claude ]] && out="$("$ROOT/bin/setup.sh" . --level lite)" && grep -q "spec-kit: initialized" <<<"$out" && [[ -d .specify/extensions/jit ]]'

exit "$FAIL"
