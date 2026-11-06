# Quickstart: checking feature 002

Run from the repository root.

1. **The suite passes**: `tests/run.sh` exits 0 on Linux; the `bash32` job and the macOS workflow
   pass on the release PR (SC-005).
2. **Every fix has its check** (SC-001): for each row of [contracts/checks.md](contracts/checks.md),
   the named test file has a check whose label starts with that row's "when …".
   `for f in F5.2 F5.4 F5.3 F4.7 F3.3 F3.4 F3.6 F3.9 F3.8 F3.1 F4.3 F2.3 F2.4 F1.1 F1.2 F1.6 F1.8 F3.5 F4.2 F4.1 F4.4 F5.6 F1.7 F4.5 F1.9 F3.7 '#41'; do gh pr list -R iamalisson/jit-speckit --state merged --search "$f in:body" --json number -q 'length' | grep -qv '^0$' || echo "no merged PR for $f"; done`
   prints nothing once all tasks merged.
3. **Each check was seen failing** (FR-022): every task PR's `## Evidence` has a line "seen failing
   before the change: <check label>".
4. **The defects are gone** (SC-002): run each public `broken` reproduction from feature 001's
   section files on the 1.8.0 tree (`git worktree add "$(mktemp -d)" v1.8.0`); none shows its
   stated output.
5. **Docs match behavior** (SC-004): every gate the README and `docs/` present as refusing is in
   [contracts/output-lines.md](contracts/output-lines.md) "Refusals", or the doc says it is asked of
   the agent.
6. **Nothing private** (FR-024): `git log -p v1.7.2..v1.8.0 | grep -c 'F2\.1'` counts only the id,
   never a description; `bash .specify/extensions/jit/scripts/secrets.sh range v1.7.2 v1.8.0` is
   clean.
7. **Release** (FR-025, SC-006): `.claude-plugin/plugin.json`, `extension/extension.yml` and
   `preset/preset.yml` say `1.8.0`; `tests/static.test.sh` passes; the release notes list each fixed
   id, and a reader finds a given id's change in under 5 minutes.
