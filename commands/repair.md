---
name: repair
description: "Fix bugs, improve features, or modify UI from GitHub issues, text, screenshots, or URLs"
argument-hint: "<#issue|description> [--screenshot PATH] [--url URL] [--hotfix] [--no-pipeline] [--skip-verify] [--skip-finalise]"
allowed-tools: ["Bash(git:*)", "Bash(gh:*)", "Bash(bun:*)", "Bash(mkdir:*)", "Bash(cat:*)", "Bash(rm:*)", "Bash(date:*)", "Bash(test:*)", "Read", "Write", "Edit", "Glob", "Grep", "Task", "WebSearch", "WebFetch"]
---

# Super-Ralph Repair Command

Fast-track reactive workflow for bug fixes, feature modifications, and UI changes. Skips the full design/plan cycle — goes straight from problem to implementation with TDD. After the fix, automatically chains through review-fix, verify, and finalise to merge.

**Two merge paths:**
- **Default:** fix → review-fix → verify → finalise (merge to **staging**)
- **Hotfix:** fix → review-fix → verify → finalise (merge to **main**) → backport to staging

## Arguments

Parse the user's input for:
- **#N** (optional): GitHub issue number — fetch with `gh issue view N --repo $REPO --json title,body,labels`
- **Text description** (optional): Free-form problem statement used as codebase search query
- **--screenshot** (optional): Path to image showing the visual issue
- **--url** (optional): URL to inspect via claude-in-chrome
- **--hotfix** (optional): Branch from `main`, PR targets `main`, auto-backport to `staging` after merge. Use for production-critical bugs and security fixes.
- **--no-pipeline** (optional): Skip review-fix/verify/finalise — only implement the fix and report. Legacy mode for manual pipeline.
- **--skip-verify** (optional): Skip browser verification in the pipeline. Useful for pure backend fixes.
- **--skip-finalise** (optional): Stop at PR creation, don't merge. Useful when you want manual PR review first.

At least one of `#N` or text description must be provided.

## Temp File Strategy

All inter-phase state lives in temp files for pipeline resume:

```
/tmp/super-ralph-repair-$SLUG/
├── context.md        # Problem statement, domain, hotfix flag
├── fix-result.md     # Fix phase output: branch, files, tests
├── review-result.md  # Review-fix phase: PR number, status
├── verify-result.md  # Verify phase: pass/fail
├── final-result.md   # Finalise phase: merge status
└── progress.md       # Phase tracker for resume detection
```

## Workflow

Execute all steps autonomously. **Do NOT ask the user for input at any point.**

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

### Step 1: Parse Input & Gather Context

Collect context from every source provided:

| Input | Action |
|-------|--------|
| `#N` | `gh issue view N --repo $REPO --json title,body,labels,milestone` — extract acceptance criteria, steps to reproduce, labels |
| Text | Use as search query for codebase in Step 3 |
| `--screenshot` | Read image file to understand the visual issue |
| `--url` | Use claude-in-chrome: `tabs_create` → `navigate` → `read_page` / `get_page_text` / `read_console_messages` |

Combine all sources into a single problem statement.

### Step 2: Detect Domain & Hotfix Mode

**Load the repair-domains skill:**

Invoke `super-ralph:repair-domains` for domain detection heuristics and routing.

**2a. Domain Detection:**

1. **Label-based** (if `#N` provided): Read issue labels for `area/frontend`, `area/backend`, `security`, etc.
2. **File-path-based**: Search codebase for files matching the problem statement. Classify by directory:
   - `$FE_DIR/` → frontend
   - `$BE_DIR/` → backend
   - `.github/`, `vercel.*`, `Dockerfile*` → devops
   - `**/terraform/**`, `**/pulumi/**` → cloud-infra
   - `**/auth/**`, `**/session/**`, `**/cors.*` → security
3. **Content-based**: Read the problem statement for signals (CSS/JSX = frontend, SQL/Hono = backend, etc.)
4. **Default**: `backend`

Set `PRIMARY_DOMAIN` and optional `SECONDARY_DOMAINS`.

