#!/usr/bin/env bash
# git pre-push hook body. stdin: "<local ref> <local sha> <remote ref> <remote sha>" per ref.
# 1. Every commit being pushed is scanned for secrets.
# 2. On levels standard and full, pushing straight to a protected branch is refused.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
jit_cd_root

zero="0000000000000000000000000000000000000000"
status=0
while read -r _local_ref local_sha remote_ref remote_sha; do
  [[ "$local_sha" == "$zero" ]] && continue # deleting a remote branch
  branch="${remote_ref#refs/heads/}"
  if [[ "$(jit_level)" != lite ]] && is_protected "$branch"; then
    echo "jit: refusing to push straight to '$branch'; open a pull request instead" >&2
    status=1; continue
  fi
  if [[ "$remote_sha" == "$zero" ]]; then
    # New remote branch: scan what isn't on the remote yet.
    from="$(git merge-base "$local_sha" "origin/$(base_branch)" 2>/dev/null || git rev-list --max-parents=0 "$local_sha" | tail -1)"
  else
    from="$remote_sha"
  fi
  bash "$(dirname "$0")/secrets.sh" range "$from" "$local_sha" || status=1
done
exit "$status"
