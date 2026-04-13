# Review-Fix Prompt Template

This is the ralph-loop prompt that gets written to `.claude/ralph-loop.local.md` when launching a review-fix cycle. Replace all `[bracketed]` values before writing.

---

## Template

```
You are running an autonomous code review-and-fix cycle via Ralph Loop with regression testing. A PR will be created when the code is clean.

## Branch

Feature branch: [FEATURE_BRANCH]

## Each Iteration

### 1. Rebase to Default Branch

Rebase onto the latest default branch every iteration to stay current:

```bash
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')
git fetch origin "$DEFAULT_BRANCH"
git rebase "origin/$DEFAULT_BRANCH"
```

If rebase conflicts:
- Attempt auto-resolution for trivial conflicts (lock files, auto-generated files)
- For non-trivial: `git rebase --abort`, dispatch sme-brainstormer to analyze
- If unresolvable: output <promise>REVIEW_BLOCKED</promise> with conflict details

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

**Summarize test output before passing to agents (IMPORTANT — prevents context exhaustion):**

Do NOT paste raw test output into sub-agent prompts. Instead, create a concise summary:

```
Test Summary: [N] passed, [M] failed, [K] skipped

Failures:
1. [test-file-path] > [test-suite] > [test-name]
   Error: [one-line error message — first line only]
2. [test-file-path] > [test-suite] > [test-name]
   Error: [one-line error message — first line only]

Classification:
- NEW (regression): [list test names]
- PRE-EXISTING: [list test names]
- FLAKY: [list test names]
```

Keep each failure to 2-3 lines maximum. Omit full stack traces — the issue-fixer can read the full output when it runs the test itself.

### 3. Run Review Agents

Dispatch review agents via the Task tool. **Use max_turns to prevent context exhaustion.** Agents review the branch diff against the default branch.

**Get the diff for agent context:**
```bash
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')
git diff "origin/$DEFAULT_BRANCH"...HEAD
```

**Code Reviewer (sonnet model, max_turns: 20):**
```
Review the code changes on branch [FEATURE_BRANCH] for quality issues.

Read the diff: `git diff origin/<default-branch>...HEAD`
Read affected files for full context.

Regression test summary:
[PASTE SUMMARIZED TEST RESULTS — not raw output]

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

**Silent Failure Hunter (sonnet model, max_turns: 20):**
```
Hunt for silent failures in the changes on branch [FEATURE_BRANCH].

Read the diff: `git diff origin/<default-branch>...HEAD`
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

**Test Analyzer (sonnet model, max_turns: 20):**
```
Analyze test coverage quality for the changes on branch [FEATURE_BRANCH].

Read the diff: `git diff origin/<default-branch>...HEAD`
Read test files for context.

Focus on:
- Critical code paths without test coverage
- Edge cases and boundary conditions
- Error handling paths
- Tests that test implementation instead of behavior

Output findings with the same severity classification.
```

**Comment Analyzer (sonnet model, max_turns: 20):**
```
Analyze code comments in the changes on branch [FEATURE_BRANCH].

Read the diff: `git diff origin/<default-branch>...HEAD`
Read affected files for context.

Check for:
- Comments that are factually incorrect vs the code
- Misleading or outdated comments
- Missing documentation for complex logic
- Comments that merely restate obvious code

Output findings with the same severity classification.
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
- Proceed to Step 8 (Create PR)

If either condition fails:
- Proceed to Step 6

### 6. Dispatch Issue Fixer (in batches)

**CRITICAL: Dispatch issue-fixer agents in batches of at most 3 issues per dispatch.**

Sub-agents cannot compact their context. A single dispatch with many issues will exhaust the context window as the agent reads files, runs tests, and commits for each issue. Batching prevents this.

**Batching rules:**
- Maximum 3 issues per issue-fixer dispatch
- Process batches sequentially (not in parallel) to avoid git conflicts
- Each batch gets its own Task dispatch with `max_turns: 30`
- Critical issues go in the first batch(es), then Important
- If a batch has fewer than 3 issues, that is fine

**Example:** 2 Critical + 4 Important = 3 batches:
- Batch 1 (max_turns: 30): 2 Critical + 1 Important
- Batch 2 (max_turns: 30): 2 Important
- Batch 3 (max_turns: 30): 1 Important

**Prompt template for each batch:**

```
You are fixing code review issues on branch [FEATURE_BRANCH]. This is batch [N] of [TOTAL].

## Issues to Fix (max 3)

[Paste ONLY this batch's findings. Include: severity, file, line, issue description, suggested fix.
For test failures: include the test name, file path, and one-line error message.]

## Fix Process

For each issue:
1. Read the file and 20 lines of surrounding context
2. Understand the intent of the existing code
3. Implement the minimal fix
4. Run the relevant test: `bun test [test-file-path]`
5. Commit: `git add [files] && git commit -m "fix: [what] (review-fix)"`

## Context Economy Rules
- Read only the lines you need — do NOT read entire files
- Use targeted grep with head_limit (e.g., head_limit: 10) when searching
- Do NOT trace full call chains unless the fix specifically requires it
- Run only the specific test file, not the entire test suite
- NEVER ask for human input
```

