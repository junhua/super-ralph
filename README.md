<p align="center">
  <img src="./assets/teaser.png" alt="Super-Ralph — Orbital Cadence" width="100%" />
</p>

# Super-Ralph

> **v0.10.0** — Project-agnostic, design-first autonomous development. `/design` produces 4 issues per story: `[STORY]` + `[BE]` + `[FE]` + `[INT]` (new), with mandatory User Journey, full Gherkin ≥3 scenarios including `[SECURITY]`, and mandatory TDD Tasks. Nine enforcement gates in `/review-design` block non-compliant designs. Project-specific values loaded from `.claude/super-ralph-config.md` (auto-generated on first use).

Hit enter. Walk away. Come back to results.

## Install

```
/plugin marketplace add junhua/claude-plugins
/plugin install super-ralph@junhua-plugins
```

Then restart Claude Code. See the full command list at [`/super-ralph:help`](./commands/help.md) and the changelog in [CHANGELOG.md](./CHANGELOG.md).

## Dependencies

Super-ralph builds on other plugins. Declared in `plugin.json`:

| Plugin | Required? | Why |
|--------|-----------|-----|
| `ralph-loop` | **required** | Stop hook that drives autonomous iteration |
| `superpowers` | **required** | TDD, debugging, verification, parallel-agents skills |
| `pr-review-toolkit` | optional | code-reviewer, silent-failure-hunter, pr-test-analyzer, type-design-analyzer, code-simplifier, comment-analyzer for `/review-fix` |
| `claude-in-chrome` | optional | browser automation for `/verify` |

## What It Does

Super-ralph orchestrates the full development lifecycle autonomously using a **design-first** pipeline:

1. **Design** — Create implementation-ready epics with Gherkin AC, TDD tasks, FE/BE/INT sub-issues, and execution plans
2. **Build** — Execute stories from issue body directly (TDD tasks are embedded — no separate plan step)
3. **Review & Fix** — Multi-agent code review on branch diff, fix issues until clean, create PR
4. **Verify** — Browser-verify Vercel preview deployments against Gherkin acceptance criteria
5. **Finalise** — Merge PR, close issues, cleanup worktrees
6. **Release** — QA + Codex review + merge staging→main + tag + milestone close

For ad-hoc work ([FIX], [CHORE], spikes), use `/plan` → `/build` instead.

## Release Lifecycle

```
1. Requirements    HoP confirms business requirements (human)
2. Planning        PM uses /design → EPIC + STORYs + [FE]/[BE]/[INT] sub-issues
3a. FE Dev         Design Engineering iterates with PM/HoP (mock data)
3b. BE Dev         Backend/AI built concurrently
3c. Integration    Mock swap + Gherkin E2E + `/super-ralph:verify` (after BE+FE merge)
4. Testing         Playwright e2e + manual verification
5. Release         /release seals and versions
```

## Pipelines

```
Design-first:  design → build-story → review-fix → verify → finalise
Epic:          e2e (parallel build-story per story, then release)
Ad-hoc:        plan → build → review-fix → verify → finalise
Reactive:      repair → review-fix → verify → finalise
Hotfix:        repair --hotfix → review-fix → verify → finalise on main
Release:       release (QA → Codex review → merge staging→main → tag)
Quality:       review-design (validate issues against quality gates)
Brainstorm:    brainstorm (research → CPO+CTO+CAIO → recommendations)
Observability: status (runtime dashboard) / cleanup (prune stale state)
```

## Issue Taxonomy

```
[EPIC]  → Feature epic with PM Summary + execution plan
  └── [STORY] → User story with Gherkin AC + shared contract
        ├── [BE]  → Backend: schema + service + route + TDD tasks
        ├── [FE]  → Frontend: component + mock data + i18n + TDD tasks + PM checkpoints
        └── [INT] → Integration: mock swap + Gherkin E2E + `/super-ralph:verify`
[FIX]   → Bug fix (use /plan or /repair)
[CHORE] → Technical work (use /plan)
```

## Sub-Agent Architecture (SADD)

`/design` uses **Sub-Agent Driven Development**:

| Phase | Agent | Model | Parallel? |
|-------|-------|-------|-----------|
| 1. Context | Orchestrator reads docs + codebase | Opus | Sequential |
| 2. Research | research-agent + 2 SME brainstormers | Haiku + Sonnet | 3 parallel |
| 3. Epic | Orchestrator defines scope, SLICE decomposition | Opus | Sequential |
| 4. Stories | 1 story-planner per story | Sonnet | Max 4 parallel |
| 5. Issues | Create GitHub issues, set Project #9 fields | Opus | Sequential |
| 6. Review | design-reviewer validates all issues | Sonnet | Sequential |

