# Issue Body Templates

> **Config:** Project-specific values (paths, repo, team) are loaded from `.claude/super-ralph-config.md` (auto-generated on first use).

Copy-paste-ready issue body templates for each issue type in the monorepo.

## [EPIC] -- Feature Epic

Use for feature container issues that group sub-issues. Attach to a Milestone.

````markdown
## PM Summary

### What we're building
[2-3 sentences describing the feature objective and user value]

### Story Priority
| # | Story | User Value | Size | Can ship without? |
|---|-------|------------|------|--------------------|
| 1 | [STORY] Title | [value] | M | No |
| 2 | [STORY] Title | [value] | S | Yes |

### Success Metrics
| Metric | Current | Target | How to Measure |
|--------|---------|--------|----------------|
| [metric] | [baseline] | [goal] | [method] |

### Not Building
- [exclusion + why]

### PM Decision Points
- [ ] [decision to resolve before dev]

## Stories
- [ ] #N1 [STORY] Title (P0, M) — [FE] #N2, [BE] #N3
- [ ] #N4 [STORY] Title (P1, S) — [FE] #N5, [BE] #N6

## Execution Plan

### AI-Hours
| Story | Size | AI-Hours | Depends On |
|-------|------|----------|------------|
| #N1 Title | M | 2h | — |
| #N4 Title | S | 0.75h | #N1 |
**Total:** Xh

### Waves
| Wave | Stories | Prereqs | Calendar |
|------|---------|---------|----------|
| 0 | #N1 | — | Day 1-2 |
| 1 | #N4 | #N1 BE | Day 2-3 |

## Notes
- **Dependencies:** [What must exist before this epic can start]
- **Risks:** [What could go wrong, with mitigation]
````

### Example

````markdown
## PM Summary

### What we're building
Build the real-time case streaming infrastructure so that case detail and dashboard pages update live without polling. This eliminates the current 30-second stale data window that frustrates ops managers.

### Story Priority
| # | Story | User Value | Size | Can ship without? |
|---|-------|------------|------|--------------------|
| 1 | SSE streaming for cases | Core real-time updates | M | No |
| 2 | SSE streaming for dashboard | Live aggregate counts | M | No |
| 3 | Reconnection handling | Resilient UX on flaky networks | S | Yes |

### Success Metrics
| Metric | Current | Target | How to Measure |
|--------|---------|--------|----------------|
| Data freshness | 30s | <1s | Time from DB write to UI update |
| Page reloads/session | 4.2 | <1 | Analytics event tracking |

### Not Building
- WebSocket support — SSE is simpler and sufficient for our unidirectional updates
- Offline queue — deferred to v1.3

### PM Decision Points
- [ ] Max concurrent SSE connections per tenant (suggest 50)

## Stories
- [ ] #101 [STORY] SSE streaming for individual cases (P0, M) — [FE] #102, [BE] #103
- [ ] #104 [STORY] SSE streaming for dashboard aggregates (P0, M) — [FE] #105, [BE] #106
- [ ] #107 [STORY] Reconnection with exponential backoff (P1, S) — [FE] #108, [BE] #109

## Execution Plan

### AI-Hours
| Story | Size | AI-Hours | Depends On |
|-------|------|----------|------------|
| #101 SSE for cases | M | 2h | — |
| #104 SSE for dashboard | M | 2h | — |
| #107 Reconnection | S | 0.75h | #101, #104 |
**Total:** 4.75h

### Waves
| Wave | Stories | Prereqs | Calendar |
|------|---------|---------|----------|
| 0 | #101, #104 | — | Day 1-2 |
| 1 | #107 | #101 BE, #104 BE | Day 2-3 |

## Notes
- **Dependencies:** Case CRUD API must be deployed
- **Risks:** Hono SSE adapter compatibility with Bun runtime — verify in Story #101
````

## [STORY] -- User Story

Use for user-facing features that belong to an [EPIC]. Written from a persona's perspective. Each STORY gets [FE] and [BE] sub-issues for concurrent development.

````markdown
**Parent:** #[EPIC_NUMBER]

## User Story
**As a** [specific persona — not "user"],
**I want** [concrete capability],
**So that** [measurable business value].
**Priority:** P0/P1/P2 | **Size:** S/M/L

## User Journey (narrative)

> Required. 3-5 sentences describing the happy path from the persona's POV: trigger → steps → outcome. Reference concrete UI elements and data. This is the "demo script" for the story.

