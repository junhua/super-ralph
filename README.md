<p align="center">
  <img src="./assets/teaser.png" alt="Super-Ralph — Orbital Cadence" width="100%" />
</p>

# Super-Ralph

> **v0.8.0** — Design-first autonomous development. `/design` is the single entry point: it produces implementation-ready GitHub issues with embedded TDD tasks, Gherkin AC, and FE/BE sub-issues for concurrent development.

Hit enter. Walk away. Come back to results.

## Install

```
/plugin marketplace add junhua/claude-plugins
/plugin install super-ralph@junhua-plugins
```

Then restart Claude Code. See the full command list at [`/super-ralph:help`](./commands/help.md).

## What It Does

Super-ralph orchestrates the full development lifecycle autonomously using a **design-first** pipeline:

1. **Design** — Create implementation-ready epics with Gherkin AC, TDD tasks, FE/BE sub-issues, and execution plans
2. **Build** — Execute stories from issue body directly (TDD tasks are embedded — no separate plan step)
3. **Review & Fix** — Multi-agent code review on branch diff, fix issues until clean, create PR
4. **Verify** — Browser-verify Vercel preview deployments against Gherkin acceptance criteria
5. **Finalise** — Merge PR, close issues, cleanup worktrees
6. **Release** — QA + Codex review + merge staging→main + tag + milestone close

For ad-hoc work ([FIX], [CHORE], spikes), use `/plan` → `/build` instead.

## Release Lifecycle

```
1. Requirements    HoP confirms business requirements (human)
2. Planning        PM uses /design → EPIC + STORYs + [FE]/[BE] sub-issues
3a. FE Dev         Design Engineering iterates with PM/HoP (mock data)
3b. BE Dev         Backend/AI built concurrently
4. Integration     FE + BE connected, e2e tests pass
5. Testing         Playwright e2e + manual verification
6. Release         /release seals and versions
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
```

## Issue Taxonomy

```
[EPIC]  → Feature epic with PM Summary + execution plan
  └── [STORY] → User story with Gherkin AC + shared contract
        ├── [BE] → Backend: schema + service + route + TDD tasks
        └── [FE] → Frontend: component + mock data + i18n + TDD tasks + PM checkpoints
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
| `/super-ralph:help` | Show full documentation |

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
├── .claude-plugin/plugin.json
├── agents/
│   ├── browser-verifier.md
│   ├── issue-fixer.md
│   ├── plan-reviewer.md
│   ├── research-agent.md
│   └── sme-brainstormer.md
├── commands/
│   ├── brainstorm.md
│   ├── build-story.md
│   ├── build.md
│   ├── design.md            ← PRIMARY COMMAND (6-phase SADD)
│   ├── e2e.md
│   ├── finalise.md
│   ├── help.md
│   ├── plan.md              ← AD-HOC ONLY (FIX/CHORE/spikes)
│   ├── release.md
│   ├── repair.md
│   ├── review-design.md     ← NEW: quality gate command
│   ├── review-fix.md
│   └── verify.md
├── skills/
│   ├── browser-verification/
│   ├── issue-management/     ← [EPIC]/[STORY]/[FE]/[BE] taxonomy
│   ├── product-brainstorm/
│   ├── product-design/       ← SLICE, Gherkin, pre-decided implementation
│   ├── ralph-planning/
│   ├── repair-domains/
│   └── review-fix-loop/
└── README.md
```

## License

MIT
