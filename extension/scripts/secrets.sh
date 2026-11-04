#!/usr/bin/env bash
# Fast secret check, run by the git pre-commit and pre-push hooks.
#   secrets.sh staged            check what is about to be committed
#   secrets.sh range <from> <to> check every commit in from..to, one by one (a secret added and
#                                removed again in the same push is still caught)
#   secrets.sh range - <to>      check every commit reachable from <to> that no remote has yet
# Refuses secret-bearing files (.env, private keys, credential files) and secret-looking added
# lines. Uses gitleaks when installed; the built-in patterns below always run too.
# A line can be allowed on purpose with a trailing comment containing "jit:allow-secret".
# Exits 1 with findings as file:line and the kind of secret, never the secret itself; 0 when clean.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
jit_cd_root

mode="${1:-staged}"
# The diff format is pinned, whatever the user's git config says: color.ui=always or
# diff.noprefix would otherwise hide every added line from the parser below. Merge commits are
# diffed against their first parent, so lines added while resolving a merge are scanned too.
fmt=(--no-color --no-ext-diff --src-prefix=a/ --dst-prefix=b/)
case "$mode" in
  staged) files="$(git diff --cached --no-color --name-only --diff-filter=ACMR)"
          diff="$(git diff --cached "${fmt[@]}" --unified=0 --diff-filter=ACMR)" ;;
  range) [[ -n "${2:-}" && -n "${3:-}" ]] || die "usage: secrets.sh range <from|-> <to>"
         if [[ "$2" == - ]]; then revs=("$3" --not --remotes); else revs=("$2..$3"); fi
         files="$(git log --no-color --diff-merges=first-parent --name-only --format= --diff-filter=ACMR "${revs[@]}" | sort -u)"
         diff="$(git log -p "${fmt[@]}" --diff-merges=first-parent --unified=0 --format= --diff-filter=ACMR "${revs[@]}")" ;;
  *) die "usage: secrets.sh staged | secrets.sh range <from|-> <to>" ;;
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
names=(); patterns=()
add() { names+=("$1"); patterns+=("$2"); }
add "AWS access key"          'AKIA[0-9A-Z]{16}'
add "GitHub token"            'gh[pousr]_[A-Za-z0-9]{36,}'
add "GitHub fine-grained token" 'github_pat_[A-Za-z0-9_]{60,}'
add "GitLab token"            'glpat-[A-Za-z0-9_-]{20,}'
add "Slack token"             'xox[abprs]-[A-Za-z0-9-]{10,}'
add "Stripe live key"         'sk_live_[A-Za-z0-9]{20,}'
add "Google API key"          'AIza[0-9A-Za-z_-]{35}'
add "Anthropic key"           'sk-ant-[A-Za-z0-9_-]{20,}'
add "OpenAI key"              'sk-(proj-)?[A-Za-z0-9_-]{40,}'
add "SendGrid key"            'SG\.[A-Za-z0-9_-]{22}\.[A-Za-z0-9_-]{43}'
add "private key"             '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----'
add "URL with a password"     '(postgres|postgresql|mysql|mongodb(\+srv)?|redis|amqp)://[^:/@ ]+:[^@ ]{3,}@'
add "hard-coded credential"   '(password|passwd|secret|api_?key|access_?token|auth_?token|client_?secret)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"'$<{ ]{8,}["'"'"']'

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
printf '%s\n' "${patterns[@]}" > "$tmp/patterns"
# One line per added line: where it is (meta) and what it says (text), in the same order.
# Lines marked jit:allow-secret are blanked, so they never match.
awk -v meta="$tmp/meta" -v text="$tmp/text" '
  /^\+\+\+ b\// { file = substr($0, 7); next }
  /^(\+\+\+|---)/ { next }
  /^@@/ { split($3, n, ","); line = substr(n[1], 2) + 0; next }
  /^\+/ { s = substr($0, 2); if (index(s, "jit:allow-secret")) s = ""
           print file ":" line > meta; print s > text; line++ }
' <<<"$diff"
touch "$tmp/meta" "$tmp/text"
# One grep over every added line. Only matching line numbers come back: never the text.
while IFS= read -r n; do
  where="$(sed -n "${n}p" "$tmp/meta")"; text="$(sed -n "${n}p" "$tmp/text")"
  kind="secret"
  for k in "${!patterns[@]}"; do
    if grep -qiE -e "${patterns[$k]}" <<<"$text"; then kind="${names[$k]}"; break; fi
  done
  findings+=("$where: possible $kind")
done < <(grep -niE -f "$tmp/patterns" "$tmp/text" | cut -d: -f1 || true)

if command -v gitleaks >/dev/null; then
  if [[ "$mode" == staged ]]; then
    gitleaks git --pre-commit --staged --redact --no-banner >/dev/null 2>&1 || findings+=("gitleaks: secrets found (run: gitleaks git --pre-commit --staged --redact -v)")
  else
    opts="$2..$3"; [[ "$2" == - ]] && opts="$3 --not --remotes"
    gitleaks git --log-opts="$opts" --redact --no-banner >/dev/null 2>&1 || findings+=("gitleaks: secrets found (run: gitleaks git --log-opts=\"$opts\" --redact -v)")
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
