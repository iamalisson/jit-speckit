### Threat model

- Every feature's `plan.md` has a short threat model: what is exposed, who can reach it, what is
  the worst misuse, and which control stops it.

### Data integrity

- "Read, decide, write" over a limited resource is protected by the database (unique constraint,
  atomic update checking affected rows, or `SELECT … FOR UPDATE`), not by application locks.
- Every concurrency fix has a test that fires two simultaneous requests and proves a single effect.
- Every migration is reviewed before it reaches the integration branch and is backward compatible
  with the version currently running.

### Observability

- Structured logs with a request ID; no personal data in logs.
- Health check endpoint; alerts on failed health checks and on error-rate spikes.

### Releases

- Releases are tagged (`vX.Y.Z`) and promote the same build through every environment; nothing is
  rebuilt for production.
- Every release has a tested rollback path (redeploy the previous tag).
- `/speckit-analyze` runs before any task is implemented; its critical findings are fixed first.
