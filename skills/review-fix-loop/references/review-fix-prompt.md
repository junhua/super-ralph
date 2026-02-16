# Review-Fix Prompt Template

This is the ralph-loop prompt that gets written to `.claude/ralph-loop.local.md` when launching a review-fix cycle. Replace all `[bracketed]` values before writing.

---

## Template

```
You are running an autonomous PR review-and-fix cycle via Ralph Loop with regression testing and auto-merge.

## PR

PR number: [PR_NUMBER or "create PR first"]
Base branch: [BASE_BRANCH, e.g., "main"]
Feature branch: [FEATURE_BRANCH]

## Each Iteration

### 1. Ensure PR Exists

Check if the PR exists:

```bash
gh pr view [PR_NUMBER] --json state 2>/dev/null
```

If no PR exists, create one:

```bash
gh pr create --title "[PR_TITLE]" --body "[PR_BODY]" --base [BASE_BRANCH]
```

If the PR exists, ensure local commits are pushed:

```bash
git push
```

### 2. Run Regression Tests

Run ALL regression tests to catch regressions from previous iterations early.

**Auto-detect and run all test suites:**

```bash
# Detect test runner
if [ -f bun.lock ] || [ -f bun.lockb ]; then RUNNER="bun"
elif [ -f package.json ]; then RUNNER="npm"
fi

# Run all tests
$RUNNER test 2>&1
```

**If specific test directories exist, also run them explicitly:**

```bash
# Integration tests
if [ -d tests/integration ] || [ -d test/integration ]; then
  $RUNNER test -- tests/integration/ 2>&1
fi

# E2E / behavior tests
if [ -d tests/e2e ] || [ -d test/e2e ]; then
  $RUNNER test -- tests/e2e/ 2>&1
fi
```

**Record test results:**
- Total: N passed, M failed, K skipped
- List each failing test: file path, test name, error message
- Classify failures:
  - NEW failure (file touched by `git log --grep="review-fix" --name-only`): Critical — regression from fix
  - PRE-EXISTING failure (file NOT touched by review-fix commits): Log but do not block
  - FLAKY (passes on retry `$RUNNER test -- <file> 2>&1`): Minor

### 3. Run PR Review Agents

Dispatch review agents via the Task tool:

**Code Reviewer (sonnet model):**
```
Review PR #[PR_NUMBER] for code quality issues.

Read the diff: `gh pr diff [PR_NUMBER]`
Read affected files for full context.

Regression test results from this iteration:
[PASTE TEST RESULTS HERE]

Classify each finding:
- Critical (>=90% confidence): Bugs, security issues, data loss, crashes
- Important (>=80% confidence): Architecture problems, missing error handling, test gaps, convention violations
- Minor (>=50% confidence): Style, optimization, minor DRY
- Suggestion: Docs, refactoring ideas, nice-to-haves

Output format for each finding:
SEVERITY: [Critical|Important|Minor|Suggestion]
FILE: [path]
LINE: [number or range]
ISSUE: [description]
FIX: [suggested fix approach]
```

**Silent Failure Hunter (sonnet model):**
```
Hunt for silent failures in PR #[PR_NUMBER].

Read the diff: `gh pr diff [PR_NUMBER]`
Read affected files for full context.

Look for:
- Swallowed errors (empty catch blocks, ignored promise rejections)
- Missing error paths (what if this API call fails?)
- Silent data corruption (wrong type coercion, truncation)
- Race conditions that fail silently
- Null/undefined that propagates without error

Classify each finding with the same severity scale.
Output in the same format as above.
```

### 4. Parse and Classify Findings

Aggregate findings from all review agents AND test failures from Step 2.
De-duplicate: if multiple agents flag the same issue, keep the highest severity.
New test failures are automatically Critical.
Sort: Critical first, then Important.

### 5. Evaluate Completion

Completion requires BOTH:
1. Critical = 0 AND Important = 0 (from code review)
2. All regression tests pass (no new test failures; pre-existing failures exempt)

If BOTH conditions met:
- Log Minor and Suggestion findings for reference (do not fix)
- Output: <promise>REVIEW_CLEAN</promise>
- Proceed to Step 8 (Merge PR)

If either condition fails:
- Proceed to Step 6

### 6. Dispatch Issue Fixer

Dispatch an issue-fixer agent (Task tool, sonnet model):

```
You are fixing issues found during autonomous PR review and regression testing.

## Issues to Fix

[Paste all Critical findings first (including test failures), then Important findings.
Include: severity, file, line, issue description, suggested fix.
For test failures: include the test name, file path, error message, and stack trace.]

## Fix Process

For each issue (Critical first, then Important):
1. Read the file and surrounding context (at least 20 lines around the issue)
2. Understand the intent of the existing code
3. Implement the fix
4. Run the relevant test to verify the fix:
   `bun test [test-file-path]`
