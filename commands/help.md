---
name: help
description: "Explain the super-ralph plugin, its philosophy, and usage"
allowed-tools: ["Read"]
---

# Super-Ralph Help

Display comprehensive help for the super-ralph plugin.

## Output the following help text:

```
# Super-Ralph v0.9.2 — Design-First Autonomous Development

Super-ralph is a project-agnostic, design-first autonomous development plugin.
/design is the single entry point: it produces implementation-ready GitHub issues
with embedded TDD tasks, Gherkin acceptance criteria, and FE/BE sub-issues for
concurrent development. Project-specific values are loaded from
.claude/super-ralph-config.md — auto-generated on first use, or run
/super-ralph:init to regenerate.

## Philosophy

1. Design-first: /design produces EVERYTHING — no separate /plan step needed.
2. Every story exits /design implementation-ready for a low-reasoning model.
3. FE and BE are built concurrently, integrated after PM sign-off.
4. Every decision is pre-made by the design agent (Opus). Execution agents copy code.
5. Documentation is AI-readable: tables over prose, decisions pre-made, concrete values.

## Release Lifecycle

  1. Requirements   — HoP confirms business requirements (human)
  2. Planning        — PM uses /design to create EPIC + stories + sub-issues
  3a. FE Dev         — Design Engineering iterates with PM/HoP
  3b. BE Dev         — Backend/AI built concurrently
  4. Integration    — FE + BE connected, e2e tests pass
  5. Testing        — Playwright e2e + manual verification
  6. Release        — /release seals and versions

## Branch Model

  feature branches ──PR──▶ staging (default branch, preview deploys)
                                │
                       /super-ralph:release
                                │
                                ▼
                           main (production: work.forth.ai)
                                │
                       /super-ralph:repair --hotfix
                                │
                           hotfix branch ──PR──▶ main ──cherry-pick──▶ staging

## Pipelines

  Design-first:  design → build-story → review-fix → verify → finalise
  Epic:          e2e (parallel build-story per story, then release)
  Ad-hoc:        plan → build → review-fix → verify → finalise
  Reactive:      repair → review-fix → verify → finalise
  Hotfix:        repair --hotfix → review-fix → verify → finalise on main
  Release:       release (QA → Codex review → merge staging→main → tag)
  Quality:       review-design (validate all issues against quality gates)
  Brainstorm:    brainstorm (research → CPO+CTO+CAIO → recommendations)

## Sub-Agent Architecture (SADD)

  /design uses Sub-Agent Driven Development (SADD):

  Phase 1 (Context):     Orchestrator reads docs + explores codebase
  Phase 2 (Research):    3 parallel agents — research + 2 SME brainstormers
  Phase 3 (Epic):        Orchestrator defines scope, SLICE decomposition
  Phase 4 (Stories):     1 Sonnet agent per story (max 4 parallel)
                         Each produces: STORY body + [BE] sub-issue + [FE] sub-issue
  Phase 5 (Issues):      Create GitHub issues, set Project #9 fields
  Phase 6 (Review):      /review-design validates all issues

  Run-state files (.claude/runs/design-*/) bridge context between phases.
  (Fallback to /tmp/super-ralph-design-*/ when .claude is not writable.)

## Commands

### /super-ralph:design <feature-or-goal> [--output PATH]

  THE PRIMARY COMMAND. Creates implementation-ready epics with:
  - [EPIC] issue with PM Summary, execution plan, dependency DAG
  - [STORY] issues with Gherkin AC, shared contract, e2e test skeleton
  - [BE] sub-issues with schema, service, route, TDD tasks
  - [FE] sub-issues with component, mock data, i18n, PM checkpoints, TDD tasks

  6-phase SADD flow: context → research → epic → story planning → issues → review.
  Stories are immediately buildable — no /plan step needed.

  Example:
    /super-ralph:design "Admin governance hardening — RBAC, user lifecycle, batch ops"
    /super-ralph:design "Finance AP invoices and payment workflow"

### /super-ralph:review-design <EPIC_NUMBER> [--fix] [--strict]

  Validate design quality before development starts. Checks 3 tiers of gates:

  PM Gates:        Persona specificity, measurable outcomes, AC coverage, Gherkin format
  Developer Gates: TDD tasks present, no pseudocode, exact paths, expected output
  Cross-Issue:     Shared file conflicts, dependency DAG, AC-to-test coverage

  Verdicts:
    READY       — 0 Critical findings, all PM decisions resolved
    CONDITIONAL — some stories can start, others blocked
    BLOCKED     — Critical findings prevent any /build-story execution

  --fix:    Auto-fix mechanical issues (missing i18n rows, placeholder removal)
  --strict: Treat Important findings as Critical (zero-tolerance mode)

  Example:
    /super-ralph:review-design 479
    /super-ralph:review-design 479 --fix
    /super-ralph:review-design 479 --strict

### /super-ralph:build-story <STORY> [--skip-verify] [--skip-finalise]

  Execute a story end-to-end: build → review-fix → verify → finalise.
  Skips plan phase when TDD tasks are embedded in the issue body (from /design).
  Auto-detects [FE] and [BE] sub-issues for concurrent execution.

  Input formats:
    /super-ralph:build-story #42                        # GitHub issue number
    /super-ralph:build-story docs/epics/gl.md#story-3   # Epic story reference
    /super-ralph:build-story "Add JWT auth endpoints"   # Description string

### /super-ralph:plan <feature> [--mode auto|standard|hybrid] [--story EPIC#STORY]

  Create implementation plans for AD-HOC work only. For epic-driven features,
  use /design instead.

  Use cases:
    - [FIX] hotfixes and bug fixes
    - [CHORE] infrastructure, DevOps, dependency upgrades
    - Exploratory spikes and prototypes
    - Small ad-hoc improvements by tech lead

  Example:
    /super-ralph:plan "Fix null pointer in policy cascade"
    /super-ralph:plan "Upgrade Drizzle ORM to 0.41"

### /super-ralph:brainstorm <topic> [--scope product|module|feature]

  Autonomous brainstorming with CPO/CTO/CAIO perspectives.
  Outputs ranked recommendations to docs/brainstorms/.

  Example:
    /super-ralph:brainstorm "Finance module usability"
    /super-ralph:brainstorm "What should we build next?" --scope product

### /super-ralph:build <plan-path> [--max-iterations N]

  Execute a plan autonomously via ralph-loop.

### /super-ralph:repair <#issue|description> [--hotfix] [--skip-verify]

  Domain-aware reactive fix with full pipeline.
  --hotfix branches from main for immediate production fixes.

### /super-ralph:review-fix [--max-iterations N] [--no-pr]

  Autonomously review, test, and fix code on a feature branch.
  6 review agents dispatched in parallel.

### /super-ralph:verify [--pr NUMBER] [--url URL]

  Browser-verify a PR against acceptance criteria using claude-in-chrome.

### /super-ralph:finalise [--pr NUMBER]

  Merge PR into staging, close issues, cleanup worktrees.

### /super-ralph:e2e EPIC_NUMBER [--max-parallel N] [--skip-release]

  Execute an entire epic end-to-end with wave-based parallelism.

### /super-ralph:release [--milestone NAME] [--tag VERSION]

  Promote staging → main with QA + Codex review gate.

### /super-ralph:status [--runs|--worktrees|--prs|--epics|--all]

  Dashboard view of runtime state: active ralph-loops, worktrees,
  open PRs on super-ralph/* branches, in-flight epics, stale runs.

  Example:
    /super-ralph:status
    /super-ralph:status --worktrees
    /super-ralph:status --prs

### /super-ralph:init

  Auto-detect project structure and generate .claude/super-ralph-config.md.

### /super-ralph:help

  Show this help text.

## Issue Taxonomy

  [EPIC]  — Feature epic, container for stories. Has PM Summary + execution plan.
  [STORY] — User story with Gherkin AC + shared contract. Has [FE] + [BE] subs.
  [FE]    — Frontend sub-issue: component, mock data, i18n, PM checkpoints, TDD tasks.
  [BE]    — Backend sub-issue: schema, service, route, TDD tasks.
  [FIX]   — Bug fix (use /plan or /repair).
  [CHORE] — Technical work (use /plan).
  [QA]    — Test verification task.

## SLICE Decomposition (used by /design)

  Before writing any story, /design applies SLICE:
    S — System boundary: BE+FE in one user action = 1 story
    L — Lifecycle: each CRUD operation = candidate story
    I — Interaction: list/detail/form/action = separate stories
    C — Configuration vs operation: admin ≠ operator
    E — Error surface: >3 error modes = split error story

  Target: S/M size. XL = must split. Aim 8-15 stories per epic.

## FE/BE Concurrent Development

  Each [STORY] produces 3 GitHub issues:

  [STORY] — Shared contract (TS types) + Gherkin AC + e2e skeleton
    ├── [BE] — Schema + service + route + TDD tasks
    └── [FE] — Component + mock data + i18n + TDD tasks + PM checkpoints

  FE iterates with PM/HoP using mock data (CP1→CP2→CP3→CP4 sign-off).
  BE is built concurrently.
  Integration swaps mocks for real API calls after both are ready.

## AI-Readable Documentation Standard

  | Rule                    | Bad                          | Good                              |
  |-------------------------|------------------------------|-----------------------------------|
  | Tables over prose       | "The slice includes..."      | Vertical Slice table              |
  | Expected output         | Run: bun test                | Run: bun test / Expected: PASS    |
  | Concrete values         | "appropriate error"          | "Vendor is required"              |
  | Decisions pre-made      | "Choose between..."          | "Use JWT. See auth.ts."           |
  | No filler               | "This is important..."       | Required for: Task N+1            |

## Gherkin Format (required for all stories)

  Feature → describe()
  Background → beforeEach()
  Scenario → test()
  Scenario Outline + Examples → test.each()

  Category labels: [HAPPY], [EDGE], [SECURITY], [PERF]
  Max 6 scenarios per story. Concrete data everywhere.

## Project Config

  Super-ralph reads .claude/super-ralph-config.md for project-specific values:
  repo, org, project board IDs, team members, codebase paths, production URLs.
  This file is auto-generated on first use, or run /super-ralph:init to regenerate.

## Plugin Dependencies

  Required:
    - ralph-loop plugin — Stop hook that drives the autonomous iteration loop
    - superpowers plugin — TDD, debugging, verification, parallel-agents, planning skills

  Optional (graceful degradation when missing):
    - pr-review-toolkit — code-reviewer, silent-failure-hunter, pr-test-analyzer,
      comment-analyzer, type-design-analyzer, code-simplifier agents for /review-fix
    - claude-in-chrome — browser automation for /verify

  See .claude-plugin/plugin.json for the dependency manifest.

## Run State

  Per-run state (context, progress, phase outputs) is kept in:
    .claude/runs/<kind>-<id>/       ← durable, survives reboots, preferred
    /tmp/super-ralph-<kind>-<id>/   ← legacy fallback when .claude isn't writable

  Resume detection reads both locations, preferring .claude/runs/.
  Use /super-ralph:status to inspect current runs.

## Prerequisites

  - .claude/super-ralph-config.md — project config (auto-generated on first use)
  - claude-in-chrome — browser automation for verify/release (optional)
  - codex CLI — AI code review for release promotion (optional)
```
