# Data model: Critical-points review

All entities live as Markdown in `report.md` and `report/*.md`; there is no storage.

## Promise

| Field | Rule |
|---|---|
| id | `P01`–`P28`, fixed by the inventory in [contracts/report-format.md](contracts/report-format.md) |
| text | the guarantee, in one sentence |
| stated in | file and section (README, `docs/security.md`, `docs/reference.md`, `docs/design.md`, constitution) |
| section | report section 1–5 that checks it |

## Finding (defect)

| Field | Rule |
|---|---|
| id | `F<section>.<n>`, e.g. `F2.1` |
| promise | one or more Promise ids; a finding without a promise is not reported (SC-003) |
| verdict | `holds`, `limit` (holds with a documented limit), `broken`, `unverified` when it could not be reproduced (`unverified (advisory pending)` when filing its advisory failed), or `reported privately (Fn.m, GHSA id)` for an exploitable one |
| rank | `High`, `Medium` or `Low` per FR-009; required for `broken` and for `limit` when the docs mislead; a `limit` the docs describe honestly is always `Low` |
| evidence | `file:line`, a test name, or a command and its output |
| reproduction | required for `broken` and `limit`: steps on a throwaway repo; for an exploitable finding, only in its private advisory (FR-013); for a public bypass of a protection, the script lives in `.git/landspec-repro/`, the report gives class, output and `file:line` |
| exposure | `public` or `private` (exploitable, FR-013); a private finding's committed text is only its promise row with `reported privately (Fn.m, GHSA id)` |
| fix | required for High and Medium: one change, the promise it restores, and a check "when …, then …" that fails now and passes after (FR-010) |

Transitions: `unverified` → `holds`/`limit`/`broken` once reproduced. A `limit` whose doc describes
it honestly gets no fix, only a note (US3 scenario 2).

## Design verdict

| Field | Rule |
|---|---|
| id | `D1` task = issue = branch = PR · `D2` spec as its own PR · `D3` the three levels |
| problem solved | what it protects, in one line |
| cost | steps and waits it adds per task, per level |
| evidence cited | the sources `docs/design.md` gives, and whether each supports the claim made |
| alternative | the simplest model that would keep the same promises |
| verdict | `keep`, `simplify` or `replace`, with the reason |

Design verdicts are not ranked and need no reproduction.

## Principle verdict (section 8)

| Field | Rule |
|---|---|
| id | `C01`–`C11`, fixed by research R8 |
| verdict | `follows`, `departs (reason written)`, `departs`, or `unverified` |
| files | the prompt files it applies to |
| evidence | `file:line` and measured sizes (lines, words loaded before any work) |
| suggestion | required for `departs`: what the prompt would look like following the principle |
