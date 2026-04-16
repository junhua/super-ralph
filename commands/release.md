---
name: release
description: "QA staging, Codex-review PR to main, merge, seal a version — comprehensive promotion gate"
argument-hint: "[--milestone NAME] [--tag VERSION] [--no-verify] [--no-codex]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)", "Bash(git:*)", "Bash(gh:*)", "Bash(bun:*)", "Bash(codex:*)", "Read", "Write", "Edit", "Glob", "Grep", "Task"]
---

# Super-Ralph Release Command

Promote staging to production: pre-flight checks, QA verification on staging, create staging→main PR, Codex CLI review + fix loop, merge to main, tag, milestone closure, release notes, cleanup. Runs as a ralph-loop with subagent-driven orchestration.

### Step 0: Load Project Config

Read `.claude/super-ralph-config.md` to load project-specific values. If the file does not exist, stop and tell the user to run `/super-ralph:init`.

Extract these values for use in all subsequent steps:
- `$REPO` — GitHub repo (e.g., `Forth-AI/work-ssot`)
- `$ORG` — GitHub org (e.g., `Forth-AI`)
- `$PROJECT_NUM` — Project board number
- `$PROJECT_ID` — Project board GraphQL ID
- `$STATUS_FIELD_ID` — Status field ID
- `$STATUS_SHIPPED` — Shipped status option ID
- `$BE_DIR` — Backend directory (e.g., `work-agents`)
- `$FE_DIR` — Frontend directory (e.g., `work-web`)
- `$BE_TEST_CMD` — Backend test command (e.g., `cd work-agents && bun test`)
- `$FE_TEST_CMD` — Frontend test command (e.g., `cd work-web && bun test`)
- `$APP_URL` — Production app URL (e.g., `https://app.forthai.work`)
- `$PROD_URLS` — All production URLs to health-check (from Production URLs table)
- `$PM_USER` — Product manager name
- `$TECH_LEAD` — Tech lead name
- `$TESTERS` — Tester names (e.g., `Amy & Faye`)

## Branch Model

```
feature branches ──PR──▶ staging (default branch, preview deploys)
                              │
                     /super-ralph:release
                              │
                              ▼
                         main (production, URLs from config)
```

- **staging** = GitHub default branch. All feature PRs merge here via `/super-ralph:finalise`.
- **main** = production branch. Only `/super-ralph:release` merges into main.
- Vercel auto-deploys: staging → preview URL, main → production domains.

## Arguments

Parse the user's input for:
- **--milestone** (optional): Milestone name (e.g., `v1.2`). If omitted, auto-detect the first open milestone.
- **--tag** (optional): Git tag (e.g., `v1.2.0`). If omitted, derive from milestone (`v1.2` -> `v1.2.0`).
- **--no-verify** (optional): Skip Phase 2 (QA verification). Pre-flight always runs.
- **--no-codex** (optional): Skip Phase 5 (Codex review). Useful if codex CLI is not installed.

## Workflow

Execute phases in order. **NEVER ask for human input** -- research + SME for decisions.

### Step 0: Identify Release Context

1. **Find milestone:**
   - If `--milestone` provided: use it
   - Else: auto-detect:
     ```bash
     gh api repos/$REPO/milestones \
       --jq '.[] | select(.state=="open") | "\(.number) \(.title)"' | head -1
     ```
   - Extract `MILESTONE` (title) and `MILESTONE_NUMBER` from result

2. **Derive tag:**
   - If `--tag` provided: use it
   - Else: append `.0` to milestone title (e.g., `v1.2` -> `v1.2.0`)

3. **Get milestone metadata:**
   ```bash
   gh api repos/$REPO/milestones/$MILESTONE_NUMBER \
     --jq '{title: .title, goal: .description, open: .open_issues, closed: .closed_issues}'
   ```
   - Store `MILESTONE_GOAL` from description

4. **Ensure on staging branch:**
   ```bash
   git checkout staging
   git fetch origin staging main
   git pull origin staging
   ```

5. **Report:**
   ```
   Release context: $MILESTONE ($MILESTONE_GOAL)
   Tag: $TAG | Milestone #$MILESTONE_NUMBER
   Promoting: staging → main
   ```

