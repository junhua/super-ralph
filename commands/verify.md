---
name: verify
description: "Browser-verify a PR's deployed preview against acceptance criteria using claude-in-chrome"
argument-hint: "[--pr NUMBER] [--url URL] [--criteria PATH]"
allowed-tools: ["Bash(git:*)", "Bash(gh:*)", "Read", "Glob", "Grep", "Task"]
---

# Super-Ralph Verify Command

Browser-verify a deployed preview against acceptance criteria. Uses claude-in-chrome to navigate, interact, and assert in a real browser. Reports pass/fail per criterion with GIF evidence. Does NOT fix issues — that is `/super-ralph:repair`'s job.

## Arguments

Parse the user's input for:
- **--pr** (optional): PR number to verify. Extracts Vercel preview URL from PR comments.
- **--url** (optional): Direct URL to verify against. Overrides PR detection.
- **--criteria** (optional): Path to a file containing acceptance criteria. Overrides issue extraction.

## Workflow

### Step 1: Load Browser-Verification Skill

Invoke the `super-ralph:browser-verification` skill for browser interaction patterns, assertion techniques, and evidence capture.

### Step 2: Find Verification Target

Resolve the URL to test against, in priority order:

1. **If --url provided:** Use directly.
2. **If --pr provided:** Extract Vercel preview URL from PR comments:
   ```bash
   gh api repos/$REPO/issues/$PR_NUMBER/comments \
     --jq '[.[] | select(.user.login == "vercel[bot]")] | last | .body' \
     | grep -oE 'https://[a-zA-Z0-9._-]+\.vercel\.app'
   ```
3. **Else:** Auto-detect PR from current branch:
   ```bash
   PR_NUMBER=$(gh pr list --head "$(git branch --show-current)" --json number --jq '.[0].number')
   ```
   Then extract Vercel preview URL as above.
4. **Fallback:** `http://localhost:3000`

Report the resolved URL before proceeding.

### Step 3: Load Acceptance Criteria

Resolve what to verify, in priority order:

1. **If --criteria provided:** Read the file at the given path.
2. **Else:** Extract from PR body:
   ```bash
   gh pr view $PR_NUMBER --json body --jq '.body'
   ```
   - Find `Closes #N` references in the PR body
   - Read the linked issue body: `gh issue view N --json body --jq '.body'`
   - Extract acceptance criteria (Given/When/Then blocks, checkbox lists, or bullet points)
   - If the issue references an epic story (e.g., `**Parent:** #M`), read the epic for additional Given/When/Then scenarios

3. **Parse into structured list:**
   ```
   Criterion 1: [Given X] [When Y] [Then Z]
   Criterion 2: [Given X] [When Y] [Then Z]
   ...
   ```

### Step 4: Dispatch Browser Verifier

Dispatch the `super-ralph:browser-verifier` agent to execute all browser interactions:

```
Task tool:
  subagent_type: super-ralph:browser-verifier
  model: sonnet
  max_turns: 30
  description: "Browser-verify [URL] against [N] acceptance criteria"
  prompt: |
    Verify the following URL against acceptance criteria in a real browser.

    ## Target URL
    [RESOLVED_URL]

    ## Acceptance Criteria
    [STRUCTURED_CRITERIA_LIST]

    ## Instructions
    1. Initialize browser session (tabs_context → tabs_create → navigate to URL)
    2. Authenticate if login page is shown
    3. Start GIF recording
    4. For each criterion: navigate → interact → assert → record PASS/FAIL with evidence
    5. Run health checks: console errors, network failures
    6. Stop GIF recording
    7. Return structured results table
```

### Step 5: System Health Checks

If the browser-verifier agent did not already report health data, run supplementary checks:
- Console errors (count, types)
- Network failures (4xx/5xx responses)
- Page load performance

### Step 6: Produce Verification Report

Compile the agent's results into a final report:

```markdown
## Verification Report

**URL:** [url]
**PR:** #[number]
**Date:** [timestamp]

### Criteria Results

| # | Criterion | Status | Notes |
|---|-----------|--------|-------|
| 1 | [criterion text] | PASS/FAIL | [details] |
| 2 | [criterion text] | PASS/FAIL | [details] |

### System Health

| Check | Result |
|-------|--------|
| Console errors | [count] |
| Network failures (4xx/5xx) | [count] |

### Verdict: PASS / FAIL

**Evidence:** [GIF file path]
```

**If PASS:** "All criteria verified. Run `/super-ralph:finalise` to merge."

**If FAIL:** For each failed criterion, suggest: "Run `/super-ralph:repair` to fix: [failure description]"

## Critical Rules

- **Always browser verification, not code review.** This command tests deployed behavior, not source code.
- **Prefer Vercel preview over local dev.** Production-like environment catches more issues.
- **Every criterion gets a verdict.** No criterion is skipped or left as "not tested".
- **Record GIF evidence.** Start recording before first interaction, stop after last assertion.
- **Console/network errors are implicit fail conditions.** Even if all criteria pass, uncaught JS errors or failed API requests trigger a FAIL verdict.
- **NEVER ask for human input.** If authentication fails or a page is unreachable, report it as FAIL with details.
- **Do NOT fix issues.** Report only. Fixing is `/super-ralph:repair`'s job.
