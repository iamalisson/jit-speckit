# Test helpers: a throwaway repo with a local bare "origin" and a fake `gh` on PATH.
# shellcheck shell=bash disable=SC2034  # SCRIPTS and FAIL are used by the test files
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$ROOT/extension/scripts"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0

check() { # check "<when..., then...>" <command string>
  if eval "$2" >/dev/null 2>&1; then echo "ok   - $1"; else echo "FAIL - $1"; FAIL=1; fi
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
  "pr view") [[ -f "$GH_PR" ]] && cat "$GH_PR" || exit 1 ;;
  "pr create") echo "https://github.com/acme/app/pull/99" | tee "$GH_PR" ;;
  "repo view") exit 1 ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$TMP/bin/gh"
  export PATH="$TMP/bin:$PATH" GH_LOG="$TMP/gh.log" GH_N="$TMP/gh.n" GH_PR="$TMP/gh.pr"
}

# new_repo <level>: repo at $TMP/repo with origin, extension linked, an active feature 001-demo.
new_repo() {
  git init --quiet --bare "$TMP/origin.git"
  git clone --quiet "$TMP/origin.git" "$TMP/repo" 2>/dev/null
  cd "$TMP/repo"
  git config user.email t@t; git config user.name t; git config commit.gpgsign false
  mkdir -p .specify/extensions specs/001-demo
  mkdir -p .specify/extensions/jit && printf 'level: %s\nbase_branch: auto\nbranch_prefix: feat\nissue_labels: "type:task"\n' "$1" > .specify/extensions/jit/jit-config.yml
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
