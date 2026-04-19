# Phase 5: Finalise Sub-Agent

> Canonical spec for Phase 5 of `/super-ralph:build-story` — merge the PR, update
> the project board, cascade-close parent `[STORY]`/`[EPIC]` when all children
> closed. Skipped when `--skip-finalise` is passed.
>
> See also `../../release-flow/SKILL.md` for the broader finalise/release model.

### Phase 5: Finalise

**Skip if `--skip-finalise` was passed.** Write `status: SKIPPED` to final-result.md and output summary.

**Goal:** Merge the PR into staging and update project status.

This phase runs **inline** (not as a sub-agent) since it's quick and the orchestrator has all the context.

**Mode-specific finalise branches:**

- When `$MODE = local`: execute steps 1-5 below (PR merge + deployment health), then **skip steps 6 (issue close), 7 (project-board move), 8 (plan marker), 10 (parent-epic auto-close via gh)**. Instead run the local-mode step 9L below which flips the `**Status:**` line in the epic file and auto-prints the release hint when all stories are COMPLETED.
- When `$MODE = github`: execute all steps 1-10 as today.

### Local-mode finalise step 9L

After step 5 (Vercel staging deployment health verified), run:

```bash
EPIC_FILE="${STORY_REF%%#*}"
STORY_NUM=$(echo "${STORY_REF#*#}" | awk -F- '{print $2}')
${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh set-status "$EPIC_FILE" "$STORY_NUM" COMPLETED

# Stamp PR + branch into the <!-- PR: --> and <!-- Branch: --> comments under the story heading
awk -v n="$STORY_NUM" -v pr="$PR_NUMBER" -v br="super-ralph/$STORY_SLUG" '
  function story_num(line,   s) { s=line; sub(/^### Story /, "", s); return s+0 }
  /^### Story [0-9]+:/ { in_story = (story_num($0) == n+0) ? 1 : 0 }
  in_story && /<!-- PR: -->/     { sub(/<!-- PR: -->/, "<!-- PR: #" pr " -->") }
  in_story && /<!-- Branch: -->/ { sub(/<!-- Branch: -->/, "<!-- Branch: " br " -->") }
  { print }
' "$EPIC_FILE" > "$EPIC_FILE.tmp" && mv "$EPIC_FILE.tmp" "$EPIC_FILE"

git add "$EPIC_FILE"
git commit -m "docs: mark Story ${STORY_NUM} as COMPLETED in $(basename "$EPIC_FILE" .md)"
git push origin staging

# Check epic completion
PENDING_COUNT=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh list-stories "$EPIC_FILE" \
  | awk '{ if ($NF != "COMPLETED") c++ } END { print c+0 }')
if [ "$PENDING_COUNT" = "0" ]; then
  echo "Epic complete. Ready for: /super-ralph:release"
fi
```

Then write `$STORY_DIR/final-result.md` with `mode: local`, `pr_merged: true`, `epic_file: $EPIC_FILE`, `story_num: $STORY_NUM`, `epic_complete: [true|false]`.

1. **Ensure on staging:**
   ```bash
   git checkout staging
   git pull origin staging
   ```

2. **Wait for CI checks:**
   ```bash
   gh pr checks $PR_NUMBER --repo $REPO --watch
   ```

3. **Merge PR** (squash into staging):
   ```bash
   gh pr merge $PR_NUMBER --squash --delete-branch --repo $REPO
   ```

4. **Pull merged changes:**
   ```bash
   git pull origin staging
   ```

5. **Verify staging deployment health:**

   **Do NOT skip.** Wait for Vercel CD to deploy staging and verify the deployment is healthy before proceeding. Merge success != deployment success.

   ```bash
   echo "Waiting for Vercel staging deployment..."
   DEPLOY_OK=false
   for i in $(seq 1 36); do
     STATUS_URL=$(gh api repos/$REPO/deployments \
       --jq '[.[] | select(.ref=="staging")] | first | .statuses_url' 2>/dev/null)
     if [ -n "$STATUS_URL" ]; then
       STATE=$(gh api "$STATUS_URL" --jq '.[0].state' 2>/dev/null)
       if [ "$STATE" = "success" ]; then
         DEPLOY_OK=true
         echo "Staging deployment succeeded."
         break
       elif [ "$STATE" = "error" ] || [ "$STATE" = "failure" ]; then
         echo "STAGING DEPLOYMENT FAILED: state=$STATE"
         break
       fi
     fi
     sleep 10
   done
   ```

   If deployment fails: report the failure in `final-result.md` with `deploy_status: FAILED` and warn. If healthy: proceed.

