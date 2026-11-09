#!/usr/bin/env bash
# Guard for git commands run by Claude Code (called by the plugin's PreToolUse hook).
# Usage: guard.sh "<bash command>"   — exit 2 (with the reason on stderr) blocks the command.
# Rules: no --no-verify or a prefix of it (or commit/am -n), no hooks disabled with -c
#        core.hooksPath or SKIP=, no `git add -A/--all/.`, no commit on a protected branch, no push
#        to a protected branch (counting every branch a switch/checkout earlier in the chain may
#        have moved to).
# Each git command is checked against the repository it runs in: the hook's directory, moved by a
# `cd`/`pushd` earlier in the chain or by `git -C`. A repository without landspec is not checked.
# Best effort: it catches the usual forms (chains, env/command/VAR= prefixes, sh -c '...', git
# global options, bundled flags), not every possible shell trick. The real boundary is CI plus
# branch protection. People are not affected; their git hooks still apply.
set -uo pipefail
# Byte-wise: under a UTF-8 locale ${s:i:1} is O(i), which makes long commands quadratic and could
# outrun the hook's timeout (a timed-out hook lets the command through).
export LC_ALL=C
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
# A guard that cannot decide blocks: Claude Code lets the command through on exit 1.
die() { echo "landspec guard: $*" >&2; exit 2; }

block() { echo "landspec guard: $1" >&2; exit 2; }
start="$(pwd -P)"
# Where the next command runs; "" when a cd went somewhere it can't tell ($VAR, cd -).
dir="$start"
# Every branch the chain may be on in repository $btop: a switch/checkout earlier in it adds the
# branch it moves to. Reset when a command targets another repository.
btop="" branches=""

# resolve <base> <path>: the physical directory <path> names from <base>, or "" when it can't tell.
resolve() {
  local p="$2"
  [[ -n "$1" ]] || { echo ""; return; }
  case "$p" in
    *'$'*|*'`'*|*'*'*|*'?'*|-) echo ""; return ;;
    \~) p="$HOME" ;; # a literal ~: the command text was never expanded
    \~/*) p="$HOME/${p#\~/}" ;;
    /*) ;;
    *) p="$1/$p" ;;
  esac
  (cd "$p" 2>/dev/null && pwd -P) || echo ""
}

# enter_repo <dir>: cd to the top of the landspec repository a git command runs in. Fails (the
# command is not checked) when <dir> is not in a repository or the repository has no landspec.
enter_repo() {
  local top
  cd "$1" 2>/dev/null || return 1
  top="$(git rev-parse --show-toplevel 2>/dev/null)" || return 1
  [[ -d "$top/.specify/extensions/landspec" || -d "$top/.specify/extensions/jit" ]] || return 1 # jit: the name before 2.0.0
  landspec_cd_root
  if [[ "$top" != "$btop" ]]; then btop="$top"; branches=" $(git branch --show-current 2>/dev/null || true) "; fi
}

# no_verify <word>: --no-verify or any prefix of it from 3 characters (git takes unique prefixes).
no_verify() { ((${#1} >= 3)) && [[ "--no-verify" == "$1"* ]]; }

# switched <switch|checkout> <args...>: add the branch they may move to. Restoring files
# (`checkout [<tree-ish>] -- <paths>`) adds nothing; a word it cannot tell apart is added.
switched() {
  local cmd="$1" w o found=""; shift
  while (($#)); do
    w="$1"; shift
    o="${w%%=*}"
    case "$w" in
      # checkout -- <paths> restores files; for switch, -- only ends the options and the branch follows.
      --) [[ "$cmd" == switch ]] || return 0; [[ -z "${1:-}" ]] || found+=" $1 "; break ;;
      --*)
        # git takes a unique prefix of a long option, so --cr is --create.
        if ((${#o} >= 4)) && [[ "--create" == "$o"* || "--force-create" == "$o"* || "--orphan" == "$o"* ]]; then
          if [[ "$w" == *=* ]]; then w="${w#*=}"; else w="${1:-}"; fi; branches+=" $w "; return 0
        fi
        [[ "$w" != *=* ]] || found+=" ${w#*=} " ;;
      -?*)
        # Short bundle: a new-branch letter takes the rest of the word, or the next word.
        if [[ "$w" == -*[bBcC]* ]]; then
          w="${w#*[bBcC]}"; [[ -n "$w" ]] || w="${1:-}"; branches+=" $w "; return 0
        fi ;;
      -) found+=" $(git rev-parse --abbrev-ref "@{-1}" 2>/dev/null || echo -) " ;;
      *) found+=" $w " ;;
    esac
  done
  # A switch to [refs/][remotes/]<remote>/<branch> may land on the local <branch>: git creates it
  # with --track, --no-track, or none when only the remote has it. Add that name whatever the flags,
  # so no tracking form is missed; the cost is a refusal git would not need (detached checkouts).
  for w in $found; do w="${w#refs/}"; w="${w#remotes/}"; [[ "$w" != */* ]] || found+=" ${w#*/} "; done
  branches+="$found"
}

