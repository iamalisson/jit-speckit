#!/usr/bin/env bash
# Run every test file; exit non-zero if any check failed.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
status=0
log="$(mktemp)"; trap 'rm -f "$log"' EXIT
for t in *.test.sh; do
  echo "== $t"
  # A file that stops early (a failing setup step under set -e) would otherwise show no FAIL line.
  bash "$t" 2>&1 | tee "$log"
  rc="${PIPESTATUS[0]}"
  if ((rc != 0)); then echo "FAIL - $t stopped with exit $rc (a failing check, or a setup step that failed before the end)"; status=1; fi
  # A file that lost its last line exits 0 whatever its checks said.
  if grep -q '^FAIL' "$log"; then status=1; fi
  if [[ "$(tail -n 1 "$t")" != 'exit "$FAIL"' ]]; then echo "FAIL - $t does not end in: exit \"\$FAIL\""; status=1; fi
done
exit "$status"
