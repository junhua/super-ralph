# EPIC: Mixed Sample Feature

<!-- super-ralph: local-mode -->
<!-- super-ralph: brief -->

## Goal
Story 1 is expanded to full; Story 2 remains brief.

## Personas
- Developer — mixes brief and full stories

---

## Stories

### Story 1: Foo listing

**As a** Developer, **I want** to list foos, **So that** I can see what exists.

**Persona:** Developer   **Priority:** P0   **Size:** M   **Status:** PENDING

#### Acceptance Criteria (Gherkin)

Feature: Foo listing
  Scenario: [HAPPY] Foos render
    Given 3 foos exist
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

#### Shared Contract
```typescript
export interface Foo { id: string; name: string }
```

#### [BE] Story 1 — Backend

Mock backend section for the fixture.

#### [FE] Story 1 — Frontend

Mock frontend section for the fixture.

#### [INT] Story 1 — Integration & E2E

Mock integration section for the fixture.

---

### Story 2: Foo detail

**As a** Developer, **I want** to view a foo, **So that** I can inspect it.

**Persona:** Developer   **Priority:** P1   **Size:** S   **Status:** PENDING

#### Acceptance Criteria (Outline)

- `[HAPPY]` Given foo "abc" exists, when I open /foos/abc, then I see its name.
- `[EDGE]` Given foo "missing" does not exist, when I open /foos/missing, then I see a 404 page.
- `[SECURITY]` Given I am in org X and foo belongs to org Y, when I open /foos/Y-foo, then I get 403.
