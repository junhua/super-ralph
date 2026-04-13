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

Parse the user's input for:
- **--pr** (optional): PR number to merge. If omitted, auto-detect from the current or most recent `super-ralph/*` branch.
- **--plan** (optional): Path to the implementation plan file. If omitted, auto-detect from the branch name.
- **--story** (optional): Epic story reference (`EPIC_PATH#story-N`) to mark as complete. If omitted, infer from the plan file's header.
- **--no-cleanup** (optional): If set, skip worktree and branch cleanup. Default: cleanup IS performed automatically.

## Workflow

Execute these steps in order. **Do NOT ask the user for input at any point.**

### Step 1: Identify Context

Determine the PR, branch, plan, and story to work with:

1. **Find the PR:**
   - If `--pr` provided: use it
   - Else: find the most recent open PR from a `super-ralph/*` branch:
     ```bash
     gh pr list --author "@me" --json number,headRefName,state --jq '[.[] | select(.headRefName | startswith("super-ralph/"))] | sort_by(.number) | last'
     ```

2. **Extract branch and merge info from the PR:**
   ```bash
   PR_INFO=$(gh pr view $PR_NUMBER --json headRefName,state,mergedAt,baseRefName,title,body)
   BRANCH=$(echo "$PR_INFO" | jq -r '.headRefName')
   BASE_BRANCH=$(echo "$PR_INFO" | jq -r '.baseRefName')
   ```

3. **Find the plan file:**
   - If `--plan` provided: use it
   - Else: derive from branch name:
     ```bash
     SLUG=$(echo "$BRANCH" | sed 's|super-ralph/||; s|/|-|g')
     PLAN_FILE=$(ls docs/plans/*${SLUG}*.md 2>/dev/null | head -1)
     ```

4. **Find the epic story:**
   - If `--story` provided: use it
   - Else: read the plan file and extract the `--story` reference from its header or Task 0

### Step 2: Merge PR

Merge the PR using squash merge (consolidates all commits into clean history):

1. **Verify PR is mergeable:**
   ```bash
   gh pr view $PR_NUMBER --json mergeable,mergeStateStatus --jq '{mergeable, mergeStateStatus}'
   ```

2. **Wait for CI checks** (if any are running):
   ```bash
   gh pr checks $PR_NUMBER --watch
   ```

3. **Merge:**
   ```bash
   gh pr merge $PR_NUMBER --squash --delete-branch
   ```

4. **If merge fails** (conflicts, branch protection, etc.):
   - Log the error
   - Output: `"PR #$PR_NUMBER could not be merged: [reason]. Resolve and retry."`
   - Stop — do NOT proceed to status updates

5. **If merge succeeds:**
   - Output: `"PR #$PR_NUMBER merged successfully."`
   - Pull the merged changes into the local default branch:
     ```bash
     git checkout "$BASE_BRANCH"
     git pull origin "$BASE_BRANCH"
     ```

### Step 2b: Close Related GitHub Issues

After PR merge, close any GitHub Issues linked to this work. Use multiple discovery methods (PR body, plan metadata, branch-to-issue matching) since not all PRs contain `Closes #N`.

1. **Discover issue numbers from ALL sources** (union of results):

   **Source A — PR body keywords** (macOS-compatible grep, no `-P` flag):
   ```bash
   PR_ISSUES=$(gh pr view $PR_NUMBER --json body --jq '.body' | grep -oE '(Closes|Fixes|Resolves) #[0-9]+' | grep -oE '[0-9]+' | sort -u)
   ```

   **Source B — Plan file metadata** (already read in Step 1):
   ```bash
   if [ -n "$PLAN_FILE" ]; then
     PLAN_ISSUES=$(grep -oE '(Closes|Fixes|Issue|#)[[:space:]]*#?[0-9]+' "$PLAN_FILE" | grep -oE '[0-9]+' | sort -u)
   fi
   ```

   **Source C — GitHub issue title matching** (match branch slug to issue title):
   ```bash
   SLUG=$(echo "$BRANCH" | sed 's|super-ralph/||; s|/|-|g; s|-| |g')
   TITLE_ISSUES=$(gh issue list --repo Forth-AI/work-ssot --state open --limit 200 --json number,title --jq ".[] | select(.title | ascii_downcase | contains(\"$(echo "$SLUG" | tr '[:upper:]' '[:lower:]')\")) | .number")
   ```

   **Merge all sources:**
   ```bash
   ISSUES=$(echo "$PR_ISSUES $PLAN_ISSUES $TITLE_ISSUES" | tr ' ' '\n' | sort -u | grep -v '^$')
   ```

