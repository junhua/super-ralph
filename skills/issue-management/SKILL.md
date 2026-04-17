---
name: issue-management
description: "Create and manage GitHub Issues and Milestones following the [EPIC]/[STORY]/[FIX]/[CHORE] taxonomy. Use when /super-ralph:design, /super-ralph:finalise, or /super-ralph:release is invoked. Triggers on mentions of 'create epic', 'create story', 'file issue', 'filing bug', 'update project board', 'create milestone', 'sub-issue', 'FE/BE split', 'close issue', 'move to shipped', 'link PR to issue', 'GitHub issue taxonomy'."
---

> **Config:** Project-specific values (repo, org, project IDs, team members, paths) are loaded from `.claude/super-ralph-config.md` (auto-generated on first use by any super-ralph command).

# Issue Management

## Overview

Create, classify, and manage GitHub Issues for the monorepo using a strict taxonomy. Every issue gets a type tag, area label, and metadata via Project #$PROJECT_NUM fields. All issues live on the Project #$PROJECT_NUM board and follow a four-stage lifecycle from Todo to Shipped.

**Announce at start:** "I'm using the issue-management skill to create and manage GitHub Issues on the Project #$PROJECT_NUM board."

**Core insight:** Issues are the single source of truth for work scope. The taxonomy ([EPIC], [STORY], [FIX], [CHORE]) determines templates and sizing, the board column determines status, Milestones group EPICs into releases, and `Closes #N` in PRs automates lifecycle transitions. Getting the taxonomy right at creation time eliminates downstream confusion.

> All `$VARIABLE` references below (e.g., `$REPO`, `$ORG`, `$PROJECT_NUM`) resolve from `.claude/super-ralph-config.md`.

## Issue Taxonomy

### [EPIC] -- Feature Epic

A container issue that groups related [STORY] sub-issues into a functional module. Always has sub-issues. Attached to a Milestone.

- **Title format:** `[EPIC] Module or feature area title`
- **Labels:** `area/*`
- **Project fields:** Type=epic, Size, Priority
- **Milestone:** Attach to the active Milestone via `--milestone`
- **Sub-issues:** Yes, always ([STORY] issues)
- **Assignment:** Leave unassigned or assign to tech lead

### [STORY] -- User Story

A user-facing feature within an EPIC, written from a persona's perspective. The primary unit of product work. Each story should be independently implementable. Each STORY gets [FE] and [BE] sub-issues for concurrent frontend/backend development.

- **Title format:** `[STORY] Feature description`
- **Labels:** `vertical-slice`, `area/*`
- **Project fields:** Type=story, Size, Priority
- **Parent:** Always belongs to an [EPIC]
- **Sub-issues:** [FE] and [BE] sub-issues (created by /design for concurrent development)
- **Assignment:** None -- devs self-assign with `gh issue edit N --add-assignee @me`

### [FE] -- Frontend Sub-Issue

A frontend implementation task within a [STORY]. Created by /design for concurrent FE development.

- **Title format:** `[FE] Feature description — Frontend`
- **Labels:** `area/frontend`
- **Project fields:** Type=story, Size
- **Parent:** Always belongs to a [STORY]
- **Assignment:** None — FE devs self-assign

### [BE] -- Backend Sub-Issue

A backend implementation task within a [STORY]. Created by /design for concurrent BE/AI development.

- **Title format:** `[BE] Feature description — Backend`
- **Labels:** `area/backend`
- **Project fields:** Type=story, Size
- **Parent:** Always belongs to a [STORY]
- **Assignment:** None — BE devs self-assign

### [INT] -- Integration & Verification Sub-Issue

An integration sub-issue within a [STORY]. Owns the FE↔BE handshake: replacing mocks with real API client calls, running the Gherkin user journey as end-to-end tests, and verifying the deployed preview URL via `/super-ralph:verify`. Runs AFTER [BE] and [FE] are merged.

