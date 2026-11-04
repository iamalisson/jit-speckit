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
grep -qE '^milestone:' "$JIT_CONFIG" || cfg_set milestone '""'
grep -qE '^project:' "$JIT_CONFIG" || cfg_set project '""'
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
  for b in ${need[@]+"${need[@]}"}; do
    if $has_origin; then
      git fetch --quiet origin 2>/dev/null || true
      if ! git show-ref --verify --quiet "refs/remotes/origin/$b"; then
        # --no-verify: this only gives an existing remote commit a new branch name; nothing new is sent.
        git push --quiet --no-verify origin "refs/remotes/origin/$(default_branch):refs/heads/$b" 2>/dev/null \
          || git push --quiet --no-verify origin "$(default_branch):refs/heads/$b"
        echo "branch: created origin/$b from $(default_branch)"
      fi
    elif ! git show-ref --verify --quiet "refs/heads/$b"; then
      if git rev-parse --verify --quiet HEAD >/dev/null; then git branch "$b"; echo "branch: created $b"; fi
    fi
  done
fi

# ── Stack facts ──────────────────────────────────────────────────────────────
stacks=(); while IFS= read -r s; do stacks+=("$s"); done < <(bash "$JIT_EXT_DIR/scripts/detect-stack.sh")
idioms=""; tests=()
for s in ${stacks[@]+"${stacks[@]}"}; do
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
[[ -n "$idioms" ]] || idioms=$'- [STACK_IDIOMS: formatter, linter and idioms for this stack; run /jit-speckit:adopt]\n'
test_cmd="[TEST_COMMAND]"
if ((${#tests[@]})); then test_cmd="$(printf '%s && ' "${tests[@]}")"; test_cmd="${test_cmd% && }"; fi

# ── Constitution block ───────────────────────────────────────────────────────
render() {
  local t; t="$(cat "$1")"
  t="${t//\{\{LEVEL\}\}/$level}"; t="${t//\{\{BRANCH_FLOW\}\}/$flow}"
  t="${t//\{\{TEST_COMMAND\}\}/$test_cmd}"; t="${t//\{\{STACK_IDIOMS\}\}/${idioms%$'\n'}}"
  printf '%s\n' "$t"
}
block="<!-- jit:start (managed by /jit-speckit:level; edit outside this block) -->"$'\n'
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
# shellcheck source=pins.sh
source "$JIT_EXT_DIR/scripts/pins.sh"

put() { # put <dest> (content on stdin): write only if missing
  if [[ -e "$1" ]]; then cat >/dev/null; echo "kept:    $1"; return; fi
  mkdir -p "$(dirname "$1")"; cat > "$1"; echo "created: $1"
}

branch_list() { # the long-lived branches workflows run on
  printf '%s' "$(default_branch)"
  if [[ $level != lite ]]; then printf ', develop'; fi
  if [[ $level == full ]]; then printf ', staging'; fi
}

checkout_step() { printf '      - uses: %s\n        with:\n          persist-credentials: false\n' "$PIN_CHECKOUT"; }

ci_yaml() {
  printf 'name: CI\n\non:\n  push:\n    branches: [%s]\n  pull_request:\n\npermissions:\n  contents: read\n\njobs:\n' "$(branch_list)"
  ((${#stacks[@]})) || printf '  checks:\n    runs-on: ubuntu-latest\n    steps:\n      - run: |\n          echo "jit: no stack detected. Replace this job with your lint, test and build commands." && exit 1\n'
  for s in ${stacks[@]+"${stacks[@]}"}; do
    case "$s" in
      rust)
        printf '  rust:\n    runs-on: ubuntu-latest\n    steps:\n'; checkout_step
        printf '      - uses: %s\n        with:\n          toolchain: stable\n          components: rustfmt, clippy\n' "$PIN_RUST_TOOLCHAIN"
        printf '      - uses: %s\n' "$PIN_RUST_CACHE"
        printf '      - run: cargo fmt --all -- --check\n      - run: cargo clippy --all-targets -- -D warnings\n      - run: cargo test --all\n' ;;
      node:*) pm="${s#node:}"
        printf '  node:\n    runs-on: ubuntu-latest\n    steps:\n'; checkout_step
        if [[ "$pm" == pnpm ]]; then printf '      - uses: %s\n' "$PIN_PNPM"; fi
        # The project's pinned Node, else the current LTS (never a hard-coded major that goes EOL).
        nv="node-version: lts/*"; for f in .node-version .nvmrc; do if [[ -f $f ]]; then nv="node-version-file: $f"; break; fi; done
        printf '      - uses: %s\n        with:\n          %s\n          cache: %s\n' "$PIN_SETUP_NODE" "$nv" "$pm"
        case "$pm" in pnpm) printf '      - run: pnpm install --frozen-lockfile\n' ;;
                      yarn) printf '      - run: yarn install --frozen-lockfile\n' ;;
                      npm) if [[ -f package-lock.json ]]; then printf '      - run: npm ci\n'; else printf '      - run: npm install\n'; fi ;; esac
        for script in lint typecheck test build; do
          if grep -qE "\"$script\" *:" package.json; then printf '      - run: %s run %s\n' "$pm" "$script"; fi
        done ;;
      python:uv)
        printf '  python:\n    runs-on: ubuntu-latest\n    steps:\n'; checkout_step
        printf '      - uses: %s\n      - run: uv sync --all-extras\n      - run: uv run ruff check .\n      - run: uv run pytest\n' "$PIN_SETUP_UV" ;;
      python:pip)
        printf '  python:\n    runs-on: ubuntu-latest\n    steps:\n'; checkout_step
        printf '      - uses: %s\n        with:\n          python-version: "3.12"\n' "$PIN_SETUP_PYTHON"
        printf '      - run: pip install -e ".[dev]" || pip install -r requirements.txt\n      - run: pip install ruff pytest && ruff check . && pytest\n' ;;
      go)
        printf '  go:\n    runs-on: ubuntu-latest\n    steps:\n'; checkout_step
        printf '      - uses: %s\n        with:\n          go-version-file: go.mod\n      - run: go vet ./...\n      - run: go test ./...\n' "$PIN_SETUP_GO" ;;
    esac
  done
}