2. **Close discovered issues (if not auto-closed):**
   ```bash
   for ISSUE in $ISSUES; do
     STATE=$(gh issue view $ISSUE --repo Forth-AI/work-ssot --json state --jq '.state')
     if [ "$STATE" = "OPEN" ]; then
       gh issue close $ISSUE --repo Forth-AI/work-ssot --comment "Shipped in PR #$PR_NUMBER" --reason completed
     fi
   done
   ```

3. **Move issues to "Shipped" on Project #9 board:**
   ```bash
   for ISSUE in $ISSUES; do
     ITEM_ID=$(gh project item-list 9 --owner Forth-AI --format json | \
       python3 -c "import json,sys; [print(i['id']) for i in json.load(sys.stdin)['items'] if i.get('content',{}).get('number')==$ISSUE]" 2>/dev/null)
     if [ -n "$ITEM_ID" ]; then
       gh project item-edit --project-id PVT_kwDOCrEjbc4BTqhr \
         --id "$ITEM_ID" \
         --field-id PVTSSF_lADOCrEjbc4BTqhrzhA3_Wc \
         --single-select-option-id 98236657
     fi
   done
   ```

4. **Check if parent [EPIC] issue should be closed:**
   If all sub-issues of an [EPIC] are now closed, close the parent too:
   ```bash
   for ISSUE in $ISSUES; do
     PARENT=$(gh issue view $ISSUE --repo Forth-AI/work-ssot --json body --jq '.body' | grep -oE 'Parent:[[:space:]]*#[0-9]+' | grep -oE '[0-9]+')
     if [ -n "$PARENT" ]; then
       OPEN_SUBS=$(gh issue list --repo Forth-AI/work-ssot --json body,state --jq "[.[] | select(.body | contains(\"Parent: #$PARENT\")) | select(.state==\"OPEN\")] | length")
       if [ "$OPEN_SUBS" = "0" ]; then
         gh issue close $PARENT --repo Forth-AI/work-ssot --comment "All sub-issues shipped. Epic complete." --reason completed
       fi
     fi
   done
   ```

