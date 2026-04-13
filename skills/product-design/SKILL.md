---
name: product-design
description: This skill should be used when writing epics and user stories from product vision, business goals, or user feedback. Triggers when /super-ralph:design is invoked, or when the user mentions "write epics", "create user stories", "product design", "acceptance criteria", "feature breakdown", "e2e test scenarios", or wants to translate business goals into structured development artifacts. Produces BDD-style acceptance criteria that feed directly into /super-ralph:plan as e2e test scaffolding.
---

# Product Design — Epics & Stories

## Overview

Translate product vision, business goals, and user feedback into structured epics and user stories with BDD acceptance criteria. The acceptance criteria serve dual purpose: defining "done" for stakeholders AND generating e2e/behavior test scaffolding for implementation plans.

**Announce at start:** "I'm using the product-design skill to create epics and stories with testable acceptance criteria."

**Core insight:** Acceptance criteria written in Given/When/Then format are directly translatable to e2e test cases. This creates traceability from business goal to passing test — every story is verifiable by a machine.

## The Outside-In Pipeline

```
Vision / Goals / Feedback
    ↓ /super-ralph:design
Epic (docs/epics/YYYY-MM-DD-<slug>.md)
    ├── Story 1 → Acceptance Criteria → E2E Test Skeleton
    ├── Story 2 → Acceptance Criteria → E2E Test Skeleton
    └── Story N → Acceptance Criteria → E2E Test Skeleton
    ↓ /super-ralph:plan --story <path>#story-N
Implementation Plan (docs/plans/YYYY-MM-DD-<slug>.md)
    ├── Task 0: E2E test from acceptance criteria (outer RED)
    ├── Task 1-N: TDD implementation tasks (inner red-green)
    └── Final: E2E test goes GREEN
```

The outer e2e test starts red and stays red until all inner TDD tasks complete. When it goes green, the story is delivered.

## Epic Structure

Every epic follows the template in `references/epic-template.md`.

### Required Sections

1. **Title** — Clear, outcome-focused name
2. **Business Context** — Why this epic exists, what business problem it solves
3. **Success Metrics** — Measurable outcomes (not output metrics like "feature shipped")
4. **Personas** — Who benefits and how (reference product vision personas)
5. **Scope** — What's in and explicitly what's out
6. **Stories** — Ordered list of user stories with acceptance criteria
7. **Dependencies** — What must exist before this epic can start
8. **Risks** — What could go wrong, with mitigation strategies

### Sizing Guidelines

| Epic Size | Stories | Implementation Plans | Suitable For |
|-----------|---------|---------------------|--------------|
| Small | 2-4 | 1 plan | Single feature or improvement |
| Medium | 5-8 | 1-2 plans | Feature set or workflow |
| Large | 9-15 | 2-4 plans (phased) | Major capability or system |
| Too Large | 15+ | Split into multiple epics | — |

## Story Structure

Every story follows the template in `references/story-template.md`.

### Format

```markdown
### Story N: [Title]

**As a** [persona from product vision],
**I want to** [specific action],
**so that** [measurable outcome].

**Priority:** P0 (must-have) | P1 (should-have) | P2 (nice-to-have)
**Size:** S | M | L | XL
```

### Acceptance Criteria (BDD Format)

Write every acceptance criterion in Given/When/Then format. Each criterion becomes one e2e test case.

```markdown
#### Acceptance Criteria

- [ ] **Given** I am on the agent builder page
      **When** I select a template and click "Create"
      **Then** a new agent is created with the template's default configuration
      **And** I am redirected to the agent editor

- [ ] **Given** I have an agent in draft status
      **When** I click "Deploy"
      **Then** the agent status changes to "Active"
      **And** a confirmation message shows the agent's endpoint
```

Rules for good acceptance criteria:
- One observable behavior per criterion
- No implementation details (test WHAT, not HOW)
- Include both happy path and key error paths
- Every criterion must be machine-verifiable via UI or API test
- Use concrete values where possible ("shows 3 items" not "shows items")

### E2E Test Skeleton

Generate a test skeleton from the acceptance criteria. This skeleton feeds into `/super-ralph:plan` as the outer test loop.

