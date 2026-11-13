#!/usr/bin/env bash
# Builds issue #120's reproduction as a throwaway git repo: main holds a helper that logs the
# user's e-mail at INFO; the branch feat/save-deal adds a failure path that passes the e-mail to it,
# and a test that patches the whole helper module, so it can never see the helper's log line.
# Usage: make-repo.sh <new-empty-dir>. Refuses a directory that exists and is not empty.
set -euo pipefail
dir="${1:?usage: make-repo.sh <new-empty-dir>}"
if [[ -e "$dir" && -n "$(ls -A "$dir")" ]]; then echo "make-repo.sh: $dir is not empty" >&2; exit 1; fi
mkdir -p "$dir/app" "$dir/tests"
cd "$dir"
git init --quiet -b main
git config user.email fixture@example.invalid; git config user.name fixture

cat > AGENTS.md <<'MD'
# Rules
- No personal data (e-mail, name, phone) and no secret in any log line, at any level.
MD
cat > app/__init__.py </dev/null
cat > tests/__init__.py </dev/null
cat > app/alerts.py <<'PY'
import logging

log = logging.getLogger("alerts")


def send_error(exception, email="", extra_context=None):
    log.info(f"[Alert] Sending error notification for user: {email}")
    return {"error": str(exception), "context": extra_context or {}}
PY
cat > app/controller.py <<'PY'
import logging

log = logging.getLogger("controller")


def save_deal(deal_id, email, store):
    store.save(deal_id)
    return True
PY
git add -A; git commit --quiet -m "app: deals controller and alert helper"

git switch --quiet -c feat/save-deal
cat > app/controller.py <<'PY'
import logging

from app import alerts

log = logging.getLogger("controller")


def save_deal(deal_id, email, store):
    try:
        store.save(deal_id)
    except Exception as e:
        log.error(f"deal={deal_id} save failed: {e}")
        alerts.send_error(e, email=email, extra_context={"deal": deal_id})
        return False
    return True
PY
cat > tests/test_controller.py <<'PY'
import logging
from unittest import mock

from app import controller


class FailingStore:
    def save(self, deal_id):
        raise RuntimeError("db down")


def test_failure_does_not_log_the_email(caplog):
    caplog.set_level(logging.DEBUG)
    with mock.patch.object(controller, "alerts"):
        assert controller.save_deal(7, "ana@example.com", FailingStore()) is False
    assert "ana@example.com" not in caplog.text
PY
git add -A; git commit --quiet -m "feat(deals): report a failed save"
echo "built $dir on feat/save-deal"
