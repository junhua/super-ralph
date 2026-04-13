---
name: issue-management
description: "Create and manage GitHub Issues and Milestones following the [EPIC]/[STORY]/[FIX]/[CHORE] taxonomy. Use when creating EPICs, stories, filing bugs, tracking requirements, managing milestones/releases, or syncing the ForthAI Work Project #9 board. Triggers on /super-ralph:issues or mentions of 'create epic', 'create story', 'file issue', 'update board', 'create milestone', 'release'."
---

# Issue Management

## Overview

Create, classify, and manage GitHub Issues for the ForthAI Work monorepo using a strict taxonomy. Every issue gets a type tag, area label, and metadata via Project #9 fields. All issues live on the Project #9 board and follow a four-stage lifecycle from Todo to Shipped.

**Announce at start:** "I'm using the issue-management skill to create and manage GitHub Issues on the ForthAI Work Project #9 board."

**Core insight:** Issues are the single source of truth for work scope. The taxonomy ([EPIC], [STORY], [FIX], [CHORE]) determines templates and sizing, the board column determines status, Milestones group EPICs into releases, and `Closes #N` in PRs automates lifecycle transitions. Getting the taxonomy right at creation time eliminates downstream confusion.

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

A user-facing feature within an EPIC, written from a persona's perspective. The primary unit of product work. Each story should be independently implementable.

- **Title format:** `[STORY] Feature description`
- **Labels:** `vertical-slice`, `area/*`
- **Project fields:** Type=story, Size, Priority
- **Parent:** Always belongs to an [EPIC]
- **Sub-issues:** Optional (for complex stories)
- **Assignment:** None -- devs self-assign with `gh issue edit N --add-assignee @me`

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

A test verification task against acceptance criteria. Run by testers (Amy, Faye) or automated test suites. Typically created per-module when a milestone approaches UAT.

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
  --body "BODY" --repo Forth-AI/work-ssot
# Then add to Project #9 and set fields: Type=epic, Size=XL, Priority=P1
```

### [STORY] under an EPIC

```bash
gh issue create --title "[STORY] Feature description" \
  --label "vertical-slice,area/backend" \
  --body "**Parent:** #N\n\nBODY" --repo Forth-AI/work-ssot
# Then add to Project #9 and set fields: Type=story, Size=M, Priority=P1
```

### [FIX] for bugs

```bash
gh issue create --title "[FIX] Bug description" \
  --label "area/backend" \
  --body "BODY" --repo Forth-AI/work-ssot
# Then add to Project #9 and set fields: Type=fix, Size=S, Priority=P0
```

### [CHORE] for technical work

```bash
gh issue create --title "[CHORE] Task description" \
  --label "area/backend" \
  --body "BODY" --repo Forth-AI/work-ssot
# Then add to Project #9 and set fields: Type=chore, Size=M, Priority=P2
```

## Issue Body Templates

Use the templates in `references/issue-templates.md` for copy-paste-ready bodies. The templates below summarize the required structure for each type.

### EPIC Body

```markdown
## Goal
[1-2 sentences describing the feature objective]

## Stories
- [ ] [STORY] Story 1 -- [brief description]
- [ ] [STORY] Story 2 -- [brief description]

## Notes
[Dependencies, design decisions, risks]
```

### [STORY] Body

```markdown
**Parent:** #N

## User Story
**As a** [persona],
**I want** [capability],
**So that** [business value].

## Acceptance Criteria

### AC-1: Happy path
**Given** [precondition]
**When** [action]
**Then** [outcome]

### AC-2: Edge case
**Given** [boundary condition]
**When** [action]
**Then** [graceful handling]

## Vertical Slice
| Layer | File | Action |
|-------|------|--------|
| API | `work-agents/src/routes/foo.ts` | Create |
| DB | `work-agents/src/db/schema.ts` | Modify |
| UI | `work-web/src/app/.../page.tsx` | Create |
```

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
- [ ] Tests pass: `bun test` in affected service(s)
```

## Project Board Management

All issues must be added to the ForthAI Work Project #9 board. See `references/project-board-ids.md` for the complete ID reference.

### Add issue to Project #9

```bash
gh project item-add 9 --owner Forth-AI --url URL
```

### Move item to a status column