After each batch completes, verify the fixes were committed before dispatching the next batch:
```bash
git log --oneline -5
```

### 7. Check for Oscillation

After fixes are committed, check for oscillation patterns:

```bash
# Get recent review-fix commits
git log --oneline --grep="review-fix" -20
```

If the same file has been fixed in 3+ consecutive review-fix iterations:
- This indicates oscillation
- Dispatch sme-brainstormer agents to analyze the root cause (max_turns: 15):

```
Two or more fixes are oscillating on [FILE]:

Recent fix history (last 5 commits only):
[paste ONLY the relevant git log entries — not full diffs, just commit messages and file names]

Fixing one issue re-introduces another. This needs an architectural solution.
Analyze the root cause and recommend a fix that resolves all oscillating issues simultaneously.
```

- Apply the architectural fix
- Commit: `git commit -m "fix: resolve oscillation in [file] (review-fix)"`

### 8. Create PR (on REVIEW_CLEAN only)

When the loop outputs REVIEW_CLEAN, push the branch and create a PR:

1. Push the branch:
   ```bash
   git push -u origin HEAD
   ```

2. Check if a PR already exists:
   ```bash
   EXISTING_PR=$(gh pr list --head "[FEATURE_BRANCH]" --json number --jq '.[0].number')
   ```

3. **Discover the associated GitHub issue** (so the PR body includes `Closes #N`):
   ```bash
   SLUG=$(echo "[FEATURE_BRANCH]" | sed 's|super-ralph/||; s|/|-|g')
   PLAN_FILE=$(ls docs/plans/*${SLUG}*.md 2>/dev/null | head -1)
   ISSUE_NUM=""
   if [ -n "$PLAN_FILE" ]; then
     ISSUE_NUM=$(grep -oE '(Closes|Issue)[[:space:]]*#[0-9]+' "$PLAN_FILE" | grep -oE '[0-9]+' | head -1)
   fi
   CLOSES_LINE=""
   if [ -n "$ISSUE_NUM" ]; then
     CLOSES_LINE="Closes #$ISSUE_NUM"
   fi
   ```

4. Create or update PR:
   - If no PR exists:
     ```bash
     DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')
     gh pr create --title "<auto-generated title>" --body "<summary>

$CLOSES_LINE" --base "$DEFAULT_BRANCH"
     ```
     **IMPORTANT:** The PR body MUST include `Closes #N` if an issue number was found. This enables GitHub auto-close and the finalise command's issue discovery.
   - If PR exists: report `"PR #$EXISTING_PR updated with clean code."`

5. Output: `"Branch is review-clean. PR #[NUMBER] created/updated. Run /super-ralph:finalise to merge and update project status."`

### 9. Continue (if not creating PR)

The ralph-loop Stop hook will feed this prompt back for the next iteration.
The next iteration will rebase, re-run all regression tests, AND re-review the updated branch diff.

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

- Rebase to default branch at the start of EVERY iteration — do not skip
- Run ALL regression tests after rebase — do not skip
- Fix Critical issues (including test failures) before Important ones
- Skip Minor and Suggestions — they do not block completion
- NEVER ask for human input — use research-agent if stuck on a fix
- Commit each fix separately with message format: `fix: [what] (review-fix)`
- If the same issue persists after 2 fix attempts, escalate to sme-brainstormer analysis
- NEVER output <promise>REVIEW_CLEAN</promise> if Critical or Important issues remain OR tests are failing — that would be lying
- The promise must be TRUE: the review genuinely found no blocking issues AND all tests pass
- After REVIEW_CLEAN, create a PR (do NOT merge — that is /super-ralph:finalise's job)
```

---

## Usage

When launching a review-fix cycle:

1. Replace all `[bracketed]` values in the template:
   - `[FEATURE_BRANCH]` — The current branch name

2. Write the filled template to `.claude/ralph-loop.local.md` via the setup script or `/super-ralph:build`

3. Set ralph-loop parameters:
   - `--completion-promise "REVIEW_CLEAN"`
   - `--max-iterations 15` (typical) or `--max-iterations 25` (large branches)

4. The loop runs autonomously: rebase, test, review, fix, commit, repeat until clean, then creates a PR.

## Expected Convergence

- **Healthy:** Each iteration finds fewer issues and test failures. Converges in 3-6 iterations for typical branches. Creates PR on clean.
- **Slow convergence:** Each fix introduces minor new issues. Normal for complex branches. Converges in 6-10 iterations.
- **Oscillation:** Same issues reappear. Anti-oscillation logic kicks in after 2 cycles.
- **Divergence:** More issues each iteration. Indicates a fundamental problem. Brainstormers are dispatched automatically.
