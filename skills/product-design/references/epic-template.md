# Epic Template

Use this template when creating epics. Fill in all bracketed sections. Remove comments before finalizing.

---

````markdown
# Epic: [Outcome-Focused Title]

> **Product:** [Product name, e.g., ForthAI Work]
> **Phase:** [Roadmap phase, e.g., Phase 2: Core Platform]
> **Created:** [YYYY-MM-DD]
> **Status:** Draft | Ready | In Progress | Done

## Business Context

[2-3 sentences: Why does this epic exist? What business problem does it solve? Reference product vision or business goals.]

### User Feedback / Input

[If this epic was triggered by user feedback, feature requests, or business metrics, include the original input here. Quote directly when possible.]

> "[Original feedback or request]"
> — [Source: user interview, support ticket, OKR, etc.]

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

- [Explicitly excluded to prevent scope creep]
- [Another exclusion — state WHY it's excluded]

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
**Complexity:** S | M | L | XL

#### Acceptance Criteria

- [ ] **Given** [precondition]
      **When** [action]
      **Then** [observable result]

- [ ] **Given** [precondition]
      **When** [action]
      **Then** [observable result]

#### E2E Test Skeleton

```typescript
// tests/e2e/[story-slug].test.ts
describe("[Story title]", () => {
  test("[criterion 1 summary]", async () => {
    // Given: [precondition]
    // When: [action]
    // Then: [result]
  });

  test("[criterion 2 summary]", async () => {
    // Given: [precondition]
    // When: [action]
    // Then: [result]
  });
});
```

#### Technical Notes

[Optional: architecture considerations, API endpoints involved, data model implications. Keep brief — detailed design belongs in the implementation plan.]

---

### Story 2: [Title]

[Same structure as Story 1]

---

[Continue for all stories...]

---

## Launch Checklist

Before marking this epic as Done:

- [ ] All P0 stories delivered and e2e tests passing
- [ ] All P1 stories delivered or explicitly deferred with rationale
- [ ] Success metrics have baseline measurements established
- [ ] No Critical or Important review findings remain (via /super-ralph:review-fix)
````