security_yaml() {
  cat <<EOF
# Security gate: runs on every pull request, on pushes to long-lived branches, and weekly
# (new CVEs land in dependencies nobody touched). Tools are pinned and checksum-verified.
name: Security

on:
  pull_request:
  push:
    branches: [$(branch_list)]
  schedule:
    - cron: "17 6 * * 1"
  workflow_dispatch:

permissions:
  contents: read

jobs:
  secrets:
    name: Secrets (gitleaks, full history)
    runs-on: ubuntu-latest
    steps:
      - uses: $PIN_CHECKOUT
        with:
          fetch-depth: 0
          persist-credentials: false
      - name: Install gitleaks $GITLEAKS_VERSION (checksum-verified)
        run: |
          curl -sSfL -o gitleaks.tgz https://github.com/gitleaks/gitleaks/releases/download/v$GITLEAKS_VERSION/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz
          echo "$GITLEAKS_SHA256  gitleaks.tgz" | sha256sum -c -
          tar -xzf gitleaks.tgz gitleaks
      - run: ./gitleaks git --redact --verbose --no-banner .

  dependencies:
    name: Dependencies (osv-scanner)
    runs-on: ubuntu-latest
    steps:
$(checkout_step)
      - name: Install osv-scanner $OSV_VERSION (checksum-verified)
        run: |
          curl -sSfL -o osv-scanner https://github.com/google/osv-scanner/releases/download/v$OSV_VERSION/osv-scanner_linux_amd64
          echo "$OSV_SHA256  osv-scanner" | sha256sum -c -
          chmod +x osv-scanner
      - name: Scan every lockfile (exit 128 = no lockfiles)
        run: ./osv-scanner scan source -r . || { s=\$?; [ "\$s" = 128 ] || exit "\$s"; }

  workflows:
    name: Workflows (zizmor)
    runs-on: ubuntu-latest
    steps:
$(checkout_step)
      - uses: $PIN_ZIZMOR
        with:
          advanced-security: false
EOF
  if [[ -n "$(infra_files)" ]]; then
    cat <<EOF

  infra:
    name: Dockerfiles and Terraform (trivy config)
    runs-on: ubuntu-latest
    steps:
$(checkout_step)
      - name: Install trivy $TRIVY_VERSION (checksum-verified)
        run: |
          curl -sSfL -o trivy.tgz https://github.com/aquasecurity/trivy/releases/download/v$TRIVY_VERSION/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz
          echo "$TRIVY_SHA256  trivy.tgz" | sha256sum -c -
          tar -xzf trivy.tgz trivy
      - run: ./trivy config --exit-code 1 --severity HIGH,CRITICAL .
EOF
  fi
  if [[ $level == full ]]; then
    cat <<EOF

  code:
    name: Code (semgrep, OWASP rules)
    runs-on: ubuntu-latest
    steps:
$(checkout_step)
      - uses: $PIN_SETUP_UV
      - run: uvx --from semgrep==$SEMGREP_VERSION semgrep scan --config p/default --config p/owasp-top-ten --error --metrics off
EOF
  fi
}