### Phase 1: Pre-flight Checks

ALL must pass to proceed. Pre-flight is mandatory -- never skip even with `--no-verify`.

| Check | Command | Pass condition |
|-------|---------|----------------|
| All issues closed | `gh issue list --milestone "$MILESTONE" --state open --repo $REPO --json number --jq 'length'` | `0` |
| No open PRs to staging | `gh pr list --base staging --state open --repo $REPO --json number --jq 'length'` | `0` |
| Staging up to date | `git diff origin/staging --quiet` | exit 0 |
| Staging ahead of main | `git log origin/main..origin/staging --oneline \| head -1` | non-empty (staging has new commits) |
| Tag unused | `git tag -l "$TAG"` | empty |

- **Any failure** -> report blocking items with details, stop. Do NOT proceed.
- **Idempotent** -- if tag already exists, report `"Tag $TAG already exists. Release already sealed."` and stop.
- **Staging == main** -- if staging has no new commits over main, report `"Nothing to release — staging is identical to main."` and stop.

### Phase 2: QA Verification on Staging

Skip entirely if `--no-verify` was passed. Otherwise dispatch subagents in parallel via Task tool.

All verification runs against the **staging** branch and its preview deployment URL.

#### 2a. Browser Smoke Test

```
Task tool:
  description: "Browser smoke test on staging for release $TAG"
  model: sonnet
  max_turns: 30
  prompt: |
    Run the browser smoke test checklist from
    ${CLAUDE_PLUGIN_ROOT}/skills/browser-verification/references/smoke-test-checklist.md
    against the STAGING preview URL (not production).
    Find the staging URL from the most recent Vercel deployment:
      gh api repos/$REPO/deployments --jq '[.[] | select(.ref=="staging")] | first | .statuses_url'
    Or use the Vercel preview URL pattern for the staging branch.
    Report each check as PASS/FAIL with screenshot evidence.
    Output a summary table at the end.
```

#### 2b. Full Regression Tests

```
Task tool:
  description: "Regression tests on staging for release $TAG"
  model: sonnet
  max_turns: 20
  prompt: |
    Run full test suites on the staging branch:
      $BE_TEST_CMD
      $FE_TEST_CMD
    Report: total passed, total failed, total skipped.
    List each failure with file path and assertion message.
```

#### 2c. API Contract Check

```
Task tool:
  description: "API contract check on staging for release $TAG"
  model: haiku
  max_turns: 10
  prompt: |
    Run API contract tests on the staging branch:
      $BE_TEST_CMD src/contracts.test.ts
    Report PASS or FAIL. If FAIL, list each broken contract with expected vs actual.
```

#### 2d. Acceptance Criteria Audit

```
Task tool:
  description: "Acceptance criteria audit for release $TAG"
  model: sonnet
  max_turns: 25
  prompt: |
    Audit acceptance criteria coverage for milestone "$MILESTONE":
    1. List closed issues: gh issue list --milestone "$MILESTONE" --state closed --repo $REPO --json number,title,body
    2. For each issue: extract acceptance criteria from body (lines starting with "- [ ]" or "- [x]")
    3. For each criterion: search codebase for tests covering it (grep test files for keywords)
    4. Report: total criteria, covered count, coverage percentage, list of uncovered criteria.
```

### Phase 3: Evaluate & Fix

Collect results from Phase 2 agents. Evaluate with this decision table:

| Agent | Blocking? | Pass condition |
|-------|-----------|----------------|
| Browser smoke | Yes | All checks pass |
| Regression tests | Yes | 0 failures |
| Contract check | Yes | All contracts pass |
| Acceptance audit | Warning only | >90% coverage |

**Decision logic:**
- **All pass** -> proceed to Phase 4
- **Blocking failure** -> dispatch issue-fixer/repair subagent on staging -> commit fix to staging -> re-verify failed checks -> loop
- **Unresolvable after 3 iterations** -> output `RELEASE_BLOCKED` with failure summary, stop
- **Acceptance audit below 90%** -> log warning, proceed (non-blocking)

### Phase 4: Release Documentation

