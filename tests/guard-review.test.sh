#!/usr/bin/env bash
# shellcheck disable=SC2016  # checks are strings evaluated by check()
# hooks/guard-review.sh: the PreToolUse hook on the subagent tool (Agent, and Task on older clients).
# A review launch must run on sonnet, opus or fable, in a fresh agent, never on the session's model.
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
hook="$ROOT/hooks/guard-review.sh"
# shellcheck disable=SC2034  # used inside the check strings
S="jit-speckit review: independent reviewer"

# launch <tool> <subagent_type> <model or ""> <prompt>: the hook's input, as JSON on stdin.
launch() {
  local m=""; [[ -z "$3" ]] || m=",\"model\":\"$3\""
  printf '{"session_id":"s","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":{"description":"review","subagent_type":"%s","prompt":"%s"%s}}' \
    "$TMP" "$1" "$2" "$4" "$m"
}
# rc_of <json>: the hook's exit code; its stderr goes to $TMP/err.
rc_of() { local rc=0; bash "$hook" <<<"$1" 2>"$TMP/err" || rc=$?; echo "$rc"; }
blocked() { [[ "$(rc_of "$1")" == 2 ]] && grep -qF "$2" "$TMP/err"; }
allowed() { [[ "$(rc_of "$1")" == 0 ]]; }

for tool in Agent Task; do
  check "when $tool launches jit-speckit:reviewer with model haiku, then it is blocked and names haiku" \
    'blocked "$(launch $tool jit-speckit:reviewer haiku "Review the branch.")" "jit: the review must run on sonnet, opus or fable (review_model:), not haiku"'
  check "when $tool launches jit-speckit:reviewer with no model, then it is blocked and names the session's model" \
    'blocked "$(launch $tool jit-speckit:reviewer "" "Review the branch.")" "jit: the review must run on sonnet, opus or fable (review_model:), not the session'"'"'s model"'
  check "when $tool launches general-purpose with the sentinel and model haiku, then it is blocked" \
    'blocked "$(launch $tool general-purpose haiku "Do this.\\n$S\\nReview the branch.")" "not haiku"'
  check "when $tool launches general-purpose with the sentinel and no model, then it is blocked" \
    'blocked "$(launch $tool general-purpose "" "$S\\nReview the branch.")" "not the session'"'"'s model"'
  check "when $tool launches a fork carrying the sentinel on opus, then it is blocked with the fork line" \
    'blocked "$(launch $tool fork opus "$S\\nReview the branch.")" "jit: the review must run in a fresh agent, not a fork of this session"'
  check "when $tool launches jit-speckit:reviewer on opus, then it is allowed" \
    'allowed "$(launch $tool jit-speckit:reviewer opus "$S\\nReview the branch.")"'
  check "when $tool launches general-purpose with the sentinel on opus, sonnet or fable, then it is allowed" \
    'allowed "$(launch $tool general-purpose opus "$S")" && allowed "$(launch $tool general-purpose sonnet "$S")" && allowed "$(launch $tool general-purpose fable "$S")"'
  check "when $tool launches general-purpose without the sentinel, on haiku or no model, then it is allowed" \
    'allowed "$(launch $tool general-purpose haiku "Find the config.")" && allowed "$(launch $tool general-purpose "" "Find the config.")"'
done

# A prompt bigger than the pipe buffer (64 KB) is still read whole: the sentinel launch on haiku is blocked.
# shellcheck disable=SC2034  # used inside the check string
big="$(head -c 400000 /dev/zero | tr '\0' x)"
check "when general-purpose carries the sentinel in a 400 KB prompt with model haiku or none, then it is blocked" \
  'blocked "$(launch Agent general-purpose haiku "$S\\n$big")" "not haiku" && blocked "$(launch Agent general-purpose "" "$S\\n$big")" "not the session"'

# Without python3 the hook reads the fields with sed: the same decisions.
mkdir -p "$TMP/nopy"
for t in bash cat sed grep; do ln -sf "$(command -v "$t")" "$TMP/nopy/$t"; done
check "when python3 is not on PATH, then a reviewer launch on haiku is still blocked and one on opus allowed" \
  'rc=0; launch Agent jit-speckit:reviewer haiku "x" | PATH="$TMP/nopy" bash "$hook" 2>/dev/null || rc=$?; [[ $rc == 2 ]] && launch Agent jit-speckit:reviewer opus "x" | PATH="$TMP/nopy" bash "$hook"'

# The bash 3.2 job has no python3: there, the entry from the Agent|Task matcher to its onFailure is read with sed.
check "when hooks.json is read, then it runs guard-review.sh on the Agent and Task tools with onFailure block" \
  'if ! command -v python3 >/dev/null; then e="$(sed -n "/\"matcher\": *\"Agent|Task\"/,/\"onFailure\"/p" "$ROOT/hooks/hooks.json")"; [[ "$e" == *guard-review.sh* && "$e" == *"\"onFailure\": \"block\""* ]]; exit; fi
  python3 -c "import json,sys; h=[e for e in json.load(open(sys.argv[1]))[\"hooks\"][\"PreToolUse\"] if \"guard-review.sh\" in e[\"hooks\"][0][\"command\"]]; m=h[0][\"matcher\"].split(\"|\"); sys.exit(0 if \"Agent\" in m and \"Task\" in m and h[0][\"hooks\"][0][\"onFailure\"]==\"block\" else 1)" "$ROOT/hooks/hooks.json"'

exit "$FAIL"