6. **Close related issues:**
   ```bash
   # Auto-close should work via "Closes #N" in PR body
   # Verify and force-close if needed:
   STATE=$(gh issue view $STORY_ID --repo $REPO --json state --jq '.state')
   if [ "$STATE" = "OPEN" ]; then
     gh issue close $STORY_ID --repo $REPO --comment "Shipped in PR #$PR_NUMBER"
   fi
   ```

7. **Move to Shipped on Project #9:**
   ```bash
   ITEM_ID=$(gh project item-list $PROJECT_NUM --owner $ORG --format json | \
     python3 -c "import json,sys; [print(i['id']) for i in json.load(sys.stdin)['items'] if i.get('content',{}).get('number')==$STORY_ID]" 2>/dev/null)
   if [ -n "$ITEM_ID" ]; then
     gh project item-edit --project-id $PROJECT_ID \
       --id "$ITEM_ID" \
       --field-id $STATUS_FIELD_ID \
       --single-select-option-id $STATUS_SHIPPED
   fi
   ```

8. **Update plan status** (mark as completed):
   ```bash
   # Add completion marker to plan file
   PLAN_PATH=$(grep "plan_path:" "$STORY_DIR/plan-result.md" | awk '{print $2}')
   ```
   Prepend `<!-- Status: COMPLETED -->` and `<!-- PR: #$PR_NUMBER -->` to the plan file.
   ```bash
   git add "$PLAN_PATH"
   git commit -m "plan: mark $(basename $PLAN_PATH .md) as completed"
   git push origin staging
   ```

9. **Update epic story status** (if story came from an epic):
   Read the epic file, find the story section, add completion marker.
   ```bash
   git add docs/epics/
   git commit -m "epic: mark $STORY_SLUG as completed"
   git push origin staging
   ```

10. **Check if parent epic is complete:**
   If all sub-issues of the parent epic are now closed:
   ```bash
   if [ -n "$PARENT_EPIC" ]; then
     OPEN_SUBS=$(gh issue list --repo $REPO --json body,state \
       --jq "[.[] | select(.body | test(\"Parent:?\\s*#$PARENT_EPIC\"; \"i\")) | select(.state==\"OPEN\")] | length")
     if [ "$OPEN_SUBS" = "0" ]; then
       gh issue close $PARENT_EPIC --repo $REPO --comment "All stories shipped. Epic complete."
       echo "Epic #$PARENT_EPIC complete — all stories shipped."
       echo "Ready for: /super-ralph:release"
     fi
   fi
   ```

11. **Cleanup worktree:**
    ```bash
    git worktree prune
    WORKTREE_PATH=$(git worktree list | grep "super-ralph/$STORY_SLUG" | awk '{print $1}')
    if [ -n "$WORKTREE_PATH" ]; then
      git worktree remove --force "$WORKTREE_PATH"
    fi
    ```

12. **Write result** to `$STORY_DIR/final-result.md`:
    ```
    phase: finalise
    status: DONE
    pr_number: $PR_NUMBER
    pr_merged: true
    deploy_status: [HEALTHY|FAILED|PENDING]
    issue_closed: #$STORY_ID
    epic_complete: [true|false]
    branch_deleted: true
    worktree_cleaned: true
    ```

13. Update `$STORY_DIR/progress.md`: Finalise → DONE

### Step 6: Summary

Output the final summary:

```markdown
# Story Complete: $STORY_TITLE

| Phase | Status | Details |
|-------|--------|---------|
| Plan | ✅ | $TASK_COUNT tasks, $MODE mode |
| Build | ✅ | $TASKS_COMPLETED/$TASK_COUNT tasks, $TEST_RESULTS |
| Review-Fix | ✅ | $ITERATIONS iterations, $FINDINGS_FIXED fixes, PR #$PR_NUMBER |
| Verify | ✅/⏭️ | $CRITERIA_PASSED/$CRITERIA_TOTAL criteria |
| Finalise | ✅/⏭️ | PR #$PR_NUMBER merged into staging |

**Branch:** super-ralph/$STORY_SLUG (deleted)
**PR:** #$PR_NUMBER (merged)
**Issue:** #$STORY_ID (closed)
**Plan:** $PLAN_PATH (completed)
**Epic:** #$PARENT_EPIC — [N remaining stories | complete]

## Next Steps
[context-dependent suggestions]
```

Next step suggestions:
- If epic has more stories: `"Next: /super-ralph:build-story #NEXT_STORY_ID"`
- If epic is complete: `"Epic done. Release with: /super-ralph:release"`
- If verify failed: `"Verify had failures. Run: /super-ralph:repair [failure description]"`

Output completion promise: `STORY_COMPLETE`

---

## Error Recovery