- **Title format:** `[INT] Feature description — Integration & E2E`
- **Labels:** `area/fullstack`, `integration`
- **Project fields:** Type=story, Size (typically S)
- **Parent:** Always belongs to a [STORY]
- **Assignment:** None — self-assigned by the integration agent or engineer
- **Depends on:** parent [STORY]'s [BE] and [FE] sub-issues (both merged)
- **Owns:** mock-to-real swap, full-journey E2E test execution, staging smoke verification

### [FIX] -- Bug Fix

A confirmed bug that needs fixing. Includes bugs, security vulnerabilities, and performance regressions.

- **Title format:** `[FIX] Bug description`
- **Labels:** `area/*`
- **Project fields:** Type=fix, Size, Priority
- **Parent:** Belongs to an [EPIC] or standalone
- **Sub-issues:** Optional
- **Assignment:** Assign to reporter or leave unassigned

### [CHORE] -- Technical Work

Non-user-facing technical work: DevOps, infrastructure, refactoring, test infrastructure, dependency upgrades, documentation. No user persona.

- **Title format:** `[CHORE] Task description`
- **Labels:** `area/*`
- **Project fields:** Type=chore, Size, Priority
- **Parent:** Belongs to an [EPIC] or standalone
- **Sub-issues:** No
- **Assignment:** Leave unassigned

### [QA] -- Test Verification

A test verification task against acceptance criteria. Run by testers ($TESTERS) or automated test suites. Typically created per-module when a milestone approaches UAT.

- **Title format:** `[QA] Module Name — N test cases`
- **Labels:** `area/*`
- **Project fields:** Type=qa, Size, Priority
- **Parent:** Belongs to a Milestone or [EPIC]
- **Sub-issues:** No
- **Assignment:** Assign to tester or leave unassigned

### [REQ] -- Feature Requirement (Legacy)

> **Note:** [REQ] is a legacy type from pre-v0.6.0. Existing [REQ] issues remain valid. For **new** work, use [STORY] for user-facing features or [CHORE] for technical tasks.

- **Title format:** `[REQ] Feature description`
- **Labels:** `area/*`
- **Project fields:** Type=story, Size, Priority

## Creating Issues

### [EPIC] with milestone

```bash
gh issue create --title "[EPIC] Feature Title" \
  --label "area/fullstack" \
  --milestone "v1.2" \
  --body "BODY" --repo $REPO
# Then add to Project #$PROJECT_NUM and set fields: Type=epic, Size=XL, Priority=P1
```

### [STORY] under an EPIC

```bash
gh issue create --title "[STORY] Feature description" \
  --label "vertical-slice,area/fullstack" \
  --body "**Parent:** #N\n\nBODY" --repo $REPO
# Then add to Project #$PROJECT_NUM and set fields: Type=story, Size=M, Priority=P1
# Then create [FE] and [BE] sub-issues (see below)
```

### [FE] under a STORY

```bash
gh issue create --title "[FE] Feature description — Frontend" \
  --label "area/frontend" \
  --body "**Parent:** #STORY_NUMBER\n\nBODY" --repo $REPO
# Then add to Project #$PROJECT_NUM and set fields: Type=story, Size
```

### [BE] under a STORY

```bash
gh issue create --title "[BE] Feature description — Backend" \
  --label "area/backend" \
  --body "**Parent:** #STORY_NUMBER\n\nBODY" --repo $REPO
# Then add to Project #$PROJECT_NUM and set fields: Type=story, Size
```

### [INT] under a STORY

```bash
gh issue create --title "[INT] Feature description — Integration & E2E" \
  --label "area/fullstack,integration" \
  --body "**Parent:** #STORY_NUMBER\n\nBODY" --repo $REPO
# Then add to Project #$PROJECT_NUM and set fields: Type=story, Size=S
```

### [FIX] for bugs

```bash
gh issue create --title "[FIX] Bug description" \
  --label "area/backend" \
  --body "BODY" --repo $REPO
# Then add to Project #$PROJECT_NUM and set fields: Type=fix, Size=S, Priority=P0
```

### [CHORE] for technical work

