#!/usr/bin/env bash
# shellcheck disable=SC2016  # checks are strings evaluated by check()
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
export CLAUDE_SKILLS_DIR="$TMP/skills"

"$ROOT/install.sh" >/dev/null
check "when installed, then the three skills are linked" \
  '[[ -L "$CLAUDE_SKILLS_DIR/jit-speckit-init" && -L "$CLAUDE_SKILLS_DIR/jit-speckit-adopt" && -L "$CLAUDE_SKILLS_DIR/jit-speckit-level" ]]'
check "then each link points at a SKILL.md" '[[ -f "$CLAUDE_SKILLS_DIR/jit-speckit-init/SKILL.md" ]]'
check "then the setup script is reachable from the skill folder" '[[ -x "$CLAUDE_SKILLS_DIR/jit-speckit-init/../../bin/setup.sh" ]]'
check "when installed twice, then it still succeeds" '"$ROOT/install.sh"'

"$ROOT/install.sh" --uninstall >/dev/null
check "when uninstalled, then the links are gone" '[[ ! -e "$CLAUDE_SKILLS_DIR/jit-speckit-init" ]]'

mkdir -p "$CLAUDE_SKILLS_DIR/jit-speckit-init"
"$ROOT/install.sh" >/dev/null 2>&1
check "when a real folder already has the name, then it is not replaced" '[[ -d "$CLAUDE_SKILLS_DIR/jit-speckit-init" && ! -L "$CLAUDE_SKILLS_DIR/jit-speckit-init" ]]'

exit "$FAIL"
