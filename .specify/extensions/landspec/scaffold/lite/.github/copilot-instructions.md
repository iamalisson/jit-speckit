# Review instructions

This project is spec-driven (GitHub Spec Kit with landspec). When reviewing a pull request:

- The rules are in `.specify/memory/constitution.md`. A task PR closes one issue and names its task
  in `specs/NNN-*/tasks.md`: check the change against that task's *Completed when* and *Impact*
  lines and the spec's acceptance scenarios, not only against itself.
- For every new file of a kind the repository already has (migration, workflow, endpoint, model,
  job), compare it with the newest existing one and flag any guard it lacks: existence checks,
  idempotent writes, timeouts, authorization, refusal to run against production.
- Prefer findings about wrong results, data loss, upgrades that break on existing state, and
  security at trust boundaries. A test that cannot fail (expected values imported from the code
  under test, an assertion that accepts two outcomes) is a finding. Skip style and naming.
- A spec PR (`docs(specs): ...`) changes only `specs/`: check that each task's *Impact* names what
  it really touches in this repository and that its *Completed when* is a command that proves it.
