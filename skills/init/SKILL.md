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
2. **Level.** Use the argument if it is `lite`, `standard` or `full`. Otherwise ask with these
   options, recommending one from what the repo shows:
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
4. **GitHub protections** (standard and full). Offer each one, explain it in one line, and run
   it only on yes:
   - Branch protection on the base branches, requiring the `CI` and `Security` checks and a pull
     request: `gh api -X PUT repos/{owner}/{repo}/branches/<branch>/protection` with
     `required_status_checks`, `enforce_admins: true`, `required_pull_request_reviews`
     (1 approval on full, 0 on standard) and `restrictions: null`.
   - Secret scanning with push protection:
     `gh api -X PATCH repos/{owner}/{repo} -f security_and_analysis[secret_scanning][status]=enabled -f security_and_analysis[secret_scanning_push_protection][status]=enabled`.

   Some of these need a public repo or a paid GitHub plan. If GitHub refuses, say so plainly and
   continue: the local hooks and the CI gate still apply.
5. **Next.** If the repo already has code, run `/jit-speckit:adopt` now. For a new project, tell
   the user to run `/speckit-constitution`.
6. Summarize in four lines: the level, the files created or kept, the protections enabled, and
   the next command. Nothing is committed; the user reviews and commits the setup.