# words "<text>": shell-like words, one per line. Quotes group and are removed; nothing is
# expanded or run. Unquoted && || ; | & and newlines become a "|" word, separating commands. A #
# at the start of a word starts a comment. In awk, linear in the length (bash's ${s:i:1} is not).
words() {
  awk '
    { text = text $0 "\n" }
    END {
      n = length(text); w = ""; inw = 0
      for (i = 1; i <= n; i++) {
        c = substr(text, i, 1)
        if (c == "\047" || c == "\"") {
          # The whole quoted run at once: no per-character work inside long messages.
          j = index(substr(text, i + 1), c); if (j == 0) j = n - i + 1
          part = substr(text, i + 1, j - 1); gsub(/\n/, " ", part)
          w = w part; inw = 1; i += j; continue
        }
        if (c == "#" && !inw) { while (i < n && substr(text, i + 1, 1) != "\n") i++; continue }
        if (c == " " || c == "\t" || c == "\n" || c == ";" || c == "|" || c == "&") {
          if (inw) { print w; w = ""; inw = 0 }
          if (c != " " && c != "\t") print "|"
          continue
        }
        w = w c; inw = 1
      }
      if (inw) print w
    }
  ' <<<"$1"
}

# without_heredocs: drops heredoc bodies (data, not commands), so a quote inside one can't hide the
# commands after it. `<<<` here-strings are left alone.
without_heredocs() {
  awk '
    skip { t = $0; if (strip) sub(/^\t+/, "", t); if (t == delim) skip = 0; next }
    { print }
    match($0, /(^|[^<])<<-?[ \t]*["\047]?[A-Za-z_][A-Za-z0-9_]*/) {
      h = substr($0, RSTART, RLENGTH); sub(/^[^<]?<</, "", h)
      strip = (h ~ /^-/); sub(/^-?[ \t]*["\047]?/, "", h); delim = h; skip = 1
    }
  ' <<<"$1"
}

hookspath() { [[ "$(tr '[:upper:]' '[:lower:]' <<<"$1")" == *core.hookspath* ]]; }
no_hooks() { block "switching git hooks off skips the secret checks"; }

# check_git <args...>: the words after `git`.
check_git() {
  local sub="" w gdir="${dir:-$start}"
  # Global options before the subcommand; -C and -c take a value. Each -C moves on from the last.
  while (($#)); do
    case "$1" in
      -c|--config-env) if hookspath "${2:-}"; then no_hooks; fi; shift 2 ;;
      -c*|--config-env=*) if hookspath "$1"; then no_hooks; fi; shift ;;
      -C) gdir="$(resolve "$gdir" "${2:-}")"; [[ -n "$gdir" ]] || gdir="$start"; shift 2 ;;
      --git-dir|--work-tree|--namespace) shift 2 ;;
      -*) shift ;;
      *) sub="$1"; shift; break ;;
    esac
  done
  enter_repo "$gdir" || return 0
  # pre-commit's SKIP= only matters where hooks run; `SKIP=x git status` is fine.
  case "$sub" in commit|push|merge|rebase|am|cherry-pick|revert)
    if $skip_env; then block "SKIP= turns pre-commit hooks off; fix what the hook reports instead"; fi ;;
  esac
  case "$sub" in
    commit)
      while (($#)); do
        case "$1" in
          -m|-F|-C|-c|-t|--message|--file|--template|--reuse-message|--reedit-message|--author|--date|--fixup|--squash) shift ;;
          --*) if no_verify "$1"; then block "--no-verify skips the secret checks; fix what the hook reports instead"; fi ;;
          -*)
            # Bundled short options: letters up to the first one that takes a value. -nm "x" is
            # -n -m "x"; -mn is the message "n".
            b="${1#-}"; b="${b%%[mFCctuS]*}"
            if [[ "$b" == *n* ]]; then block "commit -n is --no-verify, which skips the secret checks"; fi
            [[ "${1#-}" == "$b"[mFCctuS] ]] && shift ;;
        esac
        shift
      done
      for b in $branches; do
        if is_protected "$b"; then
          block "committing on '$b' is not allowed; start a task with /speckit-implement Tnnn (or /landspec:next)"
        fi
      done ;;
    switch|checkout) switched "$sub" "$@" ;;
    config)
      local w2 reading=false keys=0
      for w2 in "$@"; do case "$w2" in --get|--get-all|--get-regexp|--list|-l|get) reading=true ;; esac; done
      # `git config core.hooksPath` (a key and no value, no other action) only reads it.
      for w2 in "$@"; do case "$w2" in --local|--global|--system|--worktree|--show-origin|--show-scope) ;; -*) keys=9 ;; *) keys=$((keys + 1)) ;; esac; done
      ((keys == 1)) && reading=true
      for w2 in "$@"; do
        if hookspath "$w2" && ! $reading; then no_hooks; fi
      done ;;
    merge|rebase|am)
      for w in "$@"; do
        if no_verify "$w"; then block "--no-verify skips the secret checks; fix what the hook reports instead"; fi
        # am -n is --no-verify (merge/rebase -n is --no-stat). Bundles stop at a letter that takes a value.
        if [[ "$sub" == am && "$w" == -[!-]* ]]; then
          b="${w#-}"; b="${b%%[CpS]*}"
          if [[ "$b" == *n* ]]; then block "am -n is --no-verify, which skips the secret checks"; fi
        fi
      done ;;
    cherry-pick|revert)
      for w in "$@"; do
        [[ "$w" == --no-verify ]] && block "--no-verify skips the secret checks; fix what the hook reports instead"
      done ;;
    add)
      for w in "$@"; do
        case "$w" in -A|--all|.|:/|-[a-zA-Z]*A*) block "stage files by name (git add path/to/file), not everything at once" ;; esac
      done ;;
    push)
      local targets="" remote_seen=false
      for w in "$@"; do
        case "$w" in
          --all|--mirror) block "push --all/--mirror would push the protected branches too; push your branch by name" ;;
          -*) if no_verify "$w"; then block "--no-verify skips the pre-push secret scan"; fi ;;
          *) if ! $remote_seen && git remote get-url "$w" >/dev/null 2>&1; then remote_seen=true; continue; fi
             w="${w#+}"; w="${w##*:}"
             [[ "$w" == HEAD || "$w" == @ ]] && w="$branches"
             targets+=" $w " ;;
        esac
      done
      [[ -n "$targets" ]] || targets="$branches"
      for b in $(protected_branches); do
        if [[ "$targets" == *" $b "* || "$targets" == *" HEAD:$b "* || "$targets" == *" refs/heads/$b "* ]]; then
          block "pushing to '$b' is not allowed; it only changes through pull requests"
        fi
      done ;;
  esac
}

