# Issue Body Templates

> **Config:** Project-specific values (paths, repo, team) are loaded from `.claude/super-ralph-config.md`.

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

## Acceptance Criteria (Gherkin)
```gherkin
Feature: [Story title]
  Background:
    Given I am logged in as [persona]

  Scenario: [HAPPY] Primary flow
    Given [precondition with specific data]
    When [specific action]
    Then [verifiable outcome]

  Scenario: [EDGE] Boundary condition
    Given [boundary condition]
    When [action at boundary]
    Then [graceful handling]

  Scenario: [SECURITY] Unauthorized access
    Given [invalid state or unauthorized user]
    When [action]
    Then [specific error response]
```

## Shared Contract
```typescript
// Shared types used by both FE and BE
export type ResourceName = {
  id: string;
  // ... fields
};

export type CreateResourceInput = {
  // ... fields
};
```

## Sub-Issues
- [BE] #N — Backend implementation
- [FE] #N — Frontend implementation

## E2E Test Skeleton
```typescript
describe("[Story title]", () => {
  test("[HAPPY] primary flow", async () => {
    // arrange
    // act
    // assert
  });

  test("[EDGE] boundary condition", async () => {
    // arrange
    // act
    // assert
  });
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

## TDD Tasks

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
- [ ] All route contracts return correct status codes
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

## PM Checkpoints
- [ ] **CP1 — Shell**: Page renders with mock data, no interactions
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

## PM Checkpoints
- [ ] **CP1 — Shell**: Kanban columns render with mock data
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