[Admin opens Settings → General tab, sees three cards (Workspace, Business Hours, Cost Benchmarks) with current values. Admin changes timezone from UTC to Asia/Singapore in the Workspace card, clicks Save, sees a green "Saved" toast. Admin reloads the page; timezone is still Asia/Singapore. Downstream: Cost Savings Tracker now uses Singapore hours for ROI calculations.]

## Acceptance Criteria (Gherkin)

> Required. Minimum 3 scenarios: at least one `[HAPPY]`, one `[EDGE]`, one `[SECURITY]`. Use concrete data. Every scenario must be automatable as an e2e test.

```gherkin
Feature: [Story title]
  Background:
    Given I am logged in as [persona] with tenantId "tenant-123"
    And [workspace/data precondition]

  Scenario: [HAPPY] Primary flow
    Given [precondition with specific data]
    When [single user action]
    Then [verifiable outcome]
    And [additional assertion]

  Scenario: [EDGE] Boundary condition
    Given [boundary precondition — empty state, max limit, duplicate]
    When [action at boundary]
    Then [graceful handling with specific message]

  Scenario: [SECURITY] Unauthorized access
    Given I am logged in as [unauthorized persona]
    When [action requiring higher permission]
    Then I see: "You don't have permission to perform this action"
    And the resource is unchanged
```

## Shared Contract
```typescript
// Shared types used by FE, BE, and INT
export type ResourceName = {
  id: string;
  // ... fields
};
```

## Sub-Issues
- [BE] #N — Backend implementation
- [FE] #N — Frontend implementation
- [INT] #N — Integration, E2E, and staging verification

## E2E Test Skeleton
```typescript
describe("[Story title]", () => {
  test("[HAPPY] primary flow", async () => {
    // arrange
    // act
    // assert
  });

  test("[EDGE] boundary condition", async () => { ... });
  test("[SECURITY] unauthorized access", async () => { ... });
});
```
````

### Example

````markdown
**Parent:** #241

## User Story
**As a** sales manager,
**I want** to view a kanban board of my team's pipeline,
**So that** I can see deal distribution across stages at a glance.
**Priority:** P0 | **Size:** M

## User Journey (narrative)
Sales manager opens the Pipeline page and sees three columns (Qualification, Proposal, Negotiation) each populated with deal cards showing title, value, and a `[⋮]` action menu. She filters by stage "Proposal", sees only those deals, and clicks a deal card to open the detail drawer. When the pipeline is empty, she sees a "Create your first deal" prompt with a call-to-action button.

## Acceptance Criteria (Gherkin)
```gherkin
Feature: Pipeline kanban board
  Background:
    Given I am logged in as sales manager

  Scenario: [HAPPY] Board renders with stage columns
    Given I have deals in stages "Qualification", "Proposal", "Negotiation"
    When I navigate to the pipeline page
    Then I see 3 columns with the correct deals in each

  Scenario: [EDGE] Empty pipeline
    Given I have no deals
    When I navigate to the pipeline page
    Then I see empty columns with a "Create your first deal" prompt

  Scenario: [EDGE] Stage with many deals
    Given I have 50 deals in "Qualification"
    When I scroll within the column
    Then deals paginate smoothly without full page reload

  Scenario: [SECURITY] Non-sales user cannot access
    Given I am logged in as a finance user
    When I navigate to the pipeline page
    Then I see a 403 forbidden page
```

## Shared Contract
```typescript
export type PipelineStage = {
  id: string;
  name: string;
  order: number;
  dealCount: number;
};

export type Deal = {
  id: string;
  title: string;
  value: number;
  stageId: string;
  assigneeId: string;
  createdAt: string;
};
```

## Sub-Issues
- [BE] #242 — Backend: pipeline API endpoints
- [FE] #243 — Frontend: kanban board UI
- [INT] #244 — Integration: real data, e2e, staging verify

## E2E Test Skeleton
```typescript
describe("Pipeline kanban board", () => {
  test("[HAPPY] board renders with stage columns", async () => {
    // seed 3 stages with deals
    // GET /api/pipeline/stages
    // assert 3 stages returned with correct deals
  });

  test("[EDGE] empty pipeline shows prompt", async () => {
    // no deals seeded
    // GET /api/pipeline/stages
    // assert empty stages returned
  });
});
```
````

## [BE] -- Backend Sub-Issue

Use for backend implementation tasks within a [STORY]. Created by /design for concurrent BE/AI development.

````markdown
**Parent:** #[STORY_NUMBER]

## Shared Contract
See parent #[STORY_NUMBER] — Shared Contract section.

