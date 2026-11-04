#!/usr/bin/env bash
# Copy action pins from the workflows into extension/scripts/pins.sh, after Dependabot bumped them.
# For each PIN_* in pins.sh: if every workflow that uses that action agrees on one SHA (and its
# version comment), pins.sh is rewritten to it. If workflows disagree, it stops and lists them.
# Usage: bin/sync-pins.sh     (then tests/static.test.sh checks there is no drift)
set -euo pipefail
cd "$(dirname "$0")/.."
pins=extension/scripts/pins.sh
workflows="$(find .github/workflows -name '*.yml')"
changed=0
while IFS= read -r line; do
  name="${line%%=*}"; ref="${line#*=\"}"; ref="${ref%%\"*}"; action="${ref%%@*}"
  # shellcheck disable=SC2086  # $workflows is a list of paths without spaces
  used="$(grep -hoE "uses: $action@[0-9a-f]{40}( # [^ ]+)?" $workflows | sed 's/^uses: //' | sort -u || true)"
  [[ -n "$used" ]] || continue
  if [[ "$(wc -l <<<"$used")" -gt 1 ]]; then
    echo "sync-pins: workflows disagree on $action:" >&2; echo "$used" >&2; exit 1
  fi
  [[ "$used" == "$ref" ]] && continue
  NAME="$name" NEW="$used" awk 'index($0, ENVIRON["NAME"] "=\"") == 1 { print ENVIRON["NAME"] "=\"" ENVIRON["NEW"] "\""; next } { print }' \
    "$pins" > "$pins.tmp" && mv "$pins.tmp" "$pins"
  echo "$name: $ref → $used"
  changed=$((changed + 1))
done < <(grep -E '^PIN_[A-Z_]+="' "$pins")
echo "SYNCED=$changed"