```bash
gh issue create --title "[CHORE] Task description" \
  --label "area/backend" \
  --body "BODY" --repo $REPO
# Then add to Project #$PROJECT_NUM and set fields: Type=chore, Size=M, Priority=P2
```

## Issue Body Templates

Use the templates in `references/issue-templates.md` for copy-paste-ready bodies. The templates below summarize the required structure for each type.

### EPIC Body

````markdown
## PM Summary

### What we're building
[2-3 sentences]

### Story Priority
| # | Story | User Value | Size | Can ship without? |

### Success Metrics
| Metric | Current | Target | How to Measure |

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
**Total:** Xh

### Waves
| Wave | Stories | Prereqs | Calendar |

## Notes
- **Dependencies:** ...
- **Risks:** ...
````

### [STORY] Body

````markdown
**Parent:** #[EPIC_NUMBER]

## User Story
**As a** [persona], **I want** [action], **So that** [outcome].
**Priority:** P0/P1/P2 | **Size:** S/M/L

## Acceptance Criteria (Gherkin)
```gherkin
Feature: [Story title]
  Background:
    Given I am logged in as [persona]
  Scenario: [HAPPY] ...
  Scenario: [EDGE] ...
  Scenario: [SECURITY] ...
```

## Shared Contract
```typescript
export type ResourceName = { ... };
```

## Sub-Issues
- [BE] #N — Backend implementation
- [FE] #N — Frontend implementation

## E2E Test Skeleton
```typescript
describe("[Story]", () => {
  test("[scenario]", async () => { ... });
});
```
````

### [FIX] Body

```markdown
### Bug Description
[What's wrong — observed vs expected behavior]

### Steps to Reproduce
1. [Step 1]
2. [Step 2]

### Root Cause
[If known — file path, function, logic error]

### Acceptance Criteria
- [ ] Bug no longer reproduces
- [ ] Regression test added
- [ ] No related regressions introduced
```

### [CHORE] Body

```markdown
### Task
[What technical work needs to be done and why]

### Category
[devops | infra | test | refactor | docs | deps]

### Done Criteria
- [ ] [Specific, verifiable outcome 1]
- [ ] [Specific, verifiable outcome 2]
- [ ] Tests pass: `$RUNTIME test` in affected service(s)
```

## Project Board Management

All issues must be added to the Project #$PROJECT_NUM board. See `references/project-board-ids.md` for the complete ID reference.

### Add issue to Project #$PROJECT_NUM

```bash
gh project item-add $PROJECT_NUM --owner $ORG --url URL
```

### Move item to a status column

```bash
# Move to In Progress
gh project item-edit --project-id $PROJECT_ID \
  --id ITEM_ID \
  --field-id $STATUS_FIELD_ID \
  --single-select-option-id $STATUS_IN_PROGRESS
```

### Status option IDs

| Status | Option ID |
|--------|-----------|
| Todo | `$STATUS_TODO` |
| In Progress | `$STATUS_IN_PROGRESS` |
| Pending Review | `$STATUS_PENDING_REVIEW` |
| Shipped | `$STATUS_SHIPPED` |

### Get item ID after adding to project

After adding an issue to the project, retrieve its item ID for status updates:

```bash
# Get item ID for an issue URL
gh project item-list $PROJECT_NUM --owner $ORG --format json \
  | jq -r '.items[] | select(.content.url == "ISSUE_URL") | .id'
```

## EPIC Planning Workflow

Follow these steps to create an EPIC with sub-issues.

### Step 1: Create the EPIC parent

Create the EPIC with a size label, attach to the active Milestone, and list all planned sub-issues:

```bash
gh issue create --title "[EPIC] Feature Title" \
  --label "size/XL,area/fullstack" \
  --milestone "v1.2" \
  --body "$(cat <<'EOF'
## Goal
[1-2 sentences]

## Tasks
- [ ] Sub-issue 1
- [ ] Sub-issue 2
- [ ] Sub-issue 3

## Notes
[Dependencies, design decisions]
EOF
)" --repo $REPO
```

> **Note:** Always attach EPICs to the active Milestone. Check `gh api repos/$REPO/milestones --jq '.[] | select(.state=="open")'` to find the current one.

