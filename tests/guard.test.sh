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
check "when the remote's default branch is develop, then pushing to main is still blocked" \
  'git remote set-head origin develop >/dev/null 2>&1 || git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/develop; blocked "git push origin main"; rc=$?; git remote set-head origin main >/dev/null 2>&1 || git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main; exit $rc'
check "when Claude pushes to develop or main explicitly, then it is blocked" \
  'blocked "git push origin develop" && blocked "git push origin HEAD:main" && blocked "git push --force origin main"'
check "when the push hides in a chain or uses -C, then it is still blocked" \
  'blocked "npm test && git -C . push origin develop"'

check "when no-verify hides in a bundled flag, a global option or a wrapper, then it is blocked" \
  'blocked "git commit -nm x" && blocked "git --no-pager commit -n -m x" && blocked "env git commit --no-verify -m x" && blocked "GIT_X=1 command git push --no-verify"'
check "when hooks are switched off with -c core.hooksPath, then it is blocked" \
  'blocked "git -c core.hooksPath=/dev/null commit -m x" && blocked "git -c core.hooksPath /dev/null commit -m x"'
check "when pre-commit hooks are skipped with SKIP=, then it is blocked" \
  'blocked "SKIP=blue git commit -m x" && blocked "SKIP=a,b env git push" && blocked "npm test && SKIP=x git commit -m y"'
check "when SKIP= only appears in the message, then it is allowed" '"$g" "git commit -m \"docs: SKIP=blue explained\""'
check "when a commit message merely contains -n or --no-verify, then it is allowed" \
  '"$g" "git commit -m \"docs: explain -n and --no-verify\""'
check "when merge or rebase use -n (no-stat, not no-verify), then they are allowed" '"$g" "git merge -n main" && "$g" "git rebase -n main"'
check "when the git command is wrapped in sh -c or bash -lc, then it is still checked" \
  'blocked "sh -c \"git push origin develop\"" && blocked "bash -lc '"'"'git add -A'"'"'"'
check "when a force refspec +main or a bundled add -A is used, then it is blocked" \
  'blocked "git push origin +main" && blocked "git add -vA"'
check "when the remote has an unusual name, then it is not mistaken for the target branch" \
  'git remote add fork "$TMP/origin.git" && "$g" "git push fork feat/001-t001-thing" && blocked "git push fork develop"'

check "when hooks are switched off any other way (case, env, --config-env, git config), then it is blocked" \
  'blocked "git -c CORE.HOOKSPATH=/x commit -m x" && blocked "GIT_CONFIG_PARAMETERS=\"'"'"'core.hooksPath=/x'"'"'\" git commit -m x" && blocked "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/x git commit -m x" && blocked "git --config-env=core.hooksPath=X commit -m x" && blocked "git config core.hooksPath /dev/null" && blocked "git config --unset core.hooksPath"'
check "when the hooks path is only read, then it is allowed" '"$g" "git config --get core.hooksPath"'
check "when an apostrophe sits in a comment or a heredoc, then the commands after it are still checked" \
  'blocked "# don'"'"'t forget
git push origin develop" && blocked "cat > notes.md <<EOF
it'"'"'s fine
EOF
git push origin develop"'
check "when pushing everything or HEAD/@ while on a protected branch, then it is blocked" \
  'blocked "git push --all origin" && blocked "git push --mirror origin"'
check "when the message is bundled after -m (-mn is the message n), then it is allowed; -nm is not" \
  '"$g" "git commit -mn" && "$g" "git commit -am \"fix -n handling\"" && blocked "git commit -anm x"'
check "when other git commands use -n (git log -n 5), then they are allowed" '"$g" "git log -n 5 --oneline"'
long="git commit -m \"$(head -c 100000 /dev/zero | tr '\0' 'a')\""
check "when a 100 KB command is checked under a UTF-8 locale, then it takes under 3 seconds (the hook allows 10)" \
  'start=$(date +%s); LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 "$g" "$long"; (( $(date +%s) - start < 3 ))'

git switch --quiet main
check "when Claude commits on main, then it is blocked" 'blocked "git commit -m x"'
check "when Claude pushes with no refspec while on main, then it is blocked" 'blocked "git push"'
check "when pushing HEAD or @ while on main, then it is blocked" 'blocked "git push origin HEAD" && blocked "git push origin @"'
check "when the command is not git, then it is allowed" '"$g" "ls -la && echo done"'

# The plugin hook shim: JSON in, guard decision out; silent outside jit projects.
shim="$ROOT/hooks/guard-git.sh"
json() { printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"%s"}}' "$1" "$2"; }
check "when the hook gets a blocked command inside a jit project, then it exits 2" \
  'rc=0; json "$PWD" "git push origin develop" | bash "$shim" 2>/dev/null || rc=$?; [[ $rc == 2 ]]'
mkdir -p "$TMP/plain" && git -C "$TMP/plain" init --quiet
check "when the project does not use jit-speckit, then the hook allows everything" \
  'json "$TMP/plain" "git push origin main" | bash "$shim"'


mkdir -p "$TMP/plain/.specify/extensions/jit/scripts"; echo 'exit 0' > "$TMP/plain/.specify/extensions/jit/scripts/guard.sh"
printf 'level: lite\n' > "$TMP/plain/.specify/extensions/jit/jit-config.yml"
check "when the repo ships its own guard (stale or tampered), then the plugin's copy decides, not the repo's" \
  'rc=0; json "$TMP/plain" "git add -A" | bash "$shim" 2>/dev/null || rc=$?; [[ $rc == 2 ]]'
mkdir -p "$TMP/plain/sub/.specify"
check "when the guard cannot decide (spec-kit in a subfolder), then it blocks instead of letting the command through" \
  'rc=0; (cd "$TMP/plain/sub" && "$g" "git status") 2>/dev/null || rc=$?; [[ $rc == 2 ]]'

exit "$FAIL"
