#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # checks are strings evaluated by check()
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
scan="$SCRIPTS/security-scan.sh"

# Fake scanners: each logs its arguments; FAKE_FIND=<tool> makes that tool report findings.
mkdir -p "$TMP/tools"
for t in gitleaks osv-scanner semgrep zizmor; do
  cat > "$TMP/tools/$t" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$TMP/$t.log"
[[ " \${FAKE_FIND:-} " == *" $t "* ]] && exit 1
exit 0
EOF
  chmod +x "$TMP/tools/$t"
done
mkdir -p "$TMP/none"; ln -s "$(command -v git)" "$TMP/none/git"

new_repo standard
mkdir -p .github/workflows; echo "on: push" > .github/workflows/ci.yml
git add -A; git commit --quiet -m wf

out="$(PATH="$TMP/none:/usr/bin:/bin" bash "$scan")"
check "when no scanner is installed, then each is reported missing with how to install it" \
  'grep -q "^gitleaks *missing *install:" <<<"$out" && grep -q "^semgrep *missing" <<<"$out" && grep -q "^zizmor *missing" <<<"$out"'
check "then the report directory lives inside .git, never in the working tree" \
  'dir="$(sed -n "s/^REPORT_DIR=//p" <<<"$out")"; [[ "$dir" == .git/jit-security/* || "$dir" == */.git/jit-security/* ]] && [[ -z "$(git status --porcelain)" ]]'

out="$(PATH="$TMP/tools:$PATH" bash "$scan")"
check "when the scanners are installed and clean, then each reports ok" \
  'grep -q "^gitleaks *ok" <<<"$out" && grep -q "^osv-scanner *ok" <<<"$out" && grep -q "^semgrep *ok" <<<"$out" && grep -q "^zizmor *ok" <<<"$out"'
check "then semgrep runs the default and OWASP rule sets without telemetry" 'grep -q -- "--config p/default --config p/owasp-top-ten" "$TMP/semgrep.log" && grep -q -- "--metrics off" "$TMP/semgrep.log"'
check "then trivy is skipped when there is no infrastructure code" 'grep -q "^trivy *skipped" <<<"$out"'

out="$(FAKE_FIND="semgrep gitleaks" PATH="$TMP/tools:$PATH" bash "$scan")"
check "when a scanner finds something, then it reports findings with the report path" \
  'grep -q "^semgrep *findings .*semgrep.json" <<<"$out" && grep -q "^gitleaks *findings" <<<"$out"'

git switch --quiet -c feat/x; echo "x = 1" > app.py; git add app.py; git commit --quiet -m app
: > "$TMP/semgrep.log"
PATH="$TMP/tools:$PATH" bash "$scan" --changed >/dev/null
check "when --changed, then semgrep only scans the files this branch changed" 'grep -q " app.py$" "$TMP/semgrep.log" && ! grep -q " \.$" "$TMP/semgrep.log"'

exit "$FAIL"
