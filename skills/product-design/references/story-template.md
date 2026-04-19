# Story Template

> **Config:** Project-specific values (paths, repo, team) are loaded from `.claude/super-ralph-config.md` (auto-generated on first use).

## Brief Story Format (for `/super-ralph:design --brief`)

Brief stories capture the user journey and acceptance criteria outline without implementation detail. Used for backlog grooming. Promote to full via `/super-ralph:expand-story #<story>`.

```markdown
### Story N: [Action-oriented title]

**As a** [persona], **I want** [action], **So that** [outcome].

**Persona:** [X]   **Priority:** P0|P1|P2   **Size:** S|M|L   **Status:** PENDING
<!-- PR: -->
<!-- Branch: -->

#### Acceptance Criteria (Outline)

- `[HAPPY]` Given [precondition], when [action], then [observable outcome with concrete values].
- `[EDGE]` Given [boundary condition], when [action], then [graceful handling].
- `[SECURITY]` Given [unauthorized role], when [action], then [403 / denial message].

#### Notes (optional)

[Free-form context: open decisions, links to discussion, user feedback.]
```

**Rules:**
- Minimum 3 AC bullets: at least one `[HAPPY]`, one `[EDGE]`, one `[SECURITY]`.
- Each bullet is a single sentence combining Given/When/Then.
- Use concrete values ("3 items", "within 2 seconds"), not vague phrases.
- Use the specific persona from the vision, never generic "user".
- No implementation detail (no file paths, no code, no API shapes).
- The `#### Acceptance Criteria (Outline)` heading is the structural marker that distinguishes brief from full (full uses `#### Acceptance Criteria (Gherkin)`).

**Forbidden in brief (enforced by BRIEF-G2 gate):**
- `#### Shared Contract` subsection
- `#### Pre-Decided Implementation` subsection
- `#### [BE]`, `#### [FE]`, `#### [INT]` subsections

---

Use this template for individual user stories within an epic. Each story is independently buildable via `/super-ralph:build-story #N` -- no separate plan step required.

---

## Story Format

```markdown
### Story N: [Action-Oriented Title]

**As a** [specific persona from product vision -- not "user"],
**I want to** [concrete action -- verb phrase],
**so that** [measurable outcome -- not "I can do X" but "X is achieved"].

**Priority:** P0 (must-have for MVP) | P1 (should-have) | P2 (nice-to-have)
**Size:** S (1-2 TDD tasks) | M (3-5 tasks) | L (6-10 tasks)
**Depends on:** Story N-1 | None
```

## User Journey (narrative)

> Required. 3-5 sentences walking through the happy path from the persona's POV. Reference concrete UI elements. This is the demo script.

## Acceptance Criteria (Gherkin Format)

Write every acceptance criterion as a Gherkin scenario. Each scenario maps 1:1 to a test case. Use category labels on every scenario.

### Gherkin Structure

> **Required:** minimum 3 scenarios per story — at least one `[HAPPY]`, one `[EDGE]`, one `[SECURITY]`. Every scenario is automatable.

```gherkin
Feature: [Story title]
  Background:
    Given I am logged in as [persona] with orgId "org-123"
    And [workspace/data precondition]

  Scenario: [HAPPY] [description of happy path]
    Given [precondition with concrete data]
    When [single user action]
    Then [observable outcome with specific values]
    And [additional assertion]

  Scenario: [EDGE] [description of boundary condition]
    Given [boundary precondition -- empty state, max limit, duplicate]
    When [action that triggers the edge case]
    Then [graceful handling with specific message]

  Scenario: [SECURITY] [description of auth/authz case]
    Given I am logged in as [unauthorized persona]
    When [action requiring higher permission]
    Then I see: "You don't have permission to perform this action"
    And the resource is unchanged

  Scenario Outline: [HAPPY] [parameterized case description]
    Given [precondition with <variable>]
    When [action]
    Then [outcome with <expected>]
    Examples:
      | variable | expected |
      | val1     | result1  |
      | val2     | result2  |
      | val3     | result3  |
```

### Scenario Category Labels

