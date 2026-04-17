# Super-Ralph Changelog

## v0.9.2 — Effectiveness Pass (2026-04-17)

Focused improvements driven by a 4-agent parallel deep review of the plugin.

### Critical Fixes

- **Fixed `/super-ralph:build` "print-instead-of-execute" bug.** Created `skills/build/SKILL.md` as the executable driver; `commands/build.md` is now a thin shim that invokes the skill. Removed the 130+ line "For Reference" documentation that risked being executed verbatim. The skill uses imperative directives and completes all 7 steps in a single turn.

- **Eliminated hardcoded absolute paths.** Five commands were hardcoding `/Users/junhua/.claude/plugins/super-ralph/...` — breaking portability for teammates. Replaced every occurrence with `${CLAUDE_PLUGIN_ROOT}/...`:
  - `commands/build-story.md` (3 occurrences)
  - `commands/e2e.md` (1)
  - `commands/repair.md` (1)
  - `commands/design.md` (1)
  - `skills/build/*` (3)

- **Created missing quality-gate agents.** Hybrid-mode ralph loops dispatch `spec-reviewer` and `code-quality-reviewer` agents that didn't exist — previously falling back to generic Task dispatch and losing adversarial framing. New agents:
  - `agents/spec-reviewer.md` (haiku) — adversarial spec-compliance verification
  - `agents/code-quality-reviewer.md` (sonnet) — correctness + quality + testing + security review

### Architectural Improvements

- **Durable run state.** Moved per-run state from `/tmp/super-ralph-*/` (lost on reboot) to `.claude/runs/<kind>-<id>/` (version-trackable, survives restarts). Fallback to `/tmp/` preserved for sandboxed environments. Updated `build-story.md`, `e2e.md`, `repair.md`, `design.md`, `help.md`.

- **Robust setup script.** `scripts/setup-ralph-loop.sh` now resolves the target directory via `git rev-parse --show-toplevel` instead of raw CWD — prevents state-file misdirection when invoked from an unexpected directory.

- **Declared plugin dependencies.** `plugin.json` now lists required (`ralph-loop`, `superpowers`) and optional (`pr-review-toolkit`, `claude-in-chrome`) plugins with clear reasons. Surfaces in `/help`.

### New Commands

- **`/super-ralph:status`** — Dashboard view of active ralph-loops, worktrees, open PRs on `super-ralph/*` branches, in-flight epics, stale runs. The "missing control plane".

- **`/super-ralph:cleanup`** — Prune stale worktrees, run-state directories, and orphan branches. Complements `/status` (which only reports). Safe defaults: interactive confirmation unless `--force`, respects open PRs.

### New Skills

- **`skills/deployment-verification/`** — Extracted the 4 duplicated deployment-verification bash loops (finalise, build-story, e2e, release) into a single skill. Single source of truth for CD polling + HTTP health check. Enforces the `.claude/rules/deployment-verification.md` rule.

### Skill Description Improvements

Weak skill trigger descriptions now include explicit keyword lists for better activation:
- **`browser-verification`** — added 'smoke test', 'verify deployment', 'test in browser', 'check preview URL', 'playwright test', 'visual verify', 'check vercel preview' (etc.)
- **`repair-domains`** — added 'fix bug', 'hotfix', 'debug issue', 'production issue', 'incident', 'regression' (etc.)
- **`issue-management`** — removed broken `/super-ralph:issues` trigger, added real trigger commands and keywords like 'sub-issue', 'FE/BE split', 'link PR to issue'
- **`build`** (new) — explicit triggers for 'run plan', 'execute plan', 'autonomous build', 'ralph-loop build', 'walk-away build'

### Agent Improvements

- **`plan-reviewer`**: added explicit adversarial posture ("DO NOT trust what the plan claims") and required Read/Glob/Grep verification of every claim.
- **`issue-fixer`**: removed redundant `WebSearch` tool — agent now properly delegates research via `Task → research-agent` as documented.

### Documentation

- **`help.md`**: added `/status` and `/init` commands, documented plugin dependencies, documented the `.claude/runs/` run-state convention.
- **`CHANGELOG.md`**: this file.

## v0.9.1 — Previous release

(no changelog kept pre-v0.9.2)
