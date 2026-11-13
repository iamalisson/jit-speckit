# Quickstart: validating reviewer isolation and privacy findings

Prerequisites: Claude Code with this branch's plugin loaded (`claude --plugin-dir .` from the
repository root, or `/reload-plugins` after `specify extension add --dev extension --force`), `gh`
logged in, a scratch landspec project (any repo after `/landspec:init lite`).

## 1. The guard sees `isolation` on a real launch (R3)

In the scratch project, ask Claude to launch `landspec:reviewer` on `sonnet` **without**
`isolation`. Expected: blocked with the line from [contracts/guard-review.md](contracts/guard-review.md).
Ask again **with** `isolation: "worktree"`. Expected: it runs. If the second launch is also blocked,
the client does not pass the field: stop, the design's R3 is wrong.

## 2. The reviewer reviews the right commit (R1)

On a feature branch with one commit not on the default branch, run `/speckit-landspec-review`.
Expected: the report's `Copy:` is under `.claude/worktrees/`, and its `Reviewed:` ends at the
branch's `git rev-parse HEAD`, not at `origin/HEAD`.

## 3. The author's checkout is untouched (SC-001, #121)

Add a check script that writes a mutant into a source file, takes a lock file at the repository
root, and sleeps past the reviewer's tool timeout; name it in the task's *Completed when*. Before
the review: `git status --porcelain --ignored > before`, and `find . -newer before -not -path './.git/*'`
is empty. Run `/speckit-landspec-pr`. After `review.sh record`:
- `git status --porcelain --ignored` equals `before`;
- no lock file in the checkout, and the script's next run starts normally;
- `git worktree list` shows no reviewer copy; `record` printed `removed the reviewer's copy` if one
  was left;
- before `record`, with the copy still on disk, `pr.sh` does not refuse for uncommitted changes.

## 3b. An old project copy is told to update (R8)

With this plugin and a project whose landspec copy predates it: a reviewer launch without
`isolation` is blocked with the isolation line, which names `/landspec:init`; with `isolation`
added by hand, the reviewer stops with "the project's landspec copy predates the plugin: run
/landspec:init" and `Assessment: changes needed`. After `/landspec:init`, the review runs.

## 4. The leak through a helper is found (SC-004, #120)

Build it: `bash specs/003-reviewer-isolation-privacy/fixtures/leak-through-helper/make-repo.sh "$(mktemp -d)/r"`
(a helper that logs the e-mail at INFO, a new failure path on `feat/save-deal` passing the e-mail to
it, a test that patches the helper module and passes). Run `/landspec:init lite` there, then the review
of `feat/save-deal` three times. Expected each
time: a finding at the helper's `file:line`, a Medium for the test that fakes the module, and
`Assessment: changes needed`.

## 5. Suite

`tests/run.sh` passes; removing any new rule from `extension/commands/review.md`, or `isolation`
from a launching command, fails `tests/static.test.sh` (SC-005).