| Label | When to Use | Required? |
|-------|------------|-----------|
| `[HAPPY]` | Primary success path | Yes, at least 1 |
| `[EDGE]` | Boundary conditions, empty states, limits | Yes, at least 1 |
| `[SECURITY]` | Authentication, authorization, role checks | Yes, for any story with role-based access |
| `[PERF]` | Performance requirements, latency targets | Only for perf-critical stories |

### Rules for Good Scenarios

1. **One behavior per scenario** -- If "And" joins two unrelated outcomes, split into two scenarios
2. **Max 6 scenarios per story** -- If you need more, the story is too large (SLICE it)
3. **Concrete data** -- "3 agents" not "some agents"; `"Vendor is required"` not "error message"
4. **API assertions in UI scenarios** -- When a UI action triggers an API call, assert both the UI feedback AND the API result
5. **Mandatory Background** -- Always include auth context (persona + orgId) in Background
6. **Category label on every Scenario** -- No unlabeled scenarios allowed

### Gherkin-to-bun:test Mapping

| Gherkin Element | bun:test Element | Example |
|----------------|-----------------|---------|
| `Feature:` | `describe()` | `describe("Create Resource", () => { ... })` |
| `Background:` | `beforeEach()` | `beforeEach(async () => { await login("operator") })` |
| `Scenario:` | `test()` | `test("[HAPPY] creates resource", async () => { ... })` |
| `Scenario Outline:` | `test.each()` | `test.each(examples)("[HAPPY] creates %s", ...)` |
| `Given` | Test setup | Variable initialization, fixture loading |
| `When` | Test action | API call, UI interaction |
| `Then` / `And` | `expect()` | `expect(response.status).toBe(201)` |

## Shared Contract

Define TypeScript types shared between FE and BE. These go into both the [STORY] issue body and are implemented as the first task in both [BE] and [FE] sub-issues.

```typescript
// Shared types for this story
export type ResourceName = {
  id: string;
  orgId: string;
  name: string;
  status: "active" | "archived";
  createdAt: string;
  updatedAt: string;
};

export type CreateResourceInput = Pick<ResourceName, "name">;
export type UpdateResourceInput = Partial<Pick<ResourceName, "name" | "status">>;
```

## Pre-Decided Implementation

Every story with Size >= M must include these sections. The design agent fills them by reading the codebase.

### Schema

```typescript
// $SCHEMA_FILE -- append to // --- [Feature] ----
export const resources = pgTable("resources", {
  id: text("id").primaryKey().$defaultFn(() => createId()),
  orgId: text("org_id").notNull().references(() => organizations.id),
  name: text("name").notNull(),
  status: text("status", { enum: ["active", "archived"] }).notNull().default("active"),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
});
```

### Service Interface

```typescript
// $BE_SERVICES_DIR/resources.ts
export async function listResources(db: DB, orgId: string): Promise<Resource[]>
export async function getResource(db: DB, orgId: string, id: string): Promise<Resource | null>
export async function createResource(db: DB, orgId: string, input: CreateResourceInput): Promise<Resource>
export async function updateResource(db: DB, orgId: string, id: string, input: UpdateResourceInput): Promise<Resource>
export async function deleteResource(db: DB, orgId: string, id: string): Promise<void>
```

### Route Contract

| Method | Path | Auth | Request Body | Response 200 | Errors |
|--------|------|------|-------------|--------------|--------|
| GET | `/api/orgs/:orgId/resources` | Bearer | -- | `{ data: Resource[] }` | 401, 403 |
| GET | `/api/orgs/:orgId/resources/:id` | Bearer | -- | `{ data: Resource }` | 401, 403, 404 |
| POST | `/api/orgs/:orgId/resources` | Bearer | `CreateResourceInput` | `{ data: Resource }` | 400, 401, 403 |
| PATCH | `/api/orgs/:orgId/resources/:id` | Bearer | `UpdateResourceInput` | `{ data: Resource }` | 400, 401, 403, 404 |
| DELETE | `/api/orgs/:orgId/resources/:id` | Bearer | -- | `204 No Content` | 401, 403, 404 |

