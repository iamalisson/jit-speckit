#!/usr/bin/env bash
# Install the /jit-speckit-* skills for Claude Code on this machine (once).
# Usage: ./install.sh [--uninstall]
# Skills are symlinked, so `git pull` in this folder updates them.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
target="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
skills=(jit-speckit-init jit-speckit-adopt jit-speckit-level)

if [[ "${1:-}" == --uninstall ]]; then
  for s in "${skills[@]}"; do
    [[ -L "$target/$s" ]] && rm "$target/$s" && echo "removed $target/$s"
  done
  exit 0
fi

mkdir -p "$target"
for s in "${skills[@]}"; do
  if [[ -e "$target/$s" && ! -L "$target/$s" ]]; then
    echo "skip: $target/$s exists and is not a jit-speckit link" >&2; continue
  fi
  ln -sfn "$here/skills/$s" "$target/$s"
  echo "linked /$s"
done

missing=()
for tool in git gh specify; do command -v "$tool" >/dev/null || missing+=("$tool"); done
if ((${#missing[@]})); then
  echo
  echo "Still needed: ${missing[*]}"
  echo "  specify: uv tool install specify-cli --from git+https://github.com/github/spec-kit.git"
  echo "  gh:      https://cli.github.com (then: gh auth login)"
fi
echo
echo "Done. In any project, open Claude Code and run: /jit-speckit-init"
