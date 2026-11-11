### Simplicity (KISS, YAGNI)

- Build the smallest thing that fully solves the task. No abstraction, option or "for later" code
  nobody asked for.
- Choose in this order: what the codebase already has → the standard library → an installed
  dependency → a new dependency.

### Secrets

- No secret, token or password in the repository, in logs, or in client-side code. Configuration
  comes from the environment; `.env` files are git-ignored and an `.env.example` documents the keys.

### Accessibility (when the project has a user interface)

- What people see meets WCAG 2.2 AA: text contrast at least 4.5:1 against its background (3:1
  for large text, 24 px or 18.7 px bold, and for icons, borders and focus indicators), a visible
  focus on every control, an accessible name on every control and image. A colour copied from an
  existing page is checked too: the old page may already fail.

### Tests

- Every piece of logic (parsing, validation, money, permissions, sorting) has a test, written as
  "when …, then …".
- A failing test is never deleted, skipped or loosened to make it pass.
- One command runs the whole suite: `{{TEST_COMMAND}}`.

### Way of working

- One task = one issue = one branch = one pull request. A task is done when its issue is closed
  by the merged PR (`Closes #N`); a ticked checkbox alone is not done.
- Features go through specs and tasks. A small fix (a typo, a one-line bug, a dependency bump)
  goes on a normal branch and PR: no spec or issue needed, but the review, hooks and CI still apply.
- Branch flow: `{{BRANCH_FLOW}}`, always through a pull request.
- Before a PR opens, a fresh reader reviews it against the whole repository
  (`/speckit-landspec-review`); High and Medium findings are fixed, the review is recorded for the
  exact diff, and the PR's `## Review` section says what was found and done. No PR opens without
  it, at any level: a task through `pr.sh task`, anything else through `pr.sh fix`.
