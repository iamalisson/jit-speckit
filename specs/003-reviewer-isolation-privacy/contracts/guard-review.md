# Contract: hooks/guard-review.sh

**Invariant**: for a review launch, the hook exits 0 at one place only, after the isolation check,
and nothing skips that check. The fork and model checks can only refuse (exit 2); none of them
allows. Every path that used to end in `exit 0` for a review (a good model, or no model under
`CLAUDE_CODE_SUBAGENT_MODEL_FORCE`) falls through to the isolation check. A launch that is not a
review exits 0 before any check, as today. The hook reads no file and no directory: its decision
depends on the call's fields alone.

Input: the PreToolUse JSON for the `Agent` or `Task` tool; `isolation` is a field of `tool_input`.
Exit 0 lets the launch run; exit 2 blocks it and stderr is shown to Claude.

| Launch | Exit | stderr |
|---|---|---|
| not a review (no `landspec:reviewer`, no sentinel) | 0 | — |
| review, `subagent_type: fork` | 2 | `landspec: the review must run in a fresh agent, not a fork of this session` |
| review, model not sonnet/opus/fable | 2 | `landspec: the review must run on sonnet, opus or fable (review_model:), not <model>` |
| review, good model or no model under `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`, `isolation` missing or not `worktree` | 2 | the isolation line |
| review, good model or no model under `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`, `isolation: worktree` | 0 | — |

The isolation line, exactly:
`landspec: the review must run in its own copy of the repository: pass isolation: "worktree" (an older landspec copy in this project? run /landspec:init; Claude Code too old to take it? update it)`

Both parsers (python3, and sed when python3 is missing) give the same decisions.
