#!/usr/bin/env bash
# Claude Code PreToolUse hook (Agent, and Task on older clients). A review launch, landspec:reviewer
# or any agent whose prompt holds the reviewer sentinel, must run on sonnet, opus or fable, passed as
# the call's model (never the session's, which may be cheap), in a fresh agent (a fork inherits the
# author's context, so it is not independent), and in its own copy of the repository (isolation:
# worktree), so it never writes to the author's checkout. Every other launch passes untouched.
# For a review, the fork and model checks only refuse: the one exit 0 is after the isolation check.
# The decision reads the call's fields only, never a project file.
# Exit 2 blocks the launch; stderr tells Claude why. This is the plugin's own copy, as guard-git.sh.
set -uo pipefail
input="$(cat)"
field() { # field <name>: a string field of tool_input
  if command -v python3 >/dev/null; then
    python3 -c 'import json,sys; v=json.load(sys.stdin).get("tool_input",{}).get(sys.argv[1], ""); print(v if isinstance(v,str) else "")' "$1" <<<"$input" 2>/dev/null
  else
    sed -nE "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"(([^\"\\\\]|\\\\.)*)\".*/\1/p" <<<"$input" | sed -n 1p
  fi
}
type="$(field subagent_type)"
# The sentinel has no character JSON escapes, so it reads the same with either parser. The prompt is
# matched in a variable: a pipe into grep -q fails under pipefail on a prompt bigger than the pipe buffer.
prompt="$(field prompt)"
if [[ "$type" != landspec:reviewer && "$prompt" != *"landspec review: independent reviewer"* ]]; then exit 0; fi
if [[ "$type" == fork ]]; then
  echo "landspec: the review must run in a fresh agent, not a fork of this session" >&2; exit 2
fi
model="$(field model)"
case "$model" in
  sonnet|opus|fable) ;;
  "") # A session that forces one subagent model decides it; the record warns.
      if [[ -z "${CLAUDE_CODE_SUBAGENT_MODEL_FORCE:-}" ]]; then
        echo "landspec: the review must run on sonnet, opus or fable (review_model:), not the session's model" >&2; exit 2
      fi ;;
  *) echo "landspec: the review must run on sonnet, opus or fable (review_model:), not $model" >&2; exit 2 ;;
esac
if [[ "$(field isolation)" != worktree ]]; then
  echo 'landspec: the review must run in its own copy of the repository: pass isolation: "worktree" (an older landspec copy in this project? run /landspec:init; Claude Code too old to take it? update it)' >&2; exit 2
fi
exit 0
