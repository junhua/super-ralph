# Epic Template

Use this template when creating epics. Fill in all bracketed sections. Remove comments before finalizing.

---

````markdown
# Epic: [Outcome-Focused Title]

> **Product:** [Product name, e.g., ForthAI Work]
> **Phase:** [Roadmap phase, e.g., Phase 2: Core Platform]
> **Created:** [YYYY-MM-DD]
> **Status:** Draft | Ready | In Progress | Done

## PM Summary

### What we're building
[2-3 sentences explaining the feature in business terms. What user problem does this solve? What does success look like?]

### Story Priority
| # | Story | User Value | Size | Can ship without? |
|---|-------|-----------|------|-------------------|
| 1 | [Story title] | [Why users care] | S/M/L | No (core) |
| 2 | [Story title] | [Why users care] | S/M/L | No (core) |
| 3 | [Story title] | [Why users care] | S/M/L | Yes (enhancement) |

### Success Metrics
| Metric | Current | Target | How to Measure |
|--------|---------|--------|----------------|
| [e.g., Task completion time] | [e.g., N/A] | [e.g., < 5 min] | [e.g., Time from page open to submit] |
| [e.g., Error rate] | [e.g., N/A] | [e.g., < 2%] | [e.g., 400/500 responses / total requests] |

### Not Building (Parking Lot)
- [Excluded feature + why] -- e.g., "Bulk import -- deferred to Phase 3, need CSV spec"
- [Excluded feature + why] -- e.g., "Mobile layout -- desktop-first, mobile in next epic"

### PM Decision Points
- [ ] [Decision that must be resolved before dev] -- e.g., "Approval workflow: auto-approve < $500?"
- [ ] [Decision that must be resolved before dev] -- e.g., "Default sort: by date or by name?"

## Business Context

[2-3 sentences: Why does this epic exist? What business problem does it solve? Reference product vision or business goals.]

### User Feedback / Input

[If this epic was triggered by user feedback, feature requests, or business metrics, include the original input here. Quote directly when possible.]

> "[Original feedback or request]"
> -- [Source: user interview, support ticket, OKR, etc.]

## Success Metrics

How to measure if this epic achieved its goal. Every metric must be measurable.

| Metric | Current | Target | How to Measure |
|--------|---------|--------|----------------|
| [e.g., Agent creation time] | [e.g., N/A (no feature)] | [e.g., < 5 minutes] | [e.g., Time from builder open to first deploy] |
| [e.g., Non-technical user completion rate] | [e.g., N/A] | [e.g., > 80%] | [e.g., % of users who complete setup without support tickets] |

## Personas

Who benefits from this epic. Reference product vision personas.

| Persona | Role | How They Benefit |
|---------|------|-----------------|
| [e.g., Business Operator] | [e.g., Non-technical team lead] | [e.g., Can create agents without engineering support] |
| [e.g., IT Admin] | [e.g., Platform administrator] | [e.g., Maintains governance without blocking business teams] |

## Scope

### In Scope

- [Capability or behavior this epic delivers]
- [Another capability]

### Out of Scope

- [Explicitly excluded to prevent scope creep -- state WHY]
- [Another exclusion -- state WHY]

## Dependencies

What must exist before this epic can start.

| Dependency | Status | Notes |
|------------|--------|-------|
| [e.g., Authentication system] | [Done / In Progress / Blocked] | [e.g., Required for user identity in builder] |
| [e.g., Agent data model API] | [Done / In Progress / Blocked] | [e.g., CRUD operations for agent entities] |

## Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| [e.g., Template design doesn't match user mental models] | High | Medium | [e.g., User testing with 3 non-technical users before finalizing] |

---

## Stories

### Story 1: [Title]

**As a** [persona],
**I want to** [action],
**so that** [outcome].

**Priority:** P0 | P1 | P2
**Size:** S | M | L
**Depends on:** None

#### Acceptance Criteria (Gherkin)

