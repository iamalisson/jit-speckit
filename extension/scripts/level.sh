#!/usr/bin/env bash
# Set the project's complexity level and apply its defaults.
# Usage: level.sh <lite|standard|full> [--no-branches]
#   - stores the level in .specify/extensions/jit/jit-config.yml
#   - creates the level's long-lived branches (develop, staging) if missing (skip with --no-branches)
#   - rewrites the jit block of .specify/memory/constitution.md (nothing outside it is touched)
#   - adds the level's scaffold files that do not exist yet (existing files are never overwritten)
# Safe to re-run; going down a level never deletes files.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
shopt -u patsub_replacement 2>/dev/null || true

level="${1:-}"; branches=true
[[ "${2:-}" == --no-branches ]] && branches=false
case "$level" in lite|standard|full) ;; *) die "usage: level.sh <lite|standard|full> [--no-branches]" ;; esac
jit_cd_root

previous="$(cfg level none)"
cfg_set level "$level"
grep -qE '^base_branch:' "$JIT_CONFIG" || cfg_set base_branch auto
grep -qE '^branch_prefix:' "$JIT_CONFIG" || cfg_set branch_prefix feat
grep -qE '^issue_labels:' "$JIT_CONFIG" || cfg_set issue_labels '"type:task"'
echo "level: $previous → $level"

case "$level" in
  lite) levels=(lite); flow="feat/* → $(default_branch)" ;;
  standard) levels=(lite standard); flow="feat/* → develop → $(default_branch)" ;;
  full) levels=(lite standard full); flow="feat/* → develop → staging → $(default_branch)" ;;
esac

# ── Branch flow ──────────────────────────────────────────────────────────────
if $branches; then
  need=()
  if [[ "$level" != lite ]]; then need+=(develop); fi
  if [[ "$level" == full ]]; then need+=(staging); fi
  has_origin=false; git remote get-url origin >/dev/null 2>&1 && has_origin=true
  for b in "${need[@]}"; do
    if $has_origin; then
      git fetch --quiet origin 2>/dev/null || true
      if ! git show-ref --verify --quiet "refs/remotes/origin/$b"; then
        git push --quiet origin "refs/remotes/origin/$(default_branch):refs/heads/$b" 2>/dev/null \
          || git push --quiet origin "$(default_branch):refs/heads/$b"
        echo "branch: created origin/$b from $(default_branch)"
      fi
    elif ! git show-ref --verify --quiet "refs/heads/$b"; then
      if git rev-parse --verify --quiet HEAD >/dev/null; then git branch "$b"; echo "branch: created $b"; fi
    fi
  done
fi

# ── Stack facts ──────────────────────────────────────────────────────────────
mapfile -t stacks < <("$JIT_EXT_DIR/scripts/detect-stack.sh")
idioms=""; tests=()
for s in "${stacks[@]}"; do
  case "$s" in
    rust) idioms+=$'- Rust: `cargo fmt` and `cargo clippy -- -D warnings` clean; `Result` with `?`, no `unwrap` outside tests and startup.\n'
          tests+=("cargo test --all") ;;
    node:*) pm="${s#node:}"
          idioms+="- TypeScript/JavaScript: strict type checking, lint clean (\`$pm run lint\`), no \`any\` without a comment saying why."$'\n'
          tests+=("$pm test") ;;
    python:*) run=""; [[ "$s" == python:uv ]] && run="uv run "
          idioms+=$'- Python: `ruff` clean, type hints on public functions, a type checker in CI where configured.\n'
          tests+=("${run}pytest") ;;
    go) idioms+=$'- Go: `gofmt` and `go vet` clean; wrap errors with context, no panics in library code.\n'
          tests+=("go test ./...") ;;
  esac
