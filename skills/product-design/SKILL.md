---
name: product-design
description: "Create epics and user stories with Gherkin acceptance criteria, TDD tasks, FE/BE sub-issues, and pre-decided implementation contracts. Triggers when /super-ralph:design is invoked, or when the user mentions 'write epics', 'create user stories', 'product design', 'acceptance criteria', 'feature breakdown', 'e2e test scenarios', or wants to translate business goals into structured development artifacts. Produces implementation-ready stories that feed directly into /super-ralph:build-story without a separate plan step."
---

> **Config:** Project-specific values (paths, repo, team) are loaded from `.claude/super-ralph-config.md` (auto-generated on first use by any super-ralph command).

# Product Design -- Epics & Stories

## Overview

Translate product vision, business goals, and user feedback into structured epics and implementation-ready user stories. Every story includes Gherkin acceptance criteria, pre-decided implementation contracts, FE/BE sub-issues with TDD tasks, and shared type definitions. Stories are immediately buildable -- no separate planning step required.

**Announce at start:** "I'm using the product-design skill to create epics and implementation-ready stories with Gherkin AC, shared contracts, and TDD tasks."

**Core insight:** A story is not "designed" until a developer can start coding without asking questions. Pre-decided implementation (schema, service signatures, route contracts, component specs, i18n keys) eliminates ambiguity. Gherkin scenarios map 1:1 to test cases. The design phase does the thinking; the build phase does the typing.

## The Outside-In Pipeline

```
Vision / Goals / Feedback
    |  /super-ralph:design (single command, 6-phase SADD)
Epic (docs/epics/) + GitHub Issues
    |-- [STORY] -- Gherkin AC + Shared Contract + E2E skeleton
    |   |-- [BE] -- Schema + Service + Route + TDD tasks
    |   +-- [FE] -- Component + Mock data + i18n + TDD tasks
    |  /super-ralph:build-story #N (no plan step needed)
Implementation -> PR -> Merge -> Deploy
```

Each story is immediately buildable via `/super-ralph:build-story #N`. No intermediate `/plan` step exists.

## SLICE Decomposition

Before writing any story, apply the SLICE test to ensure it is the right size and shape.

| Letter | Check | Question | If No |
|--------|-------|----------|-------|
| **S** | System boundary | Does this cross BE+FE in one user action? | OK -- vertical slices should |
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

### Size Targets

- **Target:** S or M for every story
- **L:** Acceptable only for complex workflows with justification
- **XL:** Must split -- no exceptions
- **Epic target:** 8-15 stories per epic

## AI-Readable Documentation Standard

All design output must be optimized for AI consumption. Every sentence must be actionable or removable.

| Rule | Bad | Good |
|------|-----|------|
| Tables over prose | "The slice includes a backend service, a database migration, and a frontend component..." | Vertical Slice table with Layer/File/Action columns |
| Expected output | `Run: bun test` | `Run: bun test foo.test.ts` / `Expected: PASS -- 2 passed` |
| Concrete values | "appropriate error message" | `"Vendor is required"` |
| Pre-decided | "Choose between JWT and session auth" | "Use JWT Bearer. See `$BE_DIR/src/middleware/auth.ts`." |
| No filler | "This is important because..." | `**Required for:** Task N+1` |
| Exact paths | "in the schema file" | `$SCHEMA_FILE` -- append to `// --- [Feature] ----` |

### Template Order = TDD Loop

Within each sub-issue (FE or BE), tasks follow the TDD loop order:

1. Progress check (how to detect this task is done)
2. Files to create/modify (exact paths)
3. Write failing test (complete test code)
4. Expected fail output
5. Implement (complete implementation code)
6. Expected pass output
7. Commit message

## Pre-Decided Implementation

Every story with Size >= M must have these sections filled by the design agent after reading the codebase. The design agent reads existing code to match patterns, not invent new ones.

### Required Sections

**Schema Changes:**
```typescript
// $SCHEMA_FILE -- append to // --- [Feature] ----
export const tableName = pgTable("table_name", {
  id: text("id").primaryKey().$defaultFn(() => createId()),
  orgId: text("org_id").notNull().references(() => organizations.id),
  // ... exact columns with types and constraints
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
});
```