5. If no test exists and the fix is non-trivial, write a regression test
6. Commit the fix:
   `git add [files]`
   `git commit -m "fix: [concise description] (review-fix)"`
7. Push:
   `git push`

## Rules
- Fix Critical issues before Important ones (test failures are Critical)
- One commit per fix (not one commit for all fixes)
- Push after each commit
- Run tests after each fix to ensure no regressions
- If a fix is unclear, search the codebase for similar patterns
- If truly stuck on a specific fix, skip it and add a comment:
  `// TODO(review-fix): [description of issue and why fix was skipped]`
- NEVER ask for human input
```

### 7. Check for Oscillation

After fixes are committed, check for oscillation patterns:

```bash
# Get recent review-fix commits
git log --oneline --grep="review-fix" -20
```

If the same file has been fixed in 3+ consecutive review-fix iterations:
- This indicates oscillation
- Dispatch sme-brainstormer agents to analyze the root cause:

```
Two or more fixes are oscillating on [FILE]:

Recent fix history:
[paste relevant git log entries and diffs]

Fixing one issue re-introduces another. This needs an architectural solution.
Analyze the root cause and recommend a fix that resolves all oscillating issues simultaneously.
```

- Apply the architectural fix
- Commit: `git commit -m "fix: resolve oscillation in [file] (review-fix)"`

### 8. Merge PR (on REVIEW_CLEAN only)

When the loop outputs REVIEW_CLEAN, merge the PR automatically:

1. Verify PR is mergeable:
   ```bash
   gh pr view [PR_NUMBER] --json mergeable,mergeStateStatus
   ```

2. Wait for CI checks to complete (if any):
   ```bash
   gh pr checks [PR_NUMBER] --watch
   ```

3. Merge using squash (consolidates review-fix commits):
   ```bash
   gh pr merge [PR_NUMBER] --squash --delete-branch
   ```

4. If merge fails (conflicts, branch protection, etc.):
   - Log the error
   - Output: "PR #[PR_NUMBER] is review-clean but could not be auto-merged: [reason]"
   - Do NOT retry or force-merge

5. If merge succeeds:
   - Output: "PR #[PR_NUMBER] merged successfully. Branch deleted."

### 9. Continue (if not merging)

The ralph-loop Stop hook will feed this prompt back for the next iteration.
The next iteration will re-run all regression tests AND re-review the updated PR.

## Fix History Tracking

Maintain awareness of what has been fixed by checking git log:

```bash
git log --oneline --grep="review-fix"
```

Use this to:
- Avoid re-fixing issues that were already addressed
- Detect oscillation (same file/issue appearing repeatedly)
- Track convergence (fewer issues each iteration = healthy)
- Detect divergence (more issues each iteration = something is wrong — dispatch brainstormers)
- Classify test failures as new vs pre-existing

## Rules

- Run ALL regression tests at the start of each iteration — do not skip
- Fix Critical issues (including test failures) before Important ones
- Skip Minor and Suggestions — they do not block completion
- NEVER ask for human input — use research-agent if stuck on a fix
- Commit each fix separately with message format: `fix: [what] (review-fix)`
- Push after each commit so the PR stays updated
- If the same issue persists after 2 fix attempts, escalate to sme-brainstormer analysis
- NEVER output <promise>REVIEW_CLEAN</promise> if Critical or Important issues remain OR tests are failing — that would be lying
- The promise must be TRUE: the review genuinely found no blocking issues AND all tests pass
- After REVIEW_CLEAN, merge the PR automatically via squash merge
```

---

## Usage

When launching a review-fix cycle:

1. Replace all `[bracketed]` values in the template:
   - `[PR_NUMBER]` — The PR number, or "create PR first" if no PR exists yet
   - `[BASE_BRANCH]` — Usually "main" or "master"
   - `[FEATURE_BRANCH]` — The current branch name
   - `[PR_TITLE]` — Title for PR creation (if needed)
   - `[PR_BODY]` — Body for PR creation (if needed)

2. Write the filled template to `.claude/ralph-loop.local.md` via the setup script or `/super-ralph:launch`

3. Set ralph-loop parameters:
   - `--completion-promise "REVIEW_CLEAN"`
   - `--max-iterations 15` (typical) or `--max-iterations 25` (large PRs)

4. The loop runs autonomously: test, review, fix, push, re-test, re-review, until clean and green, then auto-merges.

## Expected Convergence

- **Healthy:** Each iteration finds fewer issues and test failures. Converges in 3-6 iterations for typical PRs. Auto-merges on clean.
- **Slow convergence:** Each fix introduces minor new issues. Normal for complex PRs. Converges in 6-10 iterations.
- **Oscillation:** Same issues reappear. Anti-oscillation logic kicks in after 2 cycles.
- **Divergence:** More issues each iteration. Indicates a fundamental problem. Brainstormers are dispatched automatically.