5. **Check if Milestone is ready for UAT:**
   If an EPIC was just closed, check if its Milestone has 0 remaining open issues:
   ```bash
   for ISSUE in $ISSUES; do
     MILESTONE=$(gh issue view $ISSUE --repo Forth-AI/work-ssot --json milestone --jq '.milestone.title // empty')
     if [ -n "$MILESTONE" ]; then
       OPEN_COUNT=$(gh api repos/Forth-AI/work-ssot/milestones --jq ".[] | select(.title==\"$MILESTONE\") | .open_issues")
       if [ "$OPEN_COUNT" = "0" ]; then
         echo "Milestone '$MILESTONE' has 0 open issues — ready for UAT by Amy & Faye."
         echo "   After UAT sign-off: git tag -a ${MILESTONE}.0 -m '${MILESTONE}: <description>'"
       fi
     fi
   done
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
<!-- PR: #NNN (merged) -->
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

### Step 5: Update Roadmap

Sync `docs/roadmap.md` to reflect the completed work. This step is **idempotent** — if the roadmap already reflects the current state, skip it and move on.

1. **Read the roadmap:**
   ```bash
   # Read docs/roadmap.md
   ```

2. **Identify what to update.** Using the epic/story reference, PR numbers, and plan info gathered in Step 1, determine which roadmap sections reference this work. Search for the epic name, story references (e.g., "Kernel Story 6"), and PR numbers.

3. **Update the Epic Map table.** Find the row for the relevant epic and:
   - Bump the story count (e.g., `6/8 done` → `7/8 done`)
   - If all stories are done, change status to `Completed` (e.g., `7/7 done (Story 7 remaining) | In Progress` → `7/7 done | Completed`)
   - Skip if the row already shows the correct count and status

4. **Update the MVP-Required Work table.** If the completed story maps to an MVP item:
   - Strike through the item name with `~~` if not already
   - Add `**DONE**` marker with PR reference if not already present
   - Skip items that are already marked done

5. **Update the MVP-Adjacent table.** Same logic as MVP-Required:
   - Strike through and add `**DONE**` marker with PR reference
   - Skip items already marked done

6. **Update the MVP Execution Order.** If the completed work appears in the execution order list:
   - Change the line to include `✅ DONE` with PR reference
   - Skip lines already marked done

7. **Update the MVP lifecycle diagram.** If the completed work maps to a lifecycle stage:
   - Change `[todo]` → `[done]` for the relevant stage
   - Skip stages already marked done

8. **Update Phase checklist items.** Find the relevant `- [ ]` item in the Phase sections and:
   - Change `[ ]` → `[x]`
   - Append epic/story reference and PR number if not already present (e.g., `— **COMPLETED** (work-agents#16)`)
   - Skip items already checked `[x]`

9. **Update Phase headers.** After updating checklist items, recalculate phase completion:
   - Count `[x]` vs total items in the phase
   - If all items are checked, change the header to `— COMPLETE` (e.g., `## Phase 2: Core Platform — COMPLETE`)
   - If partially done, update the percentage estimate (e.g., `~60% Complete` → `~80% Complete`)
   - Skip headers that already show `COMPLETE` if all items are indeed done

10. **Write and commit** (only if changes were made):
    ```bash
    git add docs/roadmap.md
    git commit -m "docs: update roadmap — <brief description of what changed>"
    ```

### Step 6: Worktree Cleanup

Clean up the worktree for this branch. **Cleanup runs by default** unless `--no-cleanup` was passed.

1. **Prune stale worktree references** first:
   ```bash
   git worktree prune
   ```

2. **Check if a worktree exists** for this branch:
   ```bash
   git worktree list | grep "$BRANCH"
   ```

3. If a worktree exists:
   - If cleanup enabled (default): remove immediately with `--force` (worktrees always have untracked files like node_modules, .claude/, build artifacts):
     ```bash
     WORKTREE_PATH=$(git worktree list | grep "$BRANCH" | awk '{print $1}')
     git worktree remove --force "$WORKTREE_PATH"
     ```
   - If `--no-cleanup`: report the worktree path:
     ```
     Worktree at <path> can be removed with: git worktree remove --force <path>
     ```

### Step 7: Branch Cleanup

After worktree removal, clean up branches. **Only runs if cleanup is enabled.**

1. **Check if the branch is the current branch:**
   ```bash
   CURRENT=$(git branch --show-current)
   if [ "$CURRENT" = "$BRANCH" ]; then
     echo "WARNING: Cannot delete current branch. Switch to another branch first."
     # Skip branch cleanup
   fi
   ```

2. **Delete local branch** (force delete since worktree was just removed):
   ```bash
   git branch -D "$BRANCH"
   ```

3. **Delete remote branch** (only if not already deleted by `--delete-branch` during merge):
   ```bash
   if git ls-remote --heads origin "$BRANCH" | grep -q "$BRANCH"; then
     git push origin --delete "$BRANCH"
   fi
   ```

### Step 8: Generate Summary & Suggest Next Steps

1. **Gather metrics:**
   ```bash
   # Commits in the merged branch (from squash commit message or PR)
   gh pr view $PR_NUMBER --json additions,deletions,changedFiles,commits
   ```

2. **Output a summary:**
   ```markdown
   # Finalised: <feature-name>

   - **PR:** #NNN (merged)
   - **Plan:** docs/plans/<file> → COMPLETED
   - **Epic Story:** <story-ref> → COMPLETED
   - **Roadmap:** Updated
   - **Issues:** #[list] → Closed and moved to Shipped
   - **Milestone:** <vX.Y> — N open / M closed (or "ready for UAT" if 0 open)
   - **Cleanup:** Worktree removed, branches deleted
   ```

3. **Suggest next steps** based on current state:
   - If more stories remain in the epic: `"Next story: /super-ralph:plan --story EPIC#story-N+1"`
   - If epic is complete: list remaining epics or suggest next phase
   - If plan has incomplete tasks: `"Resume with: /super-ralph:build <plan-path>"`

## Critical Rules

- **Auto-detect everything.** The user should be able to run `/super-ralph:finalise` with no arguments after review-fix creates a PR and get a complete merge + status update.
- **Never lose data.** Only ADD markers to plan/epic/roadmap files — never delete existing content.
- **Commit from the right directory.** Plan, epic, and roadmap files live in the root repo, not the worktree. Ensure commits happen in the correct git context (switch to default branch first).
- **Idempotent.** Running finalise twice should not create duplicate markers or commits. The roadmap step should detect already-updated items and skip them.
- **Cleanup defaults to ON.** Worktree and branch cleanup happen automatically unless `--no-cleanup` is passed. Use `--force` for worktree removal (untracked files are expected).
- **Roadmap sync is mandatory.** The roadmap update always runs — it keeps `docs/roadmap.md` in sync with epic/story state so the roadmap never drifts stale.
- **NEVER ask for human input** during any step.
- **Stop on merge failure.** If the PR cannot be merged, do NOT proceed to status updates — the project state should only update after code is actually on the default branch.
