# Issue Body Templates

Copy-paste-ready issue body templates for each issue type in the ForthAI Work monorepo.

## [EPIC] -- Feature Epic

Use for feature container issues that group sub-issues. Attach to a Milestone.

```markdown
## Goal
[1-2 sentences describing the feature objective]

## Tasks
- [ ] Sub-issue 1 — [brief description]
- [ ] Sub-issue 2 — [brief description]
- [ ] Sub-issue 3 — [brief description]

## Notes
- **Dependencies:** [What must exist before this epic can start]
- **Design decisions:** [Key architectural or product decisions]
- **Risks:** [What could go wrong, with mitigation]
```

### Example

```markdown
## Goal
Build the real-time case streaming infrastructure so that case detail and dashboard pages update live without polling.

## Tasks
- [ ] SSE streaming endpoint for individual cases
- [ ] SSE streaming endpoint for dashboard aggregates
- [ ] React hook for case-level streaming
- [ ] React hook for dashboard-level streaming
- [ ] Wire case detail page to streaming hook
- [ ] Wire dashboard page to streaming hook

## Notes
- **Dependencies:** Case CRUD API must be deployed
- **Design decisions:** SSE over WebSockets for simplicity; reconnect with exponential backoff
- **Risks:** Hono SSE adapter compatibility with Bun runtime — verify in Task 1
```

## [STORY] -- User Story

Use for user-facing features that belong to an [EPIC]. Written from a persona's perspective.

```markdown
**Parent:** #[EPIC_NUMBER]

## User Story
**As a** [specific persona — not "user"],
**I want** [concrete capability],
**So that** [measurable business value].

## Context
[Why this story exists, how it fits the parent EPIC]

## Acceptance Criteria

### AC-1: Happy path
**Given** [precondition with specific data]
**When** [specific action]
**Then** [verifiable outcome]

### AC-2: Edge case
**Given** [boundary condition]
**When** [action at boundary]
**Then** [graceful handling]

### AC-3: Error case
**Given** [invalid state or input]
**When** [action]
**Then** [specific error response]

## Vertical Slice
| Layer | File | Action |
|-------|------|--------|
| [Schema/Service/Route/Types/i18n/Page] | `[file path]` | [Create/Modify] |

## Implementation Notes
[Patterns to follow, files to reference, constraints]
```

### Example

```markdown
**Parent:** #241

## User Story
**As a** sales manager,
**I want** to view a kanban board of my team's pipeline,
**So that** I can see deal distribution across stages at a glance.

## Context
Part of the Sales/CRM Pipeline MVP. The board is the primary interface for day-to-day pipeline management.

## Acceptance Criteria

### AC-1: Board renders with stage columns
**Given** I have deals in stages "Qualification", "Proposal", "Negotiation"
**When** I navigate to the pipeline page
**Then** I see 3 columns with the correct deals in each

### AC-2: Empty pipeline
**Given** I have no deals
**When** I navigate to the pipeline page
**Then** I see empty columns with a "Create your first deal" prompt

### AC-3: Stage with many deals
**Given** I have 50 deals in "Qualification"
**When** I scroll within the column
**Then** deals paginate smoothly without full page reload

## Vertical Slice
| Layer | File | Action |
|-------|------|--------|
| Schema | `work-agents/src/db/schema.ts` | Add pipeline_stages |
| Service | `work-agents/src/services/pipeline.ts` | Create |
| Route | `work-agents/src/routes/pipeline.ts` | Create |
| Types | `work-web/src/lib/types.ts` | Add PipelineStage, Deal |
| i18n | `work-web/src/i18n/en.ts` | Add sales.pipeline keys |
| Page | `work-web/src/app/(dashboard)/sales/pipeline/page.tsx` | Create |
```

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
- [ ] Tests pass: `bun test` in affected service(s)

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
- [ ] `bun --version` returns 1.2.x in work-agents, work-web, and work-www
- [ ] All existing tests pass: `bun test` in each service
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
- **Service:** [work-agents | work-web | work-www]
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
- **Service:** work-web
- **Branch/commit:** main @ c3266ba
```

## Sub-issue (of a STORY)

Use for granular sub-tasks when a [STORY] is too large for a single PR. No tag prefix, no size field, no assignee. Rare — most STORYs are implemented as a single unit.

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
| API | `work-agents/src/routes/case-stream.ts` | Create |
| Service | `work-agents/src/services/case-stream.ts` | Create |
| Types | `work-agents/src/types/stream.ts` | Modify |
| Test | `work-agents/src/routes/case-stream.test.ts` | Create |

### Acceptance criteria
- [ ] `GET /api/cases/:id/stream` returns `Content-Type: text/event-stream`
- [ ] Events are sent when case status changes
- [ ] Client receives initial state on connection
- [ ] Connection closes cleanly on client disconnect
- [ ] Test covers happy path and disconnect scenarios
```
