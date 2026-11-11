---
name: report
description: "Report a problem or an improvement in landspec itself, found while using it in a project: a script that failed or refused wrongly, a generated file that is wrong, a step that is missing or confusing, a gate that cannot pass. Drafts a GitHub issue for the landspec repository, checks for duplicates, and files it after the user confirms. Use for /landspec:report, or when the user says landspec got something wrong or could do better."
argument-hint: "[what happened]"
---

# Report something to landspec

The report is an issue on landspec's repository, the `repository:` in
`${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`, as `owner/name` (call it `<repo>`). It is about **landspec**, not
the project it runs in: a bug in the project's own code is not a landspec report.

1. **What happened.** Take the argument and this session's context: the landspec command or script
   that ran, its output or error as printed, what was expected instead, and what the user or you
   had to do to get past it. If none of that is known, ask the user once what happened, and stop
   until they answer.
2. **The facts.** Collect them; don't guess:
   - landspec: `version` in `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`, and the project's copy
     (`version:` in `.specify/extensions/landspec/extension.yml`, when it exists);
   - the project's level (`level:` in `.specify/extensions/landspec/landspec-config.yml`), `specify
     --version`, `gh --version | head -1`, `uname -s`;
   - where in landspec it comes from: search `${CLAUDE_PLUGIN_ROOT}` for the message or the step
     (`grep -rn`), and name the file and line (`extension/scripts/level.sh:142`,
     `skills/init/SKILL.md` step 8). Say so when it can't be found.
3. **Keep the project private.** `<repo>` is public. The issue carries no secret, token, internal
   URL, customer data, private repository or organization name, and no project code beyond the
   few lines needed to reproduce. Replace them with neutral stand-ins (`<org>/<repo>`,
   `apps/<app>`). A reproduction is a minimal setup anyone could recreate, not the project.
4. **Duplicates.** `gh issue list -R <repo> --state all --search "<two or three key words>"`. If one
   matches, show it, and offer to add a comment with the new facts
   (`gh issue comment -R <repo> <n> --body-file <file>`) instead of a new issue.
5. **Draft**, to a temporary file (`mktemp`). Title: what goes wrong, in a few words
   (`init: setup PR cannot branch from develop when it already has spec-kit files`). Body:
   - `## What happened`: the observed behavior, with the exact message in a code block;
   - `## Expected`: what landspec should have done;
   - `## Reproduce`: numbered minimal steps;
   - `## Environment`: the versions and level from step 2;
   - `## Where`: the landspec file and line from step 2, and a suggested fix in one or two
     sentences when there is an obvious one.

   Label: `bug` when landspec does something wrong, `enhancement` when it works but could do
   better, `documentation` when only the docs are wrong. No AI attribution lines.
6. **Confirm.** Show the title, label and body, and ask: "File this on `<repo>`?" Filing is public,
   so never file without a yes. On yes: `gh issue create -R <repo> --title "<title>" --label <label>
   --body-file <file>`. If gh refuses (not logged in, no access), keep the file and give the user
   its path and `<repo>/issues/new` to paste it.
7. Several findings in one session are several issues, one per problem, each confirmed. End with
   the issue URLs.
