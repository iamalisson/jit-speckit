#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # checks are strings evaluated by check()
# bin/check-tools.sh: the pinned tool versions against each tool's latest release (fake gh).
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
# shellcheck source=../extension/scripts/pins.sh
source "$ROOT/extension/scripts/pins.sh"
fake_gh
run() { : > "$GH_LOG"; out="$(GH_API="$1" "$ROOT/bin/check-tools.sh" 2>&1)"; }
creates() { grep -c "^issue create" "$GH_LOG" || true; }

newer="gitleaks/gitleaks v99.0.0
google/osv-scanner v99.0.0
semgrep/semgrep v99.0.0
aquasecurity/trivy v99.0.0"
equal="gitleaks/gitleaks v$GITLEAKS_VERSION
google/osv-scanner v$OSV_VERSION
semgrep/semgrep v$SEMGREP_VERSION
aquasecurity/trivy v$TRIVY_VERSION"

check "when every tool's latest release is newer than its pin, then check-tools prints BEHIND=4 and opens one Tool pins behind issue" \
  'run "$newer"; grep -qx "BEHIND=4" <<<"$out" && [[ "$(creates)" == 1 ]] && grep -q "^issue create .*--title Tool pins behind" "$GH_LOG"'
check "then the issue names SEMGREP_DIGEST beside SEMGREP_VERSION (they move together)" \
  'run "$newer"; grep -q "SEMGREP_VERSION.*SEMGREP_DIGEST" "$GH_LOG"'
check "when every latest release equals its pin, then it prints BEHIND=0 and opens no issue" \
  'run "$equal"; grep -qx "BEHIND=0" <<<"$out" && [[ "$(creates)" == 0 ]]'
printf '%s\n' "7 Tool pins behind" > "$GH_CLOSED" # the fake's open issues
check "when a Tool pins behind issue is already open, then it prints BEHIND=4 and opens no second one" \
  'run "$newer"; grep -qx "BEHIND=4" <<<"$out" && [[ "$(creates)" == 0 ]]'
rm -f "$GH_CLOSED"
check "when a release lookup fails, then it exits non-zero, names the tool and its repo, and prints no BEHIND=" \
  'run "$(grep -v trivy <<<"$newer")" && exit 1; grep -qF "cannot read the latest trivy release from aquasecurity/trivy" <<<"$out" && ! grep -q "^BEHIND=" <<<"$out" && [[ "$(creates)" == 0 ]]'

exit "$FAIL"