# infra_dirs <ecosystem> <regex>: one Dependabot entry per folder holding matching infra files.
infra_dirs() {
  local dir
  while IFS= read -r dir; do
    [[ -n "$dir" ]] || continue
    dir="${dir#.}"; dir="${dir#/}"
    printf '  - package-ecosystem: %s\n    directory: "/%s"\n    schedule:\n      interval: weekly\n    target-branch: %s\n' "$1" "$dir" "$(base_branch)"
  done < <(infra_files | grep -E "$2" | sed -E 's#^#./#; s#/[^/]*$##' | sort -u)
}

# Kept out of $( ... ): bash 3.2 (macOS) misparses a case pattern's ")" inside a command substitution.
ecosystems() {
  echo github-actions
  for s in ${stacks[@]+"${stacks[@]}"}; do
    case "$s" in
      rust) echo cargo ;;
      node:*) echo npm ;;
      python:uv) echo uv ;;
      python:pip) echo pip ;;
      go) echo gomod ;;
    esac
  done
}

dependabot_yaml() {
  printf 'version: 2\nupdates:\n'
  local eco
  local dir
  for eco in $(ecosystems); do
    dir=/
    printf '  - package-ecosystem: %s\n    directory: "%s"\n    schedule:\n      interval: weekly\n    target-branch: %s\n    open-pull-requests-limit: 5\n    groups:\n      minor-and-patch:\n        update-types: [minor, patch]\n' "$eco" "$dir" "$(base_branch)"
  done
  # Base images and Terraform providers, in every folder that has them.
  infra_dirs docker '(^|/)Dockerfile[^/]*$'
  infra_dirs terraform '\.tf$'
}

for l in "${levels[@]}"; do
  src="$JIT_EXT_DIR/scaffold/$l"
  [[ -d "$src" ]] || continue
  while IFS= read -r f; do
    put "${f#"$src"/}" < "$f"
  done < <(find "$src" -type f | sort)
  case "$l" in
    lite) chmod +x .githooks/* ;;
    standard) ci_yaml | put .github/workflows/ci.yml
              security_yaml | put .github/workflows/security.yml
              dependabot_yaml | put .github/dependabot.yml ;;
    full) owner="$(repo_slug)"; owner="${owner%%/*}"
          printf '# Every change needs a review from an owner.\n* @%s\n' "${owner:-OWNER}" | put .github/CODEOWNERS ;;
  esac
done

# ── Git hooks ────────────────────────────────────────────────────────────────
# core.hooksPath is per clone: every teammate's /jit-speckit:init (or this script) sets it.
hooks_path="$(git config --get core.hooksPath || true)"
if [[ "$hooks_path" == .githooks ]]; then
  echo "git hooks: enabled (.githooks)"
elif [[ -z "$hooks_path" && ! -f .pre-commit-config.yaml && ! -d .husky ]]; then
  git config core.hooksPath .githooks
  echo "git hooks: enabled (.githooks: secret check on commit, secret + branch check on push)"
else
  echo "git hooks: this repo already has its own (${hooks_path:-pre-commit or husky}); add these lines to it:"
  echo "  pre-commit: bash .specify/extensions/jit/scripts/secrets.sh staged"
  echo "  pre-push:   bash .specify/extensions/jit/scripts/prepush.sh \"\$@\""
fi

if [[ "$previous" == full && "$level" != full ]] || [[ "$previous" == standard && "$level" == lite ]]; then
  echo "note: files added by the higher level were kept; delete any you no longer want"
fi
