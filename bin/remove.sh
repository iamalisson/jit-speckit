#!/usr/bin/env bash
# Remove jit-speckit from one project (the reverse of setup.sh). Spec-kit, your specs and your edits stay.
# Usage: remove.sh [project-dir] [--with-speckit]
#   --with-speckit  also delete spec-kit's own files (.specify/, .claude/skills/speckit-*) for a reinstall from zero; specs/ is never touched
# Deletes only what jit-speckit created: files that still carry its "managed file" marker or are identical
# to its scaffold, its lines in hook configs, and its block in the constitution. Safe to re-run.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
die() { echo "jit: $*" >&2; exit 1; }
usage() { sed -n '3p' "$0" | sed 's/^# Usage/Usage/' >&2; exit 2; }

dir="."; speckit=false
while (($#)); do
  case "$1" in
    --with-speckit) speckit=true; shift ;;
    -h|--help) usage ;;
    -*) echo "jit: unknown option $1" >&2; usage ;;
    *) dir="$1"; shift ;;
  esac
done
cd "$dir" 2>/dev/null || die "no such directory: $dir"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not a git repository: $dir"
cd "$(git rev-parse --show-toplevel)"
gone() { echo "removed: $1"; }

# ── spec-kit registrations: extension, preset, hook skills ───────────────────
if [[ -d .specify/extensions/jit || -d .specify/presets/jit ]]; then
  command -v specify >/dev/null || die "spec-kit (specify) is required to unregister the extension; install it as /jit-speckit:init says"
  # specify refuses what its registry doesn't know; a half-installed copy is then deleted by hand.
  specify preset remove jit >/dev/null 2>&1 || rm -rf .specify/presets/jit
  specify extension remove jit --force >/dev/null 2>&1 || rm -rf .specify/extensions/jit
  rm -rf .specify/extensions/.backup/jit
  gone "spec-kit extension and preset 'jit' (templates and the implement command restored)"
fi
rm -rf .claude/skills/speckit-jit-*

# ── Files added to the repo ──────────────────────────────────────────────────
ours() { # ours <file>: created by jit-speckit and not taken over by the user
  [[ -f "$1" ]] || return 1
  if head -2 "$1" | grep -q '^# jit-speckit: managed file'; then return 0; fi
  local l
  for l in lite standard full; do
    if [[ -f "$here/extension/scaffold/$l/$1" ]] && cmp -s "$1" "$here/extension/scaffold/$l/$1"; then return 0; fi
  done
  [[ "$1" == .github/CODEOWNERS && "$(head -1 "$1")" == "# Every change needs a review from an owner." && "$(wc -l < "$1")" -le 2 ]]
}
{ (cd "$here/extension/scaffold" && find lite standard full -type f | sed 's#^[a-z]*/##')
  printf '%s\n' .github/workflows/ci.yml .github/workflows/security.yml .github/dependabot.yml .github/CODEOWNERS
} | sort -u | while IFS= read -r f; do
  if ours "$f"; then rm "$f"; gone "$f"; fi
done
rmdir -p .githooks .github/workflows 2>/dev/null || true

# ── Git hooks ────────────────────────────────────────────────────────────────
if [[ "$(git config --get core.hooksPath || true)" == .githooks && ! -e .githooks ]]; then
  git config --unset core.hooksPath; echo "git hooks: core.hooksPath unset"
fi
pc=.pre-commit-config.yaml
if [[ -f "$pc" ]] && grep -qE '^ *- +id: jit-(secrets|prepush) *$' "$pc"; then
  awk '
    function ind(s) { match(s, /^ */); return RLENGTH }
    { L[NR] = $0 }
    END {
      n = 0
      for (i = 1; i <= NR; i++) { # the jit hook items: the "- id:" line and every line indented deeper
        if (L[i] ~ /^ *- +id: jit-(secrets|prepush) *$/) {
          d = ind(L[i]); while (i < NR && (L[i+1] ~ /^ *$/ || ind(L[i+1]) > d)) i++
          continue
        }
        M[++n] = L[i]
      }
      for (i = 1; i <= n; i++) { # a "repo: local" left with no hooks
        if (M[i] ~ /^ *- +repo: local *$/ && M[i+1] ~ /^ *hooks: *$/ && !(M[i+2] ~ /^ *- / && ind(M[i+2]) >= ind(M[i+1]))) { i++; continue }
        print M[i]
      }
    }' "$pc" > "$pc.tmp" && mv "$pc.tmp" "$pc"
  echo "git hooks: jit hooks removed from $pc"
fi
for h in .husky/pre-commit .husky/pre-push; do
  if grep -qs '\.specify/extensions/jit/scripts/' "$h"; then
    sed -i.bak '/\.specify\/extensions\/jit\/scripts\//d' "$h" && rm -f "$h.bak"; echo "git hooks: jit line removed from $h"
  fi
done

# ── Constitution ─────────────────────────────────────────────────────────────
const=.specify/memory/constitution.md
if [[ -f "$const" ]] && grep -q '<!-- jit:start' "$const"; then
  grep -q '<!-- jit:end -->' "$const" || die "$const has '<!-- jit:start' but no '<!-- jit:end -->'; restore the end marker, then run again"
  if grep -q '^# \[PROJECT_NAME\] Constitution' "$const"; then
    rm "$const"; gone "$const (jit's template, never filled in)"
  else
    awk '/<!-- jit:start/ { skip = 1 } !skip { print } /<!-- jit:end -->/ { skip = 0 }' "$const" > "$const.tmp" && mv "$const.tmp" "$const"
    echo "constitution: jit block removed from $const (your text kept)"
  fi
fi

if $speckit; then
  rm -rf .specify .claude/skills/speckit-*
  rmdir .claude/skills .claude 2>/dev/null || true
  gone "spec-kit (.specify/, .claude/skills/speckit-*); specs/ kept"
fi

cat <<EOT

Done. Kept on purpose: specs/, your commits, files you edited, and:
  branches develop/staging, if created:   git push origin --delete develop staging
  GitHub protections set at init:         repository Settings → Branches, Code security
Reinstall: /jit-speckit:init
EOT
