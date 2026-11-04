#!/usr/bin/env bash
# Record that /speckit-analyze ran on the current tasks.md (checked by branch.sh on level "full").
# The marker lives in .git, so it never dirties the working tree.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

jit_cd_root
fdir="$(feature_dir)"
dir="$(git rev-parse --git-dir)/jit-analyzed"
mkdir -p "$dir"
sha256 < "$fdir/tasks.md" > "$dir/$(basename "$fdir")"
echo "ANALYZED=$(basename "$fdir")"
