#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # checks are strings evaluated by check()
# Static checks on this repo's own workflows and docs: pins, drift, references.
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
cd "$ROOT"

# The harness itself: a check must fail when any step fails, and must never end the file.
harness="$(FAIL=0; check "a failing first step" 'false; true'; check "an exit inside" 'exit 0'; echo "still running")"
check "the test harness fails a check whose first step fails (not only its last)" 'grep -q "^FAIL - a failing first step" <<<"$harness"'
check "an exit inside a check ends only that check, never the test file" 'grep -q "^still running$" <<<"$harness"'

workflows="$(find .github/workflows extension/scaffold -name '*.yml' -path '*workflows*')"

check "every action in every workflow is pinned to a full commit SHA" \
  '! grep -hE "uses: [^ ]+@" $workflows | grep -vE "@[0-9a-f]{40}( |$)"'

# An action pinned in pins.sh must use that same SHA everywhere, so one bump updates everything.
drift=""
while IFS= read -r line; do
  ref="${line#*=\"}"; ref="${ref%% *}"; action="${ref%@*}"
  other="$(grep -hoE "uses: $action@[0-9a-f]{40}" $workflows | sed 's/^uses: //' | sort -u | grep -vx "$ref" || true)"
  [[ -z "$other" ]] || drift+="$other (pins.sh: $ref) "
done < <(grep -E '^PIN_[A-Z_]+="' extension/scripts/pins.sh)
check "then actions also in pins.sh use the same SHA everywhere${drift:+ — drift: $drift (fix: bin/sync-pins.sh)}" '[[ -z "$drift" ]]'

if python3 -c "import yaml" 2>/dev/null; then
  check "every workflow is valid YAML" 'python3 -c "import sys, yaml; [yaml.safe_load(open(f)) for f in sys.argv[1:]]" $workflows'
else
  echo "skip - YAML parse check (python3 with PyYAML not available here)"
fi

# bin/sync-pins.sh, on a copy: a Dependabot-style bump in every workflow is copied into pins.sh.
copy="$TMP/pins-repo"; mkdir -p "$copy/extension/scripts"
cp -R bin .github "$copy/"; cp extension/scripts/pins.sh "$copy/extension/scripts/"; cp -R extension/scaffold "$copy/extension/"
old="$(sed -nE 's/^PIN_CHECKOUT="actions\/checkout@([0-9a-f]{40}).*/\1/p' extension/scripts/pins.sh)"
new=1111111111111111111111111111111111111111
find "$copy/.github/workflows" -name '*.yml' -exec sed -i.bak "s/checkout@$old # v[0-9.]*/checkout@$new # v9.9.9/" {} +
check "when Dependabot bumped an action in every workflow, then sync-pins copies it into pins.sh" \
  '"$copy/bin/sync-pins.sh" | grep -q "SYNCED=1" && grep -qx "PIN_CHECKOUT=\"actions/checkout@$new # v9.9.9\"" "$copy/extension/scripts/pins.sh"'
check "then sync-pins keeps pins.sh executable (it rewrites in place)" '[[ -x "$copy/extension/scripts/pins.sh" ]]'
check "then sync-pins also updates the scaffold workflows Dependabot doesn't see" \
  'grep -q "uses: actions/checkout@$new # v9.9.9" "$copy/extension/scaffold/full/.github/workflows/release.yml" && ! grep -rq "checkout@$old" "$copy/extension/scaffold"'
cp "$copy/.github/workflows/test.yml" "$copy/.github/workflows/other.yml"
sed -i.bak "s/checkout@$new # v9.9.9/checkout@$old # v4.4.0/" "$copy/.github/workflows/other.yml"
check "when workflows disagree on an action, then sync-pins refuses and lists both" \
  'out="$("$copy/bin/sync-pins.sh" 2>&1)" && exit 1; grep -q "$old" <<<"$out" && grep -q "$new" <<<"$out"'

# The spec-kit version jit-speckit is tested with is written in three places; they must agree.
sk="$(sed -nE 's/^SPECKIT_VERSION="(v[0-9.]+)".*/\1/p' bin/setup.sh)"
check "the spec-kit version in setup.sh ($sk) matches the init skill and the README badge" \
  '[[ -n "$sk" ]] && grep -qF "spec-kit.git@$sk\`" skills/init/SKILL.md && grep -qF "spec--kit-$sk-" README.md && grep -qF "alt=\"spec-kit $sk\"" README.md'

refs=docs/references.yaml
check "every reference has a title, url, use_when and key" \
  '[[ $(grep -c "^ *- title: " $refs) -gt 0 && $(grep -c "^ *- title: " $refs) == $(grep -c "^ *url: https://" $refs) && $(grep -c "^ *- title: " $refs) == $(grep -c "^ *use_when: " $refs) && $(grep -c "^ *- title: " $refs) == $(grep -c "^ *key: " $refs) ]]'
check "then no reference is listed twice" '[[ -z "$(grep -oE "url: \S+" $refs | sort | uniq -d)" ]]'
check "then no reference is Wikipedia (primary sources only)" '! grep -q "wikipedia.org" $refs'

exit "$FAIL"