```gherkin
Feature: [Story title]
  Background:
    Given I am logged in as [persona] with orgId "org-123"
    And [workspace/data precondition]

  Scenario: [HAPPY] [description]
    Given [precondition with concrete data]
    When [action]
    Then [outcome]

  Scenario: [EDGE] [description]
    Given [boundary condition]
    When [action]
    Then [graceful handling]

  Scenario: [SECURITY] [auth case]
    Given I am logged in as [unauthorized role]
    When [action requiring permission]
    Then I see: "You don't have permission to perform this action"
```

#### Shared Contract

```typescript
// TypeScript types shared between FE and BE
export type ResourceName = { ... };
export type CreateResourceInput = Pick<ResourceName, "field1" | "field2">;
```

#### Pre-Decided Implementation

**Schema:**
```typescript
// work-agents/src/db/schema.ts -- append to // --- [Feature] ----
export const tableName = pgTable("table_name", { ... });
```

**Service Interface:**
```typescript
export async function getResources(db: DB, orgId: string): Promise<Resource[]>
export async function createResource(db: DB, orgId: string, input: CreateInput): Promise<Resource>
```

**Route Contract:**
| Method | Path | Auth | Request | Response | Errors |
|--------|------|------|---------|----------|--------|
| GET | `/api/orgs/:orgId/resources` | Bearer | -- | `{ data: Resource[] }` | 401, 403 |
| POST | `/api/orgs/:orgId/resources` | Bearer | `CreateInput` | `{ data: Resource }` | 400, 401, 403 |

**Component Spec:**
```typescript
interface ComponentProps { ... }
// State: loading, error, data
// Events: onSelect, onDelete
// Error states: empty list, fetch error, delete confirmation
```

**i18n Keys:**
```typescript
featureKey: {
  title: "English",     // zh-CN: "Chinese"
  create: "Create",     // zh-CN: "..."
}
```

**Patterns to Follow:**
```
Service: work-agents/src/services/knowledge.ts
Route:   work-agents/src/routes/knowledge.ts
Page:    work-web/src/app/(app)/[orgId]/knowledge/page.tsx
```

#### FE Sub-Issue Scope

- Component spec, API client, i18n, mock data, page
- **PM Checkpoints:** CP1 (shell with mock data) -> CP2 (happy path with real API) -> CP3 (edge cases + error states) -> CP4 (PM sign-off: i18n, responsive, a11y)
- TDD tasks for frontend layers (see story template for task format)

#### BE Sub-Issue Scope

- Schema, service, route, route registration, tests
- TDD tasks for backend layers (see story template for task format)

---

### Story 2: [Title]

[Same structure as Story 1]

---

[Continue for all stories...]

---

## Execution Plan

### AI-Hours Estimate

| Story | Size | AI-Hours | Depends On |
|-------|------|----------|------------|
| Story 1: [title] | S/M/L | Xh | None |
| Story 2: [title] | S/M/L | Yh | Story 1 |
| Story 3: [title] | S/M/L | Zh | None |
| **Total** | | **Nh** | |

### Waves (Parallel Execution Groups)

| Wave | Stories (concurrent) | Prereqs | Calendar Time |
|------|---------------------|---------|---------------|
| Wave 0 | Story 1, Story 3 | None | Xh |
| Wave 1 | Story 2, Story 4 | Wave 0 | Yh |
| Wave 2 | Story 5 | Wave 1 | Zh |

### Critical Path

Wave 0 (Xh) -> Wave 1 (Yh) -> Wave 2 (Zh) = **Nh minimum**.
With N devs working in parallel -> **Mh calendar time**.

---

## Launch Checklist

Before marking this epic as Done:

- [ ] All P0 stories delivered and Gherkin scenarios passing
- [ ] All P1 stories delivered or explicitly deferred with rationale
- [ ] Success metrics have baseline measurements established
- [ ] No Critical or Important review findings remain (via /super-ralph:review-fix)
- [ ] i18n complete for en + zh-CN
- [ ] PM sign-off on all CP4 checkpoints
````