**Service Interface:**
```typescript
// $BE_SERVICES_DIR/feature-name.ts
export async function getResources(db: DB, orgId: string): Promise<Resource[]>
export async function createResource(db: DB, orgId: string, input: CreateInput): Promise<Resource>
export async function updateResource(db: DB, orgId: string, id: string, input: UpdateInput): Promise<Resource>
```

**Route Contract:**

| Method | Path | Auth | Request Body | Response 200 | Errors |
|--------|------|------|-------------|--------------|--------|
| GET | `/api/orgs/:orgId/resources` | Bearer | -- | `{ data: Resource[] }` | 401, 403 |
| POST | `/api/orgs/:orgId/resources` | Bearer | `CreateInput` | `{ data: Resource }` | 400, 401, 403 |

**Component Spec:**
```typescript
interface ResourceListProps {
  orgId: string;
  onSelect: (id: string) => void;
}
// State: loading, error, data (from useQuery)
// Events: onSelect, onDelete, onRefresh
// Error states: empty list, fetch error, delete confirmation
```

**Indicative Layout (ASCII art):**
```
┌─────────────────────────────────────────────┐
│ Resources                    [+ Create]      │
├─────────────────────────────────────────────┤
│ ┌─── DataTable ─────────────────────────┐   │
│ │ Name    │ Status  │ Created │ Actions  │   │
│ │─────────┼─────────┼─────────┼──────────│   │
│ │ Item 1  │ Active  │ Apr 16  │ [⋮]     │   │
│ │ Item 2  │ Draft   │ Apr 15  │ [⋮]     │   │
│ └───────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```
Show structure with box-drawing chars, `[...]` for interactive elements, labels for components. Include empty/error state variants when layout differs. Show responsive breakpoints if layout changes between mobile/desktop.

**i18n Keys:**
```typescript
// $I18N_BASE_FILE -- append to feature section
featureKey: {
  title: "Resources",           // zh-CN: "..."
  create: "Create Resource",    // zh-CN: "..."
  deleteConfirm: "Delete this resource?", // zh-CN: "..."
  empty: "No resources yet",    // zh-CN: "..."
}
```

**Patterns to Follow:**
```
// Reference existing implementations the dev should mirror
Service pattern: $BE_SERVICES_DIR/knowledge.ts
Route pattern: $BE_ROUTES_DIR/knowledge.ts
Page pattern: $FE_PAGES_DIR/knowledge/page.tsx
```

## Story Planner Sub-Agents (Phase 4)

During Phase 4 of the SADD process, the design agent dispatches sub-agents to flesh out each story. Each sub-agent operates independently and produces a specific section of the story.

### Sub-Agent: Schema Planner

**Receives:** Story user-story text, scope description, existing `$SCHEMA_FILE`
**Produces:** Exact Drizzle table definitions, relations, indexes, enums
**Rules:** Match existing naming conventions, use `createId()` for PKs, always include `orgId` for tenant isolation, add `createdAt`/`updatedAt`

### Sub-Agent: Service Planner

**Receives:** Schema output, existing service files in `$BE_SERVICES_DIR/` for pattern matching
**Produces:** Function signatures with full TypeScript types, error types, validation rules
**Rules:** Match existing service patterns (e.g., `knowledge.ts`), use `DB` type from drizzle, return typed results

### Sub-Agent: Route Planner

**Receives:** Service interface, existing route files
**Produces:** Route contract table, Zod validation schemas, error response map
**Rules:** Follow Hono patterns from existing routes, use `zValidator` middleware, standard error codes

### Sub-Agent: FE Planner

**Receives:** Route contract, existing page/component files
**Produces:** Component props interface, API client functions, indicative layout (ASCII art), i18n key-value pairs
**Rules:** Match existing Next.js app router patterns, use `useQuery`/`useMutation` hooks, follow existing i18n structure. Always produce an ASCII art layout showing spatial structure of the page using box-drawing characters (┌─┐│└─┘), `[...]` for interactive elements, and labels for component names. Include empty/error state variants when layout differs.

