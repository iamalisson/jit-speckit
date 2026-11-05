#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # checks are strings evaluated by check()
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
m="$SCRIPTS/mutants.sh"

new_repo standard
mkdir -p .specify/memory
check "when the constitution has no mutate command, then it says so and does not fail" \
  'out="$("$m")" && grep -q "^mutants missing" <<<"$out" && grep -q "jit-speckit:adopt" <<<"$out"'

# A fake mutation tool: records what it was given, exits as told.
cat > "$TMP/mutate.sh" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$JIT_CHANGED_FILES" > "$TMP/seen.files"; cp "$JIT_DIFF_FILE" "$TMP/seen.diff"
exit "$(cat "$TMP/mutate.rc")"
FAKE
chmod +x "$TMP/mutate.sh"; export TMP
printf '**Commands**: build `[BUILD_COMMAND]` · test `npm test` · lint `[LINT_COMMAND]` · mutate `%s`\n' "$TMP/mutate.sh" > .specify/memory/constitution.md

commit_tasks '- [ ] T001 Add search in `src/search.ts` — #5'
"$SCRIPTS/branch.sh" T001 >/dev/null
check "when nothing changed on the branch, then it is skipped" 'out="$("$m")" && grep -q "^mutants skipped" <<<"$out"'

mkdir -p src tests; echo 'export const search = 1' > src/search.ts; echo 'test' > tests/search.test.ts
git add src tests; git commit --quiet -m "feat: search"
echo 0 > "$TMP/mutate.rc"
check "when every mutant is caught, then it reports ok and the command saw the changed sources without the tests" \
  'out="$("$m")" && grep -q "^mutants ok" <<<"$out" && [[ "$(cat "$TMP/seen.files")" == "src/search.ts" ]] && grep -q "^+export const search" "$TMP/seen.diff"'
echo 2 > "$TMP/mutate.rc"
check "when a mutant survives, then it reports survivors and where the log is" \
  'out="$("$m")" && grep -q "^mutants survivors" <<<"$out" && grep -q "mutants.log" <<<"$out"'
check "then the report lives under .git, never in the tree" '[[ -z "$(git status --porcelain)" ]]'

exit "$FAIL"
