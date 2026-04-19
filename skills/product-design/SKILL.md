---
name: product-design
description: "Create epics and user stories with Gherkin acceptance criteria, TDD tasks, FE/BE sub-issues, and pre-decided implementation contracts. Triggers when /super-ralph:design is invoked, or when the user mentions 'write epics', 'create user stories', 'product design', 'acceptance criteria', 'feature breakdown', 'e2e test scenarios', or wants to translate business goals into structured development artifacts. Produces implementation-ready stories that feed directly into /super-ralph:build-story without a separate plan step."
---

> **Config:** Project-specific values (paths, repo, team) are loaded from `.claude/super-ralph-config.md` (auto-generated on first use by any super-ralph command).

# Product Design — Epics & Stories

## Overview

Translate product vision, business goals, and user feedback into structured epics and implementation-ready user stories. Every story includes Gherkin acceptance criteria, pre-decided implementation contracts, FE/BE sub-issues with TDD tasks, and shared type definitions. Stories are immediately buildable — no separate planning step required.

**Announce at start:** "I'm using the product-design skill to create epics and implementation-ready stories with Gherkin AC, shared contracts, and TDD tasks."

**Core insight:** A story is not "designed" until a developer can start coding without asking questions. Pre-decided implementation (schema, service signatures, route contracts, component specs, i18n keys) eliminates ambiguity. Gherkin scenarios map 1:1 to test cases. The design phase does the thinking; the build phase does the typing.

## The Outside-In Pipeline

```
Vision / Goals / Feedback
    |  /super-ralph:design (single command, 6-phase SADD)
Epic (docs/epics/) + GitHub Issues
    |-- [STORY] -- User Journey + Gherkin AC + Shared Contract + E2E skeleton
    |   |-- [BE]  -- Schema + Service + Route + Test Plan + TDD tasks
    |   |-- [FE]  -- Component + Mock data + i18n + PM Checkpoints + TDD tasks
    |   +-- [INT] -- Mock swap + Gherkin E2E + /super-ralph:verify against staging
    |  /super-ralph:build-story #N (executes any of [BE], [FE], or [INT])
Implementation -> PR -> Merge -> Deploy -> Verify
```

Each story is immediately buildable via `/super-ralph:build-story #N`. No intermediate `/plan` step exists.

## The 6-Phase SADD Flow (at a glance)

| Phase | Purpose | Step range |
|-------|---------|------------|
| 0 | Load project config from `.claude/super-ralph-config.md` | Step 0 |
| 1 | Context: read product docs, explore codebase | Steps 1–3 |
| 2 | Research: 3 parallel sub-agents (research, product SME, tech SME) | Steps 4–5 |
| 3 | Epic definition: SLICE decomposition, write epic doc | Steps 6–8 |
| 4 | Story planning: parallel story-planner sub-agents → STORY/BE/FE/INT bodies | Step 9 |
| — | Post-plan: DAG, context-budget audit, wave assignment | Steps 10, 10.5, 11 |
| 5 | Issue creation on GitHub (skipped when `--local`) | Steps 12–14 |
| 6 | Design review via `/super-ralph:review-design`, then final report | Steps 15–17 |

**Full step-by-step procedure:** see `references/sadd-workflow.md`.

## SLICE Decomposition

Before writing any story, apply the SLICE test to ensure it is the right size and shape.

| Letter | Check | Question | If No |
|--------|-------|----------|-------|
| **S** | System boundary | Does this cross BE+FE in one user action? | OK — vertical slices should |
| **L** | Lifecycle stage | Does this cover only ONE CRUD operation? | Split by operation (create vs update vs delete) |
| **I** | Interaction type | Does this touch only ONE surface (list/detail/form/action)? | Split by surface (list page != detail page) |
| **C** | Configuration vs operation | Does this mix admin config with operator usage? | Split into config story + usage story |
| **E** | Error surface | Does this have <=3 error modes? | Split error handling into a separate story |

