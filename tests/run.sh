#!/usr/bin/env bash
# Run every test file; exit non-zero if any check failed.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
status=0
for t in *.test.sh; do
  echo "== $t"
  # A file that stops early (a failing setup step under set -e) would otherwise show no FAIL line.
  bash "$t" || { rc=$?; echo "FAIL - $t stopped with exit $rc (a failing check, or a setup step that failed before the end)"; status=1; }
done
exit "$status"