Report: `"Domain: $PRIMARY_DOMAIN [+ $SECONDARY_DOMAINS]"`

**2b. Load domain-specific skills** (from routing table in repair-domains skill):

| Domain | Skill to load |
|--------|--------------|
| frontend | `frontend-design:frontend-design` |
| devops (Vercel) | `vercel:vercel-functions` |
| others | (no extra skill) |

**2c. Hotfix auto-detection** (if `--hotfix` not explicitly passed):

Auto-enable hotfix when ANY of:
- Issue label is `priority/critical` or `priority/urgent`
- Issue label is `security` with severity indicators in body
- Problem statement mentions "production", "prod", "live site", "customer-facing"
- `--url` points to a production domain (matches URLs from config's Production URLs section)

If auto-detected: `"Auto-detected hotfix: [reason]. Branching from main."`

Set `IS_HOTFIX=true/false` and `TARGET_BRANCH` (`main` if hotfix, `staging` otherwise).

**2d. Create temp directory and write context:**

```bash
SLUG=$(echo "$PROBLEM_SUMMARY" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | head -c 40)
REPAIR_DIR="/tmp/super-ralph-repair-$SLUG"
mkdir -p "$REPAIR_DIR"
```

Write `$REPAIR_DIR/context.md`:
```markdown
# Repair: $PROBLEM_SUMMARY

**Issue:** #N (or "none")
**Domain:** $PRIMARY_DOMAIN [+ $SECONDARY_DOMAINS]
**Hotfix:** $IS_HOTFIX
**Target branch:** $TARGET_BRANCH
**Branch:** fix/$DEV/$SLUG (or hotfix/$DEV/$SLUG)

## Problem Statement
[combined from all inputs]

## Domain Patterns
[from repair-domains skill — relevant search paths, constraints, test commands]
```

Initialize `$REPAIR_DIR/progress.md`:
```markdown
| Phase | Status | Started | Completed |
|-------|--------|---------|-----------|
| Fix | PENDING | - | - |
| Review-Fix | PENDING | - | - |
| Verify | PENDING | - | - |
| Finalise | PENDING | - | - |
| Backport | PENDING | - | - |
```

### Step 3: Research the Problem

Use domain-specific search patterns from `repair-domains/references/domain-patterns.md`:

1. **Search codebase** with Glob/Grep using domain-appropriate patterns
2. **Read** the most relevant files (limit to 5-8 files)
3. **If ambiguous:** dispatch research-agent (Task tool, haiku) for web references
4. **If multiple fix approaches:** dispatch sme-brainstormer (Task tool, sonnet) to evaluate tradeoffs

### Step 4: Create Worktree

1. **Derive branch name:**
   - Default: `fix/<dev>/<slug>` where dev = `git config user.name` lowercased
   - Hotfix: `hotfix/<dev>/<slug>`

2. **Detect worktree directory:**
   ```bash
   if [ -d .worktrees ]; then WTDIR=".worktrees"
   elif [ -d worktrees ]; then WTDIR="worktrees"
   else WTDIR=".worktrees"
   fi
   ```

3. **Ensure git-ignored:**
   ```bash
   git check-ignore -q "$WTDIR" 2>/dev/null || echo "$WTDIR/" >> .gitignore
   ```

4. **Create worktree** (branch point depends on hotfix mode):
   ```bash
   if [ "$IS_HOTFIX" = "true" ]; then
     # Hotfix: branch from main
     git fetch origin main
     git worktree add -b "hotfix/$DEV/$SLUG" "$WTDIR/hotfix-$SLUG" origin/main
   else
     # Regular: branch from HEAD (usually staging)
     git worktree add -b "fix/$DEV/$SLUG" "$WTDIR/fix-$SLUG" HEAD
   fi
   ```

5. **Install deps:**
   ```bash
   cd "$WTDIR/$PREFIX-$SLUG"
   if [ -f bun.lock ] || [ -f bun.lockb ]; then bun install
   elif [ -f package.json ]; then bun install
   fi
   ```

6. **All subsequent work happens inside the worktree.**

### Step 5: Implement Fix with TDD

Follow superpowers:test-driven-development. Apply domain-specific fix constraints from the repair-domains skill.

For each logical change:

1. **Write failing test** that reproduces the bug or specifies the new behavior
2. **Verify RED:** Run domain-appropriate test command:
   - Frontend: `$FE_TEST_CMD <test-file>` (within `$FE_DIR`)
   - Backend: `$BE_TEST_CMD <test-file>` (within `$BE_DIR`)
   - Security: Run both + auth-specific tests
   - DevOps: Validate configs
3. **Implement minimal fix** — apply domain-specific constraints (e.g., i18n for frontend, structured errors for backend, no credential logging for security)
4. **Verify GREEN:** Same test command
5. **Run related test files** to check for regressions
6. **Commit:**
   - From issue: `fix: <description> (#N)`
   - From text: `fix: <description>`

For multi-file fixes, repeat the TDD cycle per logical change. Keep commits atomic.

**Write fix result** to `$REPAIR_DIR/fix-result.md`:
```
phase: fix
status: DONE
branch: $BRANCH_NAME
domain: $PRIMARY_DOMAIN
hotfix: $IS_HOTFIX
target_branch: $TARGET_BRANCH
files_modified: [list]
tests_added: [list]
commits: [count]
issue: #N (or "none")
```

Update progress: Fix → DONE

### Step 6: Pipeline — Review-Fix

**Skip if `--no-pipeline` was passed.** Report branch and suggest manual `/super-ralph:review-fix`.

**Goal:** Review code quality, fix issues, create a PR.

Select review agents based on domain (from repair-domains skill routing table):

| Domain | Agents |
|--------|--------|
| frontend | code-reviewer, type-design-analyzer, code-simplifier |
| backend | code-reviewer, silent-failure-hunter, pr-test-analyzer |
| security | code-reviewer, silent-failure-hunter, pr-test-analyzer |
| devops | code-reviewer |
| cloud-infra | code-reviewer |
| fullstack | ALL agents |

**Dispatch review-fix sub-agent:**

```
Task tool:
  model: opus
  max_turns: 80
  description: "Review-fix repair: $SLUG"
  prompt: |
    You are a review-fix agent for a repair branch.

    ## Context
    Read the repair context: $REPAIR_DIR/context.md
    Read the fix result: $REPAIR_DIR/fix-result.md
    Branch: $BRANCH_NAME

    ## Instructions
    Read the full review-fix workflow: /Users/junhua/.claude/plugins/super-ralph/commands/review-fix.md
    Follow it completely, with these specifics:

    1. **Switch to the branch** in a worktree:
       Check if a worktree already exists for this branch:
       ```bash
       git worktree list | grep "$BRANCH_NAME"
       ```
       If yes, use it. If no, create one.

    2. **Rebase to target branch** ($TARGET_BRANCH):
       ```bash
       git fetch origin "$TARGET_BRANCH"
       git rebase "origin/$TARGET_BRANCH"
       ```

    3. **Run regression tests** (domain-specific):
       $DOMAIN_TEST_COMMANDS

    4. **Dispatch review agents IN PARALLEL** (domain-selected):
       $DOMAIN_REVIEW_AGENTS
       All agents get: branch diff + summarized test results. Max 20 turns each.

    5. **Fix Critical and Important findings** in batches of max 3.

    6. **Loop** until: 0 Critical, 0 Important, all tests pass. Max 5 iterations.

    7. **Create PR** targeting $TARGET_BRANCH:
       ```bash
       git push -u origin HEAD
       EXISTING_PR=$(gh pr list --head "$BRANCH_NAME" --json number --jq '.[0].number')
       if [ -z "$EXISTING_PR" ]; then
         gh pr create \
           --base $TARGET_BRANCH \
           --head "$BRANCH_NAME" \
           --title "fix: $PROBLEM_SUMMARY" \
           --body "## Fix

       $PROBLEM_DESCRIPTION

       ## Domain: $PRIMARY_DOMAIN
       ## Test Plan
       - [x] TDD: failing test → fix → passing test
       - [x] Review-fix: 0 Critical, 0 Important
       - [ ] Browser verification [pending /verify]

       Closes #$ISSUE_NUM"
       fi
       ```

    8. **Write result** to $REPAIR_DIR/review-result.md:
       ```
       phase: review
       status: REVIEW_CLEAN|BLOCKED
       pr_number: [NNN]
       pr_url: [URL]
       branch: $BRANCH_NAME
       target_branch: $TARGET_BRANCH
       iterations: [N]
       findings_fixed: [N]
       ```

    NEVER ask for human input. NEVER output false REVIEW_CLEAN.
```

**After sub-agent completes:**
1. Read `$REPAIR_DIR/review-result.md`
2. Extract `PR_NUMBER`
3. If BLOCKED: report and stop pipeline
4. Update progress: Review-Fix → DONE

### Step 7: Pipeline — Verify

**Skip if `--skip-verify` or `--no-pipeline` was passed.**
**Skip if domain is pure `backend` or `devops` or `cloud-infra`** (no browser UI to verify) — write `status: SKIPPED` and proceed.

**Wait for preview deployment:**
```bash
for i in $(seq 1 30); do
  PREVIEW_URL=$(gh api repos/$REPO/issues/$PR_NUMBER/comments \
    --jq '[.[] | select(.user.login == "vercel[bot]")] | last | .body' 2>/dev/null \
    | grep -oE 'https://[a-zA-Z0-9._-]+\.vercel\.app' | head -1)
  if [ -n "$PREVIEW_URL" ]; then break; fi
  sleep 10
done
```

**Dispatch browser verifier:**

```
Task tool:
  subagent_type: super-ralph:browser-verifier
  model: sonnet
  max_turns: 30
  description: "Verify repair fix for $SLUG"
  prompt: |
    Verify the fix deployed at $PREVIEW_URL.

    ## Problem Fixed
    $PROBLEM_STATEMENT

    ## Acceptance Criteria
    [extracted from issue body or generated: "The reported issue should no longer reproduce"]

    ## Instructions
    1. Navigate to $PREVIEW_URL
    2. Attempt to reproduce the original bug
    3. Verify the fix resolves the issue
    4. Check for side effects (console errors, layout shifts, network failures)
    5. Record GIF evidence
    6. Return structured PASS/FAIL
```

**After sub-agent completes:**
1. Write `$REPAIR_DIR/verify-result.md`
2. If FAIL and fixable: dispatch mini-repair on the branch, re-push, re-verify (max 1 retry)
3. Update progress: Verify → PASS/FAIL/SKIPPED

### Step 8: Pipeline — Finalise

**Skip if `--skip-finalise` or `--no-pipeline` was passed.**

This phase runs **inline** (not as a sub-agent) since it's quick.

1. **Ensure on target branch:**
   ```bash
   git checkout "$TARGET_BRANCH"
   git pull origin "$TARGET_BRANCH"
   ```

2. **Wait for CI checks:**
   ```bash
   gh pr checks $PR_NUMBER --repo $REPO --watch
   ```

3. **Merge PR** (squash):
   ```bash
   gh pr merge $PR_NUMBER --squash --delete-branch --repo $REPO
   ```

4. **If merge fails:** Report error and stop. Do NOT proceed.

5. **Pull merged changes:**
   ```bash
   git pull origin "$TARGET_BRANCH"
   ```

6. **Close related GitHub Issues** (if not auto-closed):
   ```bash
   if [ -n "$ISSUE_NUM" ]; then
     STATE=$(gh issue view $ISSUE_NUM --repo $REPO --json state --jq '.state')
     if [ "$STATE" = "OPEN" ]; then
       gh issue close $ISSUE_NUM --repo $REPO --comment "Shipped in PR #$PR_NUMBER" --reason completed
     fi
   fi
   ```

7. **Move issue to Shipped on Project #$PROJECT_NUM:**
   ```bash
   if [ -n "$ISSUE_NUM" ]; then
     ITEM_ID=$(gh project item-list $PROJECT_NUM --owner $ORG --format json | \
       python3 -c "import json,sys; [print(i['id']) for i in json.load(sys.stdin)['items'] if i.get('content',{}).get('number')==$ISSUE_NUM]" 2>/dev/null)
     if [ -n "$ITEM_ID" ]; then
       gh project item-edit --project-id $PROJECT_ID \
         --id "$ITEM_ID" \
         --field-id $STATUS_FIELD_ID \
         --single-select-option-id $STATUS_SHIPPED
     fi
   fi
   ```

8. **Worktree cleanup:**
   ```bash
   git worktree prune
   WORKTREE_PATH=$(git worktree list | grep "$BRANCH_NAME" | awk '{print $1}')
   if [ -n "$WORKTREE_PATH" ]; then
     git worktree remove --force "$WORKTREE_PATH"
   fi
   ```

9. **Branch cleanup:**
   ```bash
   CURRENT=$(git branch --show-current)
   if [ "$CURRENT" != "$BRANCH_NAME" ]; then
     git branch -D "$BRANCH_NAME" 2>/dev/null
   fi
   ```

Write `$REPAIR_DIR/final-result.md`:
```
phase: finalise
status: DONE
pr_number: $PR_NUMBER
pr_merged: true
target_branch: $TARGET_BRANCH
issue_closed: #$ISSUE_NUM
```

Update progress: Finalise → DONE

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

### Step 10: Report

Output a summary:

```markdown
## Repair Complete

- **Problem:** <one-line summary>
- **Domain:** $PRIMARY_DOMAIN [+ $SECONDARY_DOMAINS]
- **Fix:** <what was changed>
- **Files modified:** <list>
- **Tests added:** <list>
- **Branch:** $BRANCH_NAME (deleted)
- **PR:** #$PR_NUMBER (merged into $TARGET_BRANCH)
- **Issue:** #$ISSUE_NUM (closed)
- **Hotfix:** [yes — backported to staging | no]

| Phase | Status |
|-------|--------|
| Fix | DONE |
| Review-Fix | DONE / SKIPPED |
| Verify | PASS / SKIPPED |
| Finalise | DONE / SKIPPED |
| Backport | DONE / SKIPPED / N/A |
```

**Next steps** (context-dependent):
- If hotfix and milestone exists: `"Consider: /super-ralph:release --tag vX.Y.Z+1"`
- If more open issues: `"Open issues remaining in milestone: N"`
- If pipeline was skipped: `"Run: /super-ralph:review-fix to start the review pipeline"`

Clean up temp directory:
```bash
rm -rf "$REPAIR_DIR"
```

## Resume Detection

If the command is re-run with the same issue/description:

1. Check for existing `$REPAIR_DIR` and `progress.md`
2. Find the last completed phase
3. Resume from the next phase
4. Re-use existing temp files (branch, PR number, etc.)

| File exists | Resume from |
|-------------|------------|
| `final-result.md` with `status: DONE` | Skip all — report done |
| `verify-result.md` | Finalise |
| `review-result.md` | Verify |
| `fix-result.md` | Review-Fix |
| Only `context.md` | Fix (Step 5) |
| Nothing | Start (Step 1) |

## Critical Rules

- **NEVER ask user for input** — use research + SME agents to resolve ambiguity
- **Domain detection is mandatory** — always identify the domain before fixing
- **Domain-specific review agents** — don't run all 6 agents for a pure devops fix
- **Full pipeline by default** — repair chains through review-fix → verify → finalise unless `--no-pipeline`
- **Hotfix branches from main** — regular fixes branch from HEAD (staging)
- **Hotfix backport is mandatory** — after merging to main, cherry-pick to staging
- **Always TDD** — untested fixes cause regressions
- **Minimal changes** — fix the problem, don't refactor adjacent code
- **Link issues** — include `#N` in commits and PR body when the repair originates from a GitHub issue
- **One worktree per repair** — never fix directly on main or staging
- **Skip verify for non-UI domains** — pure backend, devops, and cloud-infra fixes have no browser UI
- **Stop on merge failure** — do NOT update project status if the PR cannot be merged
- **Temp files bridge phases** — each phase writes structured output, the next reads only what it needs
- **Idempotent** — re-running detects existing progress and resumes
