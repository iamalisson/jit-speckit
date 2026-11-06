#!/usr/bin/env bash
# Set up a project (new or existing) with spec-kit + jit-speckit.
# Usage: setup.sh [project-dir] [--level lite|standard|full] [--integration claude] [--no-branches] [--downgrade]
# Idempotent: re-running updates the extension and preset and re-applies the level.
set -euo pipefail

SPECKIT_VERSION="v1.2.5" # the spec-kit release CI tests against
here="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../extension/scripts/lib.sh
source "$here/extension/scripts/lib.sh" # version_newer
die() { echo "jit: $*" >&2; exit 1; }
usage() { sed -n '3p' "$0" | sed 's/^# Usage/Usage/' >&2; exit 2; }

dir="."; level=""; integration="claude"; extra=(); downgrade=false
while (($#)); do
  case "$1" in
    --level) [[ -n "${2:-}" ]] || usage; level="$2"; shift 2 ;;
    --integration) [[ -n "${2:-}" ]] || usage; integration="$2"; shift 2 ;;
    --no-branches) extra+=(--no-branches); shift ;;
    --downgrade) downgrade=true; shift ;;
    -h|--help) usage ;;
    -*) echo "jit: unknown option $1" >&2; usage ;;
    *) dir="$1"; shift ;;
  esac
done
case "$level" in ""|lite|standard|full) ;; *) die "unknown level '$level' (lite, standard or full)" ;; esac

# Run a command quietly, but show everything it printed if it fails (spec-kit reports errors on stdout).
quiet() {
  local out
  if ! out="$("$@" 2>&1)"; then
    echo "$out" >&2
    die "failed: $*"
  fi
}

command -v git >/dev/null || die "git is required"
command -v specify >/dev/null || die "spec-kit is required: uv tool install specify-cli --from git+https://github.com/github/spec-kit.git@$SPECKIT_VERSION"
command -v gh >/dev/null || echo "jit: warning: GitHub CLI (gh) not found; issues and PRs need it (https://cli.github.com)" >&2
if [[ "$integration" == claude ]] && ! command -v claude >/dev/null; then
  echo "jit: warning: Claude Code CLI not found; install it to use the slash commands (https://claude.com/claude-code)" >&2
fi

mkdir -p "$dir" && cd "$dir"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { git init --quiet -b main && echo "git: initialized"; }

# An older plugin copy would take the project back, dropping the gates it has. The indented
# version: line is the extension's own (not schema_version or speckit_version).
ext_version() { sed -nE 's/^[[:space:]]+version:[[:space:]]*"?([^" ]*)"?.*/\1/p' "$1" 2>/dev/null | head -1 || true; }
plugin_v="$(ext_version "$here/extension/extension.yml")"; project_v="$(ext_version .specify/extensions/jit/extension.yml)"
if ! $downgrade && version_newer "$project_v" "$plugin_v"; then
  die "this plugin copy is $plugin_v, the project is at $project_v; run /reload-plugins (or setup.sh --downgrade)"
fi

if [[ ! -d .specify/templates ]]; then
  # The agent's own CLI may be installed later (or never, e.g. in CI); the warning above covers it.
  quiet specify init --here --force --non-interactive --ignore-agent-tools --integration "$integration"
  echo "spec-kit: initialized ($integration)"
fi

quiet specify extension add --dev "$here/extension" --force
echo "spec-kit: extension 'jit' installed"
specify preset remove jit >/dev/null 2>&1 || true
quiet specify preset add --dev "$here/preset"
echo "spec-kit: preset 'jit' installed"

# spec-kit was initialized for another agent before: the hooks would be invisible to Claude Code.
if [[ "$integration" == claude && ! -d .claude/skills/speckit-jit-branch ]]; then
  die "this project's spec-kit is set up for another agent; add Claude with: specify integration add claude"
fi

# A fresh project still has spec-kit's blank constitution; start from ours instead.
const=.specify/memory/constitution.md
if [[ ! -s "$const" ]] || grep -q '\[PRINCIPLE_1_NAME\]' "$const"; then
  mkdir -p "$(dirname "$const")"
  cp "$here/preset/templates/constitution-template.md" "$const"
  echo "constitution: started from the jit template"
fi

current="$(sed -nE 's/^level:[[:space:]]*([a-z]+).*/\1/p' .specify/extensions/jit/jit-config.yml 2>/dev/null || true)"
level="${level:-${current:-standard}}"
bash .specify/extensions/jit/scripts/level.sh "$level" ${extra[@]+"${extra[@]}"}

cat <<EOF

Done. Next:
  existing code?  /jit-speckit:adopt      (fills the constitution from this repo)
  new project?    /speckit-constitution   (fills the [PLACEHOLDERS])
  then per feature: /speckit-specify → /speckit-plan → /speckit-tasks → /speckit-implement T001
EOF
