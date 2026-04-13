# Story Template

Use this template for individual user stories within an epic. Each story is independently plannable and deliverable.

---

## Story Format

```markdown
### Story N: [Action-Oriented Title]

**As a** [specific persona from product vision — not "user"],
**I want to** [concrete action — verb phrase],
**so that** [measurable outcome — not "I can do X" but "X is achieved"].

**Priority:** P0 (must-have for MVP) | P1 (should-have) | P2 (nice-to-have)
**Size:** S (1-2 TDD tasks) | M (3-5 tasks) | L (6-10 tasks) | XL (split this story)

**Epic:** [Parent epic reference]
**Depends on:** [Story N-1, or "None"]
```

## Acceptance Criteria Format

Write in BDD Given/When/Then. Each criterion = one e2e test case.

### Rules

1. **One behavior per criterion** — If you write "and" between two unrelated outcomes, split into two criteria
2. **Observable results only** — Test what the user sees/experiences, not internal state
3. **Concrete values** — "shows 3 agents" not "shows agents"; "within 2 seconds" not "quickly"
4. **Include error paths** — At minimum: one happy path, one validation error, one system error
5. **No implementation details** — "Then a confirmation appears" not "Then a toast component renders"

### Happy Path Example

```markdown
- [ ] **Given** I am a business operator on the agent builder page
      **When** I select the "Invoice Processing" template
      **And** I click "Create Agent"
      **Then** a new agent named "Invoice Processing Agent" appears in my agent list
      **And** its status is "Draft"
      **And** I am redirected to the agent configuration page
```

### Validation Error Example

```markdown
- [ ] **Given** I am creating an agent
      **When** I leave the agent name empty
      **And** I click "Create Agent"
      **Then** a validation message appears: "Agent name is required"
      **And** the agent is NOT created
```

### System Error Example

```markdown
- [ ] **Given** I am deploying an agent
      **When** the backend API is unreachable
      **Then** an error message appears: "Unable to deploy. Please try again or contact support."
      **And** the agent remains in "Draft" status
```

### Edge Case Example

```markdown
- [ ] **Given** I have reached the maximum agent limit (10 agents)
      **When** I try to create a new agent
      **Then** a message appears: "Agent limit reached. Upgrade your plan or archive existing agents."
      **And** the "Create Agent" button is disabled
```

## E2E Test Skeleton

Generate from acceptance criteria. Maps 1:1 — every criterion becomes a test case.

```typescript
// tests/e2e/[story-slug].test.ts
import { describe, test, expect } from "bun:test";

describe("Story N: [Title]", () => {
  // Happy path
  test("creates agent from template", async () => {
    // Given: business operator on agent builder page
    // When: select "Invoice Processing" template, click "Create Agent"
    // Then: agent appears in list, status = Draft, redirected to config
  });

  // Validation error
  test("rejects empty agent name", async () => {
    // Given: creating an agent
    // When: leave name empty, click "Create Agent"
    // Then: validation message, agent NOT created
  });

  // System error
  test("handles API failure gracefully", async () => {
    // Given: deploying an agent
    // When: API unreachable
    // Then: error message, agent stays Draft
  });

  // Edge case
  test("prevents creation at agent limit", async () => {
    // Given: 10 agents exist (max)
    // When: try to create new agent
    // Then: limit message, button disabled
  });
});
```

## Story Sizing Guide

| Size | Acceptance Criteria | TDD Tasks | Iterations | Example |
|------|-------------------|-----------|------------|---------|
| **S** | 2-3 | 1-2 | 5-10 | Add a button, simple validation |
| **M** | 4-6 | 3-5 | 10-20 | CRUD for a resource, form with validation |
| **L** | 7-10 | 6-10 | 20-35 | Multi-step wizard, complex workflow |
| **XL** | 10+ | 10+ | 35+ | **Split into smaller stories** |

If a story is XL, decompose it. Common split patterns:
- **By user action:** "Create agent" and "Configure agent" are separate stories
- **By persona:** "Operator creates agent" and "Admin sets permissions" are separate
- **By error handling:** Happy path is one story, error handling is another (if complex)
- **By platform:** "Web creates agent" and "API creates agent" are separate

## Connecting to Implementation Plans

When a story is ready for implementation via `/super-ralph:plan`:

1. The plan's **Task 0** generates e2e tests from the acceptance criteria skeleton
2. Tasks 1-N implement the feature via TDD (inner loop)
3. The plan's **Final Verification** confirms e2e tests pass (outer loop goes green)
4. **Completion criteria** include: "E2E tests for Story N all pass"

### Plan Command Integration

```bash
# Plan a single story
/super-ralph:plan --story docs/epics/2026-02-16-agent-builder.md#story-1

# Plan multiple stories (if independent)
/super-ralph:plan --story docs/epics/2026-02-16-agent-builder.md#story-1,story-2
```

The `--story` flag tells the plan command to:
1. Read the story's acceptance criteria
2. Generate e2e test scaffolding as Task 0
3. Use the story's complexity to set iteration budget
4. Reference the story's dependencies as plan prerequisites
