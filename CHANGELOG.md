# Super-Ralph Changelog

## 0.14.2 — drop plugin.json `dependencies` field

### Fixed
- Removed `dependencies` from `.claude-plugin/plugin.json`. Claude Code's plugin manifest doesn't support cross-marketplace dependency references: bare names resolve to the plugin's own marketplace (`junhua-plugins`), and the `name@marketplace` suffix tried in 0.14.1 isn't valid syntax. Both forms produced `Dependency "ralph-loop@junhua-plugins" is not found` on load. The requirement on `ralph-loop` and `superpowers` (both from `claude-plugins-official`) remains documented in the README — users must install them manually, as was the case before 0.13.1.

## 0.14.1 — qualify dependency marketplaces (broken, do not use)

### Fixed
- `.claude-plugin/plugin.json` dependencies qualified the marketplace (`ralph-loop@claude-plugins-official`, `superpowers@claude-plugins-official`). This syntax turned out not to be supported by Claude Code — superseded by 0.14.2.

## 0.13.1 — plugin.json schema fix + CI validation

### Fixed
- Reshaped `.claude-plugin/plugin.json` to a schema-valid form (`repository` as string URL, `dependencies` as array; dropped `optionalDependencies`). Previous npm-style shapes failed Claude Code's manifest validator, blocking installs and upgrades of 0.13.0.

### Added
- `.github/workflows/validate-manifest.yml` — blocks future npm-shape regression on every PR and push to `main`.

## 0.14.0 — Brief design mode + /expand-story

### Added
- `--brief` flag on `/super-ralph:design` for backlog-grooming output (EPIC + STORY skeletons with bulleted `[HAPPY]`/`[EDGE]`/`[SECURITY]` AC, no BE/FE/INT, no TDD). Combines with `--local`.
- `/super-ralph:expand-story <target> [--all]` command to promote brief stories to full by running the Phase 4 story-planner. Auto-creates `[BE]`/`[FE]`/`[INT]` sub-issues and replaces bulleted AC with full Gherkin.
- `BRIEF-G1`, `BRIEF-G2`, `BRIEF-G3` gates in `/super-ralph:review-design`. New verdicts `READY FOR EXPAND` (all brief) and `READY — MIXED` (hybrid).
- `parse-local-epic.sh detect-story-level` and `detect-design-level` subcommands — structural detection of brief vs full per story and per epic.

### Changed
- `/super-ralph:improve-design` is now brief-aware: detects per-story level and refuses `EDIT_TDD`/`EDIT_SHARED_CONTRACT` on brief stories with a clarification pointing to `/expand-story`.

### Fixed
- `/super-ralph:build-story` local-mode Phase 1 skip-detection previously hardcoded `mode: embedded`. It now falls through to `mode: standard` when the story is brief (empty `be.md`/`fe.md`), unblocking brief local stories. This is also a latent-bug fix: a full epic with accidentally-empty sub-sections would previously crash the build sub-agent.

## v0.13.0 — Thin Commands + Modular Skills Refactor (2026-04-19)

### Added
- **New skill `story-execution`** — canonical 5-phase state machine (plan → build → review-fix → verify → finalise) for `/super-ralph:build-story`, with 7 reference files:
  - `state-machine.md` (320 lines) — Step 0 context resolution, Step 1 resume detection, `[INT]` sub-issue branching, temp-file layout
  - `phase-1-plan.md`, `phase-2-build.md`, `phase-3-review-fix.md`, `phase-4-verify.md`, `phase-5-finalise.md` — per-phase sub-agent dispatch specs
  - `epic-orchestration.md` (545 lines) — wave-driven multi-story execution for `/super-ralph:e2e`
- **New skill `release-flow`** — unified skill covering per-story finalise + release promotion, with 2 reference files:
  - `finalise-flow.md` (404 lines) — 8-step per-PR finalise procedure
  - `release-flow.md` (525 lines) — 10-phase staging → main promotion
- **Expanded `repair-domains` skill** — added 2 reference files:
  - `repair-flow.md` (522 lines) — 10-step end-to-end repair procedure (parse → detect → research → worktree → TDD fix → review-fix → verify → finalise → backport → report)
  - `hotfix-backport.md` (61 lines) — hotfix backport procedure for main-targeting fixes
- **Expanded `product-brainstorm` skill** — added 2 reference files:
  - `brainstorm-flow.md` (186 lines) — 7-step brainstorm procedure
  - `executive-personas.md` (81 lines) — CPO / CTO / CAIO SME brainstormer prompts

