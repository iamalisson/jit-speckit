#!/usr/bin/env bash
# Run the project's mutation-testing command on this branch's changes and keep its output.
#   mutants.sh
# The command is the constitution's **Commands** line: mutate `<command>`. It must exit non-zero
# when a mutant survives, and it gets two variables to scope itself to the change:
#   JIT_DIFF_FILE      a unified diff of this branch against the base (cargo mutants --in-diff)
#   JIT_CHANGED_FILES  the changed source files, space-separated, tests excluded (stryker --mutate)
# Prints one line: "mutants ok|survivors|missing|skipped <detail>", then REPORT_DIR=<dir>.
# Output goes to .git/jit-mutants/<timestamp>/ so it is never committed; the result line is also
# this diff's record (.git/jit-mutants/<diff id>), which pr.sh task requires.
set -uo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
jit_cd_root

dir="$(git rev-parse --git-common-dir)/jit-mutants/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$dir"
finish() { echo "mutants $1 $2" | tee "$(diff_record jit-mutants)"; echo "REPORT_DIR=$dir"; exit 0; }

cmd="$(constitution_cmd mutate)"
[[ -n "$cmd" ]] || finish missing "no 'mutate' command in the constitution's **Commands** line; /jit-speckit:adopt fills it"

from="$(git merge-base HEAD "$(base_ref)" 2>/dev/null || echo HEAD)"
git diff "$from" HEAD > "$dir/changes.diff"
changed="$(git diff --name-only --diff-filter=ACMR "$from" HEAD | grep -vE "$TEST_PATH_RE" | tr '\n' ' ')"
changed="${changed% }"
[[ -n "$changed" ]] || finish skipped "no changed source files"

if JIT_DIFF_FILE="$dir/changes.diff" JIT_CHANGED_FILES="$changed" bash -c "$cmd" > "$dir/mutants.log" 2>&1; then
  finish ok "every mutant in the changed lines was caught ($cmd)"
fi
finish survivors "a mutant survived: a behavior no test checks; see $dir/mutants.log"