## Schema
```typescript
// $SCHEMA_FILE — append to // ─── [Feature] ────
export const tableName = pgTable("table_name", {
  id: text("id").primaryKey().$defaultFn(() => createId()),
  orgId: text("org_id").notNull().references(() => organizations.id),
  // ... fields
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});
```

## Service Interface
```typescript
// $BE_SERVICES_DIR/[feature].ts
export async function getResources(db: DB, orgId: string): Promise<Resource[]>
export async function createResource(db: DB, orgId: string, input: CreateInput): Promise<Resource>
export async function updateResource(db: DB, orgId: string, id: string, input: UpdateInput): Promise<Resource>
export async function deleteResource(db: DB, orgId: string, id: string): Promise<void>
```

## Route Contract
| Method | Path | Auth | Request | Response | Errors |
|--------|------|------|---------|----------|--------|
| GET | `/api/resources` | Bearer | query: `?limit&offset` | `Resource[]` | 401, 403 |
| POST | `/api/resources` | Bearer | body: `CreateInput` | `Resource` | 400, 401, 403 |
| PUT | `/api/resources/:id` | Bearer | body: `UpdateInput` | `Resource` | 400, 401, 403, 404 |
| DELETE | `/api/resources/:id` | Bearer | — | `204` | 401, 403, 404 |

## Test Plan

> Required. Describes the layered test strategy for this BE sub-issue. Drives the TDD Tasks below.

| Layer | Scope | Tool | File |
|-------|-------|------|------|
| Unit | Service functions (pure business logic, no DB) | `bun:test` | `$BE_SERVICES_DIR/__tests__/[feature].test.ts` |
| Integration | Route handlers + DB + auth middleware | `bun:test` + testcontainers or real test DB | `$BE_ROUTES_DIR/__tests__/[feature].integration.test.ts` |
| Contract | Zod schema validates request/response bodies | `bun:test` | inline in route test |

### Coverage Requirements
- Every service function has at least one unit test (happy + 1 error path)
- Every route handler has at least one integration test covering: 200 success, 400 validation, 401 unauthenticated, 403 forbidden, 404 not found (where applicable)
- Every Gherkin `[SECURITY]` scenario from the parent [STORY] maps to an integration test

## TDD Tasks

> **MANDATORY.** Every task below MUST include:
> - A `**Progress check:**` shell command that returns exit 0 when the task is done
> - Complete test code (copy-pasteable, no `// TODO`, no `...`, no `implement X here`)
> - Exact run command (`$RUNTIME test ...`)
> - Expected output on both FAIL and PASS runs (counts, pass/fail labels)
> - Exact implementation code (no placeholders)
> - Git commit command with commit message
>
> A reviewer will BLOCK this issue if any of the above is missing.

