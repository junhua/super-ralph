# Phase 3: Review-Fix Sub-Agent

> Canonical spec for Phase 3 of `/super-ralph:build-story` — review code quality,
> fix issues, create a PR targeting staging. Loops until 0 Critical and 0 Important
> findings remain, or max 5 iterations.

### Phase 3: Review-Fix

**Goal:** Review code quality, fix issues, create a PR targeting staging.

**Dispatch sub-agent:**

```
Task tool:
  model: opus
  max_turns: 80
  description: "Review-fix Story $STORY_ID: $STORY_TITLE"
  prompt: |
    You are a review-fix agent for a feature branch.

    ## Context
    Read the story context: $STORY_DIR/context.md
    Read the build result: $STORY_DIR/build-result.md
    Branch: super-ralph/$STORY_SLUG

    ## Instructions
    Read the full review-fix workflow: ${CLAUDE_PLUGIN_ROOT}/commands/review-fix.md
    Follow it completely, with these specifics:

    1. **Switch to the branch** in a worktree:
       Check if a worktree already exists for this branch:
       ```bash
       git worktree list | grep "super-ralph/$STORY_SLUG"
       ```
       If yes, use it. If no, create one.

    2. **Rebase to staging** (the default branch):
       ```bash
       DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')
       git fetch origin "$DEFAULT_BRANCH"
       git rebase "origin/$DEFAULT_BRANCH"
       ```

    3. **Run regression tests:**
       ```bash
       bun test 2>&1
       ```
       Classify failures: NEW (caused by this branch), PRE-EXISTING, FLAKY.

    4. **Dispatch review agents IN PARALLEL** (all at once via Task tool):
       - code-reviewer: review `git diff origin/$DEFAULT_BRANCH...HEAD`
       - silent-failure-hunter: review error handling
       - pr-test-analyzer: review test coverage
       - comment-analyzer: review comment quality
       - type-design-analyzer: review new types (if any)
       - code-simplifier: review for simplification opportunities

       All agents get: branch diff + summarized test results. Max 20 turns each.

    5. **Parse and classify findings:**
       - Critical (confidence >= 90): MUST fix
       - Important (confidence >= 80): SHOULD fix
       - Minor/Suggestions: Log, skip

    6. **Fix issues** — Dispatch issue-fixer in batches of max 3:
       Critical first, then Important. Commit each fix.

    7. **Re-run tests** after fixes. If new failures, fix those too.

    8. **Loop** until: 0 Critical, 0 Important, all tests pass. Max 5 iterations.

    9. **Create PR** targeting staging (mode-aware `Closes` line):
       ```bash
       git push -u origin HEAD
       EXISTING_PR=$(gh pr list --head "super-ralph/$STORY_SLUG" --json number --jq '.[0].number')
       if [ "$MODE" = "local" ]; then
         CLOSES_LINE="Closes local epic $STORY_REF"
       else
         CLOSES_LINE="Closes #$STORY_ID"
       fi
       if [ -z "$EXISTING_PR" ]; then
         gh pr create \
           --base staging \
           --head "super-ralph/$STORY_SLUG" \
           --title "$STORY_TITLE" \
           --body "$(cat <<PREOF
       ## Summary
       [auto-generated from story context and changes]

       ## Test Plan
       - [ ] All unit tests pass
       - [ ] E2E acceptance tests pass
       - [ ] Browser verification [pending /verify]

       $CLOSES_LINE
       PREOF
       )"
       else
         echo "PR #$EXISTING_PR already exists — updated."
       fi
       ```

    10. **Write result** to $STORY_DIR/review-result.md:
        ```
        phase: review
        status: REVIEW_CLEAN|BLOCKED
        pr_number: [NNN]
        pr_url: [URL]
        branch: super-ralph/$STORY_SLUG
        iterations: [N]
        findings_fixed: [N]
        findings_skipped: [N minor/suggestions]
        test_results: [X passed, 0 failed]
        ```

    NEVER ask for human input. NEVER output false REVIEW_CLEAN.
```

**After sub-agent completes:**
1. Read `$STORY_DIR/review-result.md`
2. Extract `PR_NUMBER`
3. If BLOCKED: report and decide whether to proceed to verify anyway
4. Update `$STORY_DIR/progress.md`: Review → DONE or BLOCKED
