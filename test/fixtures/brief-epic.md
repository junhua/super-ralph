# EPIC: Brief Sample Feature

<!-- super-ralph: local-mode -->
<!-- super-ralph: brief -->

## Goal
Test fixture for brief-mode parsing.

## Business Context
Exercises brief story-level detection.

## Personas
- Developer — exercises brief fixtures

## Scope — In
- Two brief stories

## Scope — Out
- Full TDD

---

## Stories

### Story 1: Foo listing

**As a** Developer, **I want** to list foos, **So that** I can see what exists.

**Persona:** Developer   **Priority:** P0   **Size:** M   **Status:** PENDING
<!-- PR: -->
<!-- Branch: -->

#### Acceptance Criteria (Outline)

- `[HAPPY]` Given 3 foos exist, when I open /foos, then I see 3 rows within 2 seconds.
- `[EDGE]` Given no foos exist, when I open /foos, then I see an empty-state message "No foos yet".
- `[SECURITY]` Given I am not authenticated, when I open /foos, then I am redirected to /login.

---

### Story 2: Foo detail

**As a** Developer, **I want** to view a foo, **So that** I can inspect it.

**Persona:** Developer   **Priority:** P1   **Size:** S   **Status:** PENDING

#### Acceptance Criteria (Outline)

- `[HAPPY]` Given foo "abc" exists, when I open /foos/abc, then I see its name.
- `[EDGE]` Given foo "missing" does not exist, when I open /foos/missing, then I see a 404 page.
- `[SECURITY]` Given I am in org X and foo belongs to org Y, when I open /foos/Y-foo, then I get 403.