### Sub-Agent: Gherkin Writer

**Receives:** User story, component spec, route contract, error modes
**Produces:** Complete Gherkin feature file with Background, Scenarios (HAPPY/EDGE/SECURITY), Scenario Outlines
**Rules:** Max 6 scenarios per story, concrete test data, mandatory Background for auth context, category labels on every scenario

## Story-to-Build Mapping

Since stories are immediately buildable via `/super-ralph:build-story`, the following mapping shows how story elements translate to build execution:

| Story Element | Build Execution Element |
|---|---|
| Gherkin AC | E2E test skeleton in [STORY] issue |
| Pre-Decided Implementation | TDD tasks in [FE] and [BE] sub-issues |
| Priority (P0/P1/P2) | Wave assignment in Execution Plan |
| Dependencies (Story N) | Execution plan ordering |
| Shared Contract | Types file created in Task 0 of both FE and BE |
| Patterns to Follow | Reference files for the executing agent |

## Epic Structure

Every epic follows the template in `references/epic-template.md`.

### Required Sections

1. **PM Summary** -- What we're building, story priority matrix, success metrics, parking lot, PM decision points
2. **Business Context** -- Why this epic exists, what business problem it solves
3. **Success Metrics** -- Measurable outcomes (not output metrics like "feature shipped")
4. **Personas** -- Who benefits and how (reference product vision personas)
5. **Scope** -- What's in and explicitly what's out
6. **Stories** -- Ordered list using the story template with Gherkin AC
7. **Execution Plan** -- AI-hours, waves, critical path
8. **Dependencies** -- What must exist before this epic can start
9. **Risks** -- What could go wrong, with mitigation strategies

### Sizing Guidelines

| Epic Size | Stories | Suitable For |
|-----------|---------|--------------|
| Small | 2-4 | Single feature or improvement |
| Medium | 5-8 | Feature set or workflow |
| Large | 9-15 | Major capability or system |
| Too Large | 15+ | Split into multiple epics |

## Story Structure

Every story follows the template in `references/story-template.md`.

### Format

```markdown
### Story N: [Title]

**As a** [persona from product vision],
**I want to** [specific action],
**so that** [measurable outcome].

**Priority:** P0 (must-have) | P1 (should-have) | P2 (nice-to-have)
**Size:** S | M | L
**Depends on:** Story N-1 | None
```

### Acceptance Criteria (Gherkin Format)

Write every acceptance criterion as a Gherkin scenario. Each scenario becomes one test case. See `references/acceptance-criteria-guide.md` for the full guide.

```gherkin
Feature: [Story title]
  Background:
    Given I am logged in as [persona] with orgId "org-123"
    And [workspace/data precondition]

  Scenario: [HAPPY] Create a resource
    Given I am on the resources page
    When I click "Create" and fill in name "Test Resource"
    Then a resource named "Test Resource" appears in the list
    And its status is "Active"

  Scenario: [EDGE] Duplicate name rejected
    Given a resource named "Test Resource" already exists
    When I try to create another with name "Test Resource"
    Then I see error: "A resource with this name already exists"
```

### Sub-Issue Structure

Each story produces three GitHub issues:

1. **[STORY] #N** -- The parent with Gherkin AC, shared contract, and E2E skeleton
2. **[BE] #N** -- Backend sub-issue with schema, service, route, and TDD tasks
3. **[FE] #N** -- Frontend sub-issue with component, API client, i18n, and TDD tasks

## Writing Good Epics and Stories

### Deriving from Vision

Read the product vision document and extract:
- **Personas** -- Map story "As a..." to vision's target users
- **Capabilities** -- Map stories to vision's solution pillars
- **Principles** -- Ensure stories respect vision's core principles
- **Non-goals** -- Reject stories that conflict with stated non-goals

### Deriving from User Feedback

When input is user feedback or feature requests:
1. Extract the underlying need (not the proposed solution)
2. Map to existing personas or identify new ones
3. Write stories that solve the need, not implement the suggestion
4. Include the original feedback as context in the epic

### Deriving from Business Goals

