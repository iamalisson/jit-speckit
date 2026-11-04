#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # checks are strings evaluated by check()
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
fake_gh
n="$SCRIPTS/next.sh"
closed() { printf '%s\n' "$@" > "$GH_CLOSED"; } # issue numbers the fake gh reports as closed

new_repo standard
commit_tasks '- [ ] T001 First in `a` — #1
- [ ] T002 [P] Second in `b` — #2
- [ ] T003 Third in `c` — #3'

closed
out="$("$n")"
check "when no issue is closed, then the next task is the first one" '[[ "$out" == *"DONE=0/3 NEXT=T001"* ]]'

closed 1 3
out="$("$n")"
check "when issues are closed out of order, then the next task is the first still open" '[[ "$out" == *"DONE=2/3 NEXT=T002"* ]]'
check "then each task shows its state" 'grep -q "^done T001 #1 First" <<<"$out" && grep -q "^open T002 #2 Second" <<<"$out"'

closed 1 2 3
check "when every issue is closed, then there is no next task" '[[ "$("$n")" == *"DONE=3/3 NEXT="* ]]'

printf '%s\n' '- [ ] T004 Fourth in `d`' >> specs/001-demo/tasks.md
check "when a task has no issue, then it is listed as no-issue and not picked" \
  'out="$("$n")"; grep -q "^no-issue T004" <<<"$out" && [[ "$out" == *"NEXT="* && "$out" != *"NEXT=T004"* ]]'

exit "$FAIL"
