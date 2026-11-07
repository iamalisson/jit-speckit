# Quickstart: checking the report

Prerequisites: the repository at the reviewed commit, `git`, `bash`, `shellcheck`. Run every step
from `specs/001-critical-points-review/`; the git commands use repository-root pathspecs (`:/`), so
they give the same answer from anywhere.

1. **Nothing changed** (FR-011): `out="$(git diff --stat "$(git merge-base HEAD origin/main)" -- ':/' ':(top,exclude)specs/001-critical-points-review')" && [ -z "$out" ]` exits 0. It compares the working tree's tracked files
   with the merge-base, so committed and uncommitted changes outside the folder both fail it;
   untracked folders of other features are ignored. Then `(cd "$(git rev-parse --show-toplevel)" && tests/run.sh)` passes.
2. **Every promise answered** (SC-001): every id P01–P28 from
   [contracts/report-format.md](contracts/report-format.md) appears in a section table under
   `report/` with a verdict and evidence:
   `for i in $(seq -w 1 28); do grep -qh "^| P$i |" report/*.md || echo "missing P$i"; done` prints nothing,
   and every row has an allowed verdict and some evidence:
   `awk -F'|' '/^\| P[0-9]+ \|/ { v=$4; e=$5; gsub(/^ +| +$/, "", v); gsub(/ /, "", e); if (v !~ /^(holds|limit|broken|unverified|unverified \(advisory pending\)|reported privately \(F[0-9.]+, GHSA-[a-z0-9-]+(; F[0-9.]+, GHSA-[a-z0-9-]+)*\))$/ || e == "") print FILENAME ": " $2 }' report/*.md` prints nothing.
3. **Every broken finding reproduces** (SC-002): pick each public `broken` finding, follow its
   reproduction in a temp directory, and see the stated output in under 10 minutes. Each
   `reported privately` row has an advisory (draft, or published once fixed): `gh api --paginate repos/iamalisson/landspec/security-advisories --jq '.[] | select(.summary | startswith("[001 ")) | .ghsa_id'`
   lists exactly the GHSA ids in those rows. A public finding that is a bypass of a protection is reproduced from its
   script in `$(git rev-parse --git-common-dir)/landspec-repro/` (never committed), and the maintainer reproduces it from there.
4. **Every High/Medium has a fix** (FR-010): each appears under *Fixes* in `report.md` with a "when …, then …" check.
5. **Design verdicts present** (SC-003a): `D1`, `D2` and `D3` in `report/7-core-model.md` each end in keep, simplify or replace.
6. **Nothing that helps an attacker** (FR-012, FR-013): no exploitable finding described beyond its
   one row, no token-shaped string
   (`(cd "$(git rev-parse --show-toplevel)" && bash .specify/extensions/landspec/scripts/secrets.sh staged)` on the staged report files is clean) and no bypass written
   as a runnable command.
7. **Prompts checked** (SC-003b): `for i in $(seq -w 1 11); do grep -q "^| C$i |" report/8-context-engineering.md || echo "missing C$i"; done`
   prints nothing, and section 8 lists the words each command loads before any work.
