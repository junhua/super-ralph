# Hotfix Backport

> Canonical procedure for the hotfix backport branch when a repair targets
> production (main). Enables fast-track ship without waiting for the next
> staging → main promotion.

### Step 9: Hotfix Backport (hotfix only)

**Only runs if `IS_HOTFIX=true` AND finalise succeeded.**

After merging to main, the fix must also land on staging to prevent regression when the next release merges staging→main.

1. **Get the merge commit SHA:**
   ```bash
   MERGE_SHA=$(gh pr view $PR_NUMBER --repo $REPO --json mergeCommit --jq '.mergeCommit.oid')
   ```

2. **Cherry-pick to staging:**
   ```bash
   git checkout staging
   git pull origin staging
   git cherry-pick "$MERGE_SHA" --no-commit
   git commit -m "fix(backport): cherry-pick hotfix from PR #$PR_NUMBER

   Backported from main to staging.
   Original fix: $PROBLEM_SUMMARY"
   ```

3. **If cherry-pick conflicts:**
   - Attempt auto-resolution: `git checkout --theirs . && git add .`
   - If that fails, dispatch sme-brainstormer to analyze conflicts
   - Last resort: `git cherry-pick --abort` and create a manual backport issue:
     ```bash
     gh issue create --repo $REPO \
       --title "[FIX] Backport hotfix PR #$PR_NUMBER to staging" \
       --label "size/S,area/backend" \
       --body "Hotfix PR #$PR_NUMBER was merged to main but failed to cherry-pick to staging. Manual backport required.

     **Conflict files:** [list]
     **Original fix:** $PROBLEM_SUMMARY"
     ```

4. **Push staging:**
   ```bash
   git push origin staging
   ```

5. **Run regression tests on staging:**
   ```bash
   $BE_TEST_CMD
   $FE_TEST_CMD
   ```
   - If tests fail: dispatch issue-fixer to resolve, commit, push

6. **Report:**
   ```
   Hotfix backported to staging via cherry-pick.
   Staging tests: [PASS/FAIL]
   ```

Update progress: Backport → DONE