**Hybrid-mode ralph loops** (`/build --mode hybrid`) additionally dispatch:

| Agent | Role | Model |
|-------|------|-------|
| `spec-reviewer` | Adversarial spec-compliance gate after implementer | Haiku |
| `code-quality-reviewer` | Correctness + readability + testing + security gate | Sonnet |

## Commands

### `/super-ralph:design` — THE PRIMARY COMMAND

Create implementation-ready epics with stories, Gherkin AC, TDD tasks, and FE/BE sub-issues.

```
/super-ralph:design "Admin governance hardening — RBAC, user lifecycle, batch ops"
/super-ralph:design "Finance AP invoices and payment workflow"
```

**What happens:** 6-phase SADD flow — reads product docs + explores codebase, dispatches research + SME agents, applies SLICE decomposition to define stories, dispatches per-story planner agents (Sonnet) that read the codebase and produce exact TDD tasks, creates GitHub issues with Project #9 fields, then self-reviews with `/review-design`.

### `/super-ralph:review-design` — QUALITY GATE

Validate all issues in an EPIC against quality gates before development starts.

```
/super-ralph:review-design 479              # Review EPIC #479
/super-ralph:review-design 479 --fix        # Auto-fix mechanical issues
/super-ralph:review-design 479 --strict     # Zero-tolerance mode
```

**What happens:** Fetches EPIC + all child issues, dispatches parallel review agents checking PM gates (persona, outcomes, Gherkin coverage), developer gates (TDD tasks, no pseudocode, exact paths), and cross-issue gates (shared file conflicts, dependency DAG). Returns **READY** / **CONDITIONAL** / **BLOCKED** verdict.

### `/super-ralph:build-story`

Execute a story end-to-end. **Skips plan phase** when TDD tasks are in the issue body.

```
/super-ralph:build-story #42
/super-ralph:build-story #42 --skip-verify --skip-finalise
```

### `/super-ralph:plan` — AD-HOC ONLY

For `[FIX]`, `[CHORE]`, spikes. For epic-driven features, use `/design` instead.

```
/super-ralph:plan "Fix null pointer in policy cascade"
/super-ralph:plan "Upgrade Drizzle ORM to 0.41"
```

### `/super-ralph:brainstorm`

Autonomous brainstorming with CPO/CTO/CAIO perspectives.

```
/super-ralph:brainstorm "Finance module usability"
/super-ralph:brainstorm "What should we build next?" --scope product
```

### `/super-ralph:status` — RUNTIME DASHBOARD

Inspect active ralph-loops, worktrees, open PRs, in-flight epics, stale state.

```
/super-ralph:status              # full dashboard
/super-ralph:status --worktrees  # just worktrees
/super-ralph:status --prs        # just open PRs on super-ralph/* branches
```

### `/super-ralph:cleanup` — PRUNE STALE STATE

Safely remove old worktrees, run directories, and orphan branches.

```
/super-ralph:cleanup                        # interactive, 7-day age default
/super-ralph:cleanup --dry-run              # list only, no delete
/super-ralph:cleanup --age-days 14 --force  # auto-remove items >14 days
```

### Other Commands

| Command | Purpose |
|---------|---------|
| `/super-ralph:build` | Execute a plan via ralph-loop |
| `/super-ralph:repair` | Domain-aware reactive fix (supports `--hotfix`) |
| `/super-ralph:review-fix` | Multi-agent code review + fix loop |
| `/super-ralph:verify` | Browser-verify PR against acceptance criteria |
| `/super-ralph:finalise` | Merge PR, close issues, cleanup |
| `/super-ralph:e2e` | Execute entire epic with wave parallelism |
| `/super-ralph:release` | Promote staging → main with QA gate |
| `/super-ralph:init` | Generate `.claude/super-ralph-config.md` |
| `/super-ralph:help` | Show full documentation |

## Run State Durability

Per-run state (context, progress, phase outputs) lives in:

```
.claude/runs/<kind>-<id>/         ← preferred: durable, survives reboots
/tmp/super-ralph-<kind>-<id>/     ← legacy fallback for sandboxed envs
```

Resume detection reads both locations. `/super-ralph:status` surfaces the active runs and `/super-ralph:cleanup` prunes stale ones.

## SLICE Decomposition

Before writing any story, `/design` applies SLICE:

| Letter | Check | Split if... |
|--------|-------|-------------|
| **S** | System boundary | BE+FE in one action = OK |
| **L** | Lifecycle stage | Multiple CRUD ops → separate stories |
| **I** | Interaction type | List/detail/form/action → separate stories |
| **C** | Config vs operation | Admin ≠ operator |
| **E** | Error surface | >3 error modes → split error story |