### Task 0: E2E Tests (outer RED)
**Progress check:** `test -f $BE_DIR/tests/e2e/[slug].test.ts`
**File:** Create `$BE_DIR/tests/e2e/[slug].test.ts`
```typescript
import { describe, test, expect } from "bun:test";

describe("[Feature] E2E", () => {
  test("[HAPPY] creates and retrieves resource", async () => {
    // POST /api/resources -> 201
    // GET /api/resources -> includes created resource
  });

  test("[EDGE] rejects invalid input", async () => {
    // POST /api/resources with bad data -> 400
  });

  test("[SECURITY] rejects unauthenticated request", async () => {
    // GET /api/resources without token -> 401
  });
});
```
Run: `$RUNTIME test $BE_DIR/tests/e2e/[slug].test.ts`
Expected: FAIL (endpoints don't exist yet)
Commit: `git commit -m "test: add e2e for [feature] (outer red)"`

### Task 1: Schema & Migration
**Progress check:** `grep -q "export const tableName" $SCHEMA_FILE`
Step 1: Write test
```typescript
// $BE_SERVICES_DIR/[feature].test.ts
test("getResources returns empty array for new org", async () => {
  const result = await getResources(db, testOrgId);
  expect(result).toEqual([]);
});
```
Run / Expected: FAIL (table doesn't exist)
Step 2: Implement schema + migration
Run / Expected: PASS
Commit: `git commit -m "feat: add [feature] schema"`

### Task 2: Service Layer
**Progress check:** `grep -q "export async function getResources" $BE_SERVICES_DIR/[feature].ts`
Step 1: Write test [code]
Run / Expected: FAIL
Step 2: Implement [code]
Run / Expected: PASS
Commit: `git commit -m "feat: add [feature] service"`

### Task 3: Route Layer
**Progress check:** `grep -q "[feature]" $ROUTE_REG_FILE`
Step 1: Write test [code]
Run / Expected: FAIL
Step 2: Implement routes + register
Run / Expected: PASS
Commit: `git commit -m "feat: add [feature] routes"`

### Task 4: E2E Green
Run: `$RUNTIME test $BE_DIR/tests/e2e/[slug].test.ts`
Expected: PASS (all e2e tests pass now)
Commit: `git commit -m "feat: [feature] e2e green"`

## Completion Criteria
- [ ] `$BE_TEST_CMD` exits 0
- [ ] `$RUNTIME run build` exits 0
- [ ] All route contracts return documented status codes (asserted in integration tests)
- [ ] Every Gherkin [SECURITY] scenario in parent [STORY] has a corresponding integration test
- [ ] PR body includes `Closes #[BE_NUMBER]`
- [ ] [feature-specific check]
````

### Example

````markdown
**Parent:** #241

## Shared Contract
See parent #241 — Shared Contract section.

## Schema
```typescript
// $SCHEMA_FILE — append to // ─── Sales/CRM ────
export const pipelineStages = pgTable("pipeline_stages", {
  id: text("id").primaryKey().$defaultFn(() => createId()),
  orgId: text("org_id").notNull().references(() => organizations.id),
  name: text("name").notNull(),
  order: integer("order").notNull(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});
```

## Service Interface
```typescript
export async function getStages(db: DB, orgId: string): Promise<PipelineStage[]>
export async function getDeals(db: DB, orgId: string, stageId?: string): Promise<Deal[]>
```

## Route Contract
| Method | Path | Auth | Request | Response | Errors |
|--------|------|------|---------|----------|--------|
| GET | `/api/pipeline/stages` | Bearer | — | `PipelineStage[]` | 401, 403 |
| GET | `/api/pipeline/deals` | Bearer | query: `?stageId` | `Deal[]` | 401, 403 |

## TDD Tasks

### Task 0: E2E Tests (outer RED)
**Progress check:** `test -f $BE_DIR/tests/e2e/pipeline.test.ts`
...

### Task 1: Schema
**Progress check:** `grep -q "pipelineStages" $SCHEMA_FILE`
...

## Completion Criteria
- [ ] `$BE_TEST_CMD` exits 0
- [ ] `$RUNTIME run build` exits 0
- [ ] GET /api/pipeline/stages returns stages ordered by `order` field
````

## [FE] -- Frontend Sub-Issue

Use for frontend implementation tasks within a [STORY]. Created by /design for concurrent FE development.

````markdown
**Parent:** #[STORY_NUMBER]

## Shared Contract
See parent #[STORY_NUMBER] — Shared Contract section.

## Mock Data
```typescript
// $FE_DIR/src/mocks/[feature].mock.ts
import type { Resource } from "@/lib/types";

export const MOCK_RESOURCE: Resource = {
  id: "mock-1",
  // ... fields with realistic sample data
};

export const MOCK_RESOURCE_LIST: Resource[] = [
  MOCK_RESOURCE,
  { id: "mock-2", /* ... */ },
  { id: "mock-3", /* ... */ },
];

export const MOCK_EMPTY: Resource[] = [];
```

## Component Spec
```typescript
interface ComponentProps {
  resources: Resource[];
  onSelect?: (id: string) => void;
  onAction?: (id: string, action: string) => void;
}

// State: loading | empty | populated | error
// Events: onSelect, onAction, onRefresh
// Error states: network error, empty state, permission denied
```

## API Client
```typescript
// $API_CLIENT_DIR/[feature].ts
export async function getResources(): Promise<Resource[]>
export async function createResource(input: CreateInput): Promise<Resource>
export async function updateResource(id: string, input: UpdateInput): Promise<Resource>
export async function deleteResource(id: string): Promise<void>
```

## i18n Keys
```typescript
// en.ts
featureKey: {
  title: "Feature Title",
  description: "Feature description",
  empty: "No items yet",
  create: "Create new",
  actions: {
    edit: "Edit",
    delete: "Delete",
    confirm: "Are you sure?",
  },
  errors: {
    loadFailed: "Failed to load items",
    saveFailed: "Failed to save",
  },
}

// zh-CN.ts
featureKey: {
  title: "功能标题",
  description: "功能描述",
  empty: "暂无项目",
  create: "新建",
  actions: {
    edit: "编辑",
    delete: "删除",
    confirm: "确定吗？",
  },
  errors: {
    loadFailed: "加载失败",
    saveFailed: "保存失败",
  },
}
```

## Indicative Layout
ASCII art showing the spatial structure of the page/component. Shows structure, not styling.
Use box-drawing characters (┌─┐│└─┘), `[...]` for interactive elements, labels for component names.
Show state variants (populated, empty, error) when layouts differ.

```
┌─────────────────────────────────────────────┐
│ PageTitle                    [+ Action btn]  │
├─────────────────────────────────────────────┤
│ ┌─── ComponentA ────────────────────────┐   │
│ │ [interactive element]  [control]      │   │
│ └───────────────────────────────────────┘   │
│ ┌─── ComponentB ────────────────────────┐   │
│ │ Content area with data                │   │
│ └───────────────────────────────────────┘   │
└─────────────────────────────────────────────┘

Empty state:
┌─────────────────────────────────────────────┐
│ PageTitle                    [+ Action btn]  │
├─────────────────────────────────────────────┤
│         ┌─── EmptyState ──────────┐         │
│         │   "No items yet"        │         │
│         │   [Create your first]   │         │
│         └─────────────────────────┘         │
└─────────────────────────────────────────────┘
```

## PM Checkpoints
- [ ] **CP1 — Shell**: Page renders with mock data, layout matches indicative layout
- [ ] **CP2 — Happy Path**: Primary flow works with mocks
- [ ] **CP3 — Edge Cases**: Empty, error, loading states visible
- [ ] **CP4 — PM Sign-off**: PM confirms layout/copy before integration

## TDD Tasks

### Task 0: E2E Tests (outer RED)
**Progress check:** `test -f $FE_DIR/tests/e2e/[slug].test.ts`
**File:** Create `$FE_DIR/tests/e2e/[slug].test.ts`
```typescript
import { describe, test, expect } from "bun:test";

describe("[Feature] FE E2E", () => {
  test("[HAPPY] page renders with data", async () => {
    // navigate to /feature page
    // assert page title visible
    // assert data items rendered
  });

  test("[EDGE] empty state renders prompt", async () => {
    // navigate with no data
    // assert empty state message visible
  });
});
```
Run: `$RUNTIME test $FE_DIR/tests/e2e/[slug].test.ts`
Expected: FAIL
Commit: `git commit -m "test: add FE e2e for [feature] (outer red)"`

### Task 1: Types & Mock Data
**Progress check:** `grep -q "Resource" $TYPES_FILE`
Step 1: Write test
```typescript
test("mock data matches type shape", () => {
  const item: Resource = MOCK_RESOURCE;
  expect(item.id).toBeDefined();
});
```
Run / Expected: FAIL
Step 2: Add types to `types.ts`, create mock file
Run / Expected: PASS
Commit: `git commit -m "feat: add [feature] types and mocks"`

### Task 2: Component Shell (CP1)
**Progress check:** `test -f $FE_PAGES_DIR/[feature]/page.tsx`
Step 1: Write test [code]
Run / Expected: FAIL
Step 2: Implement page component with mock data
Run / Expected: PASS
Commit: `git commit -m "feat: add [feature] page shell"`
**PM Checkpoint CP1:** Page renders with mock data

### Task 3: Interactions (CP2)
Step 1: Write test [code]
Run / Expected: FAIL
Step 2: Implement interactions
Run / Expected: PASS
Commit: `git commit -m "feat: add [feature] interactions"`
**PM Checkpoint CP2:** Happy path works

### Task 4: Edge Cases & i18n (CP3)
Step 1: Add empty/error/loading state tests
Step 2: Implement states + add i18n keys (en + zh-CN)
Commit: `git commit -m "feat: add [feature] edge cases and i18n"`
**PM Checkpoint CP3:** All states visible

### Task 5: API Client
**Progress check:** `test -f $API_CLIENT_DIR/[feature].ts`
Step 1: Create API client with type-safe functions
Step 2: Wire to mock data initially (swap to real API during integration)
Commit: `git commit -m "feat: add [feature] API client"`

## Integration Handoff
When BE is ready:
- [ ] Swap mock imports for real API client calls
- [ ] Verify type alignment (FE types match BE response)
- [ ] Remove/relocate mock files
- [ ] Smoke test with real data

## Completion Criteria
- [ ] `$FE_TEST_CMD` exits 0
- [ ] `$RUNTIME run build` exits 0
- [ ] zh-CN translations present for all user-facing strings
- [ ] PM CP4 sign-off obtained
````

### Example

````markdown
**Parent:** #241

## Shared Contract
See parent #241 — Shared Contract section.

## Mock Data
```typescript
// $FE_DIR/src/mocks/pipeline.mock.ts
import type { PipelineStage, Deal } from "@/lib/types";

export const MOCK_STAGES: PipelineStage[] = [
  { id: "s1", name: "Qualification", order: 1, dealCount: 3 },
  { id: "s2", name: "Proposal", order: 2, dealCount: 2 },
  { id: "s3", name: "Negotiation", order: 3, dealCount: 1 },
];

export const MOCK_DEALS: Deal[] = [
  { id: "d1", title: "Acme Corp", value: 50000, stageId: "s1", assigneeId: "u1", createdAt: "2026-04-01" },
  { id: "d2", title: "Globex Inc", value: 120000, stageId: "s2", assigneeId: "u1", createdAt: "2026-04-02" },
];

export const MOCK_EMPTY_STAGES: PipelineStage[] = [
  { id: "s1", name: "Qualification", order: 1, dealCount: 0 },
];
```

## Component Spec
```typescript
interface PipelineBoardProps {
  stages: PipelineStage[];
  deals: Deal[];
  onDealClick?: (dealId: string) => void;
}
// State: loading | empty | populated | error
// Events: onDealClick, onDragEnd
```

## API Client
```typescript
// $API_CLIENT_DIR/pipeline.ts
export async function getStages(): Promise<PipelineStage[]>
export async function getDeals(stageId?: string): Promise<Deal[]>
```

## i18n Keys
```typescript
// en.ts
pipeline: {
  title: "Pipeline",
  empty: "Create your first deal",
  stages: { qualification: "Qualification", proposal: "Proposal", negotiation: "Negotiation" },
}
// zh-CN.ts
pipeline: {
  title: "销售管道",
  empty: "创建第一笔交易",
  stages: { qualification: "资质审核", proposal: "提案", negotiation: "谈判" },
}
```

## Indicative Layout
```
┌──────────────────────────────────────────────────────────────┐
│ Pipeline                                    [+ New Deal]     │
├──────────────────────────────────────────────────────────────┤
│ ┌── Qualification ──┐ ┌── Proposal ─────┐ ┌── Negotiation ─┐│
│ │ ┌──────────────┐  │ │ ┌──────────────┐│ │ ┌──────────────┐││
│ │ │ Acme Corp    │  │ │ │ Globex Inc   ││ │ │ Wayne Ent    │││
│ │ │ $50,000      │  │ │ │ $120,000     ││ │ │ $200,000     │││
│ │ └──────────────┘  │ │ └──────────────┘│ │ └──────────────┘││
│ │ ┌──────────────┐  │ │ ┌──────────────┐│ │                 ││
│ │ │ Beta Ltd     │  │ │ │ Initech      ││ │                 ││
│ │ │ $30,000      │  │ │ │ $75,000      ││ │                 ││
│ │ └──────────────┘  │ │ └──────────────┘│ │                 ││
│ │  3 deals · $130k  │ │  2 deals · $195k│ │  1 deal · $200k ││
│ └───────────────────┘ └─────────────────┘ └─────────────────┘│
└──────────────────────────────────────────────────────────────┘

Empty state:
┌──────────────────────────────────────────────────────────────┐
│ Pipeline                                    [+ New Deal]     │
├──────────────────────────────────────────────────────────────┤
│ ┌── Qualification ──┐ ┌── Proposal ─────┐ ┌── Negotiation ─┐│
│ │                   │ │                 │ │                 ││
│ │  "Create your     │ │                 │ │                 ││
│ │   first deal"     │ │                 │ │                 ││
│ │  [+ Add Deal]     │ │                 │ │                 ││
│ │                   │ │                 │ │                 ││
│ └───────────────────┘ └─────────────────┘ └─────────────────┘│
└──────────────────────────────────────────────────────────────┘
```

## PM Checkpoints
- [ ] **CP1 — Shell**: Kanban columns render with mock data, layout matches indicative layout
- [ ] **CP2 — Happy Path**: Deals appear in correct columns
- [ ] **CP3 — Edge Cases**: Empty pipeline shows prompt
- [ ] **CP4 — PM Sign-off**: PM confirms layout/copy

## TDD Tasks
...

## Integration Handoff
When BE is ready:
- [ ] Swap mock imports for real API client calls
- [ ] Verify PipelineStage/Deal types match BE response
- [ ] Remove pipeline.mock.ts
- [ ] Smoke test with real pipeline data

## Completion Criteria
- [ ] `$FE_TEST_CMD` exits 0
- [ ] `$RUNTIME run build` exits 0
- [ ] zh-CN translations present
- [ ] PM CP4 sign-off obtained
````

## [INT] -- Integration & Verification Sub-Issue

Use for integration tasks within a [STORY]. Owns FE↔BE wiring, full user journey E2E tests, and deployment verification. Created by /design for every story.

````markdown
**Parent:** #[STORY_NUMBER]
**Depends on:** [BE] #[BE_NUMBER], [FE] #[FE_NUMBER]

## Scope
- Replace FE mocks with real API client calls (from [FE] #[FE_NUMBER])
- Implement Gherkin scenarios from parent [STORY] as runnable e2e tests
- Verify deployed preview URL against full user journey via `/super-ralph:verify`

## Gherkin User Journey
See parent #[STORY_NUMBER] — Acceptance Criteria (Gherkin) section.

## Integration Tasks

### Task 0: Mock Swap
**Progress check:** `! grep -r "mock[Feature]" $FE_DIR/src/app/[feature]` (mock imports removed from pages)
**Files:** Modify `$FE_PAGES_DIR/[feature]/page.tsx`, delete `$FE_DIR/src/lib/mock/[feature].ts`
1. Replace `mock[Feature]List` imports with `[feature]Api.list()` calls
2. Run type check: `cd $FE_DIR && $RUNTIME run typecheck` — Expected: PASS
3. Commit: `git commit -m "chore: swap [feature] mocks for real API"`

### Task 1: E2E Tests (from Gherkin)
**Progress check:** `test -f tests/e2e/[story-slug].test.ts && grep -c "test(" tests/e2e/[story-slug].test.ts` — Expected: ≥3
**Files:** Modify `tests/e2e/[story-slug].test.ts`
1. Implement each Gherkin scenario as a `test(...)` block — concrete setup, action, assertion
2. Run: `$RUNTIME test tests/e2e/[story-slug].test.ts`
3. Expected: PASS — all scenarios pass (3+ tests)
4. Commit: `git commit -m "test: [feature] e2e green for all Gherkin scenarios"`

## Verification Tasks

### Task 2: Staging Smoke via `/super-ralph:verify`
**Progress check:** verification report exists in `.claude/runs/verify-[story-slug]/report.md`
**Files:** Run verify command, capture output
1. Identify preview URL for the merged PR (from Vercel/preview provider)
2. Run: `/super-ralph:verify <preview-url> --story #[STORY_NUMBER]`
3. Expected: verifier returns GREEN for all Gherkin scenarios
4. If RED: file a `[FIX]` issue referencing #[STORY_NUMBER] and note here

### Task 3: Integration PR
**Progress check:** PR open with `Closes #[INT_NUMBER]` in body
1. Push branch, open PR with title `int: [feature] integration and e2e`
2. Body includes: "Closes #[INT_NUMBER]" + verifier report summary
3. Expected: CI green, PR links back to parent STORY

## Completion Criteria
- [ ] Mock data files deleted
- [ ] `$RUNTIME test tests/e2e/[story-slug].test.ts` — 0 failures, ≥3 scenarios
- [ ] `/super-ralph:verify` report is GREEN
- [ ] All 3+ Gherkin scenarios pass on staging preview
````

### Example

````markdown
**Parent:** #241
**Depends on:** [BE] #242, [FE] #243

## Scope
- Replace FE mocks with real pipeline API client
- Run the 4 Gherkin scenarios (board renders, empty state, many deals, unauthorized) as e2e tests
- Verify staging preview URL before marking done

## Integration Tasks

### Task 0: Mock Swap
**Progress check:** `! grep -r "mock" $FE_DIR/src/app/pipeline`
**Files:** Modify `$FE_PAGES_DIR/pipeline/page.tsx`, delete `$FE_DIR/src/lib/mock/pipeline.ts`
...

### Task 1: E2E Tests
**Progress check:** `grep -c "test(" tests/e2e/pipeline.test.ts` → 4
...
````

## [QA] -- Test Verification

Use for test verification tasks against acceptance criteria. Created per-module when approaching UAT.

```markdown
### Module
[Module name being tested]

### Test Cases

| # | Scenario | Steps | Expected | Status |
|---|----------|-------|----------|--------|
| 1 | [Scenario name] | [Steps to execute] | [Expected result] | [ ] |
| 2 | ... | ... | ... | [ ] |

### Environment
- **URL:** [Staging/preview URL]
- **Test data:** [Seed data or setup required]
- **Tested by:** [Tester name]
```

## [CHORE] -- Technical Work

Use for non-user-facing technical work: DevOps, infrastructure, refactoring, test infrastructure, dependency upgrades, documentation.

```markdown
### Task
[What technical work needs to be done and why]

### Category
[devops | infra | test | refactor | docs | deps]

### Done Criteria
- [ ] [Specific, verifiable outcome 1]
- [ ] [Specific, verifiable outcome 2]
- [ ] Tests pass: `$RUNTIME test` in affected service(s)

### Technical Notes
[Optional — approach, affected files, rollback plan if applicable]
```

### Example

```markdown
### Task
Upgrade Bun from 1.1 to 1.2 across all services. The new version fixes a memory leak in the SSE streaming adapter that affects long-lived connections.

### Category
deps

### Done Criteria
- [ ] `$RUNTIME --version` returns 1.2.x in $BE_DIR, $FE_DIR, and all services
- [ ] All existing tests pass: `$RUNTIME test` in each service
- [ ] CI pipeline uses Bun 1.2
- [ ] SSE streaming memory leak no longer reproduces under 100 concurrent connections

### Technical Notes
- Update `package.json` engines field in each service
- Update `.github/workflows/*.yml` to use `oven-sh/setup-bun@v2` with version 1.2
- Run memory profiling test before/after to confirm fix
```

## [REQ] -- Feature Requirement (Legacy)

> **Note:** [REQ] is a legacy type. For new issues, use [STORY] for user-facing features or [CHORE] for technical work.

Use for standalone feature requests or enhancements.

```markdown
### What to build
[Description of the feature requirement, including user-facing behavior]

### Context
[Why this is needed — business goal, user feedback, technical debt]

### Acceptance criteria
- [ ] [Criterion 1 — specific, measurable, testable]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

### Technical notes
[Optional — implementation hints, API contracts, relevant files]
```

## [FIX] -- Bug Fix

Use for confirmed bugs that need fixing.

```markdown
### What to fix
[Description of the bug, including observed vs. expected behavior]

### Steps to reproduce
1. [Step 1]
2. [Step 2]
3. [Step 3]

### Expected behavior
[What should happen]

### Actual behavior
[What actually happens]

### Acceptance criteria
- [ ] Bug no longer reproduces following the steps above
- [ ] Regression test added covering this case
- [ ] [Any additional criteria]

### Environment
- **Service:** [$BE_DIR | $FE_DIR | other]
- **Branch/commit:** [Where the bug was observed]
```

### Example

```markdown
### What to fix
Dashboard page shows stale case counts after a case is archived. The count badge still includes archived cases until the page is manually refreshed.

### Steps to reproduce
1. Open the dashboard page
2. Note the case count (e.g., 5)
3. Archive a case from the case detail page
4. Return to the dashboard
5. Case count still shows 5 instead of 4

### Expected behavior
Case count updates immediately (or within 1 second) after archiving a case.

### Actual behavior
Case count remains stale until manual page refresh.

### Acceptance criteria
- [ ] Dashboard count updates within 1 second of case archive
- [ ] Regression test: archive case, verify dashboard count decrements
- [ ] No full page reload required

### Environment
- **Service:** $FE_DIR
- **Branch/commit:** main @ c3266ba
```

## Sub-issue (of a STORY)

Use for granular sub-tasks when a [STORY] is too large for a single PR. No tag prefix, no size field, no assignee. Rare — most STORYs are implemented as a single unit. For concurrent FE/BE development, prefer [FE] and [BE] sub-issues instead.

```markdown
**Parent:** #[PARENT_ISSUE_NUMBER]

### What to build
[Description of the specific task]

### Vertical slice
| Layer | File | Action |
|-------|------|--------|
| [API/DB/UI/Test] | `[file path]` | [Create/Modify/Delete] |

### Acceptance criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]
```

### Example

```markdown
**Parent:** #40

### What to build
Create the SSE streaming endpoint for individual case updates. When a client subscribes to `/api/cases/:id/stream`, the server pushes case state changes as SSE events.

### Vertical slice
| Layer | File | Action |
|-------|------|--------|
| API | `$BE_ROUTES_DIR/case-stream.ts` | Create |
| Service | `$BE_SERVICES_DIR/case-stream.ts` | Create |
| Types | `$BE_DIR/src/types/stream.ts` | Modify |
| Test | `$BE_ROUTES_DIR/case-stream.test.ts` | Create |

### Acceptance criteria
- [ ] `GET /api/cases/:id/stream` returns `Content-Type: text/event-stream`
- [ ] Events are sent when case status changes
- [ ] Client receives initial state on connection
- [ ] Connection closes cleanly on client disconnect
- [ ] Test covers happy path and disconnect scenarios
```
