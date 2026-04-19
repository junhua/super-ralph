# GitHub CLI Invocation Patterns

> Canonical patterns for creating, updating, and managing issues and project-board items
> via the GitHub CLI (`gh`). The skill body (`../SKILL.md`) describes WHICH issue type
> to create and WHY; this file shows exactly HOW to invoke `gh` for each case.
>
> Assumes project config variables (`$REPO`, `$ORG`, `$PROJECT_NUM`, `$PROJECT_ID`,
> `$STATUS_FIELD_ID`, `$STATUS_TODO`, `$STATUS_IN_PROGRESS`, `$STATUS_PENDING_REVIEW`,
> `$STATUS_SHIPPED`) are loaded from `.claude/super-ralph-config.md`.

## Issue Creation

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


## Project Board Management

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

## Bulk Add to Project + Set Default Status

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


## Issue Lifecycle Transitions

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

## Labels Reference

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


## Milestones

### Creating a Milestone

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

### Attaching Issues to a Milestone

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

### Checking Milestone Progress

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

## UAT & Release Flow Mechanics

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