When input is business metrics or OKRs:
1. Identify which user behaviors drive the metric
2. Write stories that enable those behaviors
3. Include the metric in the epic's success criteria
4. Avoid stories that game metrics without real value

## Autonomous Decision Pattern

When ambiguity arises during epic/story creation -- scope boundaries, persona priorities, acceptance criteria precision, implementation choices -- apply the autonomous decision pattern:

1. Dispatch research-agent for codebase patterns, market/competitor/UX references
2. Dispatch 1-2 sme-brainstormer agents to evaluate options
3. Pick the option with strongest evidence
4. Document the decision in the epic
5. Proceed -- NEVER wait for human input

## Output Location

1. Save epics to `docs/epics/YYYY-MM-DD-<slug>.md` (create the directory if needed)
2. Create `[EPIC]` issue on GitHub with `[STORY]` sub-issues (each with `[BE]` and `[FE]` sub-issues)
3. Add all issues to Project #$PROJECT_NUM board

## GitHub Issue Creation

After writing the epic markdown file, create GitHub Issues to track the work.

### Creating an [EPIC] Issue

```bash
gh issue create --title "[EPIC] <Epic title>" \
  --label "area/<backend|frontend|fullstack>" \
  --milestone "<active milestone>" \
  --body "$(cat <<'EOF'
## Goal
<Epic business context -- 1-2 sentences>

## Stories
- [ ] [STORY] Story 1
- [ ] [STORY] Story 2

## Epic Document
docs/epics/YYYY-MM-DD-<slug>.md
EOF
)" --repo $REPO
```

### Creating [STORY] Issues with [BE]/[FE] Sub-Issues

For each story, create three issues:

```bash
# 1. [STORY] parent
gh issue create --title "[STORY] <Story title>" \
  --label "vertical-slice,area/fullstack" \
  --body "$(cat <<'EOF'
**Parent:** #<epic-issue-number>

## User Story
**As a** <persona>, **I want** <action>, **So that** <outcome>.

## Acceptance Criteria (Gherkin)
<Full Gherkin feature from the story>

## Shared Contract
<TypeScript types shared between FE and BE>
EOF
)" --repo $REPO

# 2. [BE] sub-issue
gh issue create --title "[BE] <Story title> -- backend" \
  --label "area/backend" \
  --body "$(cat <<'EOF'
**Parent:** #<story-issue-number>

## Scope
Schema, service, route, route registration, tests

## TDD Tasks
### Task 1: Schema migration
**Progress check:** `grep -q "tableName" $SCHEMA_FILE`
**Files:** Modify `$SCHEMA_FILE`
...

### Task 2: Service layer
...

### Task 3: Route + registration
...
EOF
)" --repo $REPO

# 3. [FE] sub-issue
gh issue create --title "[FE] <Story title> -- frontend" \
  --label "area/frontend" \
  --body "$(cat <<'EOF'
**Parent:** #<story-issue-number>

## Scope
Component, API client, i18n, mock data, page

## PM Checkpoints
- [ ] CP1: Shell renders with mock data
- [ ] CP2: Happy path works with real API
- [ ] CP3: Edge cases and error states handled
- [ ] CP4: PM sign-off (i18n, accessibility, responsive)

## TDD Tasks
### Task 1: API client + types
...

### Task 2: Component with mock data
...

### Task 3: Page integration
...
EOF
)" --repo $REPO
```

**Rules:**
- [STORY] issues use `vertical-slice` label and `area/fullstack`
- [BE] and [FE] sub-issues reference their parent [STORY]
- Size is set via Project #9 field, not labels
- Sub-issues are NOT pre-assigned (devs self-assign)
- Add all issues to Project #9: `gh project item-add $PROJECT_NUM --owner $ORG --url <issue-url>`

## References

- `references/epic-template.md` -- Complete epic template with PM Summary and Execution Plan
- `references/story-template.md` -- Story template with Gherkin AC, shared contract, pre-decided implementation, and FE/BE sub-issue scope
- `references/acceptance-criteria-guide.md` -- Gherkin format guide with category labels, Gherkin-to-bun:test mapping, and coverage patterns