1. **Generate release notes from merged PRs (into staging):**
   ```bash
   gh pr list --state merged --base staging --search "milestone:$MILESTONE" --repo $REPO \
     --json number,title,author \
     --jq '.[] | "- #\(.number) \(.title) (@\(.author.login))"' > /tmp/pr-list-$TAG.txt
   ```

2. **Count closed issues:**
   ```bash
   ISSUE_COUNT=$(gh issue list --milestone "$MILESTONE" --state closed --repo $REPO \
     --json number --jq 'length')
   PR_COUNT=$(wc -l < /tmp/pr-list-$TAG.txt | tr -d ' ')
   ```

3. **Write release notes to temp file:**
   ```bash
   cat > /tmp/release-notes-$TAG.md <<EOF
   ## What's New in $TAG

   $MILESTONE_GOAL

   ### Changes

   $(cat /tmp/pr-list-$TAG.txt)

   ### Stats
   - Issues closed: $ISSUE_COUNT
   - PRs merged: $PR_COUNT
   EOF
   ```

4. **Update docs/roadmap.md** -- mark completed items, update phase percentages. Use the same roadmap-update logic as `/super-ralph:finalise` Step 5.

5. **Commit to staging:**
   ```bash
   git add docs/roadmap.md
   git commit -m "docs: update roadmap for $TAG"
   git push origin staging
   ```

### Phase 5: Create Staging → Main PR

Create a pull request to promote staging into main.

1. **Ensure staging is pushed:**
   ```bash
   git push origin staging
   ```

2. **Generate PR diff summary:**
   ```bash
   DIFF_STATS=$(git diff --stat origin/main..origin/staging)
   COMMIT_LOG=$(git log origin/main..origin/staging --oneline --no-merges)
   ```

3. **Create the PR:**
   ```bash
   gh pr create \
     --base main \
     --head staging \
     --title "Release $TAG: $MILESTONE_GOAL" \
     --body "$(cat <<PREOF
   ## Release $TAG

   **Milestone:** $MILESTONE — $MILESTONE_GOAL

   ### Release Notes

   $(cat /tmp/release-notes-$TAG.md)

   ### Commits included

   \`\`\`
   $COMMIT_LOG
   \`\`\`

   ### Diff stats

   \`\`\`
   $DIFF_STATS
   \`\`\`

   ---
   Closes milestone $MILESTONE after merge.
   PREOF
   )" \
     --repo $REPO
   ```

4. **Store PR number:**
   ```bash
   RELEASE_PR=$(gh pr list --base main --head staging --state open --repo $REPO --json number --jq '.[0].number')
   ```

5. **Report:**
   ```
   Created release PR #$RELEASE_PR: staging → main
   ```

### Phase 6: Codex Review

Skip if `--no-codex` was passed. Otherwise use OpenAI Codex CLI to review the release PR.

1. **Check codex is available:**
   ```bash
   command -v codex >/dev/null 2>&1
   ```
   - If not found: log `"codex CLI not installed — skipping Codex review. Install: npm i -g @openai/codex"` and proceed to Phase 7.

2. **Run Codex review on the PR diff:**
   ```bash
   codex --approval-mode full-auto \
     "Review the diff between the staging and main branches of this repository ($REPO). \
      Run: git diff origin/main..origin/staging \
      Look for: bugs, logic errors, security vulnerabilities, breaking changes, missing error handling, \
      and any issues that would be risky to deploy to production. \
      For each issue found, fix it directly in the code. \
      After fixing, run tests: $BE_TEST_CMD && $FE_TEST_CMD \
      Commit each fix with message format: fix: [description] (codex-review) \
      If no issues found, output: CODEX_REVIEW_CLEAN"
   ```

3. **If Codex made fixes, push them to staging:**
   ```bash
   CODEX_COMMITS=$(git log origin/staging..HEAD --oneline | grep "codex-review" | wc -l | tr -d ' ')
   if [ "$CODEX_COMMITS" -gt "0" ]; then
     git push origin staging
     echo "Codex made $CODEX_COMMITS fix(es). Pushed to staging."
   fi
   ```

4. **Update the PR** (GitHub auto-updates since head is staging):
   ```bash
   if [ "$CODEX_COMMITS" -gt "0" ]; then
     gh pr comment "$RELEASE_PR" --body "Codex review complete: $CODEX_COMMITS fix(es) applied and pushed." --repo $REPO
   else
     gh pr comment "$RELEASE_PR" --body "Codex review complete: no issues found." --repo $REPO
   fi
   ```

