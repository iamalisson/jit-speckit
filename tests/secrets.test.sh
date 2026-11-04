#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # checks are strings evaluated by check()
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
s="$SCRIPTS/secrets.sh"
staged() { git add -- "$@"; }
reset() { git reset --quiet; git clean -fdq -e .specify; }

new_repo standard

echo "DB_PASSWORD=hunter22hunter" > .env; staged .env
check "when a .env file is staged, then the commit is refused" 'fails_with ".env: secret-bearing file" "$s" staged'
reset

echo "API_KEY=" > .env.example; staged .env.example
check "when only .env.example is staged, then it passes" '"$s" staged'
reset

mkdir -p keys; printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\nabc\n' > keys/deploy; staged keys/deploy
check "when a private key is staged under any name, then it is refused" 'fails_with "looks like a secret" "$s" staged'
reset

printf 'const t = "ghp_%s";\n' "$(printf 'a%.0s' {1..36})" > app.js; staged app.js
check "when a GitHub token is in an added line, then it is refused" 'fails_with "app.js: looks like a secret" "$s" staged'
check "then the token itself is not printed" 'out="$("$s" staged 2>&1)"; ! grep -q "aaaaaaaaaaaaaaaaaaaa" <<<"$out"'
reset

printf 'url = "postgres://app:s3cretpw@db:5432/app"\n' > cfg.toml; staged cfg.toml
check "when a database URL carries a password, then it is refused" 'fails_with "cfg.toml" "$s" staged'
reset

printf 'aws = "AKIAABCDEFGHIJKLMNOP"  # jit:allow-secret (AWS docs example key)\n' > doc.py; staged doc.py
check "when the line is marked jit:allow-secret, then it passes" '"$s" staged'
reset

printf 'password = os.environ["DB_PASSWORD"]\ntoken: ${{ secrets.TOKEN }}\nconst apiKey = process.env.API_KEY\n' > ok.py; staged ok.py
check "when secrets come from the environment, then it passes (no false positive)" '"$s" staged'
reset

git switch --quiet -c feat/x
printf 'k = "sk_live_%s"\n' "$(printf 'b%.0s' {1..24})" > pay.rb; git add pay.rb; git commit --quiet --no-verify -m leak
check "when a commit made with --no-verify is pushed, then the range check finds it" 'fails_with "pay.rb" "$s" range HEAD~1 HEAD'

zero=0000000000000000000000000000000000000000
check "when pushing a branch whose commits leak a secret, then pre-push refuses" \
  'fails_with "pay.rb" bash "$SCRIPTS/prepush.sh" <<<"refs/heads/feat/x $(git rev-parse HEAD) refs/heads/feat/x $zero"'
check "when pushing straight to develop on standard, then pre-push refuses" \
  'fails_with "open a pull request" bash "$SCRIPTS/prepush.sh" <<<"refs/heads/develop $(git rev-parse HEAD~1) refs/heads/develop $(git rev-parse HEAD~1)"'

exit "$FAIL"
