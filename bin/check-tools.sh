#!/usr/bin/env bash
# Compare the tool versions in extension/scripts/pins.sh with each tool's latest GitHub release
# (Dependabot sees actions, not these). When any is behind, open one "Tool pins behind" issue,
# unless one is already open. Run weekly by .github/workflows/pins.yml.
# Usage: bin/check-tools.sh     (prints BEHIND=<n>; a failed lookup exits non-zero)
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=../extension/scripts/lib.sh
source extension/scripts/lib.sh # version_newer, die
# shellcheck source=../extension/scripts/pins.sh
source extension/scripts/pins.sh
title="Tool pins behind"
n=0; list=""
while read -r tool var repo; do
  pin="${!var}"
  # </dev/null: gh must not read the tool list this loop reads.
  latest="$(gh api "repos/$repo/releases/latest" --jq .tag_name </dev/null)" && [[ -n "$latest" ]] \
    || die "cannot read the latest $tool release from $repo"
  version_newer "$latest" "$pin" || continue
  n=$((n + 1))
  note=""; [[ "$var" == SEMGREP_VERSION ]] && note=" (bump SEMGREP_DIGEST with it)"
  echo "behind: $tool $pin, latest $latest"
  list+="- $tool: \`$var=\"$pin\"\`, latest [$latest](https://github.com/$repo/releases/tag/$latest)$note"$'\n'
done <<'TOOLS'
gitleaks GITLEAKS_VERSION gitleaks/gitleaks
osv-scanner OSV_VERSION google/osv-scanner
semgrep SEMGREP_VERSION semgrep/semgrep
trivy TRIVY_VERSION aquasecurity/trivy
TOOLS
if ((n > 0)); then
  open="$(gh issue list --state open --limit 1000 --json number,title --jq '.[] | "\(.number) \(.title)"')"
  if grep -qE "^[0-9]+ $title\$" <<<"$open"; then
    echo "already open: $title"
  else
    gh issue create --title "$title" --body "Newer releases than the versions in \`extension/scripts/pins.sh\`:

$list
Bump each version with its SHA-256 from the release, to releases that have been out for a few weeks." >/dev/null
    echo "opened: $title"
  fi
fi
echo "BEHIND=$n"