5. **Re-run tests after Codex fixes** (if any fixes were made):
   ```bash
   if [ "$CODEX_COMMITS" -gt "0" ]; then
     $BE_TEST_CMD && $FE_TEST_CMD
     if [ $? -ne 0 ]; then
       echo "WARN: Tests failed after Codex fixes. Dispatching issue-fixer."
       # Dispatch issue-fixer subagent to resolve test failures
       # Loop up to 2 more times
     fi
   fi
   ```

### Phase 7: Merge to Main

Merge the staging → main PR. This is the production deployment moment.

1. **Wait for CI checks to pass:**
   ```bash
   gh pr checks "$RELEASE_PR" --repo $REPO --watch
   ```

2. **Merge with a merge commit** (not squash — preserve full history of the release):
   ```bash
   gh pr merge "$RELEASE_PR" --merge --repo $REPO
   ```
   - **Why merge commit, not squash?** The staging→main PR bundles many features. Squashing would lose individual commit history. A merge commit preserves the full feature-by-feature history on main while creating a clear merge point for the release.

3. **Pull main locally:**
   ```bash
   git checkout main
   git pull origin main
   ```

4. **If merge fails:**
   - Report: `"Release PR #$RELEASE_PR could not be merged: [reason]. Resolve and retry."`
   - Stop — do NOT proceed to tagging.

### Phase 7b: Verify Production Deployment

**MANDATORY — do NOT skip.** After merge to main, wait for Vercel to deploy to production and verify the deployment is healthy. Merge success != deployment success.

1. **Wait for Vercel production deployment** (max 8 minutes):
   ```bash
   echo "Waiting for Vercel production deployment on main..."
   DEPLOY_OK=false
   for i in $(seq 1 48); do
     STATUS_URL=$(gh api repos/$REPO/deployments \
       --jq '[.[] | select(.ref=="main" and .environment=="production")] | first | .statuses_url' 2>/dev/null)
     if [ -n "$STATUS_URL" ]; then
       STATE=$(gh api "$STATUS_URL" --jq '.[0].state' 2>/dev/null)
       if [ "$STATE" = "success" ]; then
         DEPLOY_OK=true
         echo "Production deployment succeeded."
         break
       elif [ "$STATE" = "error" ] || [ "$STATE" = "failure" ]; then
         echo "PRODUCTION DEPLOYMENT FAILED: state=$STATE"
         break
       fi
     fi
     sleep 10
   done
   ```

2. **Verify HTTP health of production URLs:**
   ```bash
   for URL in $PROD_URLS; do
     HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL" --max-time 15)
     if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 400 ]; then
       echo "HEALTHY: $URL → HTTP $HTTP_STATUS"
     else
       echo "UNHEALTHY: $URL → HTTP $HTTP_STATUS"
       DEPLOY_OK=false
     fi
   done
   ```

3. **If production deployment failed or unhealthy:**
   - Report: `"PRODUCTION DEPLOYMENT UNHEALTHY — do NOT seal the release. Investigate Vercel build logs."`
   - Check Vercel deployment logs:
     ```bash
     vercel ls 2>/dev/null | head -5
     ```
   - Output `RELEASE_BLOCKED` and stop — do NOT proceed to Phase 8 (tagging). A failed production deployment must be fixed before sealing the version.

4. **If healthy:**
   - Report: `"Production deployment verified: all URLs healthy."`
   - Proceed to Phase 8.

### Phase 8: Seal Version

Execute in order on the **main** branch. Each step is final -- no rollback.

1. **Create annotated tag on main:**
   ```bash
   git tag -a "$TAG" -m "$TAG: $MILESTONE_GOAL"
   ```

2. **Push tag:**
   ```bash
   git push origin "$TAG"
   ```

3. **Close milestone:**
   ```bash
   gh api repos/$REPO/milestones/$MILESTONE_NUMBER \
     --method PATCH -f state="closed"
   ```

4. **Create GitHub Release:**
   ```bash
   gh release create "$TAG" \
     --title "$TAG: $MILESTONE_GOAL" \
     --notes-file /tmp/release-notes-$TAG.md \
     --repo $REPO
   ```

