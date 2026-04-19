# Phase 4: Verify Sub-Agent

> Canonical spec for Phase 4 of `/super-ralph:build-story` — browser-verify the
> preview deployment against Gherkin acceptance criteria via
> `/super-ralph:verify`. Skipped when `--skip-verify` is passed.

### Phase 4: Verify

**Skip if `--skip-verify` was passed.** Write `status: SKIPPED` to verify-result.md and proceed.

**Goal:** Browser-verify the PR's Vercel preview against acceptance criteria.

**Wait for Vercel preview deployment:**
```bash
# Poll for Vercel bot comment with preview URL (max 5 minutes)
for i in $(seq 1 30); do
  PREVIEW_URL=$(gh api repos/$REPO/issues/$PR_NUMBER/comments \
    --jq '[.[] | select(.user.login == "vercel[bot]")] | last | .body' 2>/dev/null \
    | grep -oE 'https://[a-zA-Z0-9._-]+\.vercel\.app' | head -1)
  if [ -n "$PREVIEW_URL" ]; then break; fi
  sleep 10
done
```

If no preview URL found after 5 minutes, fall back to `http://localhost:3000` or skip verify with a warning.

**Dispatch sub-agent:**

```
Task tool:
  subagent_type: super-ralph:browser-verifier
  model: sonnet
  max_turns: 30
  description: "Verify Story $STORY_ID against acceptance criteria"
  prompt: |
    Verify the deployed preview against acceptance criteria.

    ## Target URL
    $PREVIEW_URL

    ## Acceptance Criteria
    [extracted from $STORY_DIR/context.md]

    ## Instructions
    1. Initialize browser session (tabs_context → tabs_create → navigate)
    2. Start GIF recording: "${STORY_SLUG}-verify.gif"
    3. For each criterion:
       - Navigate to the relevant page
       - Perform the interaction (Given → When)
       - Assert the expected result (Then)
       - Record PASS/FAIL with evidence
    4. Run health checks: console errors, network failures (4xx/5xx)
    5. Stop GIF recording
    6. Return structured results table
```

**After sub-agent completes:**
1. Write `$STORY_DIR/verify-result.md`:
   ```
   phase: verify
   status: PASS|FAIL
   preview_url: [URL]
   criteria_passed: [N/M]
   criteria_failed: [list of failures]
   console_errors: [count]
   network_failures: [count]
   evidence: [GIF path]
   ```
2. If FAIL and failures are fixable:
   - Dispatch repair sub-agent to fix the issues on the branch
   - Push fixes
   - Re-run verify (max 2 retries)
3. Update `$STORY_DIR/progress.md`: Verify → PASS, FAIL, or SKIPPED
