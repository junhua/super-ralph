---
name: update
description: "Update project status after development — mark plans/stories done, generate summary, clean up worktrees"
argument-hint: "[--plan PATH] [--story EPIC_PATH#STORY_ID] [--branch BRANCH] [--cleanup]"
allowed-tools: ["Bash(git:*)", "Bash(gh:*)", "Bash(bun:*)", "Read", "Write", "Edit", "Glob", "Grep", "Task"]
---

# Super-Ralph Update Command

Update project status after a development cycle completes. Marks plan tasks as done, updates epic stories to completed, generates a development summary, and optionally cleans up worktrees.

This command is the bookkeeping step after `/super-ralph:launch` or `/super-ralph:review-fix` finishes. It closes the loop by reconciling what was built against what was planned.

## Arguments

Parse the user's input for:
- **--plan** (optional): Path to the implementation plan file. If omitted, auto-detect from the current branch name or recent worktree activity.
- **--story** (optional): Epic story reference (`EPIC_PATH#story-N`) to mark as complete. If omitted, infer from the plan's `--story` header.
- **--branch** (optional): The feature branch to analyze. Default: current branch or most recent `super-ralph/*` branch.
- **--cleanup** (optional): If set, remove the worktree after updating. Default: false (prompt user).

## Workflow

Execute these steps in order. **Do NOT ask the user for input at any point** (except worktree cleanup confirmation if `--cleanup` not set).

### Step 1: Identify What Was Built

Determine the scope of the completed development:

1. **Find the branch:**
   - If `--branch` provided: use it
   - Else if inside a worktree: detect from `git branch --show-current`
   - Else: find the most recent `super-ralph/*` branch:
     ```bash
     git branch --sort=-committerdate --list 'super-ralph/*' | head -1
     ```

2. **Find the plan file:**
   - If `--plan` provided: use it
   - Else: derive from branch name (reverse of launch's slug derivation):
     ```bash
     # e.g. super-ralph/auth-api → docs/plans/*auth-api.md
     SLUG=$(echo "$BRANCH" | sed 's|super-ralph/||')
     ```
   - Search: `ls docs/plans/*${SLUG}*.md 2>/dev/null`

3. **Find the epic story:**
   - If `--story` provided: use it
   - Else: read the plan file and extract the `--story` reference from its header or Task 0

4. **Find associated PRs:**
   ```bash
   gh pr list --head "$BRANCH" --json number,title,state,mergedAt --jq '.'
   ```

### Step 2: Gather Development Metrics

Collect metrics from the completed development cycle:

1. **Commit history:**
   ```bash
   DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')
   git log --oneline "$DEFAULT_BRANCH".."$BRANCH"
   ```

2. **Files changed:**
   ```bash
   git diff --stat "$DEFAULT_BRANCH".."$BRANCH"
   ```

3. **Review-fix iterations** (if review-fix was used):
   ```bash
   git log --oneline --grep="review-fix" "$DEFAULT_BRANCH".."$BRANCH" | wc -l
   ```

4. **Test results:**
   ```bash
   # Auto-detect test runner
   if [ -f bun.lock ] || [ -f bun.lockb ]; then
     bun test 2>&1 | tail -5
   elif [ -f package.json ]; then
     npm test 2>&1 | tail -5
   fi
   ```

5. **PR status:**
   ```bash
   gh pr view --json state,mergedAt,reviewDecision,statusCheckRollup
   ```

### Step 3: Update Plan Status

Read the plan file and update task completion markers:

1. Read the plan file
2. For each task in the plan, check if its progress check command passes:
   - If the task has a `**Progress check:**` line, run the command
   - Mark passing tasks with `[x]` (completed)
   - Mark failing tasks with `[ ]` (incomplete) and note what failed
3. Update the plan file's header with completion status:

```markdown
<!-- Status: COMPLETED | PARTIAL -->
<!-- Completed at: YYYY-MM-DD -->
<!-- Branch: super-ralph/feature-name -->
<!-- PR: #NNN (merged|open) -->
```

4. Write the updated plan file
5. Commit:
   ```bash
   git add docs/plans/<file>
   git commit -m "plan: mark <plan-name> as completed"
   ```

### Step 4: Update Epic Story Status

If an epic story reference was found:

1. Read the epic file
2. Find the referenced story section
3. Add a completion marker to the story:

```markdown
<!-- Story Status: COMPLETED -->
<!-- Completed: YYYY-MM-DD -->
<!-- PR: #NNN -->
<!-- Plan: docs/plans/YYYY-MM-DD-slug.md -->
```

4. If ALL stories in the epic are now completed, add an epic-level completion marker:

```markdown
<!-- Epic Status: COMPLETED -->
<!-- Completed: YYYY-MM-DD -->
```

5. Write the updated epic file
6. Commit:
   ```bash
   git add docs/epics/<file>
   git commit -m "epic: mark story <story-id> as completed"
   ```

### Step 5: Generate Development Summary

Create a structured summary of the development cycle:

```markdown
# Development Summary: <feature-name>

## What Was Built
- [1-3 sentence description based on plan goal and PR title]

## Key Metrics
- **Commits:** N total (M implementation, K review-fix)
- **Files changed:** N files (+additions, -deletions)
- **Review-fix iterations:** N (if applicable)
- **PR:** #NNN (state)

## Tasks Completed
- [x] Task 1: description
- [x] Task 2: description
- [ ] Task N: description (if incomplete — note reason)

## Test Results
- [pass/fail summary from test run]

## Notable Decisions
[Any architectural decisions made by SME agents during execution — extracted from commit messages and code comments]
```

Output this summary to the console. Do NOT write it to a file unless `--output` is specified.

### Step 6: Worktree Cleanup

Check if a worktree exists for this branch:

```bash
git worktree list | grep "$BRANCH"
```

If a worktree exists:
- If `--cleanup` was set: remove it immediately
  ```bash
  WORKTREE_PATH=$(git worktree list | grep "$BRANCH" | awk '{print $1}')
  git worktree remove "$WORKTREE_PATH"
  ```
- If `--cleanup` was NOT set: report the worktree path and suggest cleanup:
  ```
  Worktree at <path> can be removed with: git worktree remove <path>
  ```

### Step 7: Suggest Next Steps

Based on the current state, suggest what to do next:

1. **If PR is merged and story completed:**
   - "Development complete. Next story: `/super-ralph:plan --story EPIC#story-N+1`"

2. **If PR is merged but more stories remain:**
   - List remaining stories with their priorities
   - Suggest the next P0 story for planning

3. **If PR is open but review-fix is clean:**
   - "PR #NNN is ready to merge. Run: `gh pr merge NNN --squash`"

4. **If PR has failing checks:**
   - "PR #NNN has failing checks. Run: `/super-ralph:review-fix --pr NNN`"

5. **If plan has incomplete tasks:**
   - List incomplete tasks
   - Suggest: "Resume with: `/super-ralph:launch <plan-path> --max-iterations N`"

## Critical Rules

- **Auto-detect everything.** The user should be able to run `/super-ralph:update` with no arguments after a development cycle and get a complete status update.
- **Never lose data.** Only ADD markers to plan/epic files — never delete existing content.
- **Commit from the right directory.** Plan and epic files live in the root repo, not the worktree. Ensure commits happen in the correct git context.
- **Idempotent.** Running update twice should not create duplicate markers or commits.
- **NEVER ask for human input** during status update. Only exception: worktree cleanup without `--cleanup` flag.
