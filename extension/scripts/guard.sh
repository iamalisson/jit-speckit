#!/usr/bin/env bash
# Guard for git commands run by Claude Code (called by the plugin's PreToolUse hook).
# Usage: guard.sh "<bash command>"   — exit 2 (with the reason on stderr) blocks the command.
# Rules: no --no-verify (or commit -n), no hooks disabled with -c core.hooksPath, no
#        `git add -A/--all/.`, no commit on a protected branch, no push to a protected branch.
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
die() { echo "jit-speckit guard: $*" >&2; exit 2; }
jit_cd_root

block() { echo "jit-speckit guard: $1" >&2; exit 2; }
current="$(git branch --show-current 2>/dev/null || true)"

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
  local sub="" w
  # Global options before the subcommand; -C and -c take a value.
  while (($#)); do
    case "$1" in
      -c|--config-env) if hookspath "${2:-}"; then no_hooks; fi; shift 2 ;;
      -c*|--config-env=*) if hookspath "$1"; then no_hooks; fi; shift ;;
      -C|--git-dir|--work-tree|--namespace) shift 2 ;;
      -*) shift ;;
      *) sub="$1"; shift; break ;;
    esac
  done
  case "$sub" in
    commit)
      while (($#)); do
        case "$1" in
          --no-verify) block "--no-verify skips the secret checks; fix what the hook reports instead" ;;
          -m|-F|-C|-c|-t|--message|--file|--template|--reuse-message|--reedit-message|--author|--date|--fixup|--squash) shift ;;
          --*) ;;
          -*)
            # Bundled short options: letters up to the first one that takes a value. -nm "x" is
            # -n -m "x"; -mn is the message "n".
            b="${1#-}"; b="${b%%[mFCctuS]*}"
            if [[ "$b" == *n* ]]; then block "commit -n is --no-verify, which skips the secret checks"; fi
            [[ "${1#-}" == "$b"[mFCctuS] ]] && shift ;;
        esac
        shift
      done
      if [[ -n "$current" ]] && is_protected "$current"; then
        block "committing on '$current' is not allowed; start a task with /speckit-implement Tnnn (or /jit-speckit:next)"
      fi ;;
    config)
      local w2 reading=false
      for w2 in "$@"; do case "$w2" in --get|--get-all|--get-regexp|--list|-l|get) reading=true ;; esac; done
      for w2 in "$@"; do
        if hookspath "$w2" && ! $reading; then no_hooks; fi
      done ;;
    merge|rebase|am|cherry-pick|revert)
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
          --no-verify) block "--no-verify skips the pre-push secret scan" ;;
          --all|--mirror) block "push --all/--mirror would push the protected branches too; push your branch by name" ;;
          -*) ;;
          *) if ! $remote_seen && git remote get-url "$w" >/dev/null 2>&1; then remote_seen=true; continue; fi
             w="${w#+}"; w="${w##*:}"
             [[ "$w" == HEAD || "$w" == @ ]] && w="$current"
             targets+=" $w " ;;
        esac
      done
      [[ -n "$targets" ]] || targets=" $current "
      for b in $(protected_branches); do
        if [[ "$targets" == *" $b "* || "$targets" == *" HEAD:$b "* || "$targets" == *" refs/heads/$b "* ]]; then
          block "pushing to '$b' is not allowed; it only changes through pull requests"
        fi
      done ;;
  esac
}

# check_command <command text>: every command in it, including ones inside sh -c '...'.
check_command() {
  local cmd=() w
  while IFS= read -r w; do
    if [[ "$w" == "|" ]]; then check_words ${cmd[@]+"${cmd[@]}"}; cmd=(); else cmd+=("$w"); fi
  done < <(words "$(without_heredocs "$1")")
  check_words ${cmd[@]+"${cmd[@]}"}
}

check_words() {
  local w
  # Git reads config from the environment too (GIT_CONFIG_PARAMETERS, GIT_CONFIG_KEY_n).
  for w in "$@"; do
    if [[ "$w" == GIT_CONFIG_*=* ]] && hookspath "$w"; then no_hooks; fi
  done
  # Prefixes that still run git: VAR=value, env [VAR=value...], command, exec, time, nohup.
  while (($#)); do
    case "$1" in
      *=*|env|command|exec|time|nohup|sudo) shift ;;
      *) break ;;
    esac
  done
  (($#)) || return 0
  case "$1" in
    git|*/git) shift; check_git "$@" ;;
    sh|bash|zsh|*/sh|*/bash|*/zsh)
      shift
      while (($#)); do
        if [[ "$1" == -*c* && "$1" != --* ]]; then check_command "${2:-}"; return; fi
        shift
      done ;;
  esac
}

check_command "${1:-}"
exit 0
