#!/usr/bin/env bash
# shellcheck disable=SC2016  # checks are strings evaluated by check()
# End-to-end setup against the real spec-kit CLI. Skipped when `specify` is not installed.
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
if ! command -v specify >/dev/null; then echo "skip - specify CLI not installed"; exit 0; fi
fake_gh

git init --quiet --bare "$TMP/origin.git"
git clone --quiet "$TMP/origin.git" "$TMP/app" 2>/dev/null
cd "$TMP/app"
git config user.email t@t; git config user.name t
echo '{"name":"app","scripts":{"test":"echo ok"}}' > package.json
git add -A; git commit --quiet -m init; git branch -M main; git push --quiet origin main
git remote set-head origin main >/dev/null 2>&1 || true

if ! out="$("$ROOT/bin/setup.sh" . --level standard 2>&1)"; then echo "FAIL - setup.sh failed:"; echo "$out"; exit 1; fi
check "when set up, then the four hooks are registered" \
  'for h in after_tasks after_analyze before_implement after_implement; do grep -q "^  $h:" .specify/extensions.yml || exit 1; done'
check "then spec-kit registers the hook commands as skills" '[[ -d .claude/skills/speckit-jit-branch && -d .claude/skills/speckit-jit-issues ]]'
check "then the preset templates win over the core ones" 'specify preset resolve tasks-template | grep -q "jit"'
check "then the constitution starts from the jit template with a standard block" \
  'grep -q "\[PROJECT_NAME\] Constitution" .specify/memory/constitution.md && grep -q "level: standard" .specify/memory/constitution.md'
check "then develop exists on origin and CI was scaffolded" 'git ls-remote --exit-code origin develop && [[ -f .github/workflows/ci.yml ]]'

"$ROOT/bin/setup.sh" . >/dev/null
check "when run again without a level, then it keeps the current level" 'grep -qx "level: standard" .specify/extensions/jit/jit-config.yml'

exit "$FAIL"
