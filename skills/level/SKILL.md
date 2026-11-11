---
name: level
description: "Change a landspec project's complexity level (lite, standard, full): updates the branch flow, the constitution defaults block, the CI and security scaffolding and the git hooks."
argument-hint: "<lite|standard|full>"
disable-model-invocation: true
---

# Change the complexity level

1. The level is the argument. If it is missing or not `lite`/`standard`/`full`, show the current
   one (`level:` in `.specify/extensions/landspec/landspec-config.yml`) and the three options with one line
   each, then ask.
2. Run `bash .specify/extensions/landspec/scripts/level.sh <level>`. Add `--no-branches` if the user
   doesn't want `develop`/`staging` created on `origin`.
3. Bump the constitution's version line (MINOR going up a level, PATCH going down) and set
   *Last Amended* to today.
4. Going **up** to standard or full: offer the branch protection from `/landspec:init`
   step 5. Going up from lite, also offer merge commits back on, which the promotion PRs need:
   `gh api -X PATCH repos/{owner}/{repo} -F allow_merge_commit=true`. Going **down** to lite, offer
   squash-only: `gh api -X PATCH repos/{owner}/{repo} -F allow_merge_commit=false -F allow_squash_merge=true -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY`.
5. Report what the script printed: the level change, branches created, files created and kept.
   Going down never deletes files; list the ones the user may want to delete by hand. Nothing is
   committed. Say that the change goes to the base branch of the new level
   (a small-fix PR through `pr.sh fix`, which opens it into `<base branch>`), since scripts read the level from the tree: going up from
   lite, `develop` was cut before this change and has none of it until that PR merges.
