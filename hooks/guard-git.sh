#!/usr/bin/env bash
# Claude Code PreToolUse hook (Bash). Hands git commands to the project's jit guard.
# Does nothing outside jit-speckit projects or for commands that don't involve git.
# Exit 2 blocks the command; the guard's stderr tells Claude why.
set -uo pipefail
input="$(cat)"
field() { # field <name>: a string field from the hook's JSON input
  if command -v python3 >/dev/null; then
    python3 -c 'import json,sys; d=json.load(sys.stdin); v=d.get("tool_input",{}).get(sys.argv[1], d.get(sys.argv[1], "")); print(v if isinstance(v,str) else "")' "$1" <<<"$input" 2>/dev/null
  else
    sed -nE "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"(([^\"\\\\]|\\\\.)*)\".*/\1/p" <<<"$input" | head -1
  fi
}
cmd="$(field command)"
[[ "$cmd" == *git* ]] || exit 0
cwd="$(field cwd)"
root="$(git -C "${cwd:-.}" rev-parse --show-toplevel 2>/dev/null)" || exit 0
guard="$root/.specify/extensions/jit/scripts/guard.sh"
[[ -f "$guard" ]] || exit 0
cd "$root" && exec bash "$guard" "$cmd"
