#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # checks are strings evaluated by check()
# remove.sh keeps what the user changed. A stub `specify` is enough: remove.sh only needs the command
# to exist, so this runs on every CI job (bash 3.2 and BSD included).
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
fake_gh
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/bin/specify"; chmod +x "$TMP/bin/specify"
rm_out() { "$ROOT/bin/remove.sh" . 2>&1 || true; }

new_repo standard
"$SCRIPTS/level.sh" standard --no-branches >/dev/null
git add .github/workflows/security.yml; git commit --quiet -m security
echo "# my step" >> .github/workflows/security.yml
echo "# mine" >> .github/dependabot.yml
out="$(rm_out)"
check "when a managed workflow (committed alone) is edited and not committed, then remove.sh keeps it and prints kept (edited)" \
  '[[ -f .github/workflows/security.yml ]] && grep -qxF "kept (edited): .github/workflows/security.yml" <<<"$out"'
check "when an untracked managed file differs from its recorded SHA-256, then it is kept" \
  '[[ -f .github/dependabot.yml ]] && grep -qxF "kept (edited): .github/dependabot.yml" <<<"$out"'
check "when a managed file is unchanged, then it is still removed" \
  '[[ ! -e .github/workflows/ci.yml ]] && grep -qxF "removed: .github/workflows/ci.yml" <<<"$out"'
check "then the written-file record is removed too" '[[ ! -e .specify/jit-files.sha256 ]]'

# A project set up before the record existed: only a tracked, unchanged marked file is removed.
rm -rf "$TMP/repo" "$TMP/origin.git"; cd "$TMP"
new_repo standard
"$SCRIPTS/level.sh" standard --no-branches >/dev/null
rm -f .specify/jit-files.sha256
git add .github/workflows/security.yml; git commit --quiet -m security
out="$(rm_out)"
check "when there is no record, then a tracked unchanged marked file is removed and an untracked one is kept" \
  '[[ ! -e .github/workflows/security.yml && -f .github/dependabot.yml ]] && grep -qxF "kept (edited): .github/dependabot.yml" <<<"$out"'

exit "$FAIL"