```bash
# Move to In Progress
gh project item-edit --project-id PVT_kwDOCrEjbc4BTqhr \
  --id ITEM_ID \
  --field-id PVTSSF_lADOCrEjbc4BTqhrzhA3_Wc \
  --single-select-option-id 47fc9ee4
```

### Status option IDs

| Status | Option ID |
|--------|-----------|
| Todo | `f75ad846` |
| In Progress | `47fc9ee4` |
| Pending Review | `3eb0a766` |
| Shipped | `98236657` |

### Get item ID after adding to project

After adding an issue to the project, retrieve its item ID for status updates:

```bash
# Get item ID for an issue URL
gh project item-list 9 --owner Forth-AI --format json \
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
)" --repo Forth-AI/work-ssot
```

> **Note:** Always attach EPICs to the active Milestone. Check `gh api repos/Forth-AI/work-ssot/milestones --jq '.[] | select(.state=="open")'` to find the current one.

### Step 2: Create [STORY] sub-issues

For each story in the epic, create a [STORY] issue linked to the parent:

```bash
gh issue create --title "[STORY] Implement feature X endpoint" \
  --label "vertical-slice,area/backend" \
  --body "$(cat <<'EOF'
**Parent:** #EPIC_NUMBER

## User Story
**As a** [persona],
**I want** [action],
**So that** [outcome].

## Acceptance Criteria
- [ ] **Given** ... **When** ... **Then** ...

## Vertical Slice
| Layer | File | Action |
|-------|------|--------|

EOF
)" --repo Forth-AI/work-ssot
# Add to Project #9 and set fields: Type=story, Size, Priority
```

### Step 3: Add all issues to Project #9

```bash
# Add epic
gh project item-add 9 --owner Forth-AI --url https://github.com/Forth-AI/work-ssot/issues/EPIC_NUMBER

# Add each sub-issue
gh project item-add 9 --owner Forth-AI --url https://github.com/Forth-AI/work-ssot/issues/SUB_NUMBER
```

### Step 4: Set all to Todo status

Retrieve each item's project ID and set status to Todo:

```bash
# For each item
gh project item-edit --project-id PVT_kwDOCrEjbc4BTqhr \
  --id ITEM_ID \
  --field-id PVTSSF_lADOCrEjbc4BTqhrzhA3_Wc \
  --single-select-option-id f75ad846
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
  --repo Forth-AI/work-ssot
```

### Auto-close on merge

When a PR with `Closes #N` is merged, GitHub automatically closes issue #N. The Project #9 board automation moves closed issues to the Shipped column.

## Metadata: Project Fields (preferred) + Labels

### Project #9 Fields

Size, Type, and Priority are tracked via Project #9 single-select fields, not labels. After creating an issue and adding it to the project, set these fields:

| Field | Values |
|-------|--------|
| Size | `XS`(<0.5h) `S`(0.5-1h) `M`(1-3h) `L`(3-6h) `XL`(6-12h) |
| Type | `epic` `story` `fix` `chore` `qa` |
| Priority | `P0`(blocker) `P1`(must) `P2`(should) `P3`(nice) |

**Size rules:**
- **EPIC, STORY, FIX, CHORE:** Size field required.
- **Sub-issues of STORYs:** No size field — inherit scope from parent.

### Labels Reference

| Label | Used on | Purpose |
|-------|---------|---------|
| `vertical-slice` | STORY | Full-stack feature marker |
| `area/backend` | All | Changes in `work-agents/` |
| `area/frontend` | All | Changes in `work-web/` |
| `area/fullstack` | All | Changes in both services |
| `blocked` | Any | Dependency blocker |
| `priority/critical` | Any | Hotfix auto-detection trigger (repair-domains) |
| `priority/urgent` | Any | Hotfix auto-detection trigger (repair-domains) |
| `security` | Any | Security domain trigger (repair-domains) |

> **Legacy:** Existing issues may have `size/*` labels from the previous convention. These remain valid but new issues should use Project #9 fields for size tracking.

## Milestones & Releases

### Milestone = Minor Version

Each GitHub Milestone represents a minor version release (e.g., `v1.2`). Milestones are the product-level planning layer above EPICs.

**Key rules:**
- Only **Jeph** (Product Manager) creates Milestones
- Each Milestone has a **business goal** in the description
- EPICs and standalone REQ/FIX issues are attached to Milestones
- Sub-issues do NOT need a milestone — they inherit from their parent
- Releases require **UAT sign-off** from Amy and Faye

