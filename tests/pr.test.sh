#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # checks are strings evaluated by check()
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
fake_gh
p="$SCRIPTS/pr.sh"

new_repo standard
commit_tasks '- [ ] T001 Add search in `src/search.ts` — #5'

check "when not on the task's branch, then it refuses" 'fails_with "not on T001" "$p" task T001 "feat: add search"'

"$SCRIPTS/branch.sh" T001 >/dev/null
echo 'export const search = 1' > search.ts
check "when there are uncommitted changes, then it refuses" 'fails_with "uncommitted" "$p" task T001 "feat: add search"'
git add search.ts; git commit --quiet -m "feat(search): add search"

printf 'Adds search.\n\n## Evidence\n\n`npm test` passed\n' > "$TMP/body.md"
out="$("$p" task T001 "feat(search): add search" "$TMP/body.md")"
check "when the work is committed, then it pushes and opens the PR into the base" \
  '[[ "$out" == "PR=https://github.com/acme/app/pull/99" ]] && git ls-remote --exit-code origin "$(git branch --show-current)" && grep -q -- "--base develop" "$GH_LOG"'
check "then the body links the issue with Closes #N" 'grep -q "Closes #5" "$GH_LOG"'

out="$("$p" task T001 "feat(search): add search" "$TMP/body.md")"
check "when the PR already exists, then it is reused, not duplicated" '[[ "$(grep -c "^pr create" "$GH_LOG")" == 1 ]]'

sed -i.bak 's/^level: .*/level: full/' .specify/extensions/jit/jit-config.yml
rm -f "$GH_PR"; printf 'No evidence here.\n' > "$TMP/thin.md"
check "when the level is full and the body has no Evidence section, then it refuses" \
  'fails_with "Evidence" "$p" task T001 "feat(search): add search" "$TMP/thin.md"'

sed -i.bak 's/^level: .*/level: standard/' .specify/extensions/jit/jit-config.yml
git switch --quiet main; rm -f "$GH_PR"
mkdir -p specs/002-new
printf '%s\n' '- [ ] T001 Thing in `a` — #11' '- [ ] T002 Other in `b` — #12' > specs/002-new/tasks.md
echo '{ "feature_directory": "specs/002-new" }' > .specify/feature.json
out="$("$p" spec)"
check "when opening the spec PR, then the spec folder is committed on spec/<feature>" \
  '[[ "$(git branch --show-current)" == spec/002-new ]] && [[ -z "$(git status --porcelain specs)" ]] && git ls-remote --exit-code origin spec/002-new'
check "then the spec PR lists the task issues" 'grep -q "#11 #12" "$GH_LOG"'

exit "$FAIL"