done
[[ -n "$idioms" ]] || idioms=$'- [STACK_IDIOMS: formatter, linter and idioms for this stack; run /jit-speckit-adopt]\n'
test_cmd="[TEST_COMMAND]"
if ((${#tests[@]})); then test_cmd="$(printf '%s && ' "${tests[@]}")"; test_cmd="${test_cmd% && }"; fi

# ── Constitution block ───────────────────────────────────────────────────────
render() {
  local t; t="$(cat "$1")"
  t="${t//\{\{LEVEL\}\}/$level}"; t="${t//\{\{BRANCH_FLOW\}\}/$flow}"
  t="${t//\{\{TEST_COMMAND\}\}/$test_cmd}"; t="${t//\{\{STACK_IDIOMS\}\}/${idioms%$'\n'}}"
  printf '%s\n' "$t"
}
block="<!-- jit:start (managed by /jit-speckit-level; edit outside this block) -->"$'\n'
block+="## Defaults (jit-speckit, level: $level)"$'\n'
for l in "${levels[@]}"; do block+=$'\n'"$(render "$JIT_EXT_DIR/levels/$l.md")"$'\n'; done
block+="<!-- jit:end -->"

const=".specify/memory/constitution.md"
mkdir -p "$(dirname "$const")"; touch "$const"
B="$block" awk '
  /<!-- jit:start/ { print ENVIRON["B"]; skip = 1; done = 1; next }
  /<!-- jit:end -->/ { skip = 0; next }
  skip { next }
  !done && /^## Governance/ { print ENVIRON["B"]; print ""; done = 1 }
  { print }
  END { if (!done) { print ""; print ENVIRON["B"] } }
' "$const" > "$const.tmp" && mv "$const.tmp" "$const"
echo "constitution: jit block set to '$level' in $const"

# ── Scaffold ─────────────────────────────────────────────────────────────────
put() { # put <dest> (content on stdin): write only if missing
  if [[ -e "$1" ]]; then cat >/dev/null; echo "kept:    $1"; return; fi
  mkdir -p "$(dirname "$1")"; cat > "$1"; echo "created: $1"
}

ci_yaml() {
  printf 'name: CI\n\non:\n  push:\n    branches: [%s]\n  pull_request:\n\npermissions:\n  contents: read\n\njobs:\n' \
    "$(default_branch)$([[ $level != lite ]] && echo ", develop")$([[ $level == full ]] && echo ", staging")"
  ((${#stacks[@]})) || printf '  checks:\n    runs-on: ubuntu-latest\n    steps:\n      - run: |\n          echo "jit: no stack detected. Replace this job with your lint, test and build commands." && exit 1\n'
  for s in "${stacks[@]}"; do
    case "$s" in
      rust) cat <<'EOF'
  rust:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: rustfmt, clippy
      - uses: Swatinem/rust-cache@v2
      - run: cargo fmt --all -- --check
      - run: cargo clippy --all-targets -- -D warnings
      - run: cargo test --all
EOF
      ;;
      node:*) pm="${s#node:}"
        printf '  node:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v4\n'
        if [[ "$pm" == pnpm ]]; then printf '      - uses: pnpm/action-setup@v4\n'; fi
        printf '      - uses: actions/setup-node@v4\n        with:\n          node-version: 20\n          cache: %s\n' "$pm"
        case "$pm" in pnpm) printf '      - run: pnpm install --frozen-lockfile\n' ;;
                      yarn) printf '      - run: yarn install --frozen-lockfile\n' ;;
                      npm) if [[ -f package-lock.json ]]; then printf '      - run: npm ci\n'; else printf '      - run: npm install\n'; fi ;; esac
        for script in lint typecheck test build; do
          if grep -qE "\"$script\" *:" package.json; then printf '      - run: %s run %s\n' "$pm" "$script"; fi
        done
      ;;
      python:uv) cat <<'EOF'
  python:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v5
      - run: uv sync --all-extras
      - run: uv run ruff check .
      - run: uv run pytest
EOF
      ;;
      python:pip) cat <<'EOF'
  python:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: pip install -e ".[dev]" || pip install -r requirements.txt
      - run: pip install ruff pytest && ruff check . && pytest
EOF
      ;;
      go) cat <<'EOF'
  go:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - run: go vet ./...
      - run: go test ./...
EOF
      ;;
    esac
  done
}

dependabot_yaml() {
  printf 'version: 2\nupdates:\n'
  local eco
  for eco in github-actions $(for s in "${stacks[@]}"; do case "$s" in rust) echo cargo ;; node:*) echo npm ;; python:uv) echo uv ;; python:pip) echo pip ;; go) echo gomod ;; esac; done); do
    printf '  - package-ecosystem: %s\n    directory: "/"\n    schedule:\n      interval: weekly\n    target-branch: %s\n    open-pull-requests-limit: 5\n    groups:\n      minor-and-patch:\n        update-types: [minor, patch]\n' "$eco" "$(base_branch)"
  done
}

for l in "${levels[@]}"; do
  src="$JIT_EXT_DIR/scaffold/$l"
  [[ -d "$src" ]] || continue
  while IFS= read -r f; do
    put "${f#"$src"/}" < "$f"
  done < <(find "$src" -type f | sort)
  case "$l" in
    standard) ci_yaml | put .github/workflows/ci.yml; dependabot_yaml | put .github/dependabot.yml ;;
    full) owner="$(repo_slug)"; owner="${owner%%/*}"
          printf '# Every change needs a review from an owner.\n* @%s\n' "${owner:-OWNER}" | put .github/CODEOWNERS ;;
  esac
done

if [[ "$previous" == full && "$level" != full ]] || [[ "$previous" == standard && "$level" == lite ]]; then
  echo "note: files added by the higher level were kept; delete any you no longer want"
fi