Additional rules: one schema migration = one story, one state machine = one story, list ≠ detail, XL = must split. Target 8-15 stories per epic.

## FE/BE Concurrent Development

```
[STORY] — Shared contract (TS types) + Gherkin AC
  ├── [BE] — Schema + service + route + TDD tasks
  └── [FE] — Component + mock data + i18n + PM checkpoints + TDD tasks

FE iterates with PM using mock data:
  CP1 (shell) → CP2 (happy path) → CP3 (edges) → CP4 (PM sign-off)

Integration: swap mocks for real API → run e2e tests
```

## AI-Readable Documentation Standard

| Rule | Bad | Good |
|------|-----|------|
| Tables over prose | "The slice includes..." | Vertical Slice table |
| Expected output | `Run: bun test` | `Run: bun test foo.test.ts` / `Expected: PASS — 2 passed` |
| Concrete values | "appropriate error" | `"Vendor is required"` |
| Decisions pre-made | "Choose between..." | "Use JWT. See auth.ts." |
| No filler | "This is important..." | `**Required for:** Task N+1` |

## Gherkin Format

All stories use full Gherkin with category labels:

```gherkin
Feature: Pipeline Board
  Background:
    Given I am logged in as sales manager

  Scenario: [HAPPY] View pipeline with deals
    Given deals exist in "Qualification" and "Proposal"
    When I navigate to /sales/pipeline
    Then I see 2 stage columns with correct deal counts

  Scenario: [EDGE] Empty pipeline
    Given no deals exist
    When I navigate to /sales/pipeline
    Then I see empty state with "Create your first deal" prompt
```

Mapping: Feature→`describe()`, Background→`beforeEach()`, Scenario→`test()`, Outline→`test.each()`

## Plugin Structure

```
super-ralph/
├── .claude-plugin/plugin.json   ← version, dependencies
├── CHANGELOG.md                 ← version history
├── agents/
│   ├── browser-verifier.md
│   ├── code-quality-reviewer.md ← NEW v0.9.2: hybrid-mode quality gate
│   ├── issue-fixer.md
│   ├── plan-reviewer.md         ← v0.9.2: adversarial posture
│   ├── research-agent.md
│   ├── sme-brainstormer.md
│   └── spec-reviewer.md         ← NEW v0.9.2: adversarial spec gate
├── commands/
│   ├── brainstorm.md
│   ├── build-story.md
│   ├── build.md                 ← v0.9.2: thin skill shim (fixes print-bug)
│   ├── cleanup.md               ← NEW v0.9.2: prune stale state
│   ├── design.md                ← PRIMARY COMMAND (6-phase SADD)
│   ├── e2e.md
│   ├── finalise.md
│   ├── help.md
│   ├── init.md                  ← auto-generate project config
│   ├── plan.md                  ← AD-HOC ONLY (FIX/CHORE/spikes)
│   ├── release.md
│   ├── repair.md
│   ├── review-design.md         ← quality gate command
│   ├── review-fix.md
│   ├── status.md                ← NEW v0.9.2: runtime dashboard
│   └── verify.md
├── scripts/
│   └── setup-ralph-loop.sh      ← v0.9.2: git-toplevel resolution
└── skills/
    ├── browser-verification/
    ├── build/                   ← NEW v0.9.2: /build executor skill
    ├── deployment-verification/ ← NEW v0.9.2: single-source CD polling
    ├── issue-management/
    ├── product-brainstorm/
    ├── product-design/
    ├── ralph-planning/
    ├── repair-domains/
    └── review-fix-loop/
```

## What's New in v0.9.2

Major effectiveness pass — see [CHANGELOG.md](./CHANGELOG.md) for details. Highlights:

- **Portability**: replaced all hardcoded `/Users/...` paths with `${CLAUDE_PLUGIN_ROOT}`
- **Quality gates**: created `spec-reviewer` and `code-quality-reviewer` agents that hybrid-mode ralph loops were referencing but didn't exist
- **Durable state**: `.claude/runs/` replaces `/tmp/` (survives reboots, version-trackable)
- **`/status`** and **`/cleanup`** commands for runtime visibility and maintenance
- **`deployment-verification`** skill consolidates 4 duplicated CD-polling bash blocks
- **Plugin dependencies** now declared in `plugin.json`
- **Skill triggers** expanded for broader keyword activation
- **`/super-ralph:build` print-bug** fully fixed via dedicated executor skill

## License

MIT
