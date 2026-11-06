# Why jit-speckit works this way

Design decisions, each with its reason. The what is in the [README](../README.md) and the
[reference](reference.md).

## One task = one issue = one branch = one PR

- **Review finds bugs only in small changes.** A Cisco study of 2,500 reviews put the useful
  size at 200 to 400 lines; past that, defects found per line fall off
  ([SmartBear](https://smartbear.com/learn/code-review/best-practices-for-peer-code-review/)).
  Google's guide calls about 100 lines reasonable and 1,000 too large
  ([small CLs](https://google.github.io/eng-practices/review/developer/small-cls.html)). This
  matters more with AI-written code: a 150-line PR gets read, a 2,000-line one gets scrolled.
- **Small batches are faster and safer at once.** DORA's research links batch size to both
  delivery speed and stability
  ([working in small batches](https://dora.dev/capabilities/working-in-small-batches/)), and the
  2025 model lists it among the capabilities that make AI help instead of hurt.
- **Failures localize.** A red CI, a security finding or a production bug points at one task.
  One revert removes one task. In a one-PR feature, the revert takes everything.
- **"Done" has an external definition.** The issue says which requirement produced the code and
  closes only when the PR merges. That is what makes `/jit-speckit:next` resumable after a month,
  and what the independent review checks the PR against.

The cost is real: a CI run, a review round and a merge per task. It pays off when tasks are
**vertical slices**, one observable behavior with its test, and not layers. The tasks template
says so, and the plan review flags layer-shaped tasks before any issue exists.

## The spec is its own PR

Task branches start from the base branch and read `tasks.md` there, so the spec has to be merged
before any task starts. It also means you review the design while changing it costs one edit to a
doc, and each task PR stays small and closes exactly one issue. The worked example in
[examples/](../examples/README.md#why-two-kinds-of-pr) shows both kinds.

## The review is independent

A review inside the session that wrote the code shares that session's assumptions and tests the
path it already tested. jit's review before every PR (`/speckit-jit-review`) runs in a fresh agent
that gets only facts: the branch, the task line, the PR body, the test command. It starts from the
diff, then reads the repository around it (callers, the newest siblings of every new file and
their guards), re-runs every claim, breaks the code once to prove the tests can fail, and walks
the path where state already exists. This is how GitHub's Copilot code review works, and it is
why a second reader catches what the first cannot. Every PR asks for Copilot's review too: two
independent readers, not one. `pr.sh` prints `copilot: code review requested` only when GitHub's
answer lists Copilot as a reviewer, and `copilot: not requested` otherwise, since GitHub can accept
the request and add no one. The review is a gate, not a prompt: its
report is recorded against the exact diff (`review.sh`), and `pr.sh` refuses the PR without a
recorded `ready` for that diff, at every level; the same holds for the plan review before issues.
What the gate proves is that a fresh reader reviewed this exact diff and said `ready`: the PR body
shows that review's *What changed* and `Assessment:` line, folded under "Independent review". The
script never copies findings, so a security finding's detail cannot reach a public PR through it;
findings reach the PR only through the author's `## Review`, a security finding as the one line
`Security: reported privately (<id>)`.

## Levels instead of one setup

A prototype and a payment service do not need the same ceremony, and a checklist that is too
heavy gets skipped. `lite`, `standard` and `full` size the branch flow, the constitution's
defaults, the CI and the review bar to how serious the project is, and `/jit-speckit:level`
moves between them without deleting anything.

## Nothing of yours is overwritten

Files jit-speckit generates carry a `# jit-speckit: managed file` first line and are re-created
on `/jit-speckit:level`; delete that line and the file is yours. Files it cannot mark (the PR
template, `.claude/settings.json`, `SECURITY.md`) are written only when missing. `remove` deletes
only what still matches what it wrote.

When a managed workflow is re-created, an action pin newer than jit-speckit's own (a Dependabot
bump: `uses: <action>@<sha> # <version>`) is kept and named `kept newer pin: <action> <version>`.
A `container.image` digest is not such a line and goes back to jit-speckit's.

Releases before the marker (1.0.0 to 1.3.1) wrote some files byte for byte;
`extension/scripts/old-files.sha256` lists them. Their two git hooks are replaced and marked. Their
`close-linked-issues.yml` and `release.yml` are kept and named (`kept (written by jit-speckit
<versions>, no marker)`), since a 1.4.0+ copy with its marker deleted has the same bytes; and once
an old hook matched, so are the generated workflows, Dependabot and `CODEOWNERS` (`<versions> or
older`). Delete one to get the current version.
