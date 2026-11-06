---
name: init
description: "Set up the current project (new or existing) with spec-kit and jit-speckit: one task = one issue = one branch = one PR, security checks on every commit, push and PR, and best-practice defaults sized by complexity level (lite, standard, full)."
argument-hint: "[lite|standard|full]"
disable-model-invocation: true
---

# Set up a project with jit-speckit

1. **Tools.** Check `git`, `gh` and `specify`.
   - If `specify` is missing, offer to install spec-kit (the version jit-speckit is tested with):
     `uv tool install specify-cli --from git+https://github.com/github/spec-kit.git@v1.2.5`.
     If `uv` is missing too, point to https://docs.astral.sh/uv/ and stop.
   - If `gh auth status` fails, ask the user to run `! gh auth login` and stop.
2. **Level.** Use the argument if it is `lite`, `standard` or `full`. If the project already has
   `.specify/extensions/jit/jit-config.yml`, this is an update: keep its `level:` and skip the
   question. Otherwise ask with these options, recommending one from what the repo shows:
   - **lite**: prototype, solo. `feat/*` → `main`, secret checks on commit and push, core defaults.
   - **standard** (default): a product, maybe a small team. Adds `develop`, CI, a security CI
     gate, Dependabot and the security baseline.
   - **full**: production with several environments. Adds `staging`, SAST in CI, CODEOWNERS,
     SECURITY.md, a release workflow, a threat model per feature, and required analysis.

   Recommend **full** for deploy or infra code, payments, personal data, or more than 2 active
   contributors (`git shortlog -sn --since=6.months | wc -l`); **lite** for an empty repo or
   experiment; otherwise **standard**.
3. **Setup.** From the project root run
   `bash "${CLAUDE_PLUGIN_ROOT}/bin/setup.sh" . --level <level>`. Add `--no-branches` if the user
   doesn't want `develop`/`staging` pushed to `origin`. On failure, show the output and stop.
   When it refuses because `this plugin copy is <plugin>, the project is at <project>`, show that
   line as is and suggest `/reload-plugins` (this session runs an older copy of the plugin); add
   `--downgrade` only when the user asks to take the project back to the older version.
4. **GitHub settings** (every level). Read the visibility with
   `gh repo view --json visibility -q .visibility`. Offer each one, explain it in one line, and run
   it only on yes:
   - Rebase merges off, so a task PR never lands as several commits and one revert removes it:
     `gh api -X PATCH repos/{owner}/{repo} -F allow_rebase_merge=false`.
   - On lite, merge commits off too (squash only: each task PR is one commit on `main`):
     `gh api -X PATCH repos/{owner}/{repo} -F allow_merge_commit=false -F allow_squash_merge=true -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY`.
     Standard and full keep merge commits for the promotion PRs (`develop` → `main`); their task
     PRs are squashed by convention.
   - Only when the visibility is `PUBLIC` (both are free there):
     - Secret scanning with push protection:
       `gh api -X PATCH repos/{owner}/{repo} -f 'security_and_analysis[secret_scanning][status]=enabled' -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'`
       (the brackets are quoted, so zsh does not expand them).
     - Private vulnerability reporting, so the `SECURITY.md` contact works:
       `gh api -X PUT repos/{owner}/{repo}/private-vulnerability-reporting`.
   - On a `PRIVATE` or `INTERNAL` repo, say in one line instead: secret scanning with push
     protection needs GitHub Secret Protection, and private vulnerability reporting is for public
     repos.

   If GitHub refuses one, say so plainly and continue.
5. **Branch protection** (standard and full). Offer it, explain it in one line, and run it only
   on yes:
   - Branch protection on the base branches, requiring a pull request and the checks to pass:
     `gh api -X PUT repos/{owner}/{repo}/branches/<branch>/protection` with
     `required_status_checks`, `enforce_admins: true`, `required_pull_request_reviews` and
     `restrictions: null`.
     - **Check names are job names, not workflow names.** GitHub matches each required check to
       a job's `name:`, or to the job's key when it has no name. Read them from the generated
       `.github/workflows/ci.yml` and `security.yml` (for example `rust`, `Secrets (gitleaks, full
       history)`). Never use `CI` or `Security`: no job reports under those names, so every PR
       would wait forever.
     - **Approvals:** 1 on full, 0 on standard. On full with a single contributor
       (`git shortlog -sn | wc -l` is 1), say that requiring 1 approval would block their own
       PRs, and offer 0 until a second person joins.

   On a private repo it needs a paid GitHub plan. If GitHub refuses, say so plainly and continue:
   the local hooks and the CI gate still apply.
6. **Next.** If the repo already has code, run `/jit-speckit:adopt` now. For a new project, tell
   the user to run `/speckit-constitution`.
7. Summarize in four lines: the level, the files created, updated or kept, the GitHub settings
   and protections enabled, and the next command. If the script said the git hooks are "not active in this clone
   yet", repeat the command it gave: without it, nothing checks commits locally.
8. **Offer to commit it**, in one question: "Commit this on `chore/jit-speckit-<version>` and open
   the PR?" (the version is `version:` in `.specify/extensions/jit/extension.yml`). On yes: switch
   to that branch from the current one, stage **by name** only what the setup wrote (`.specify`,
   `.claude/skills`, and each file the script listed as created or updated; never `git add -A`),
   commit `chore: jit-speckit <version> (level <level>)`, push, and open a PR with a two-line body
   saying what moved and that nothing else changed. It is a small fix: no spec, no issue; the hooks
   and CI still apply. Then `/jit-speckit:adopt` (step 6) runs on that branch. On no: leave it
   uncommitted for the user to review, and say so.
