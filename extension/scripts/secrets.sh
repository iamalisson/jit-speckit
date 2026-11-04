#!/usr/bin/env bash
# Fast secret check, run by the git pre-commit and pre-push hooks.
#   secrets.sh staged            check what is about to be committed
#   secrets.sh range <from> <to> check the commits about to be pushed
# Refuses secret-bearing files (.env, private keys, credential files) and secret-looking added
# lines. Uses gitleaks when installed; the built-in patterns below always run too.
# A line can be allowed on purpose with a trailing comment containing "jit:allow-secret".
# Exits 1 with a redacted list of findings; 0 when clean.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
jit_cd_root

mode="${1:-staged}"
case "$mode" in
  staged) files="$(git diff --cached --name-only --diff-filter=ACMR)"
          diff="$(git diff --cached --unified=0 --diff-filter=ACMR)" ;;
  range) [[ -n "${2:-}" && -n "${3:-}" ]] || die "usage: secrets.sh range <from> <to>"
         files="$(git diff --name-only --diff-filter=ACMR "$2" "$3")"
         diff="$(git diff --unified=0 --diff-filter=ACMR "$2" "$3")" ;;
  *) die "usage: secrets.sh staged | secrets.sh range <from> <to>" ;;
esac

findings=()

# Files that should never be committed. Templates (.env.example etc.) are fine.
while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  base="${f##*/}"
  case "$base" in
    .env.example|.env.sample|.env.template|.env.dist) continue ;;
    .env|.env.*|*.pem|*.key|*.p12|*.pfx|*.jks|*.keystore|id_rsa|id_dsa|id_ecdsa|id_ed25519|*.tfstate|*.tfstate.backup|credentials.json|service-account*.json|.netrc|.pgpass)
      findings+=("$f: secret-bearing file") ;;
  esac
done <<<"$files"

# Added lines that look like credentials (provider formats first, then generic assignments).
patterns=(
  'AKIA[0-9A-Z]{16}'                                   # AWS access key
  'gh[pousr]_[A-Za-z0-9]{36,}'                         # GitHub token
  'github_pat_[A-Za-z0-9_]{60,}'                       # GitHub fine-grained token
  'glpat-[A-Za-z0-9_-]{20,}'                           # GitLab token
  'xox[abprs]-[A-Za-z0-9-]{10,}'                       # Slack token
  'sk_live_[A-Za-z0-9]{20,}'                           # Stripe live key
  'AIza[0-9A-Za-z_-]{35}'                              # Google API key
  'sk-ant-[A-Za-z0-9_-]{20,}'                          # Anthropic key
  'sk-(proj-)?[A-Za-z0-9_-]{40,}'                      # OpenAI key
  'SG\.[A-Za-z0-9_-]{22}\.[A-Za-z0-9_-]{43}'           # SendGrid key
  '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----'              # private key
  '(postgres|postgresql|mysql|mongodb(\+srv)?|redis|amqp)://[^:/@ ]+:[^@ ]{3,}@' # URL with password
  '(password|passwd|secret|api_?key|access_?token|auth_?token|client_?secret)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"'$<{ ]{8,}["'"'"']'
)
current=""
while IFS= read -r line; do
  case "$line" in
    "+++ b/"*) current="${line#+++ b/}"; continue ;;
    "+++"*|"---"*) continue ;;
    +*) ;;
    *) continue ;;
  esac
  added="${line#+}"
  [[ "$added" == *jit:allow-secret* ]] && continue
  for p in "${patterns[@]}"; do
    if grep -qiE -e "$p" <<<"$added"; then
      shown="$(sed -E 's/(["'"'"'=:][[:space:]]*.{0,4})[^"'"'"' ]{4,}/\1****/' <<<"$added" | cut -c1-80)"
      findings+=("$current: looks like a secret: $shown")
      break
    fi
  done
done <<<"$diff"

if command -v gitleaks >/dev/null; then
  if [[ "$mode" == staged ]]; then
    gitleaks git --pre-commit --staged --redact --no-banner >/dev/null 2>&1 || findings+=("gitleaks: secrets found (run: gitleaks git --pre-commit --staged --redact -v)")
  else
    gitleaks git --log-opts="$2..$3" --redact --no-banner >/dev/null 2>&1 || findings+=("gitleaks: secrets found (run: gitleaks git --log-opts=\"$2..$3\" --redact -v)")
  fi
fi

if ((${#findings[@]})); then
  echo "jit: refusing: possible secrets" >&2
  printf '  %s\n' "${findings[@]}" >&2
  cat >&2 <<'EOF'
  Remove them (and rotate any real credential that was ever committed or pushed).
  Load secrets from the environment and keep a .env.example with the keys only.
  A false positive can be allowed on that line with a comment containing: jit:allow-secret
EOF
  exit 1
fi
