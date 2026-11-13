# Fixture: personal data reaching a log through a helper (#120)

`make-repo.sh <new-empty-dir>` builds a throwaway repo. `main` holds `app/alerts.py`, whose
`send_error` logs the e-mail at INFO; `feat/save-deal` adds a failure path in `app/controller.py`
that passes the e-mail to it, and a test that patches the `alerts` module, so it passes while the
real helper would leak. The repo's `AGENTS.md` forbids personal data in logs.

Expected review of `feat/save-deal` against `main`: a High at `app/alerts.py:7`, a Medium for
`tests/test_controller.py` (it fakes the module that writes the log and is the only proof of the
rule), `Assessment: changes needed`.
