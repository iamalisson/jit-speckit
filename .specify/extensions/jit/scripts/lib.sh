# Shared helpers for jit-speckit scripts. Sourced, not executed.
# shellcheck shell=bash

JIT_CONFIG=".specify/extensions/jit/jit-config.yml"
# Where this extension's files live (the repo checkout, or .specify/extensions/jit once installed).
# shellcheck disable=SC2034  # used by the scripts that source this file
JIT_EXT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die() { echo "jit: $*" >&2; exit 1; }

# Run every script from the repository root.
# A spec-kit project in a subfolder of a bigger repo is refused, not half-supported: git hooks and
# CI live at the repository root, so jit's files would land in the wrong place.
jit_cd_root() {
  local top d
  top="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repository"
  d="$(pwd -P)" # physical, like git's top level (macOS /tmp is a symlink)
  while [[ "$d" != "$top" && "$d" == "$top"/* ]]; do
    if [[ -d "$d/.specify" ]]; then
      die "spec-kit is set up in ${d#"$top"/}/, a subfolder of the repository; jit-speckit needs it at the repository root ($top)"
    fi
    d="$(dirname "$d")"
  done
  cd "$top" || die "cannot enter $top"
}

# cfg <key> <default>: read a flat `key: value` line from the config file. A quoted value is
# taken as is ("Sprint #3" or 'Sprint #3'); an unquoted one ends at a ` #` comment.
cfg() {
  local v=""
  if [[ -f "$JIT_CONFIG" ]]; then
    v="$(sed -nE "/^$1:/{
      s/^$1:[[:space:]]*//
      /^\"/{ s/^\"([^\"]*)\".*$/\1/; p; q; }
      /^'/{ s/^'([^']*)'.*$/\1/; p; q; }
      s/[[:space:]]+#.*$//; s/[[:space:]]*$//; p; q
    }" "$JIT_CONFIG")"
  fi
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

# review_model: the model family the independent review must run on (default opus). Any other
# value dies, so the config can never lower the bar: callers read it with `|| exit 1`.
review_model() {
  local m; m="$(cfg review_model opus)"
  case "$m" in sonnet|opus|fable) echo "$m" ;; *) die "review_model must be sonnet, opus or fable" ;; esac
}

# Paths that hold tests, across the stacks jit-speckit supports (Django's app/tests.py, SwiftPM's
# Tests/, .NET's X.Tests/, Cypress). Case-sensitive: the PascalCase name is anchored on a lowercase
# letter or digit before it, so Contests.java or Latests.cs stay source. Read it through test_path_re.
TEST_PATH_RE='(^|/)([Tt]ests?|__tests__|spec|e2e|cypress)/|(^|/)[^/]*\.[Tt]ests?/|[._-]([Tt]est|[Ss]pec|cy)\.[a-zA-Z]+$|(^|/)tests?\.py$|(^|/)test_[^/]*\.py$|[a-z0-9]Tests?\.[a-z]+$'


# The repository's default branch: origin/HEAD when set, otherwise whichever of main/master
# really exists (origin/HEAD is often unset when the remote was added by hand).
default_branch() {
  local b c
  b="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [[ -n "$b" ]]; then echo "${b#origin/}"; return; fi
  for c in main master; do
    if git show-ref --verify --quiet "refs/remotes/origin/$c" || git show-ref --verify --quiet "refs/heads/$c"; then echo "$c"; return; fi
  done
  git config init.defaultBranch || echo main
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
  local level c; level="$(jit_level)"
  echo "$(default_branch) $(base_branch)"
  # main/master are release branches in every jit flow, whatever the remote calls its default
  # (a repo whose first push was develop has GitHub's default set to develop).
  for c in main master; do
    if git show-ref --verify --quiet "refs/heads/$c" || git show-ref --verify --quiet "refs/remotes/origin/$c"; then echo "$c"; fi
  done
  if [[ "$level" != lite ]]; then echo develop; fi
  if [[ "$level" == full ]]; then echo staging; fi
}
is_protected() { [[ " $(protected_branches | tr '\n' ' ') " == *" $1 "* ]]; }

# branch_feature: on a task branch (<prefix>/NNN-tNNN-...), the specs/ folder of its feature when
# exactly one matches; otherwise nothing.
branch_feature() {
  local num matches
  num="$(git branch --show-current 2>/dev/null | sed -nE "s#^[^/]+/($FEATURE_KEY_RE)-t[0-9]{3,}-.*#\\1#p")"
  [[ -n "$num" ]] || return 0
  matches="$(find specs -mindepth 1 -maxdepth 1 -type d -name "$num-*" 2>/dev/null)"
  if [[ -n "$matches" && "$(wc -l <<<"$matches")" -eq 1 ]]; then echo "$matches"; fi
}

feature_dir() {
  local d="" f=.specify/feature.json
  # On a task branch, the branch says which feature it belongs to. That wins, so a worktree never
  # acts on whatever feature the main checkout moved on to.
  d="$(branch_feature)"
  if [[ -n "$d" ]]; then echo "$d"; return; fi
  # A new worktree has no untracked files: fall back to the main worktree's active feature.
  [[ -f "$f" ]] || f="$(git rev-parse --git-common-dir)/../.specify/feature.json"
  d="$(sed -n 's/.*"feature_directory": *"\([^"]*\)".*/\1/p' "$f" 2>/dev/null)"
  [[ -n "$d" && -d "$d" ]] || die "no active feature (.specify/feature.json); run /speckit-specify first"
  echo "$d"
}

# base_ref: the base branch as a ref to diff against: origin's copy when it exists, else the local one.
base_ref() {
  local b; b="$(base_branch)"
  if git rev-parse --verify --quiet "origin/$b" >/dev/null; then echo "origin/$b"; else echo "$b"; fi
}

# diff_base: the commit where the branch left the base (HEAD itself when they share no history).
diff_base() { git merge-base HEAD "$(base_ref)" 2>/dev/null || git rev-parse HEAD; }

# diff_id: the patch id of the branch against the base (empty for an empty diff). Merging the base
# in keeps it, any edit changes it. --verbatim keeps whitespace, so a re-indent (Python, YAML,
# Makefiles) counts.
diff_id() {
  local from opt=--verbatim; from="$(diff_base)"
  git patch-id --verbatim </dev/null >/dev/null 2>&1 || opt=--stable # git < 2.39: whitespace-only edits slip
  git diff "$from" HEAD | git patch-id "$opt" | cut -d' ' -f1
}

# diff_record <kind>: the file that holds this diff's <kind> record (jit-mutants, jit-security),
# under .git so it never dirties the tree; its folder is created. Any commit makes it a new file.
diff_record() {
  local d id; d="$(git rev-parse --git-common-dir)/$1"; id="$(diff_id)"
  mkdir -p "$d"; echo "$d/${id:-empty}"
}

# resolve_feature <NNN | folder name>: the specs/ folder of a feature named by number or folder.
resolve_feature() {
  local m
  if [[ -d "specs/$1" ]]; then echo "specs/$1"; return; fi
  m="$(find specs -mindepth 1 -maxdepth 1 -type d -name "$1-*" 2>/dev/null)"
  [[ -n "$m" && "$(wc -l <<<"$m")" -eq 1 ]] || die "no single feature matches '$1' in specs/"
  echo "$m"
}

# constitution_cmd <build|test|lint|mutate>: that command from the constitution's **Commands**
# line ("build `x` · test `y` · ..."); empty when unset or still a [PLACEHOLDER].
# constitution_markers <file>: refuse a damaged jit block before anything is changed. Only a marker
# at the start of a line counts: one mentioned in prose is plain text, and so is a file with none.
constitution_markers() {
  [[ -f "$1" ]] || return 0
  local s e first_s first_e
  read -r s e first_s first_e < <(awk '/^<!-- jit:start/ { s++; if (!a) a = NR } /^<!-- jit:end -->/ { e++; if (!b) b = NR }
    END { print s + 0, e + 0, a + 0, b + 0 }' "$1")
  if ((s == 0 && e == 0)) || ((s == 1 && e == 1 && first_s < first_e)); then return 0; fi
  if ((s == 1 && e == 0)); then die "$1 has '<!-- jit:start' but no '<!-- jit:end -->'; restore the end marker, then run again"; fi
  die "$1's jit block is damaged: it needs one '<!-- jit:start' line followed by one '<!-- jit:end -->' line; fix the markers, then run again"
}

constitution_cmd() {
  local c
  c="$(sed -nE "s/.*\*\*Commands\*\*.*$1 \`([^\`]+)\`.*/\1/p" .specify/memory/constitution.md 2>/dev/null | head -1)"
  if [[ -n "$c" && "$c" != \[* ]]; then echo "$c"; fi
}

# test_path_re: TEST_PATH_RE, plus the constitution's optional `tests: <regex>` line (grep -E) for
# any other layout. Dies on an invalid one: callers read it in a plain assignment, `|| exit 1`.
test_path_re() {
  local extra err rc=0
  extra="$(sed -nE 's/^tests:[[:space:]]*//p' .specify/memory/constitution.md 2>/dev/null | head -1)"
  extra="${extra%"${extra##*[![:space:]]}"}"
  if [[ -z "$extra" ]]; then echo "$TEST_PATH_RE"; return; fi
  # One input line: busybox grep compiles the pattern only when it reads a line. Exit > 1, or any
  # message, means the regex does not compile (GNU and BSD exit 2; busybox prints "bad regex").
  err="$(echo x | grep -E -- "$extra" 2>&1 >/dev/null)" || rc=$?
  ((rc <= 1)) && [[ -z "$err" ]] || die "the constitution's tests: regex is invalid: $extra"
  echo "$TEST_PATH_RE|$extra"
}

# version_newer <a> <b>: true when both are dotted numbers (optional leading v) and a > b; a missing
# part counts as 0 (v2 = v2.0.0). Anything else (a branch name) is never newer. No `sort -V` (BSD).
version_newer() {
  local a="${1#v}" b="${2#v}" x y re='^[0-9]+(\.[0-9]+)*$'
  [[ "$a" =~ $re && "$b" =~ $re ]] || return 1
  while [[ -n "$a$b" ]]; do
    x="${a%%.*}"; y="${b%%.*}"
    if ((10#${x:-0} > 10#${y:-0})); then return 0; fi
    if ((10#${x:-0} < 10#${y:-0})); then return 1; fi
    if [[ "$a" == *.* ]]; then a="${a#*.}"; else a=""; fi
    if [[ "$b" == *.* ]]; then b="${b#*.}"; else b=""; fi
  done
  return 1
}

# The task line for an ID, e.g. "- [ ] T003 [P] [US1] Do x in src/x.py — #12".
task_line() { grep -m1 -E "^- \[.\] $2 " "$1/tasks.md" || true; }

# The issue number linked on a task line ("— #12" at the end), or empty.
task_issue() { sed -nE 's/.* — #([0-9]+)[[:space:]]*$/\1/p' <<<"$1"; }

# Task description without checkbox, ID, [P]/[USn] markers or the issue link.
task_desc() {
  sed -E 's/^- \[.\] T[0-9]{3,} //; s/^(\[P\] )?(\[US[0-9]+\] )?//; s/ — #[0-9]+[[:space:]]*$//' <<<"$1"
}

# "Completed when:" sub-bullet of a task, if the task has one.
# infra_files: tracked and new (not ignored) Dockerfiles and Terraform files, one per line.
# The single answer to "does this project have infrastructure?", for CI, Dependabot and scans.
infra_files() {
  git ls-files --cached --others --exclude-standard 2>/dev/null | grep -E '(^|/)(Dockerfile[^/]*|[^/]+\.tf)$' || true
}

# task_summary <task line>: the description without its file list, for titles and branch names.
# Cuts at " in `path`" or at " in some/path…" (spec-kit writes the paths either way).
task_summary() { task_desc "$1" | sed -E 's/ in `.*//; s/ in [^ ]*[/][^ ]*.*//'; }

# feature_key <feature dir or name>: its number, as spec-kit names features: a sequential prefix
# of 3+ digits (001-search -> 001) or a timestamp (20261104-153000-search -> 20261104-153000).
FEATURE_KEY_RE='[0-9]{8}-[0-9]{6}|[0-9]{3,}'
feature_key() { basename "$1" | sed -nE "s/^($FEATURE_KEY_RE)-.*/\1/p"; }

# A wrapped sub-bullet (continuation lines indented deeper) is joined into one line.
task_field() {
  awk -v id="$2" -v key="$3" '
    $0 ~ "^- \\[.\\] " id " " { inside = 1; next }
    inside && /^- \[/ { exit }
    found && /^    +[^ -]/ { sub(/^ +/, ""); value = value " " $0; next }
    found { exit }
    inside && index($0, "  - " key ":") == 1 { sub("^  - " key ":[[:space:]]*", ""); value = $0; found = 1 }
    END { if (found) print value }
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

# add_meta <issue|pr> <url>: assign the user, and set the configured milestone and project.
# Runs after creation, one edit per item, and only warns: optional metadata never stops a run
# halfway (a bot token that can't be assigned, a closed milestone, a token without project scope).
add_meta() {
  local kind="$1" url="$2" m p err i
  m="$(cfg milestone "")"; p="$(cfg project "")"
  local a=(--add-assignee @me)
  [[ -n "$m" ]] && a+=(--milestone "$m")
  [[ -n "$p" ]] && a+=(--add-project "$p")
  for ((i = 0; i < ${#a[@]}; i += 2)); do
    if ! err="$(gh "$kind" edit "$url" "${a[i]}" "${a[i+1]}" 2>&1 >/dev/null)"; then
      echo "jit: warning: could not set ${a[i]#--} '${a[i+1]}' on $url: ${err:-unknown error}" >&2
      if [[ "${a[i]}" == --add-project ]]; then echo "jit: (project access needs: gh auth refresh -s project)" >&2; fi
    fi
  done
}
