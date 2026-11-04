#!/usr/bin/env bash
# git pre-push hook body. Args: <remote name> <url>. stdin: "<local ref> <local sha> <remote ref>
# <remote sha>" per ref.
# 1. Every commit being pushed is scanned for secrets.
# 2. On levels standard and full, pushing straight to a protected branch is refused, except the
#    very first push to a remote that has no branches yet: there is nothing to open a PR against.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
jit_cd_root

zero="0000000000000000000000000000000000000000"
status=0
remote="${1:-origin}"
# An empty remote (a brand-new repository) has no branch a pull request could target.
empty_remote=false
if [[ -z "$(git ls-remote --heads "$remote" 2>/dev/null)" ]] && git ls-remote "$remote" >/dev/null 2>&1; then empty_remote=true; fi
while read -r _local_ref local_sha remote_ref remote_sha; do
  [[ "$local_sha" == "$zero" ]] && continue # deleting a remote branch
  branch="${remote_ref#refs/heads/}"
  if [[ "$(jit_level)" != lite ]] && is_protected "$branch"; then
    if $empty_remote && [[ "$remote_sha" == "$zero" ]]; then
      echo "jit: first push to an empty repository: '$branch' allowed once; from now on it only changes through pull requests" >&2
    else
      echo "jit: refusing to push straight to '$branch'; open a pull request instead" >&2
      status=1; continue
    fi
  fi
  if [[ "$remote_sha" == "$zero" ]]; then
    # New remote branch: every commit no remote has yet, down to the root on a first push.
    from=-
  else
    from="$remote_sha"
  fi
  bash "$(dirname "$0")/secrets.sh" range "$from" "$local_sha" || status=1
done
exit "$status"