### Additional Splitting Rules

| Rule | Threshold | Action |
|------|-----------|--------|
| One schema migration = one story | If migration has >2 tables | Split tables into separate stories |
| One state machine = one story | If >4 states | Split into init + transitions stories |
| List != Detail | Always | Separate stories for list page and detail page |
| 45-minute Sonnet rule | If estimated >90 min AI-time | Must split |
| **Context budget split** | Combined build-time footprint > ~90k tok | Split regardless of AI-hours size — see `references/context-budget.md` |

### Size Targets

- **Target:** S or M for every story
- **L:** Acceptable only for complex workflows with justification
- **XL:** Must split — no exceptions
- **Epic target:** 8-15 stories per epic

## Execution Context Budget (headline)

Every execution-level issue (`[STORY]`, `[BE]`, `[FE]`, `[INT]`) will later be loaded by a `/super-ralph:build-story` subagent into a fresh 200,000-token context window. The design phase is the only place this can be enforced.

| Per-story combined body size (STORY + BE + FE + INT) | Verdict |
|------------------------------------------------------|---------|
| ≤ 360,000 chars (~90k tok) | OK |
| 360,000–480,000 chars (90k–120k tok) | Soft warn — consider trim |
| > 480,000 chars (>120k tok) | Hard cap exceeded — SPLIT the story |

Estimation heuristic: `1 token ≈ 4 chars` (measure with `wc -c`).

**Full rules, per-body caps, SPLIT_NEEDED protocol:** see `references/context-budget.md`.
**Post-plan audit procedure:** see `references/execution-planning.md` Step 10.5.

## Pre-Decided Implementation (every Size ≥ M story)

Every story with Size ≥ M must have these sections filled by the design agent after reading the codebase. The design agent reads existing code to match patterns, not invent new ones.

- **User Journey (narrative):** 3-5 sentences from the persona's POV describing the happy path.
- **Schema Changes:** exact Drizzle table definitions, relations, indexes, enums.
- **Service Interface:** function signatures with full TypeScript types, error types, validation rules.
- **Route Contract:** method / path / auth / request body / response 200 / error codes table.
- **Component Spec:** props interface, state, events, error states.
- **Indicative Layout (ASCII art):** box-drawing structure with `[...]` for interactive elements.
- **i18n Keys:** exact key-value pairs for both primary and secondary languages.
- **Patterns to Follow:** reference existing files by path (NEVER quote their content).

**Exact shapes and examples:** see `references/story-template.md`.

## Story Structure

Each story produces FOUR GitHub issues:

1. **[STORY] #N** — User Journey + Gherkin AC + shared contract + E2E skeleton
2. **[BE] #N** — Backend: schema, service, route, test plan, TDD tasks
3. **[FE] #N** — Frontend: component, mock data, i18n, PM checkpoints, TDD tasks
4. **[INT] #N** — Integration: mock swap, full Gherkin E2E, staging verify

**Story template:** `references/story-template.md`
**Gherkin AC format + category labels (HAPPY/EDGE/SECURITY):** `references/acceptance-criteria-guide.md`

## Epic Structure

Every epic follows the template in `references/epic-template.md`. Required sections:

1. PM Summary — what we're building, story priority matrix, success metrics, parking lot, PM decision points
2. Business Context — why this epic exists
3. Success Metrics — measurable outcomes (not output metrics)
4. Personas — who benefits and how (reference product vision personas)
5. Scope — what's in and explicitly what's out
6. Stories — ordered list with Gherkin AC
7. Execution Plan — AI-hours, waves, critical path
8. Dependencies — prerequisites
9. Risks — with mitigations

### Sizing Guidelines

| Epic Size | Stories | Suitable For |
|-----------|---------|--------------|
| Small | 2-4 | Single feature or improvement |
| Medium | 5-8 | Feature set or workflow |
| Large | 9-15 | Major capability or system |
| Too Large | 15+ | Split into multiple epics |

