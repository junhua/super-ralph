---
name: issue-management
description: "Create and manage GitHub Issues and Milestones following the [EPIC]/[STORY]/[FIX]/[CHORE] taxonomy. Use when /super-ralph:design, /super-ralph:finalise, or /super-ralph:release is invoked. Triggers on mentions of 'create epic', 'create story', 'file issue', 'filing bug', 'update project board', 'create milestone', 'sub-issue', 'FE/BE split', 'close issue', 'move to shipped', 'link PR to issue', 'GitHub issue taxonomy'."
---

> **Config:** Project-specific values (repo, org, project IDs, team members, paths) are loaded from `.claude/super-ralph-config.md` (auto-generated on first use by any super-ralph command).

# Issue Management

## Overview

Create, classify, and manage GitHub Issues for the monorepo using a strict taxonomy. Every issue gets a type tag, area label, and metadata via Project #$PROJECT_NUM fields. All issues live on the Project #$PROJECT_NUM board and follow a four-stage lifecycle from Todo to Shipped.

**Announce at start:** "I'm using the issue-management skill to create and manage GitHub Issues on the Project #$PROJECT_NUM board."

**Core insight:** Issues are the single source of truth for work scope. The taxonomy ([EPIC], [STORY], [FIX], [CHORE]) determines templates and sizing; the board column determines status; Milestones group EPICs into releases; `Closes #N` in PRs automates lifecycle transitions. Getting the taxonomy right at creation time eliminates downstream confusion.

> All `$VARIABLE` references below (e.g., `$REPO`, `$ORG`, `$PROJECT_NUM`) resolve from `.claude/super-ralph-config.md`.

## Issue Taxonomy (decision tree)

| Is it… | Type | Parent | Sub-issues | Key labels |
|--------|------|--------|------------|------------|
| A feature container grouping stories into a module | `[EPIC]` | Milestone (optional) | `[STORY]`s | `area/*` |
| A user-facing feature (persona + action + outcome) | `[STORY]` | `[EPIC]` | `[BE]` + `[FE]` + `[INT]` | `vertical-slice`, `area/fullstack` |
| Frontend implementation of a story | `[FE]` | `[STORY]` | None | `area/frontend` |
| Backend implementation of a story | `[BE]` | `[STORY]` | None | `area/backend` |
| Mock→real swap, Gherkin E2E, staging verify | `[INT]` | `[STORY]` | None | `area/fullstack`, `integration` |
| Confirmed bug | `[FIX]` | `[EPIC]` or standalone | Optional | `area/*` |
| Non-user-facing technical work (DevOps, refactor, deps) | `[CHORE]` | `[EPIC]` or standalone | None | `area/*` |
| Test verification against AC (UAT) | `[QA]` | Milestone or `[EPIC]` | None | `area/*` |

### Per-type details

- **[EPIC]** — Container for stories in a functional module. Project fields: `Type=epic, Size, Priority`. Attach to Milestone via `--milestone`. Assignment: leave unassigned or assign to tech lead.
- **[STORY]** — Primary unit of product work. Independently implementable. Project fields: `Type=story, Size, Priority`. Assignment: none (devs self-assign).
- **[FE] / [BE]** — Per-layer implementation tasks created by `/super-ralph:design` for concurrent development. Project field: `Type=story, Size`. Unassigned by default.
- **[INT]** — Runs AFTER `[BE]` and `[FE]` are merged. Owns the FE↔BE handshake, Gherkin E2E run, and `/super-ralph:verify` against staging.
- **[FIX]** — Bug, security vuln, or perf regression. Title: `[FIX] Bug description`.
- **[CHORE]** — DevOps, infrastructure, refactoring, test infra, dependency upgrades, documentation. No user persona.
- **[QA]** — Test verification task typically created per-module when a milestone approaches UAT. Title: `[QA] Module Name — N test cases`.
- **[REQ]** (legacy) — Pre-v0.6.0 type. Existing issues remain valid. For new work use `[STORY]` (user-facing) or `[CHORE]` (technical).

## Creating Issues

The exact `gh issue create` invocation for each type — including label flags, body heredocs, milestone attachment, and sub-issue parent references — lives in **`references/gh-invocation-patterns.md`**. The skill body describes which type to create; the reference shows how.

Canonical body templates for each type are in **`references/issue-templates.md`** (the narrative EPIC body with PM Summary + Execution Plan, STORY body with Gherkin AC, [FIX] body, [CHORE] body, etc.).

After creating any issue, add it to Project #$PROJECT_NUM and set the Type/Size/Priority fields. See `references/gh-invocation-patterns.md` § "Project Board Management" and `references/project-board-ids.md` for the field/option IDs.