5. **Verify Project #$PROJECT_NUM board** -- confirm all milestone items are in Shipped column:
   ```bash
   gh project item-list $PROJECT_NUM --owner $ORG --format json \
     | jq '[.items[] | select(.content.milestone.title == "'$MILESTONE'" and .status != "Shipped")] | length'
   ```
   - If any items not Shipped, move them:
     ```bash
     gh project item-edit --project-id $PROJECT_ID \
       --id "$ITEM_ID" \
       --field-id $STATUS_FIELD_ID \
       --single-select-option-id $STATUS_SHIPPED
     ```

### Phase 9: Sync Staging

After the release, fast-forward staging to match main so it starts clean for the next development cycle.

1. **Fast-forward staging to main:**
   ```bash
   git checkout staging
   git merge main --ff-only
   git push origin staging
   ```

2. **If fast-forward fails** (staging diverged during release):
   ```bash
   # This shouldn't happen if pre-flight passed (no open PRs to staging)
   # But if it does, merge main into staging to bring it up to date
   git merge main -m "chore: sync staging with main after $TAG release"
   git push origin staging
   ```

3. **Return to staging branch** (default working branch):
   ```bash
   git checkout staging
   ```

### Phase 10: Cleanup

1. **Prune worktrees:**
   ```bash
   git worktree prune
   ```

2. **Delete merged branches:**
   ```bash
   git fetch --prune origin
   git branch --merged staging | grep -v 'main\|staging' | xargs -r git branch -d
   ```

3. **Archive plan docs** linked to this milestone:
   ```bash
   # For each plan in docs/plans/ that references the milestone
   # Add completion marker if not already present
   ```
   Add `<!-- Status: COMPLETED -->` to the top of each plan file.

4. **Clean temp files:**
   ```bash
   rm -f /tmp/release-notes-$TAG.md /tmp/pr-list-$TAG.txt
   ```

5. **Output summary:**
   ```
   # Release Sealed: $TAG
   - Milestone: $MILESTONE (closed)
   - Tag: $TAG (pushed to main)
   - Release PR: #$RELEASE_PR (merged)
   - Production deployment: [HEALTHY / UNHEALTHY] — $PROD_URLS HTTP [status]
   - Codex review: [clean / N fixes applied]
   - PRs merged: [count]
   - Issues closed: [count]
   - Verification: All passed
   - Staging: synced with main
   ```

6. **Output completion promise:** `RELEASE_SEALED`

## Critical Rules

- **Staging is the source.** Release always promotes staging → main. Never tag from staging directly.
- **Pre-flight is mandatory** -- never skip even with `--no-verify`. It catches fatal blockers (open issues, tag collisions).
- **QA runs on staging** -- browser smoke, tests, contracts, audit all run against the staging branch and its preview deployment.
- **Codex review is a safety net** -- a second AI reviews the full diff before production. Skip only with `--no-codex` or if codex CLI is not installed.
- **Merge commit for the release PR** -- preserve feature-by-feature commit history on main. Squash is for feature PRs into staging; merge is for staging into main.
- **Tag on main** -- the release tag always points to a commit on main, after the staging→main merge.
- **Sync staging after release** -- fast-forward staging to main so it starts clean. Divergence = bug.
- **Tag is final** -- fixes after tagging go in the next patch version (`vX.Y.1`), not by re-tagging.
- **Verify production deployment before sealing.** After merge to main, Phase 7b verifies Vercel production deployment is healthy (HTTP 200 on production URLs). Do NOT tag or seal the release until production is confirmed healthy. Merge to main != production is live.
- **NEVER ask for human input** -- use research agents and SME brainstormers for ambiguous decisions.
- **Idempotent** -- running twice detects the existing tag and exits cleanly. No duplicate tags, releases, or commits.
- **Use issue-management skill conventions** -- milestone API calls, Project #$PROJECT_NUM board IDs, and status option IDs from config.
- **Commit from root repo** -- all documentation updates happen in the main working directory, not a worktree.
- **Version convention** -- `major.minor.patch`: Milestone = minor, post-release fixes = patch. Only $PM_USER + $TECH_LEAD decide major bumps.
