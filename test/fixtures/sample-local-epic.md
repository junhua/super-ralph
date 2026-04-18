# EPIC: Sample Feature

<!-- super-ralph: local-mode -->

## Goal
Test fixture for local-mode parsing.

## Business Context
Exercises all anchor and sub-section paths used by the parser.

## Success Metrics
| Metric | Current | Target | How to Measure |
| Parse accuracy | 0% | 100% | Fixture tests pass |

## Personas
- Developer — writes commands against this fixture

## Scope — In
- Three stories with full bodies

## Scope — Out
- Real implementation — this is a fixture

## Dependencies
| Prereq | Status | Notes |
| None   | -      | -     |

## Risks
| Risk | Impact | Likelihood | Mitigation |
| Fixture drift | Low | Low | Pinned to this file |

## PM Summary

### Story Priority Table
| # | Story | Priority | Size | Can Ship Without? | Notes |
| 1 | Foo listing | P0 | M | No | Base |
| 2 | Foo detail  | P1 | S | Yes | Follows 1 |
| 3 | Foo search  | P2 | M | Yes | Optional |

### Execution Plan

#### AI-Hours Estimate
| Story | BE | FE | INT | Total |
| 1 | 2h | 1.5h | 1h | 4.5h |
| 2 | 1h | 1h | 0.5h | 2.5h |
| 3 | 1.5h | 2h | 1h | 4.5h |

#### Wave Assignments
| Wave | Stories | Parallel Slots | Estimated Hours |
| 1 | Story 1, Story 3 | 2 | 4.5h |
| 2 | Story 2 | 1 | 2.5h |

---

## Stories

### Story 1: Foo listing

**Persona:** Developer   **Priority:** P0   **Size:** M   **Status:** PENDING
<!-- PR: -->
<!-- Branch: -->

#### [STORY] Story 1

**Parent:** (local epic)

## User Story
**As a** Developer, **I want** to list foos, **So that** I can see what exists.

## User Journey
Developer opens /foos page and sees a table of foos.

## Acceptance Criteria
Feature: Foo listing
  Background:
    Given 3 foos exist
  Scenario: [HAPPY] Foos render
    When I open /foos
    Then I see 3 rows
  Scenario: [EDGE] Empty list
    Given no foos exist
    When I open /foos
    Then I see an empty-state message
  Scenario: [SECURITY] Unauthorized access
    Given I am not authenticated
    When I open /foos
    Then I am redirected to /login

## Shared Contract
```typescript
export interface Foo { id: string; name: string }
```

## E2E Test Skeleton
```typescript
import { describe, test, expect } from "bun:test";
describe("Foo listing", () => {
  test("renders", async () => { /* TBD */ });
});
```

#### [BE] Story 1 — Backend

**Parent:** (local epic — Story 1)

## Backend Implementation

### Schema Changes
File: `work-agents/src/db/schema.ts`
Section: `// ─── Foo ────`
```typescript
export const foo = pgTable("foo", { id: text("id").primaryKey() });
```

## TDD Tasks

**Progress check:** `cd work-agents && bun test src/services/__tests__/foo.test.ts` — Expected: PASS

### Task 0: E2E Test Skeleton (Outer RED)
```bash
echo "red"
```

### Task 1: Schema + Migration
```bash
echo "schema"
```

## Completion Criteria
- [ ] BE tests pass

#### [FE] Story 1 — Frontend

**Parent:** (local epic — Story 1)

## Frontend Implementation

### Mock Data
File: `work-web/src/lib/mock/foo.ts`
```typescript
export const mockFoo = [{ id: "1", name: "one" }];
```

## TDD Tasks

**Progress check:** `cd work-web && bun test` — Expected: PASS

### Task 0: E2E Test (Outer RED)

## PM Checkpoints
| Checkpoint | When | What to Verify |
| CP1: Mock renders | After Task 1 | Renders |
| CP2: i18n complete | After Task 3 | EN+zh |
| CP3: API integrated | After BE | Real data |
| CP4: AC pass | End | Gherkin green |

## Completion Criteria
- [ ] FE tests pass

#### [INT] Story 1 — Integration & E2E

**Parent:** (local epic — Story 1)

## Gherkin User Journey
See parent Story 1 [STORY] section above.