## Issue Lifecycle

Every issue flows through four board columns:

| Column | Meaning | Trigger |
|--------|---------|---------|
| **Todo** | Created, not started | Issue created |
| **In Progress** | Dev self-assigned, branch open | `gh issue edit --add-assignee @me` + branch push |
| **Pending Review** | PR opened, awaiting review | PR opened with `Closes #N` |
| **Shipped** | PR merged to staging/main | Auto-close via `Closes #N` + board move |

**Transitions:** see `references/gh-invocation-patterns.md` § "Issue Lifecycle Transitions" for exact `gh project item-edit` commands.

**Dev claims an issue:**
```bash
gh issue edit N --add-assignee @me --repo $REPO
```

**PR links to issue:** include `Closes #N` in the PR body — GitHub auto-closes the issue and the board hook moves it to Shipped on merge.

**Cascade close on merge:**
1. Linked issue auto-closes via `Closes #N`
2. Board item moves to Shipped
3. If all sub-issues under a `[STORY]` are closed, close the `[STORY]`
4. If all `[STORY]`s under an `[EPIC]` are closed, close the `[EPIC]`

## Labels

Labels classify issues for filtering; Project fields carry structured metadata (Type, Size, Priority). Use labels for `area/*` (routing) and `vertical-slice` / `integration` (workflow markers). Full catalog in `references/gh-invocation-patterns.md` § "Labels Reference".

## Milestones = Minor Versions

| Version bump | Trigger | Owner |
|--------------|---------|-------|
| **major** | Breaking public API change | $PM_USER + $TECH_LEAD |
| **minor** | Feature release = GitHub Milestone | $PM_USER creates |
| **patch** | Bug fixes between minor releases | $TECH_LEAD tags, no UAT |

Milestone mechanics — creation, attaching issues, progress check, UAT/release flow — live in `references/gh-invocation-patterns.md` § "Milestones" and § "UAT & Release Flow Mechanics".

## Metadata: Project Fields (preferred) + Labels

Project #$PROJECT_NUM has the following structured fields. Prefer these over labels when available:

- **Type** — epic / story / chore / fix / qa
- **Size** — XS / S / M / L / XL (maps to AI-hours)
- **Priority** — P0 / P1 / P2
- **Status** — Todo / In Progress / Pending Review / Shipped

Field IDs and option IDs are in `references/project-board-ids.md`.

## Integration with super-ralph Pipeline

| Command | Role of this skill |
|---------|-------------------|
| `/super-ralph:design` | Creates `[EPIC]` + `[STORY]` + `[BE]` + `[FE]` + `[INT]` using the taxonomy and templates here |
| `/super-ralph:build-story` | References the issue number throughout the build: `Tracks: #42 ([BE] sub-issue), parent #40 ([STORY]), epic #38 ([EPIC])` |
| `/super-ralph:review-fix` | Creates PRs with `Closes #N` to link PR to the tracked issue |
| `/super-ralph:finalise` | On merge: auto-close via `Closes #N` → move to Shipped → cascade-close parent `[STORY]` / `[EPIC]` when all children closed |

## Autonomous Decision Pattern

When ambiguity arises — scope boundaries, label selection, sub-issue granularity:

1. Check existing issues for precedent (`gh issue list --repo $REPO`)
2. Check the product vision and roadmap for alignment
3. Pick the option most consistent with existing patterns
4. Document the decision in the issue body
5. Proceed — NEVER wait for human input

## Team Roles

| Role | Issue Actions |
|------|---------------|
| **$PM_USER** (Product Manager) | Creates Milestones, defines business goals, prioritizes EPICs |
| **$TECH_LEAD** (Tech Lead) | Creates EPICs/sub-issues, reviews PRs |
| **$TESTERS** (Testers) | UAT testing, file `[FIX]` issues for bugs |
| Developers | Self-assign sub-issues, create PRs with `Closes #N` |

## References

- `references/issue-templates.md` — Copy-paste-ready issue body templates for each type (EPIC, STORY, BE, FE, INT, FIX, CHORE, QA)
- `references/gh-invocation-patterns.md` — Exact `gh` CLI commands: issue creation, project-board mutations, lifecycle transitions, labels, milestones, UAT/release flow
- `references/project-board-ids.md` — Project #$PROJECT_NUM field IDs and option IDs for board management

### Sibling skills

- `../product-design/SKILL.md` — Produces the epics and stories this skill tracks
- `../design-review/SKILL.md` — Validates the issues before `/super-ralph:build-story` consumes them