# check_command <command text> [nested]: every command in it, including ones inside sh -c '...'.
# An env prefix (SKIP=) belongs to one top-level command; inside sh -c it carries over.
check_command() {
  local cmd=() w nested="${2:-}"
  while IFS= read -r w; do
    if [[ "$w" == "|" ]]; then
      [[ -n "$nested" ]] || skip_env=false
      check_words ${cmd[@]+"${cmd[@]}"}; cmd=()
    else cmd+=("$w"); fi
  done < <(words "$(without_heredocs "$1")")
  [[ -n "$nested" ]] || skip_env=false
  check_words ${cmd[@]+"${cmd[@]}"}
}

check_words() {
  local w
  # Git reads config from the environment too (GIT_CONFIG_PARAMETERS, GIT_CONFIG_KEY_n).
  for w in "$@"; do
    if [[ "$w" == GIT_CONFIG_*=* ]] && hookspath "$w"; then no_hooks; fi
  done
  # Prefixes that still run git: VAR=value, env [VAR=value...], command, exec, time, nohup.
  # SKIP= (pre-commit) is remembered: it also reaches the commands inside a `sh -c '...'`.
  while (($#)); do
    case "$1" in
      SKIP=*|PRE_COMMIT_ALLOW_NO_CONFIG=*) skip_env=true; shift ;;
      *=*|env|command|exec|time|nohup|sudo) shift ;;
      *) break ;;
    esac
  done
  (($#)) || return 0
  case "$1" in
    cd|pushd)
      shift
      while [[ "${1:-}" == -?* ]]; do shift; done
      dir="$(resolve "${dir:-$start}" "${1:-~}")" ;;
    git|*/git) shift; check_git "$@" ;;
    sh|bash|zsh|*/sh|*/bash|*/zsh)
      shift
      while (($#)); do
        if [[ "$1" == -*c* && "$1" != --* ]]; then check_command "${2:-}" nested; return; fi
        shift
      done ;;
  esac
}

skip_env=false
check_command "${1:-}"
exit 0
