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

# F2.4: the guard's "onFailure": "block" needs Claude Code 2.1.295, so no doc may give a lower minimum.
mins="$(grep -ohE "Claude Code v?[0-9]+\.[0-9]+\.[0-9]+ or (newer|later)" README.md docs/*.md .specify/memory/constitution.md | awk '{ sub(/^v/, "", $3); print $3 }' | tr '\n' ' ')"
low=""
for v in $mins; do
  IFS=. read -r v1 v2 v3 <<<"$v"
  if ((v1 < 2 || (v1 == 2 && (v2 < 1 || (v2 == 1 && v3 < 295))))); then low+=" $v"; fi
done
check "when hooks.json uses onFailure, then every \"Claude Code X or newer\" in the docs is 2.1.295 or newer (found: ${mins:-none}${low:+; too low:$low}) and the README says nothing about older versions" \
  '! grep -q "\"onFailure\"" hooks/hooks.json || { [[ -n "$mins" && -z "$low" ]] && ! grep -qi "older versions" README.md; }'

# F1.6: close-linked-issues' step, its run: block run as Actions runs it (bash -e), with a fake gh
# that fails to close #12.
sed -n '/^        run: |$/,$p' extension/scaffold/standard/.github/workflows/close-linked-issues.yml | sed '1d; s/^          //' > "$TMP/close-step.sh"
mkdir -p "$TMP/closebin"
printf '#!/bin/sh\necho "$*" >> "%s"\n[ "$3" = 12 ] || exit 0\necho "HTTP 403: Resource not accessible" >&2; exit 1\n' "$TMP/close.log" > "$TMP/closebin/gh"
chmod +x "$TMP/closebin/gh"
check "when the body says \"fixes #12\" and \"Closes #3\" and closing 12 fails, then the step exits non-zero and names #12" \
  'out="$(BODY="fixes #12 and Closes #3" REPO=acme/app PR=7 BASE=develop PATH="$TMP/closebin:$PATH" bash -eo pipefail "$TMP/close-step.sh" 2>&1)" && exit 1; grep -q "could not close: #12" <<<"$out"'
check "then gh issue close 3 is still called" 'grep -q "^issue close 3 " "$TMP/close.log"'

# F3.1/F4.3: a security finding reaches the PR as one line, never its detail: both prompts say so.
check "the review prompt's Report section and pr.md step 5 say a security finding is one 'Security: reported privately (<id>)' line" \
  'sed -n "/^## Report/,\$p" extension/commands/review.md | grep -qF "Security: reported privately (<id>)" \
   && sed -n "/^5\. /,/^6\. /p" extension/commands/pr.md | grep -qF "Security: reported privately (<id>)"'

# F4.2: the audit's advisory call sends the JSON body GitHub accepts, after looking for an existing one.
adv="$(sed -n '/^- \*\*Public repository:\*\*/,/^- \*\*A real secret/p' skills/security/SKILL.md)"
adv_body="$(sed -n '/--input -/,/^ *EOF$/p' <<<"$adv")"
check "when the skill's advisory call is read, then the JSON after --input - names summary, description, severity, vulnerabilities and ecosystem" \
  '[[ -n "$adv_body" ]]; for k in summary description severity vulnerabilities ecosystem; do grep -q "\"$k\"" <<<"$adv_body"; done'
check "then a --paginate lookup of the advisories comes before the -X POST" \
  'p="$(grep -n -- "--paginate" <<<"$adv" | head -1 | cut -d: -f1)"; x="$(grep -n -- "-X POST" <<<"$adv" | head -1 | cut -d: -f1)"; [[ -n "$p" && -n "$x" ]] && ((p < x))'

# F4.5: Semgrep's rules are not in the extension (their license forbids it): the docs say where they come from.
check "when the README CI row and the security doc's CI row are read, then they say the rules come from the Semgrep registry" \
  'grep -E "^\| \*\*every PR, and weekly\*\* \|" README.md | grep -q "Semgrep registry" && grep -E "^\| Every PR, push and week \|" docs/security.md | grep -q "Semgrep registry"'

