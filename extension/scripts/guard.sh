#!/usr/bin/env bash
# Guard for git commands run by Claude Code (called by the plugin's PreToolUse hook).
# Usage: guard.sh "<bash command>"   — exit 2 (with the reason on stderr) blocks the command.
# Rules: no --no-verify, no `git add -A/--all/.`, no commit on a protected branch,
#        no push to a protected branch. People are not affected; their git hooks still apply.
set -uo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
jit_cd_root

cmd="${1:-}"
block() { echo "jit-speckit guard: $1" >&2; exit 2; }
# Look at each git invocation separately (commands chained with && ; |).
# awk, not sed: BSD sed (macOS) writes a literal "n" for \n in a replacement.
segments="$(awk '{ gsub(/&&|\|\||;|\|/, "\n"); print }' <<<"$cmd")"
current="$(git branch --show-current 2>/dev/null || true)"

while IFS= read -r seg; do
  seg="$(sed -E 's/^[[:space:]]+//' <<<"$seg")"
  # `git -C dir ...` and `git -c k=v ...` still count as git.
  [[ "$seg" =~ ^git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+([a-z-]+)(.*)$ ]] || continue
  sub="${BASH_REMATCH[2]}"; args="${BASH_REMATCH[3]}"
  case "$sub" in
    commit|push|merge|rebase)
      if [[ " $args " =~ [[:space:]](--no-verify|-n)[[:space:]] && "$sub" != push ]] || [[ "$sub" == push && " $args " == *" --no-verify "* ]]; then
        block "--no-verify skips the secret checks; fix what the hook reports instead"
      fi ;;
  esac
  case "$sub" in
    add)
      if [[ " $args " =~ [[:space:]](-A|--all|\.|:/)[[:space:]] ]]; then
        block "stage files by name (git add path/to/file), not everything at once"
      fi ;;
    commit)
      if [[ -n "$current" ]] && is_protected "$current"; then
        block "committing on '$current' is not allowed; start a task with /speckit-implement Tnnn (or /jit-speckit:next)"
      fi ;;
    push)
      # Explicit refspecs are the targets; without any, git pushes the current branch.
      targets=""
      for word in $args; do
        case "$word" in -*|origin|upstream) ;; *) targets+=" ${word##*:} " ;; esac
      done
      [[ -n "$targets" ]] || targets=" $current "
      for b in $(protected_branches); do
        if [[ "$targets" == *" $b "* || "$targets" == *" HEAD:$b "* || "$targets" == *" refs/heads/$b "* ]]; then
          block "pushing to '$b' is not allowed; it only changes through pull requests"
        fi
      done ;;
  esac
done <<<"$segments"
exit 0
