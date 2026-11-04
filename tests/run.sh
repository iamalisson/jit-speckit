#!/usr/bin/env bash
# Run every test file; exit non-zero if any check failed.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
status=0
for t in *.test.sh; do
  echo "== $t"
  bash "$t" || status=1
done
exit "$status"