### Step 2: Create [STORY] sub-issues with [FE], [BE], and [INT]

For each story in the epic, create a [STORY] issue linked to the parent, then create its [FE] and [BE] sub-issues:

```bash
# Create the STORY
STORY_URL=$(gh issue create --title "[STORY] Implement feature X" \
  --label "vertical-slice,area/fullstack" \
  --body "$(cat <<'EOF'
**Parent:** #EPIC_NUMBER

## User Story
**As a** [persona], **I want** [action], **So that** [outcome].
**Priority:** P1 | **Size:** M

## Acceptance Criteria (Gherkin)
...

## Shared Contract
...

## Sub-Issues
- [BE] #TBD — Backend implementation
- [FE] #TBD — Frontend implementation
EOF
)" --repo $REPO)

STORY_NUM=$(echo "$STORY_URL" | grep -o '[0-9]*$')

# Create the [BE] sub-issue
BE_URL=$(gh issue create --title "[BE] Implement feature X — Backend" \
  --label "area/backend" \
  --body "$(cat <<EOF
**Parent:** #${STORY_NUM}

## Shared Contract
See parent #${STORY_NUM} — Shared Contract section.

## Schema
...

## Service Interface
...

## Route Contract
...

## TDD Tasks
...
EOF
)" --repo $REPO)

BE_NUM=$(echo "$BE_URL" | grep -o '[0-9]*$')

# Create the [FE] sub-issue
FE_URL=$(gh issue create --title "[FE] Implement feature X — Frontend" \
  --label "area/frontend" \
  --body "$(cat <<EOF
**Parent:** #${STORY_NUM}

## Shared Contract
See parent #${STORY_NUM} — Shared Contract section.

## Mock Data
...

## Component Spec
...

## API Client
...

## i18n Keys
...

## TDD Tasks
...
EOF
)" --repo $REPO)

FE_NUM=$(echo "$FE_URL" | grep -o '[0-9]*$')

# Create the [INT] sub-issue
INT_URL=$(gh issue create --title "[INT] Implement feature X — Integration & E2E" \
  --label "area/fullstack,integration" \
  --body "$(cat <<EOF
**Parent:** #${STORY_NUM}
**Depends on:** [BE] #${BE_NUM}, [FE] #${FE_NUM}

## Scope
Replace FE mocks with real API client, run full Gherkin user journey as e2e tests, verify staging preview.

## Gherkin User Journey
See parent #${STORY_NUM} — Acceptance Criteria (Gherkin) section.

## Integration Tasks
...

## Verification Tasks
...
EOF
)" --repo $REPO)

INT_NUM=$(echo "$INT_URL" | grep -o '[0-9]*$')

# Update STORY body with actual sub-issue numbers
gh issue edit "$STORY_NUM" --body "..." --repo $REPO
```

### Step 3: Add all issues to Project #$PROJECT_NUM

```bash
# Add epic
gh project item-add $PROJECT_NUM --owner $ORG --url https://github.com/$REPO/issues/EPIC_NUMBER

# Add each story and its FE/BE sub-issues
gh project item-add $PROJECT_NUM --owner $ORG --url https://github.com/$REPO/issues/STORY_NUMBER
gh project item-add $PROJECT_NUM --owner $ORG --url https://github.com/$REPO/issues/FE_NUMBER
gh project item-add $PROJECT_NUM --owner $ORG --url https://github.com/$REPO/issues/BE_NUMBER
gh project item-add $PROJECT_NUM --owner $ORG --url https://github.com/$REPO/issues/INT_NUMBER
```

### Step 4: Set all to Todo status

Retrieve each item's project ID and set status to Todo:

```bash
# For each item
gh project item-edit --project-id $PROJECT_ID \
  --id ITEM_ID \
  --field-id $STATUS_FIELD_ID \
  --single-select-option-id $STATUS_TODO
```

## Issue Lifecycle

```
Created (Todo) --> Claimed (In Progress) --> PR created (Pending Review) --> Merged (Shipped)
```

