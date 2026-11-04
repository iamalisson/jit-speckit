# Test helpers: a throwaway repo with a local bare "origin" and a fake `gh` on PATH.
# shellcheck shell=bash disable=SC2034  # SCRIPTS and FAIL are used by the test files
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$ROOT/extension/scripts"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0

# Each check runs in a subshell with set -e: an `exit` inside it can't end the test file, and in
# "a; b" a failing a fails the check (not just b).
# (bash ignores set -e inside an `if` condition, even in a subshell: so run it as a plain command.)
check() { # check "<when..., then...>" <command string>
  local rc
  set +e; (set -e; eval "$2") >/dev/null 2>&1; rc=$?; set -e
  if ((rc == 0)); then echo "ok   - $1"; else echo "FAIL - $1"; FAIL=1; fi
}

# fails_with <text> <cmd...>: the command fails and its output mentions <text>.
fails_with() {
  local text="$1" out; shift
  if out="$("$@" 2>&1)"; then return 1; fi
  grep -qF -- "$text" <<<"$out"
}

# Fake GitHub CLI: issues and PRs are numbered from a counter; every call is logged.
fake_gh() {
  mkdir -p "$TMP/bin"
  cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$GH_LOG"
case "$1 $2" in
  "issue create") n=$(( $(cat "$GH_N" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$GH_N"
                  echo "https://github.com/acme/app/issues/$n" ;;
  "label create") exit 0 ;;
  "pr list") [[ -f "$GH_PR" ]] && cat "$GH_PR"; exit 0 ;;
  "pr create") echo "https://github.com/acme/app/pull/99" | tee "$GH_PR" ;;
  "issue list") cat "$GH_CLOSED" 2>/dev/null; exit 0 ;;
  "repo view") exit 1 ;;
  "issue edit"|"pr edit") if [[ -n "${GH_FAIL_EDIT:-}" ]]; then echo "GraphQL: Could not resolve to a ProjectV2" >&2; exit 1; fi ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$TMP/bin/gh"
  export PATH="$TMP/bin:$PATH" GH_LOG="$TMP/gh.log" GH_N="$TMP/gh.n" GH_PR="$TMP/gh.pr" GH_CLOSED="$TMP/gh.closed"
}

# set_cfg <key> <value>: edit a config line in place, as a user would.
set_cfg() { sed -i.bak "s|^$1:.*|$1: $2|" .specify/extensions/jit/jit-config.yml; }

# new_repo <level>: repo at $TMP/repo with origin, extension linked, an active feature 001-demo.
new_repo() {
  git init --quiet --bare "$TMP/origin.git"
  git clone --quiet "$TMP/origin.git" "$TMP/repo" 2>/dev/null
  cd "$TMP/repo"
  git config user.email t@t; git config user.name t; git config commit.gpgsign false
  mkdir -p .specify/extensions specs/001-demo
  mkdir -p .specify/extensions/jit && ln -s "$ROOT/extension/scripts" .specify/extensions/jit/scripts # as spec-kit installs it
  printf 'level: %s\nbase_branch: auto\nbranch_prefix: feat\nissue_labels: "type:task"\nmilestone: ""\nproject: ""\n' "$1" > .specify/extensions/jit/jit-config.yml
  echo '{ "feature_directory": "specs/001-demo" }' > .specify/feature.json
  # Local test state stays out of git so config edits never dirty the tree.
  printf '.specify/\n*.bak\n' > .gitignore
  git add -A; git commit --quiet -m init; git branch -M main
  git push --quiet origin main; git remote set-head origin main >/dev/null 2>&1 || git remote set-head origin -a >/dev/null
  git push --quiet origin main:develop
}

# commit_tasks <content>: write tasks.md, commit it on main and develop.
commit_tasks() {
  printf '%s\n' "$1" > specs/001-demo/tasks.md
  git add -A; git commit --quiet -m tasks; git push --quiet origin main; git push --quiet origin main:develop
}