### Changed (architecture refactor, continued from v0.12)
- **Nine commands slimmed to thin orchestrators:**
  - `commands/design.md` 1,313 → 100 lines (92%)
  - `commands/build-story.md` 931 → 69 lines (93%)
  - `commands/review-design.md` 624 → 64 lines (90%)
  - `commands/repair.md` 606 → 68 lines (89%)
  - `commands/e2e.md` 580 → 85 lines (85%)
  - `commands/release.md` 547 → 75 lines (86%)
  - `commands/finalise.md` 435 → 54 lines (88%)
  - `commands/brainstorm.md` 299 → 55 lines (82%)
  - `commands/improve-design.md` 300 → 307 lines (+7, added skill pointers + context-budget clause)
- **Cumulative**: 9 commands refactored, 5,635 → 877 lines (**84% reduction**).
- **Architecture ratio:** commands : (skill bodies + references) ≈ **1 : 7** across the refactored slice. Target was 1 : 3 — well past.
- `/e2e` now delegates cleanly to two skills (`story-execution` for per-story phases and `release-flow` for promotion). `/repair` delegates to `repair-domains` for flow and to `story-execution` + `release-flow` for reused phases. `/brainstorm` delegates to `product-brainstorm`.

### Notes
- All existing invocations work unchanged. Behavior is preserved; only the home of the content changed.
- Per-invocation context savings compound: a `/super-ralph:e2e` or `/super-ralph:repair` call now loads metadata + pointers instead of 580/606 lines of inline workflow, then loads skill references on demand.
- `review-fix-loop` remains deliberately command-only (`DO_NOT_ADD_SKILL.md` marker honored).
- No behavior drift: every extracted reference preserves the source content verbatim.

## v0.12.0 — Context Budget + Thin Commands Architecture (2026-04-19)

### Added
- **Execution Context Budget** model enforced end-to-end through `/super-ralph:design`: every `[STORY]`, `[BE]`, `[FE]`, `[INT]` sub-issue must fit in the 200k-token window of the downstream `/super-ralph:build-story` subagent.
  - SLICE-time estimation rule (pre-Phase-4) to catch oversized stories before dispatching a planner.
  - In-prompt `HARD CONSTRAINT` block on the Phase 4 story-planner with per-body caps (STORY ≤ 20k tok, BE ≤ 30k, FE ≤ 30k, INT ≤ 15k, combined ≤ 90k target / 120k hard cap).
  - `SPLIT_NEEDED` sentinel protocol so an oversized story fails cheap instead of producing a bloated body.
  - New Step 10.5 post-plan Context Budget Audit (bash `awk`-based byte measurement, three-tier remediation: trim → dereference pattern excerpts → split).
  - Design-review CTX-G1..G3 gates in `/super-ralph:review-design` with soft-warn CONDITIONAL (360k–480k chars combined) vs hard-cap BLOCKED (>480k) verdict logic.
- **New skill `design-review`** with `references/gate-catalog.md` — extracts all enforcement gates (STORY-G, BE-G, FE-G, INT-G, CTX-G, CX-x) into a single authoritative catalog.

### Changed (architecture refactor)
- **Thin commands + lean skills + rich references.** Adopted Anthropic's progressive-disclosure guidance uniformly for the design loop:
  - `commands/design.md` 1,313 → 100 lines (92% reduction)
  - `commands/review-design.md` 624 → 64 lines (90% reduction)
  - `skills/product-design/SKILL.md` 479 → 215 lines (55% reduction, now a navigator)
  - `skills/issue-management/SKILL.md` 704 → 140 lines (80% reduction)
- **Extracted six reference files** (all content preserved verbatim, no behavior drift):
  - `skills/product-design/references/sadd-workflow.md` (504 lines) — Full 6-phase SADD procedure
  - `skills/product-design/references/story-planner-spec.md` (647 lines) — Phase 4 sub-agent dispatch + output contracts
  - `skills/product-design/references/execution-planning.md` (129 lines) — DAG, audit, wave assignment
  - `skills/product-design/references/context-budget.md` (122 lines) — Budget model, SPLIT_NEEDED, CTX gates
  - `skills/design-review/references/gate-catalog.md` (196 lines) — All enforcement gates in one place
  - `skills/issue-management/references/gh-invocation-patterns.md` (287 lines) — Exact `gh` CLI patterns extracted from the trimmed SKILL.md
- `improve-design.md` now references the same product-design skill references and inherits Context Budget discipline when applying changes.

### Notes
- All existing invocations of `/super-ralph:design`, `/super-ralph:review-design`, `/super-ralph:improve-design` work unchanged — content moved, behavior preserved.
- Ratio of command : (skill + references) in the refactored slice: ~1 : 5.4 (was ~1 : 1).
- Per-invocation context savings expected ~60% because commands now load metadata + pointers instead of the full workflow.

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
