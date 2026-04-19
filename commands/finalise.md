---
name: finalise
description: "Merge a review-clean PR and update project status — plan, epic, roadmap, worktree, branches"
argument-hint: "[--pr NUMBER] [--plan PATH] [--story EPIC_PATH#STORY_ID] [--no-cleanup]"
allowed-tools: ["Bash(git:*)", "Bash(gh:*)", "Bash(bun:*)", "Read", "Write", "Edit", "Glob", "Grep", "Task"]
---

# Super-Ralph Finalise Command

Merge a review-clean PR and close the development loop. Updates plan tasks to done, marks epic stories as completed, syncs the roadmap, cleans up worktrees and branches, and suggests next steps.

This command runs after `/super-ralph:review-fix` creates a clean PR. It handles all the "paperwork" — the transition from code-done to project-status-updated.

## Arguments

- **`--pr`** (optional): PR number to merge. If omitted, auto-detect from the current or most recent `super-ralph/*` branch.
- **`--plan`** (optional): Path to the implementation plan file. If omitted, auto-detect from the branch name.
- **`--story`** (optional): Epic story reference (`EPIC_PATH#story-N`) to mark as complete. If omitted, infer from the plan file's header.
- **`--no-cleanup`** (optional): Skip worktree and branch cleanup. Default: cleanup IS performed.

## Workflow

Execute the 8-step per-story finalise flow defined by the `super-ralph:release-flow` skill. **Do NOT ask the user for input at any point.**

### Step 0: Load Project Config & Skill

Read `.claude/super-ralph-config.md` to load every `$VARIABLE` used by the skill and its references (`$REPO`, `$ORG`, `$PROJECT_NUM`, `$PROJECT_ID`, `$STATUS_FIELD_ID`, `$STATUS_SHIPPED`, `$APP_URL`, plus `$MAIN_BRANCH` / `$STAGING_BRANCH` when available).

Invoke the `super-ralph:release-flow` skill for the per-story finalise procedure (Flow A). Also invoke `super-ralph:issue-management` for board/cascade-close mechanics and `super-ralph:deployment-verification` for CD health-check.

### Step 1: Execute the 8-Step Finalise

Follow `${CLAUDE_PLUGIN_ROOT}/skills/release-flow/references/finalise-flow.md`:

1. Identify context (PR, linked issues, plan file, story ref)
2. Merge PR with `gh pr merge --squash --delete-branch`
3. Verify deployment health (CD must succeed before marking Shipped)
4. Cascade-close GitHub issues (linked → `[STORY]` → `[EPIC]` when children all closed)
5. Update plan file task status
6. Update epic story `**Status:** PENDING` → `**Status:** COMPLETED` (local mode) — GitHub mode handled by cascade close
7. Update roadmap (milestone progress, module status)
8. Worktree & branch cleanup (unless `--no-cleanup`)

### Step 2: Summary

Emit the final summary with next-step suggestions (another story to build, a release to cut, etc.). Template in `references/finalise-flow.md` § "Step 8: Generate Summary & Suggest Next Steps".

## Critical Rules

- **Never force-push to shared branches.** A rewrite of staging breaks every open worktree.
- **Merge success ≠ shipped.** Deployment health must be verified before cascading any Shipped status.
- **Cascade close is conservative.** Only close `[STORY]` when ALL sub-issues closed; only close `[EPIC]` when ALL stories closed.
- **Worktree cleanup last.** Never `cd` into a worktree then `git worktree remove` it.
- **No destructive ops without explicit consent.** `--no-cleanup` exists for a reason; don't reinterpret "clean up" as "delete unmerged work".
