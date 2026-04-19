---
name: review-fix
description: "Autonomously review, test, and fix code on a feature branch until clean, then create a PR"
argument-hint: "[--max-iterations N] [--aspects ASPECTS...] [--no-pr]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)", "Bash(gh:*)", "Bash(git:*)", "Bash(bun:*)", "Bash(npm:*)", "Read", "Write", "Edit", "Glob", "Grep", "Task"]
---

# Super-Ralph Review-Fix Command

Autonomously review, test, and fix code on a feature branch. Rebases to the default branch each iteration, runs all regression tests, dispatches review agents on the branch diff, fixes Critical/Important issues, and repeats until clean. Creates a PR when done.

## Arguments

Parse the user's input for:
- **--max-iterations** (optional): Maximum review-fix cycles. Default: 0 (unlimited — loops until clean)
- **--aspects** (optional): Which review aspects to run. Options: `comments`, `tests`, `errors`, `types`, `code`, `simplify`, `all`. Default: `all`
- **--no-pr** (optional): Skip PR creation after clean. Default: false (PR is created).

## Workflow

### Step 0: Create Isolated Worktree

Create a git worktree so the review-fix loop doesn't interfere with other Claude windows.

1. **Determine the target branch:**
   - Use current branch (`git branch --show-current`)
   - Verify it's not the default branch — if so, report error

2. **Detect worktree directory** (autonomous — never ask the user):
   ```bash
   if [ -d .worktrees ]; then WTDIR=".worktrees"
   elif [ -d worktrees ]; then WTDIR="worktrees"
   else WTDIR=".worktrees"
   fi
   ```

3. **Ensure directory is git-ignored**:
   ```bash
   git check-ignore -q "$WTDIR" 2>/dev/null || echo "$WTDIR/" >> .gitignore
   ```

4. **Create worktree from the target branch:**
   ```bash
   SLUG="review-fix-$(echo "$BRANCH" | sed 's/[\/]/-/g')"
   git worktree add "$WTDIR/$SLUG" "$BRANCH"
   ```

5. **Install dependencies** (auto-detect):
   ```bash
   cd "$WTDIR/$SLUG"
   if [ -f bun.lock ] || [ -f bun.lockb ]; then bun install
   elif [ -f package.json ]; then npm install
   fi
   ```

6. **All subsequent steps run inside the worktree.**

7. **Report**: `"Worktree created at <path> for branch <BRANCH>. Starting review-fix."`

### Step 1: Construct Review-Fix Prompt

Read `${CLAUDE_PLUGIN_ROOT}/skills/review-fix-loop/references/review-fix-prompt.md` and fill in:
- `[FEATURE_BRANCH]` → the feature branch name

### Step 2: Set Up Ralph Loop

