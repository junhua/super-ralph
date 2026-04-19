---
name: release
description: "QA staging, Codex-review PR to main, merge, seal a version — comprehensive promotion gate"
argument-hint: "[--milestone NAME] [--tag VERSION] [--no-verify] [--no-codex]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)", "Bash(git:*)", "Bash(gh:*)", "Bash(bun:*)", "Bash(codex:*)", "Read", "Write", "Edit", "Glob", "Grep", "Task"]
---

# Super-Ralph Release Command

Promote staging to production: pre-flight checks, QA verification on staging, create staging→main PR, Codex CLI review + fix loop, merge to main, tag, milestone closure, release notes, cleanup. Runs as a ralph-loop with subagent-driven orchestration.

## Branch Model

```
feature branches ──PR──▶ staging (default branch, preview deploys)
                              │
                     /super-ralph:release
                              │
                              ▼
                         main (production, URLs from config)
```

- **staging** = GitHub default branch. All feature PRs merge here via `/super-ralph:finalise`.
- **main** = production branch. Only `/super-ralph:release` merges into main.
- Vercel auto-deploys: staging → preview URL, main → production domains.

## Arguments

- **`--milestone`** (optional): Milestone name (e.g., `v1.2`). If omitted, auto-detect the first open milestone.
- **`--tag`** (optional): Git tag (e.g., `v1.2.0`). If omitted, derive from milestone (`v1.2` → `v1.2.0`).
- **`--no-verify`** (optional): Skip Phase 2 (QA verification). Pre-flight always runs.
- **`--no-codex`** (optional): Skip Phase 6 (Codex review). Useful if codex CLI is not installed.

## Workflow

Execute the 10-phase release promotion flow defined by the `super-ralph:release-flow` skill.

### Step 0: Load Project Config & Skill

Read `.claude/super-ralph-config.md` to load every `$VARIABLE` used by the skill and its references (`$REPO`, `$ORG`, `$PROJECT_NUM`, `$PROJECT_ID`, `$STATUS_FIELD_ID`, `$STATUS_SHIPPED`, `$BE_DIR`, `$FE_DIR`, `$BE_TEST_CMD`, `$FE_TEST_CMD`, `$APP_URL`, `$PROD_URLS`, `$PM_USER`, `$TECH_LEAD`, `$TESTERS`, `$MAIN_BRANCH`, `$STAGING_BRANCH`).

Invoke the `super-ralph:release-flow` skill for the release promotion procedure (Flow B). Also invoke:
- `super-ralph:issue-management` — milestone mechanics, QA issue reconciliation
- `super-ralph:browser-verification` — staging smoke tests in Phase 2a
- `super-ralph:deployment-verification` — production CD health check in Phase 7b

### Step 1: Execute the 10-Phase Release

Follow `${CLAUDE_PLUGIN_ROOT}/skills/release-flow/references/release-flow.md`:

1. **Identify release context** — resolve milestone + version bump type (major/minor/patch)
2. **Pre-flight checks** — clean working tree, staging green, no blocking `[QA]` open
3. **QA verification on staging** — (a) browser smoke, (b) full regression, (c) API contract, (d) AC audit. Skipped when `--no-verify`.
4. **Evaluate & fix** — open `[FIX]` for any regressions; halt if Critical
5. **Release documentation** — CHANGELOG, release notes draft, version bump in plugin.json / package.json / VERSION
6. **Create staging → main PR** with release notes
7. **Codex review** — second-opinion review via `codex` CLI; BLOCK on Critical. Skipped when `--no-codex`.
8. **Merge to main** — squash-merge after Codex clean; no force-push
9. **Verify production deployment** (Phase 7b) — poll CD until healthy; on RED, open incident `[FIX]` and rollback
10. **Seal version** — git tag + release notes + close Milestone
11. **Sync staging** — rebase staging on main
12. **Cleanup** — prune stale branches, archive run-state dirs

### Step 2: Summary

Emit the final release summary (milestone closed, tag created, production URL verified, next milestone suggested). Template in `references/release-flow.md` § "Phase 10: Cleanup".

## Critical Rules

- **Never force-push to main or staging.** Full stop.
- **Codex review is a hard gate.** Never promote with Critical findings outstanding. `--no-codex` is for environments without the codex CLI, not a gate bypass.
- **Merge success ≠ shipped.** Production CD must verify healthy before sealing the version.
- **Milestone close is the final act.** Only after version sealed and production healthy.
- **QA issues block releases.** Close all open `[QA]` against the milestone, or pull them out of the milestone, before promoting.
- **Rollback is scripted, not improvised.** If Phase 9 fails, follow the rollback procedure in `release-flow.md` — do not ad-hoc revert.