### Component Spec

```typescript
interface ResourceListProps {
  orgId: string;
  onSelect: (id: string) => void;
}
// State: loading (skeleton), error (error banner), data (table rows)
// Events: onSelect (row click), onDelete (action menu), onRefresh (toolbar button)
// Error states: empty list (empty state CTA), fetch error (retry banner), delete confirmation (dialog)
```

### i18n Keys

```typescript
// $I18N_BASE_FILE
resources: {
  title: "Resources",                    // zh-CN: "..."
  create: "Create Resource",             // zh-CN: "..."
  deleteConfirm: "Delete this resource?", // zh-CN: "..."
  empty: "No resources yet",             // zh-CN: "..."
  nameRequired: "Name is required",      // zh-CN: "..."
  duplicateName: "A resource with this name already exists", // zh-CN: "..."
}
```

### Patterns to Follow

```
Service pattern: $BE_SERVICES_DIR/knowledge.ts
Route pattern:   $BE_ROUTES_DIR/knowledge.ts
Page pattern:    $FE_PAGES_DIR/knowledge/page.tsx
API client:      $API_CLIENT_DIR/knowledge.ts
i18n pattern:    $I18N_BASE_FILE (knowledge section)
```

## FE Sub-Issue Scope

The [FE] sub-issue covers everything the frontend developer needs to build.

### Included Work

- API client functions (typed fetch wrappers)
- React components (matching Component Spec)
- Page integration (Next.js app router)
- i18n keys (en + zh-CN)
- Mock data for development/testing
- Indicative layout (ASCII art)

### Indicative Layout

Every [FE] sub-issue must include an ASCII art layout showing the visual structure of the page or component. This gives the FE developer a spatial reference for how elements are arranged, without requiring a Figma mockup.

#### Rules

1. **Show structure, not styling** -- boxes for regions, labels for components, `[...]` for interactive elements
2. **Mark responsive breakpoints** if layout changes between mobile/tablet/desktop
3. **Label every region** with the component name or semantic purpose
4. **Show state variants** if layout differs between states (e.g., empty vs populated)

#### Format

```
┌─────────────────────────────────────────────┐
│ PageTitle                    [+ Create btn]  │
├─────────────────────────────────────────────┤
│ ┌─── Filters ───────────────────────────┐   │
│ │ [Status ▼]  [Search...]  [Date range] │   │
│ └───────────────────────────────────────┘   │
│                                             │
│ ┌─── DataTable ─────────────────────────┐   │
│ │ Name    │ Status  │ Amount │ Actions  │   │
│ │─────────┼─────────┼────────┼──────────│   │
│ │ Row 1   │ Active  │ $500   │ [⋮]     │   │
│ │ Row 2   │ Draft   │ $1200  │ [⋮]     │   │
│ └───────────────────────────────────────┘   │
│                                             │
│ ┌─── Pagination ────────────────────────┐   │
│ │ ◀ 1 [2] 3 ... 10 ▶   Showing 20/195  │   │
│ └───────────────────────────────────────┘   │
└─────────────────────────────────────────────┘

Empty state:
┌─────────────────────────────────────────────┐
│ PageTitle                    [+ Create btn]  │
├─────────────────────────────────────────────┤
│                                             │
│         ┌─── EmptyState ──────────┐         │
│         │   (illustration)        │         │
│         │   "No resources yet"    │         │
│         │   [Create your first]   │         │
│         └─────────────────────────┘         │
│                                             │
└─────────────────────────────────────────────┘
```

#### When to Show Multiple Layouts

- **List + Detail split**: Show both the list view and the detail/edit panel
- **Modal/Dialog flows**: Show the triggering page and the modal overlay
- **Responsive**: Show desktop (≥1024px) and mobile (<768px) if layout differs substantially
- **State variants**: Show populated, empty, loading skeleton, and error states when they have different structures

### PM Checkpoints

