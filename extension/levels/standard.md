### Security baseline

- Validate and sanitize every input at trust boundaries (HTTP, CLI, files, webhooks, queues).
- Least privilege: services, tokens and CI credentials get only the permissions they use;
  prefer short-lived credentials (OIDC) over static keys.
- Authorization is enforced on the server; the client is never the only barrier. A record's owner
  comes from the authenticated context, never from the request body.
- Errors shown to users carry a code, not internals; details go to server logs.
- Dependency alerts are triaged: critical and high within a week, by updating or by a written
  dismissal reason.

### Stack idioms

{{STACK_IDIOMS}}
- CI runs the formatter, linter, tests and build on every pull request; a red CI blocks the merge.

### Dependencies

- A new dependency needs one written line in the feature's `plan.md`: what it solves and why the
  standard library or a current dependency is not enough.
- Lockfiles are committed; versions are updated through reviewed pull requests.

### Tests (integration)

- Flows are tested against real infrastructure in tests (a test database, a local server); only
  external services (payment, email, third-party APIs) are mocked.
- Every test covers the happy path, expected errors, limits (zero, negative, expired) and
  unauthorized access (user A touching user B's data).

### Commits and reviews

- Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`).
- Every PR states how it was verified (test output, screenshot or run link).
