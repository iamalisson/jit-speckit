# Data model: Fix what the critical-points review found

All state is files: in the repository, in `.git/` (local, per clone) or in a project's `.specify/`.
No new storage.

## Fix entry (input)

| Field | Rule |
|---|---|
| id | `F<section>.<n>` from feature 001's `report.md` *Fixes*, or `#41` |
| change | the entry's change, as corrected by [research.md](research.md) C1 |
| promise | the P-id it restores |
| check | its "when …, then …" test in [contracts/checks.md](contracts/checks.md), seen failing on 1.7.2 behavior first |

## Diff record (new: F3.4, F3.6; shared with the review record)

One file per kind under `$(git rev-parse --git-common-dir)/<kind>/<diff id>`, where the diff id is
the patch id of `git diff <merge-base with the base> HEAD` (`diff_id()` in `lib.sh`, moved from
`review.sh`), or `empty` for an empty diff.

| Kind | Written by | Content | Read by |
|---|---|---|---|
| `landspec-review` | `review.sh record` (today) | state, assessment, blank line, report | `review.sh check`, `review.sh report` (new) |
| `landspec-mutants` | `mutants.sh` (new) | its result line: `mutants <ok\|survivors\|unavailable\|missing\|skipped> <detail>` | `pr.sh task`, only when a mutate command is set |
| `landspec-security` | `security-scan.sh --changed` (new) | its summary lines, one per scanner | `pr.sh task`, always |

Transitions: any commit changes the diff id, so every record goes stale at once and the next PR
needs fresh ones. A merge of the base keeps the id (the patch id ignores it), as reviews do today.

## Written-file record (new: F5.2)

`.specify/landspec-files.sha256` in the project (committed with the setup), one line per file `put()`
wrote: `<sha256> <path>`. `put()` replaces the line for a path each time it writes it. `remove.sh`
deletes a marked file only when its current SHA-256 equals its line; with no line (a project set up
before 1.8.0), only when the file is tracked and `git diff --quiet HEAD` says it is unchanged.

## Old-file manifest (new: F5.3)

`extension/scripts/old-files.sha256`, shipped with the extension, one line per file a release
before 1.4.0 wrote byte for byte: `<sha256> <path> <versions> <replace|name>`. `replace` means
`put()` treats the file as its own (rewrites it, now marked); `name` means it is kept and named. Six lines (research R8): the four files at commit `252a93c` (1.0.0, untagged) and the tags
`v1.2.0`, `v1.3.0`, `v1.3.1` have six distinct SHA-256s. Never edited by hand except to add a row, with the release that wrote it.

## Version (shared: F4.7, F5.4, F4.1)

`version_newer A B` in `lib.sh`: true when A is a dotted number (optional leading `v`) greater than
B; any other form is never newer. Used by `put()`'s `keep_pins`, `bin/setup.sh` (project vs plugin
version) and `bin/check-tools.sh` (latest release vs pin).

## Pins (changed: F4.5, F4.1)

`extension/scripts/pins.sh` gains `SEMGREP_DIGEST` beside `SEMGREP_VERSION` (bumped together).
Every `PIN_*` action is also used by `.github/workflows/pins.yml`, so Dependabot proposes it.

## Review record (changed: FR-030, FR-032)

The task-review record in `<git-common-dir>/landspec-review/` keeps `state:` (the whole-branch patch id)
and `assessment:`, and adds `head: <sha reviewed>` (the report's `Reviewed:` line, which must equal
HEAD at record time) and `round: full|delta`, `model: <the report's Model: line>` and any `warning:` lines; a delta record also carries the previous full
record's `- deep:`/`- proven:` lines, so the PR shows both rounds' risk maps. `record --delta` reads
the last record's `head:` and `round:`; `check` reads only `state:` and `assessment:`, so a delta's `ready` still covers the whole diff;
`pr.sh` also reads `model:`, `warning:` and the carried-over risk lines to print them. A record without `round:` (from 1.7.x) counts as
needing a full round.

Plan records (`record --plan`, keyed by the plan state) carry the same `model:` and `warning:`
header lines; `issues.sh` prints the warning, and `pr.sh spec` copies it into the spec PR body.

The header, in order, ends at the first blank line; the report follows as it came, and no line
of it is ever read as a header field:

```
state: <patch id of the whole branch diff, or the plan state>
assessment: ready | changes needed
head: <sha reviewed>                 (task records)
round: full | delta                  (task records)
model: <the report's Model: id>
warning: <reason>; the review did not run on the configured model   (when one applies)
map-full: - deep: <path>             (round 1's risk map, paths only; a delta carries it over)
map-fix: - proven: <path>            (a delta's own risk map)
```