## Integration Tasks
### Task 0: Mock Swap
### Task 1: Gherkin E2E

## Verification Tasks
### Task 2: /super-ralph:verify against staging preview

## Completion Criteria
- [ ] INT tests pass

---

### Story 2: Foo detail

**Persona:** Developer   **Priority:** P1   **Size:** S   **Status:** IN_PROGRESS
<!-- PR: #999 -->
<!-- Branch: super-ralph/foo-detail -->

#### [STORY] Story 2

**Parent:** (local epic)

## User Story
**As a** Developer, **I want** to view a foo, **So that** I can inspect it.

## User Journey
Developer clicks a row, sees detail.

## Acceptance Criteria
Feature: Foo detail
  Scenario: [HAPPY] Open detail
    Given foo "abc" exists
    When I open /foos/abc
    Then I see its name
  Scenario: [EDGE] Missing foo
    When I open /foos/missing
    Then I see 404
  Scenario: [SECURITY] Foreign org foo
    Given I am in org X and foo belongs to org Y
    When I open /foos/Y-foo
    Then I get 403

## Shared Contract
```typescript
export type FooDetail = Foo & { createdAt: string };
```

## E2E Test Skeleton
```typescript
describe("Foo detail", () => { test("opens", async () => {}); });
```

#### [BE] Story 2 — Backend

**Parent:** (local epic — Story 2)

## Backend Implementation
### Schema Changes
None.

## TDD Tasks
**Progress check:** `bun test` — Expected: PASS
### Task 0: E2E
### Task 1: Route

## Completion Criteria
- [ ] Route returns detail

#### [FE] Story 2 — Frontend

**Parent:** (local epic — Story 2)

## Frontend Implementation
### Mock Data
```typescript
export const mockFooDetail = { id: "abc", name: "abc", createdAt: "2026-01-01" };
```

## TDD Tasks
**Progress check:** `bun test` — Expected: PASS
### Task 0: E2E

## PM Checkpoints
| Checkpoint | When | What to Verify |
| CP1 | After Task 1 | render |
| CP2 | After Task 3 | i18n |
| CP3 | After BE | API |
| CP4 | End | AC |

## Completion Criteria
- [ ] Detail renders

#### [INT] Story 2 — Integration & E2E

**Parent:** (local epic — Story 2)

## Gherkin User Journey
See parent.

## Integration Tasks
### Task 0: Mock swap
### Task 1: Gherkin E2E

## Verification Tasks
### Task 2: /super-ralph:verify

## Completion Criteria
- [ ] INT green

---

### Story 3: Foo search

**Persona:** Developer   **Priority:** P2   **Size:** M   **Status:** PENDING

#### [STORY] Story 3

**Parent:** (local epic)

## User Story
**As a** Developer, **I want** to search foos, **So that** I can find one quickly.

## User Journey
Developer types in search box, list filters.

## Acceptance Criteria
Feature: Foo search
  Scenario: [HAPPY] Search returns results
  Scenario: [EDGE] No matches
  Scenario: [SECURITY] SQL-injection-safe query

## Shared Contract
```typescript
export type FooSearchQuery = { q: string };
```

## E2E Test Skeleton
```typescript
describe("Foo search", () => {});
```

#### [BE] Story 3 — Backend

**Parent:** (local epic — Story 3)

## TDD Tasks
**Progress check:** `bun test` — Expected: PASS
### Task 0: E2E
### Task 1: Search service

## Completion Criteria
- [ ] Search returns results

#### [FE] Story 3 — Frontend

**Parent:** (local epic — Story 3)

## TDD Tasks
**Progress check:** `bun test` — Expected: PASS
### Task 0: E2E

## PM Checkpoints
| Checkpoint | When | What to Verify |
| CP1 | After Task 1 | render |
| CP2 | After Task 3 | i18n |
| CP3 | After BE | API |
| CP4 | End | AC |

## Completion Criteria
- [ ] Search box works

#### [INT] Story 3 — Integration & E2E

**Parent:** (local epic — Story 3)

## Gherkin User Journey
See parent.

## Integration Tasks
### Task 0: Mock swap
### Task 1: Gherkin E2E

## Verification Tasks
### Task 2: /super-ralph:verify

## Completion Criteria
- [ ] INT green