## Phase 4 Story-Planner Sub-Agents

During Phase 4, the orchestrator dispatches up to 4 parallel story-planner sub-agents. Each produces complete STORY/BE/FE/INT bodies under the Context Budget hard constraint, or emits a `story-N-split-needed.md` sentinel when the story is too big.

**Full dispatch contract, prompt body, output format, and SPLIT_NEEDED protocol:** see `references/story-planner-spec.md`.

## Autonomous Decision Pattern

When ambiguity arises during epic/story creation — scope boundaries, persona priorities, acceptance criteria precision, implementation choices — apply the autonomous decision pattern:

1. Dispatch research-agent for codebase patterns, market/competitor/UX references
2. Dispatch 1-2 sme-brainstormer agents to evaluate options
3. Pick the option with strongest evidence
4. Document the decision in the epic
5. Proceed — NEVER wait for human input

## AI-Readable Output Standard

All design output must be optimized for AI consumption. Every sentence must be actionable or removable.

| Rule | Bad | Good |
|------|-----|------|
| Tables over prose | "The slice includes a backend service, a database migration, and a frontend component…" | Vertical Slice table with Layer/File/Action columns |
| Expected output | `Run: bun test` | `Run: bun test foo.test.ts` / `Expected: PASS — 2 passed` |
| Concrete values | "appropriate error message" | `"Vendor is required"` |
| Pre-decided | "Choose between JWT and session auth" | "Use JWT Bearer. See `$BE_DIR/src/middleware/auth.ts`." |
| No filler | "This is important because…" | `**Required for:** Task N+1` |
| Exact paths | "in the schema file" | `$SCHEMA_FILE` — append to `// --- [Feature] ----` |

## Deriving Stories from Inputs

### From product vision

Read the product vision document and extract:
- **Personas** — map story "As a…" to vision's target users
- **Capabilities** — map stories to vision's solution pillars
- **Principles** — ensure stories respect vision's core principles
- **Non-goals** — reject stories that conflict with stated non-goals

### From user feedback

1. Extract the underlying need (not the proposed solution)
2. Map to existing personas or identify new ones
3. Write stories that solve the need, not implement the suggestion
4. Include the original feedback as context in the epic

### From business goals / OKRs

1. Identify which user behaviors drive the metric
2. Write stories that enable those behaviors
3. Include the metric in the epic's success criteria
4. Avoid stories that game metrics without real value

## Output Location

1. Save epics to `docs/epics/YYYY-MM-DD-<slug>.md` (create the directory if needed)
2. Create `[EPIC]` issue on GitHub with `[STORY]` sub-issues (each with `[BE]`, `[FE]`, and `[INT]` sub-issues) — see `../issue-management/SKILL.md` for issue-taxonomy and `../issue-management/references/gh-invocation-patterns.md` for the exact `gh` invocations
3. Add all issues to Project #$PROJECT_NUM board

## References

- `references/sadd-workflow.md` — Full 6-phase SADD procedure (Phases 0–6)
- `references/story-planner-spec.md` — Phase 4 sub-agent dispatch + output contract
- `references/execution-planning.md` — Post-Phase-4 DAG, context-budget audit, wave assignment
- `references/context-budget.md` — Execution context budget rules, SPLIT_NEEDED protocol, CTX gates
- `references/epic-template.md` — Complete epic template with PM Summary and Execution Plan
- `references/story-template.md` — Story template with Gherkin AC, shared contract, pre-decided implementation, and FE/BE sub-issue scope
- `references/acceptance-criteria-guide.md` — Gherkin format guide with category labels, Gherkin-to-bun:test mapping

### Sibling skills

- `../issue-management/SKILL.md` — Issue taxonomy and GitHub/project-board mechanics (used in Phase 5)
- `../design-review/SKILL.md` — Design review gate model (invoked in Phase 6 by `/super-ralph:review-design`)
