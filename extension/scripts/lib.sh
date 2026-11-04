# Shared helpers for jit-speckit scripts. Sourced, not executed.
# shellcheck shell=bash

JIT_CONFIG=".specify/extensions/jit/jit-config.yml"
# Where this extension's files live (the repo checkout, or .specify/extensions/jit once installed).
# shellcheck disable=SC2034  # used by the scripts that source this file
JIT_EXT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die() { echo "jit: $*" >&2; exit 1; }

# Run every script from the repository root.
jit_cd_root() { cd "$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repository"; }

# cfg <key> <default>: read a flat `key: value` line from the config file.
cfg() {
  local v=""
  [[ -f "$JIT_CONFIG" ]] && v="$(sed -nE "s/^$1:[[:space:]]*\"?([^\"#]*)\"?.*$/\1/p" "$JIT_CONFIG" | head -1 | sed 's/[[:space:]]*$//')"
  echo "${v:-$2}"
}

# cfg_set <key> <value>: replace or append a key in the config file.
cfg_set() {
  mkdir -p "$(dirname "$JIT_CONFIG")"
  touch "$JIT_CONFIG"
  if grep -qE "^$1:" "$JIT_CONFIG"; then
    sed -i.bak -E "s|^$1:.*$|$1: $2|" "$JIT_CONFIG" && rm -f "$JIT_CONFIG.bak"
  else
    echo "$1: $2" >> "$JIT_CONFIG"
  fi
}

jit_level() { cfg level standard; }

default_branch() {
  local b
  b="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
  echo "${b:-$(git config init.defaultBranch || echo main)}"
}

# The branch task PRs target: configured, or derived from the level.
base_branch() {
  local b
  b="$(cfg base_branch auto)"
  if [[ "$b" == auto ]]; then
    if [[ "$(jit_level)" == lite ]]; then default_branch; else echo develop; fi
  else
    echo "$b"
  fi
}

# Long-lived branches that only change through pull requests.
protected_branches() {
  local level; level="$(jit_level)"
  echo "$(default_branch) $(base_branch)"
  if [[ "$level" != lite ]]; then echo develop; fi
  if [[ "$level" == full ]]; then echo staging; fi
}
is_protected() { [[ " $(protected_branches | tr '\n' ' ') " == *" $1 "* ]]; }

feature_dir() {
  local d
  d="$(sed -n 's/.*"feature_directory": *"\([^"]*\)".*/\1/p' .specify/feature.json 2>/dev/null)"
  [[ -n "$d" && -d "$d" ]] || die "no active feature (.specify/feature.json); run /speckit-specify first"
  echo "$d"
}

# The task line for an ID, e.g. "- [ ] T003 [P] [US1] Do x in src/x.py — #12".
task_line() { grep -E "^- \[.\] $2 " "$1/tasks.md" | head -1; }

# The issue number linked on a task line ("— #12" at the end), or empty.
task_issue() { sed -nE 's/.* — #([0-9]+)[[:space:]]*$/\1/p' <<<"$1"; }

# Task description without checkbox, ID, [P]/[USn] markers or the issue link.
task_desc() {
  sed -E 's/^- \[.\] T[0-9]{3} //; s/^(\[P\] )?(\[US[0-9]+\] )?//; s/ — #[0-9]+[[:space:]]*$//' <<<"$1"
}

# "Completed when:" sub-bullet of a task, if the task has one.
task_field() {
  awk -v id="$2" -v key="$3" '
    $0 ~ "^- \\[.\\] " id " " { inside = 1; next }
    inside && /^- \[/ { exit }
    inside && index($0, "  - " key ":") == 1 { sub("^  - " key ":[[:space:]]*", ""); print; exit }
  ' "$1/tasks.md"
}

sha256() { if command -v sha256sum >/dev/null; then sha256sum; else shasum -a 256; fi | cut -d' ' -f1; }

# owner/name of the GitHub repo: from gh, else parsed from the origin URL, else empty. Never fails.
repo_slug() {
  local s
  s="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
  [[ -n "$s" ]] || s="$(git remote get-url origin 2>/dev/null | sed -nE 's#.*github\.com[:/]([^/]+/[^/.]+)(\.git)?$#\1#p' || true)"
  echo "$s"
}