Run the setup script:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh "<PROMPT>" --max-iterations <N> --completion-promise "REVIEW_CLEAN"
```

Where:
- `<PROMPT>` is the review-fix prompt from Step 1
- `<N>` is the max iterations (0 for unlimited)

### Step 3: Start First Iteration

Execute the first review-fix cycle:

1. **Rebase to default branch:**
   ```bash
   DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')
   git fetch origin "$DEFAULT_BRANCH"
   git rebase "origin/$DEFAULT_BRANCH"
   ```

2. **Run regression tests** — run ALL test suites:
   ```bash
   if [ -f bun.lock ] || [ -f bun.lockb ]; then RUNNER="bun"
   elif [ -f package.json ]; then RUNNER="npm"
   fi
   $RUNNER test 2>&1
   ```
   Record results: total passed/failed/skipped, list of failing tests.
   Classify failures as NEW (caused by review-fix) or PRE-EXISTING.

3. **Run review agents** (dispatch via Task tool in parallel based on --aspects):
   - `code` → dispatch code-reviewer agent (review `git diff origin/$DEFAULT_BRANCH...HEAD`, include test results)
   - `errors` → dispatch silent-failure-hunter agent
   - `tests` → dispatch pr-test-analyzer agent (review branch diff for test coverage)
   - `comments` → dispatch comment-analyzer agent (review branch diff for comment quality)
   - `types` → dispatch type-design-analyzer agent (only if new types detected)
   - `simplify` → dispatch code-simplifier agent
   - `all` → dispatch all applicable agents

4. **Parse findings** — classify each issue by severity:
   - Critical (confidence >= 90): Must fix — includes new test failures
   - Important (confidence >= 80): Should fix
   - Minor: Log but don't fix
   - Suggestions: Log but don't fix

5. **Decision point:**
   - **No Critical AND no Important findings AND all tests pass** → output `<promise>REVIEW_CLEAN</promise>`, then proceed to create PR
   - **Issues found OR tests failing** → dispatch issue-fixer agent with structured findings, then commit

6. **Create PR** (after REVIEW_CLEAN, unless `--no-pr` set):
   ```bash
   git push -u origin HEAD
   EXISTING_PR=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number')
   if [ -z "$EXISTING_PR" ]; then
     DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')
     # Discover associated GitHub issue from the plan file or branch name
     SLUG=$(echo "$BRANCH" | sed 's|super-ralph/||; s|/|-|g')
     PLAN_FILE=$(ls docs/plans/*${SLUG}*.md 2>/dev/null | head -1)
     ISSUE_NUM=""
     if [ -n "$PLAN_FILE" ]; then
       ISSUE_NUM=$(grep -oE '(Closes|Issue)[[:space:]]*#[0-9]+' "$PLAN_FILE" | grep -oE '[0-9]+' | head -1)
     fi
     CLOSES_LINE=""
     if [ -n "$ISSUE_NUM" ]; then
       CLOSES_LINE="Closes #$ISSUE_NUM"
     fi
     gh pr create --title "<auto-generated title>" --body "<summary>

$CLOSES_LINE" --base "$DEFAULT_BRANCH"
   else
     echo "PR #$EXISTING_PR updated."
   fi
   ```

The ralph-loop Stop hook will handle subsequent iterations automatically.

## Dispatch Templates

All Task dispatch templates — review agents (Code Reviewer, Silent Failure Hunter, Test Analyzer, Comment Analyzer, Type Design Analyzer, Code Simplifier), issue-fixer batched dispatch, and SME brainstormer escalation — live in `${CLAUDE_PLUGIN_ROOT}/skills/review-fix-loop/references/agent-templates.md`. Follow that file verbatim when dispatching. Every template already includes the required `max_turns`, output constraints, and diff-reading instructions.

**Key constraints** (full detail in the reference):
- Every review agent: `max_turns: 20`, confidence ≥ 80 filter, agent reads `git diff origin/<default-branch>...HEAD` itself.
- Issue-fixer: `max_turns: 30`, batched at **max 3 issues per dispatch**, verify `git log --oneline -5` between batches.
- SME brainstormer (oscillation only): `max_turns: 15`, invoked after 3+ identical findings in consecutive iterations.

## Anti-Oscillation

Track fix history. If the same issue (same file, same type) appears in 3+ consecutive iterations:
1. This is oscillation — fixing one thing breaks another
2. Dispatch sme-brainstormer agents to analyze the root cause
3. The fix likely needs an architectural change, not a local patch
4. If sme-brainstormers can't resolve it, document in BLOCKED.md and output `<promise>REVIEW_BLOCKED</promise>`

## Critical Rules

- **Always create a worktree.** Never run a review-fix loop in the main working directory.
- **Never ask the user** about worktree location. Default to `.worktrees/` autonomously.
- **Rebase to default branch every iteration.** Use `gh repo view` to detect the default branch — it may be `main`, `dev`, `staging`, etc.
- **Run ALL regression tests every iteration.** Tests are the ground truth — code review alone is not enough.
- **Summarize test output.** Never paste raw test output into sub-agent prompts. Summarize to counts + one-line errors.
- **Batch issue-fixer dispatches.** Maximum 3 issues per dispatch. Sub-agents cannot compact context.
- **Set max_turns on all Task dispatches.** Review agents: 20. Issue-fixer: 30. Brainstormer: 15.
- **Fix Critical before Important.** Severity order matters. New test failures are Critical.
- **Skip Minor and Suggestions.** They don't block completion.
- **Create PR after REVIEW_CLEAN.** Do NOT merge — that is `/super-ralph:finalise`'s job.
- **NEVER ask for human input.** Dispatch research-agent if stuck.
- **Track fix history.** Detect oscillation and escalate to architectural fix.