# F4.4/#41: init offers the free GitHub settings on every level, and the docs say what lite lacks.
# init's calls are made by the model, so these are plain reads of the prompt (said, not faked).
init_gh="$(sed -n '/^4\. \*\*GitHub settings\*\* (every level)/,/^5\. /p' skills/init/SKILL.md | sed '$d')"
check "when init's step 4 is read, then it is for every level and offers allow_rebase_merge=false, and on lite allow_merge_commit=false" \
  '[[ -n "$init_gh" ]] && ! grep -q "(standard and full)" <<<"$init_gh" && grep -q "allow_rebase_merge=false" <<<"$init_gh" && grep -A3 "On lite" <<<"$init_gh" | grep -q "allow_merge_commit=false"'
check "then for a PUBLIC repo it offers secret scanning with push protection and private vulnerability reporting, and branch protection is step 5 (standard and full)" \
  'grep -q "PUBLIC" <<<"$init_gh" && grep -q "secret_scanning_push_protection" <<<"$init_gh" && grep -q "private-vulnerability-reporting" <<<"$init_gh" && grep -q "^5\. \*\*Branch protection\*\* (standard and full)" skills/init/SKILL.md'
check "when the docs are read, then the README CI row names (standard and full), the security doc says lite has no CI gate, and the design doc ties the one-revert promise to one commit per task PR" \
  'grep -E "^\| \*\*every PR, and weekly\*\* \|" README.md | grep -qF "(standard and full)" && grep -q "On lite there is no CI gate" docs/security.md && sed -n "/^## One task = one issue/,/^## /p" docs/design.md | grep -q "one commit per task PR"'

# review.sh record compares against the merge-base with origin's base (lib.sh base_ref): the prompt names the same one.
check "the review prompt takes the range's start from origin/<base>, as review.sh record does" \
  'grep -qF "git merge-base HEAD origin/<base>" extension/commands/review.md && ! grep -qF "git merge-base HEAD <base>" extension/commands/review.md'

# The installed copies (specify extension add --dev extension --force) are what this repo runs: they match the source.
stale=""
for f in extension/commands/*.md extension/scripts/*.sh; do
  d="${f#extension/}"; cmp -s "$f" ".specify/extensions/jit/$d" || stale+="$d "
done
# The skill .claude/skills links to is generated from each command: its body (after spec-kit's frontmatter) is the command's.
body() { awk 'n >= 2 { print } /^---$/ { n++ }' "$1"; }
for f in extension/commands/*.md; do
  s=".specify-dev/agent-commands/claude/speckit-jit-$(basename "$f" .md)/SKILL.md"
  [[ -f ".specify/extensions/jit/$s" && "$(body "$f")" == "$(body ".specify/extensions/jit/$s")" ]] || stale+="$s "
done
check "every extension command and script equals its .specify/extensions/jit copy${stale:+ — stale: $stale(fix: specify extension add --dev extension --force)}" '[[ -z "$stale" ]]'

# A link copied from the README into docs/ keeps its docs/ prefix and breaks; every relative link
# in a markdown file must point at a file that exists next to it.
broken=""
while IFS=: read -r f target; do
  [[ -e "$(dirname "$f")/${target%%#*}" ]] || broken+="$f -> $target "
done < <(grep -oE '\]\([^)#:]+(\.md|\.yaml|\.yml)(#[^)]*)?\)' README.md docs/*.md examples/README.md | sed -E 's/\]\(//; s/\)$//')
check "every relative link in the docs points at a file that exists${broken:+ — broken: $broken}" '[[ -z "$broken" ]]'

refs=docs/references.yaml
check "every reference has a title, url, use_when and key" \
  '[[ $(grep -c "^ *- title: " $refs) -gt 0 && $(grep -c "^ *- title: " $refs) == $(grep -c "^ *url: https://" $refs) && $(grep -c "^ *- title: " $refs) == $(grep -c "^ *use_when: " $refs) && $(grep -c "^ *- title: " $refs) == $(grep -c "^ *key: " $refs) ]]'
check "then no reference is listed twice" '[[ -z "$(grep -oE "url: \S+" $refs | sort | uniq -d)" ]]'
check "then no reference is Wikipedia (primary sources only)" '! grep -q "wikipedia.org" $refs'

exit "$FAIL"