### Transitions

| From | To | Trigger | Command |
|------|----|---------|---------|
| Todo | In Progress | Dev claims issue | `gh issue edit N --add-assignee @me` + move board to In Progress |
| In Progress | Pending Review | PR created | Include `Closes #N` in PR body + move board to Pending Review |
| Pending Review | Shipped | PR merged | Auto-close on merge moves to Shipped |

### Dev claims an issue

```bash
gh issue edit N --add-assignee @me
```

### PR links to issue

Include `Closes #N` in the PR body to auto-close the issue on merge:

```bash
gh pr create --title "feat: description" \
  --body "Closes #N\n\n## Summary\n..." \
  --repo $REPO
```

### Auto-close on merge

When a PR with `Closes #N` is merged, GitHub automatically closes issue #N. The Project #$PROJECT_NUM board automation moves closed issues to the Shipped column.

## Metadata: Project Fields (preferred) + Labels

### Project #$PROJECT_NUM Fields

Size, Type, and Priority are tracked via Project #$PROJECT_NUM single-select fields, not labels. After creating an issue and adding it to the project, set these fields:

| Field | Values |
|-------|--------|
| Size | `XS`(<0.5h) `S`(0.5-1h) `M`(1-3h) `L`(3-6h) `XL`(6-12h) |
| Type | `epic` `story` `fix` `chore` `qa` |
| Priority | `P0`(blocker) `P1`(must) `P2`(should) `P3`(nice) |

**Size rules:**
- **EPIC, STORY, FIX, CHORE:** Size field required.
- **[FE] and [BE] sub-issues:** Size field required (sum should approximate parent STORY size).
- **Other sub-issues of STORYs:** No size field — inherit scope from parent.

### Labels Reference

| Label | Used on | Purpose |
|-------|---------|---------|
| `vertical-slice` | STORY | Full-stack feature marker |
| `area/backend` | All, [BE] | Changes in `$BE_DIR/` |
| `area/frontend` | All, [FE] | Changes in `$FE_DIR/` |
| `area/fullstack` | All | Changes in both services |
| `blocked` | Any | Dependency blocker |
| `priority/critical` | Any | Hotfix auto-detection trigger (repair-domains) |
| `priority/urgent` | Any | Hotfix auto-detection trigger (repair-domains) |
| `security` | Any | Security domain trigger (repair-domains) |
| `integration` | [INT] | Integration + E2E marker |

> **Legacy:** Existing issues may have `size/*` labels from the previous convention. These remain valid but new issues should use Project #$PROJECT_NUM fields for size tracking.

## Milestones & Releases

### Milestone = Minor Version

Each GitHub Milestone represents a minor version release (e.g., `v1.2`). Milestones are the product-level planning layer above EPICs.

**Key rules:**
- Only **$PM_USER** (Product Manager) creates Milestones
- Each Milestone has a **business goal** in the description
- EPICs and standalone REQ/FIX issues are attached to Milestones
- Sub-issues do NOT need a milestone — they inherit from their parent
- Releases require **UAT sign-off** from $TESTERS

### Creating a Milestone

```bash
gh api repos/$REPO/milestones --method POST \
  -f title="v1.2" \
  -f description="Goal: Ship knowledge intelligence — vector search and LLM-powered suggestions" \
  -f due_on="2026-04-15T00:00:00Z"
```

### Attaching Issues to a Milestone

```bash
# Attach EPIC to milestone
gh issue edit 36 --milestone "v1.2" --repo $REPO

# Attach standalone REQ/FIX to milestone
gh issue edit 42 --milestone "v1.2" --repo $REPO
```

### Checking Milestone Progress

```bash
# List all milestones
gh api repos/$REPO/milestones \
  --jq '.[] | "\(.number) \(.title) — \(.open_issues) open / \(.closed_issues) closed"'

# List issues in a milestone
gh issue list --milestone "v1.2" --repo $REPO --state all

# Check if milestone is ready for UAT (0 open issues)
gh api repos/$REPO/milestones \
  --jq '.[] | select(.title=="v1.2") | "Open: \(.open_issues), Closed: \(.closed_issues)"'
```

