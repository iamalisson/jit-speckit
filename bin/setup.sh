#!/usr/bin/env bash
# Set up a project (new or existing) with spec-kit + jit-speckit.
# Usage: setup.sh [project-dir] [--level lite|standard|full] [--integration claude] [--no-branches]
# Idempotent: re-running updates the extension and preset and re-applies the level.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
dir="."; level=""; integration="claude"; extra=()
while (($#)); do
  case "$1" in
    --level) level="${2:-}"; shift 2 ;;
    --integration) integration="${2:-}"; shift 2 ;;
    --no-branches) extra+=(--no-branches); shift ;;
    -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
    *) dir="$1"; shift ;;
  esac
done
die() { echo "jit: $*" >&2; exit 1; }

command -v specify >/dev/null || die "spec-kit is required: uv tool install specify-cli --from git+https://github.com/github/spec-kit.git"
command -v git >/dev/null || die "git is required"
command -v gh >/dev/null || echo "jit: warning: GitHub CLI (gh) not found; issues and PRs need it (https://cli.github.com)" >&2

mkdir -p "$dir" && cd "$dir"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { git init --quiet -b main && echo "git: initialized"; }

if [[ ! -d .specify/templates ]]; then
  specify init --here --force --non-interactive --integration "$integration" >/dev/null
  echo "spec-kit: initialized ($integration)"
fi

specify extension add --dev "$here/extension" --force >/dev/null
echo "spec-kit: extension 'jit' installed"
specify preset remove jit >/dev/null 2>&1 || true
specify preset add --dev "$here/preset" >/dev/null
echo "spec-kit: preset 'jit' installed"

# A fresh project still has spec-kit's blank constitution; start from ours instead.
const=.specify/memory/constitution.md
if [[ ! -s "$const" ]] || grep -q '\[PRINCIPLE_1_NAME\]' "$const"; then
  mkdir -p "$(dirname "$const")"
  cp "$here/preset/templates/constitution-template.md" "$const"
  echo "constitution: started from the jit template"
fi

current="$(sed -nE 's/^level:[[:space:]]*([a-z]+).*/\1/p' .specify/extensions/jit/jit-config.yml 2>/dev/null || true)"
level="${level:-${current:-standard}}"
bash .specify/extensions/jit/scripts/level.sh "$level" "${extra[@]}"

cat <<EOF

Done. Next:
  existing code?  /jit-speckit-adopt      (fills the constitution from this repo)
  new project?    /speckit-constitution   (fills the [PLACEHOLDERS])
  then per feature: /speckit-specify → /speckit-plan → /speckit-tasks → /speckit-implement T001
EOF
