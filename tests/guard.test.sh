#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # checks are strings evaluated by check()
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
g="$SCRIPTS/guard.sh"
blocked() { local rc=0; "$g" "$1" 2>/dev/null || rc=$?; [[ $rc == 2 ]]; }

new_repo standard
git switch --quiet -c feat/001-t001-thing

check "when Claude commits with --no-verify, then it is blocked" 'blocked "git commit --no-verify -m x"'
check "when Claude commits with -n, then it is blocked" 'blocked "git commit -n -m x"'
check "when Claude pushes with --no-verify, then it is blocked" 'blocked "git push --no-verify"'
check "when Claude runs git add -A or git add ., then it is blocked" 'blocked "git add -A" && blocked "git add ." && blocked "git add --all"'
check "when Claude stages files by name, then it is allowed" '"$g" "git add src/a.ts src/b.ts"'
check "when Claude commits on a task branch, then it is allowed" '"$g" "git commit -m \"feat: x\""'
check "when Claude pushes its task branch, then it is allowed" '"$g" "git push -u origin feat/001-t001-thing"'
check "when Claude pushes to develop or main explicitly, then it is blocked" \
  'blocked "git push origin develop" && blocked "git push origin HEAD:main" && blocked "git push --force origin main"'
check "when the push hides in a chain or uses -C, then it is still blocked" \
  'blocked "npm test && git -C . push origin develop"'

git switch --quiet main
check "when Claude commits on main, then it is blocked" 'blocked "git commit -m x"'
check "when Claude pushes with no refspec while on main, then it is blocked" 'blocked "git push"'
check "when the command is not git, then it is allowed" '"$g" "ls -la && echo done"'

# The plugin hook shim: JSON in, guard decision out; silent outside jit projects.
shim="$ROOT/hooks/guard-git.sh"
json() { printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"%s"}}' "$1" "$2"; }
check "when the hook gets a blocked command inside a jit project, then it exits 2" \
  'rc=0; json "$PWD" "git push origin develop" | bash "$shim" 2>/dev/null || rc=$?; [[ $rc == 2 ]]'
mkdir -p "$TMP/plain" && git -C "$TMP/plain" init --quiet
check "when the project does not use jit-speckit, then the hook allows everything" \
  'json "$TMP/plain" "git push origin main" | bash "$shim"'

exit "$FAIL"