| Checkpoint | Gate | What PM Verifies |
|-----------|------|-------------------|
| CP1 | Shell | Component renders with mock data, layout matches spec |
| CP2 | Happy path | CRUD operations work with real API |
| CP3 | Edges | Error states, empty states, loading states all handled |
| CP4 | Sign-off | i18n complete, responsive layout, accessibility basics |

### TDD Tasks (Example)

```markdown
### Task 1: API client + types
**Progress check:** `test -f $API_CLIENT_DIR/resources.ts`
**Files:** Create `$API_CLIENT_DIR/resources.ts`, Test `$API_CLIENT_DIR/resources.test.ts`
1. Write test: fetch mock returns typed response
2. Implement: API client with typed fetch wrappers
3. Commit: "feat(web): add resources API client"

### Task 2: Resource list component
**Progress check:** `test -f $FE_COMPONENTS_DIR/resources/resource-list.tsx`
**Files:** Create component + test
1. Write test: renders mock resources in table
2. Implement: ResourceList component with loading/error/data states
3. Commit: "feat(web): add ResourceList component"

### Task 3: Page integration
**Progress check:** `test -f $FE_PAGES_DIR/resources/page.tsx`
**Files:** Create page + route
1. Write test: page renders ResourceList with real data hook
2. Implement: Page with useQuery, loading skeleton, error boundary
3. Commit: "feat(web): add resources page"
```

## BE Sub-Issue Scope

The [BE] sub-issue covers everything the backend developer needs to build.

### Included Work

- Schema migration (Drizzle table definition)
- Service layer (business logic functions)
- Route handlers (Hono routes with Zod validation)
- Route registration (append to `$ROUTE_REG_FILE`)
- Tests (service + route integration tests)

### TDD Tasks (Example)

```markdown
### Task 1: Schema migration
**Progress check:** `grep -q "resources" $SCHEMA_FILE`
**Files:** Modify `$SCHEMA_FILE`
1. Write test: import table, assert columns exist
2. Implement: Add pgTable definition to schema.ts
3. Commit: "feat(agents): add resources schema"

### Task 2: Service layer
**Progress check:** `test -f $BE_SERVICES_DIR/resources.ts`
**Files:** Create `$BE_SERVICES_DIR/resources.ts` + test
1. Write test: createResource returns typed result
2. Implement: CRUD service functions with error handling
3. Commit: "feat(agents): add resources service"

### Task 3: Route handlers + registration
**Progress check:** `test -f $BE_ROUTES_DIR/resources.ts`
**Files:** Create route file, modify `$ROUTE_REG_FILE`
1. Write test: POST /api/orgs/:orgId/resources returns 201
2. Implement: Hono routes with zValidator, register in index.ts
3. Commit: "feat(agents): add resources routes"
```

## Story Sizing Guide

| Size | Scenarios | TDD Tasks (BE+FE) | AI-Hours | Example |
|------|-----------|-------------------|----------|---------|
| **S** | 2-3 | 2-4 | 0.5-1h | Add a column, simple validation, toggle |
| **M** | 4-5 | 4-8 | 1-3h | CRUD for a resource, form with validation |
| **L** | 5-6 | 8-12 | 3-6h | Multi-step workflow, complex state management |
| **XL** | 6+ | 12+ | 6h+ | **Must split -- apply SLICE decomposition** |

## SLICE Decomposition Checklist

Before finalizing any story, verify it passes SLICE:

- [ ] **S -- System boundary:** Crosses BE+FE in one user action? (OK for vertical slices)
- [ ] **L -- Lifecycle:** Only ONE CRUD operation? (create != update != delete)
- [ ] **I -- Interaction:** Only ONE surface? (list != detail != form != action dialog)
- [ ] **C -- Config vs operation:** Admin config separate from operator usage?
- [ ] **E -- Error surface:** <=3 error modes? (Otherwise split error handling out)

Common split patterns when SLICE fails:
- **By CRUD:** "Create resource" and "Edit resource" are separate stories
- **By surface:** "Resource list page" and "Resource detail page" are separate stories
- **By persona:** "Operator manages resources" and "Admin configures resource policies" are separate
- **By error complexity:** Happy path is one story, complex error handling is another