### Creating a Milestone

```bash
gh api repos/Forth-AI/work-ssot/milestones --method POST \
  -f title="v1.2" \
  -f description="Goal: Ship knowledge intelligence — vector search and LLM-powered suggestions" \
  -f due_on="2026-04-15T00:00:00Z"
```

### Attaching Issues to a Milestone

```bash
# Attach EPIC to milestone
gh issue edit 36 --milestone "v1.2" --repo Forth-AI/work-ssot

# Attach standalone REQ/FIX to milestone
gh issue edit 42 --milestone "v1.2" --repo Forth-AI/work-ssot
```

### Checking Milestone Progress

```bash
# List all milestones
gh api repos/Forth-AI/work-ssot/milestones \
  --jq '.[] | "\(.number) \(.title) — \(.open_issues) open / \(.closed_issues) closed"'

# List issues in a milestone
gh issue list --milestone "v1.2" --repo Forth-AI/work-ssot --state all

# Check if milestone is ready for UAT (0 open issues)
gh api repos/Forth-AI/work-ssot/milestones \
  --jq '.[] | select(.title=="v1.2") | "Open: \(.open_issues), Closed: \(.closed_issues)"'
```

### UAT & Release Flow

When all EPICs in a Milestone are closed:

1. **Amy & Faye test** using acceptance criteria from the EPICs
2. **Bugs → [FIX] issues** attached to the same Milestone
3. **Devs fix** → PRs close the [FIX] issues
4. **Re-test** until both Amy and Faye sign off
5. **Tag the release:**
   ```bash
   git tag -a v1.2.0 -m "v1.2: Knowledge Intelligence"
   git push origin v1.2.0
   ```
6. **Close the milestone:**
   ```bash
   gh api repos/Forth-AI/work-ssot/milestones/MILESTONE_NUMBER \
     --method PATCH -f state="closed"
   ```

### Version Convention

`major.minor.patch`:
- **major** — Breaking API/platform changes (Jeph + Junhua decide)
- **minor** — Feature release = GitHub Milestone (Jeph creates)
- **patch** — Bug fixes between minor releases (Junhua tags, no UAT needed)

## Integration with super-ralph Pipeline

This skill connects to every other super-ralph command:

### /super-ralph:design --> issues

When `/super-ralph:design` creates epics and stories, also create corresponding `[EPIC]` issues on GitHub with `[STORY]` sub-issues for each story. The epic document in `docs/epics/` is the design artifact; the GitHub issues are the tracking artifacts.

### /super-ralph:plan --> issue references

When `/super-ralph:plan` creates implementation plans, reference issue numbers in the plan header:

```markdown
> **Tracks:** #42 (sub-issue), parent #40 ([EPIC])
```

### /super-ralph:review-fix --> PR with Closes

When `/super-ralph:review-fix` creates PRs, include `Closes #N` in the PR body to link the PR to the tracked issue.

### /super-ralph:finalise --> close and ship

When `/super-ralph:finalise` merges a PR:
1. The linked issue auto-closes via `Closes #N`
2. Move the board item to Shipped
3. If all sub-issues under an EPIC are closed, close the EPIC
4. Update the plan document to mark the task as complete

## Autonomous Decision Pattern

When creating issues and ambiguity arises -- scope boundaries, label selection, sub-issue granularity -- apply the autonomous decision pattern:

1. Check existing issues for precedent (`gh issue list --repo Forth-AI/work-ssot`)
2. Check the product vision and roadmap for alignment
3. Pick the option most consistent with existing patterns
4. Document the decision in the issue body
5. Proceed -- NEVER wait for human input

## Team Roles

| Name | Role | Issue Actions |
|------|------|--------------|
| **Jeph** | Product Manager | Creates Milestones, defines business goals, prioritizes EPICs |
| **Junhua** | Tech Lead | Creates EPICs/sub-issues, reviews PRs |
| **Amy** | Internal Tester | UAT testing, files [FIX] issues for bugs |
| **Faye** | Internal Tester | UAT testing, files [FIX] issues for bugs |
| **Jei / Tao / Twissa** | Developers | Self-assign sub-issues, create PRs with `Closes #N` |

## References

- `references/issue-templates.md` -- Copy-paste-ready issue body templates for each type
- `references/project-board-ids.md` -- Project #9 field IDs and option IDs for board management
