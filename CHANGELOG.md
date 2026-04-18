# Super-Ralph Changelog

## v0.11.0 — Local Mode + Improve-Design (2026-04-18)

### Added
- `/super-ralph:design --local` flag — writes the full epic + all stories into a single markdown file at `docs/epics/<slug>.md` and SKIPS GitHub issue creation entirely.
- Path-based invocation for downstream commands:
  - `/super-ralph:build-story docs/epics/<slug>.md#story-N`
  - `/super-ralph:e2e docs/epics/<slug>.md`
  - `/super-ralph:review-design docs/epics/<slug>.md`
  - `/super-ralph:build docs/epics/<slug>.md#story-N` (and `#story-N-<be|fe|int>` for specific sub-body)
- New command `/super-ralph:improve-design "<prompt>"` — autonomously resolves the target epic (local or GitHub) from a single natural-language prompt, interprets feedback into structured changes (add/remove/split/merge/edit_ac/edit_tdd/edit_scope/re_wave/edit_metadata), applies conservative edits, and re-validates via `/review-design`.
- Shared parser `scripts/parse-local-epic.sh` with subcommands `detect-mode`, `list-stories`, `extract-story`, `extract-substory`, `get-status`, `set-status` (POSIX-portable awk, works on BSD awk on macOS).
- Test fixtures and assertion suite: `test/fixtures/sample-local-epic.md`, `test/fixtures/completed-story-epic.md`, `test/test-parse-local-epic.sh` (20 assertions).

### Safety
- `/improve-design` refuses to edit stories with `Status: COMPLETED` (local) or a CLOSED `[STORY]` issue (GitHub).
- `/build-story` also refuses `Status: COMPLETED` stories in local mode.
- Removed stories close with `reason: not_planned` on GitHub (no deletion) and leave numbering holes in local files (preserves cross-references).
- Target disambiguation uses `AskUserQuestion` when confidence is not high; no silent guessing.
- `/design --local` refuses to overwrite an existing `docs/epics/<slug>.md`.

### Notes
- All existing GitHub-mode workflows are unchanged. Local mode is additive and default off.
- No migration needed for existing open epics.

## v0.10.0 — [INT] Sub-Issue + Gate Enforcement (2026-04-17)

### Added
- `[INT]` sub-issue type for integration + E2E + deployment verification
- Mandatory `## User Journey` narrative at `[STORY]` level
- Mandatory `## Test Plan` section in `[BE]` sub-issues
- Nine enforcement gates in `/super-ralph:review-design` (STORY-G1..3, BE-G1..2, FE-G1..2, INT-G1..2)
- `[INT]` routing in `/super-ralph:build-story`

### Changed
- Story fanout: `[STORY]` now has 3 sub-issues (`[BE]` + `[FE]` + `[INT]`), was 2
- Gherkin AC now requires minimum 3 scenarios including at least one `[SECURITY]` scenario
- TDD Tasks in `[BE]`/`[FE]` marked MANDATORY — reviewer BLOCKS issues missing exact test code

### Migration
- Existing open `[STORY]` issues without `[INT]` sub-issues need remediation — see `docs/superpowers/plans/2026-04-17-kira-zero-issue-remediation-plan.md` (in kira-zero repo) for the retroactive enhancement plan
- Closed/Shipped issues left untouched

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