```typescript
// tests/e2e/[story-slug].test.ts
describe("[Story title]", () => {
  test("creates agent from template", async () => {
    // Given: on agent builder page
    // When: select template and click Create
    // Then: new agent created, redirected to editor
  });

  test("deploys draft agent", async () => {
    // Given: agent in draft status
    // When: click Deploy
    // Then: status = Active, confirmation shown
  });
});
```

## Writing Good Epics and Stories

### Deriving from Vision

Read the product vision document and extract:
- **Personas** — Map story "As a..." to vision's target users
- **Capabilities** — Map stories to vision's solution pillars
- **Principles** — Ensure stories respect vision's core principles
- **Non-goals** — Reject stories that conflict with stated non-goals

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

When ambiguity arises during epic/story creation — scope boundaries, persona priorities, acceptance criteria precision — apply the same autonomous decision pattern used throughout super-ralph:

1. Dispatch research-agent for market/competitor/UX references
2. Dispatch 1-2 sme-brainstormer agents to evaluate options
3. Pick the option with strongest evidence
4. Document the decision in the epic
5. Proceed — NEVER wait for human input

## Integration with super-ralph Pipeline

### Feeding into /super-ralph:plan

When invoking `/super-ralph:plan` with a story reference:

```
/super-ralph:plan --story docs/epics/2026-02-16-agent-builder.md#story-1
```

The plan command should:
1. Read the referenced story and its acceptance criteria
2. Generate e2e test file as Task 0 (outer RED)
3. Generate TDD implementation tasks (inner cycles)
4. Set completion criteria: e2e tests pass (outer GREEN)

### Story-to-Plan Mapping

| Story Element | Plan Element |
|---|---|
| Acceptance criteria (Given/When/Then) | E2E test cases (Task 0) |
| Priority (P0/P1/P2) | Task ordering |
| Size (S/M/L/XL) | Iteration budget |
| Dependencies | Plan prerequisites section |

## Output Location

1. Save epics to `docs/epics/YYYY-MM-DD-<slug>.md` (create the directory if needed)
2. Create `[EPIC]` issue on GitHub with sub-issues for each story (see GitHub Issue Creation section)
3. Add all issues to Project #9 board

## GitHub Issue Creation

After writing the epic markdown file, also create GitHub Issues to track the work on the ForthAI Work Project #9 board.

### Creating an [EPIC] Issue from an Epic

After saving the epic to `docs/epics/`, create a corresponding `[EPIC]` issue:

```bash
gh issue create \
  --title "[EPIC] <Epic title>" \
  --label "area/<backend|frontend|fullstack>" \
  --milestone "<active milestone>" \
  --body "$(cat <<'EOF'
## Goal
<Epic business context — 1-2 sentences>

## Stories
<Checklist of [STORY] items from the epic>

## Epic Document
docs/epics/YYYY-MM-DD-<slug>.md

## Notes
<Dependencies, risks from the epic>
EOF
)" --repo Forth-AI/work-ssot
# Add to Project #9, set fields: Type=epic, Size, Priority
```

### Creating [STORY] Issues from Stories

For each story in the epic, create a `[STORY]` issue:

```bash
gh issue create \
  --title "[STORY] <Story title>" \
  --label "vertical-slice,area/<backend|frontend|fullstack>" \
  --body "$(cat <<'EOF'
**Parent:** #<epic-issue-number>

## User Story
**As a** <persona>,
**I want** <action>,
**So that** <outcome>.

## Acceptance Criteria
<BDD criteria from the story>
EOF
)" --repo Forth-AI/work-ssot
# Add to Project #9, set fields: Type=story, Size, Priority
```

**Rules:**
- [STORY] issues use the `[STORY]` title prefix
- Size is set via Project #9 field, not labels
- [STORY] issues are NOT pre-assigned (devs self-assign)
- Add all issues to Project #9: `gh project item-add 9 --owner Forth-AI --url <issue-url>`

### Epic Size Mapping

| Epic Size | Stories | Project Field |
|-----------|---------|---------------|
| Small (2-4 stories) | 2-4 | Size=L |
| Medium (5-8 stories) | 5-8 | Size=XL |
| Large (9+ stories) | 9+ | Split into multiple `[EPIC]` issues |

## References

- `references/epic-template.md` — Complete fill-in-the-blanks epic template
- `references/story-template.md` — Story template with BDD acceptance criteria and e2e skeleton
- `references/acceptance-criteria-guide.md` — Detailed guide for writing machine-verifiable acceptance criteria