### Milestone Execution Planning

Every milestone description should include an execution plan:

**AI-Hours Formula:** Size midpoints: XS=0.25, S=0.75, M=2, L=4.5, XL=9

**Wave Assignment Algorithm:**
1. List all stories, identify layers (schema, service, route, page)
2. Stories modifying schema.ts are Wave 0 (must run first)
3. Stories importing from services created in other stories depend on them
4. FE stories calling APIs from other stories depend on those BE stories
5. All remaining stories with no dependencies are Wave 0
6. Compute critical path (longest dependency chain)
7. Calendar time = critical path + 10% buffer

### UAT & Release Flow

When all EPICs in a Milestone are closed:

1. **$TESTERS test** using acceptance criteria from the EPICs
2. **Bugs -> [FIX] issues** attached to the same Milestone
3. **Devs fix** -> PRs close the [FIX] issues
4. **Re-test** until all testers ($TESTERS) sign off
5. **Tag the release:**
   ```bash
   git tag -a v1.2.0 -m "v1.2: Knowledge Intelligence"
   git push origin v1.2.0
   ```
6. **Close the milestone:**
   ```bash
   gh api repos/$REPO/milestones/MILESTONE_NUMBER \
     --method PATCH -f state="closed"
   ```

### Version Convention

`major.minor.patch`:
- **major** — Breaking API/platform changes ($PM_USER + $TECH_LEAD decide)
- **minor** — Feature release = GitHub Milestone ($PM_USER creates)
- **patch** — Bug fixes between minor releases ($TECH_LEAD tags, no UAT needed)

## Integration with super-ralph Pipeline

This skill connects to every other super-ralph command:

### /super-ralph:design --> issues

When `/super-ralph:design` creates epics and stories, also create corresponding `[EPIC]` issues on GitHub with `[STORY]` sub-issues for each story, and `[FE]` + `[BE]` sub-issues under each story. The epic document in `docs/epics/` is the design artifact; the GitHub issues are the tracking artifacts. Each STORY issue links to its FE and BE sub-issues for concurrent development.

### /super-ralph:build-story --> issue references

When `/super-ralph:build-story` executes a story, it claims the relevant [FE] or [BE] sub-issue and references the issue number throughout the build process:

```markdown
> **Tracks:** #42 ([BE] sub-issue), parent #40 ([STORY]), epic #38 ([EPIC])
```

### /super-ralph:review-fix --> PR with Closes

When `/super-ralph:review-fix` creates PRs, include `Closes #N` in the PR body to link the PR to the tracked issue.

### /super-ralph:finalise --> close and ship

When `/super-ralph:finalise` merges a PR:
1. The linked issue auto-closes via `Closes #N`
2. Move the board item to Shipped
3. If all sub-issues under a STORY are closed, close the STORY
4. If all STORYs under an EPIC are closed, close the EPIC
5. Update the plan document to mark the task as complete

## Autonomous Decision Pattern

When creating issues and ambiguity arises -- scope boundaries, label selection, sub-issue granularity -- apply the autonomous decision pattern:

1. Check existing issues for precedent (`gh issue list --repo $REPO`)
2. Check the product vision and roadmap for alignment
3. Pick the option most consistent with existing patterns
4. Document the decision in the issue body
5. Proceed -- NEVER wait for human input

## Team Roles

| Role | Issue Actions |
|------|--------------|
| **$PM_USER** (Product Manager) | Creates Milestones, defines business goals, prioritizes EPICs |
| **$TECH_LEAD** (Tech Lead) | Creates EPICs/sub-issues, reviews PRs |
| **$TESTERS** (Testers) | UAT testing, file [FIX] issues for bugs |
| Developers | Self-assign sub-issues, create PRs with `Closes #N` |

## References

- `references/issue-templates.md` -- Copy-paste-ready issue body templates for each type
- `references/project-board-ids.md` -- Project #$PROJECT_NUM field IDs and option IDs for board management
