---
name: build-story
description: "Execute a single story end-to-end — build, review-fix, verify, finalise. Skips plan phase when story issue contains TDD tasks."
argument-hint: "<STORY> [--skip-verify] [--skip-finalise] [--resume] [--mode auto|standard|hybrid] [--max-build-iterations N]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)", "Bash(git:*)", "Bash(gh:*)", "Bash(bun:*)", "Bash(codex:*)", "Bash(mkdir:*)", "Bash(cat:*)", "Bash(rm:*)", "Bash(wc:*)", "Bash(jq:*)", "Bash(date:*)", "Bash(realpath:*)", "Bash(test:*)", "Bash(cp:*)", "Read", "Write", "Edit", "Glob", "Grep", "Task"]
---

# Super-Ralph Build-Story Command

Execute a single story from plan to merged PR in one fire-and-forget command. Each phase runs as a dedicated sub-agent with a fresh context window. Temp files bridge state between phases so no sub-agent needs to hold the entire story lifecycle in memory.

**This is a zero-touch command.** Once invoked, it drives a story through build → review-fix → verify → finalise (skipping plan when TDD tasks are embedded in the issue) with zero human interaction.

## Arguments

Parse the user's input for:
- **STORY** (required): One of the following formats:
  - **GitHub issue number**: `#42` or `42` — fetches story context from the issue
  - **Epic story reference**: `docs/epics/my-epic.md#story-3` — extracts story from epic file
  - **Description string**: `"Add JWT authentication"` — used directly as the feature description
- **--skip-verify** (optional): Skip Phase 4 (browser verification). Default: verify runs.
- **--skip-finalise** (optional): Skip Phase 5 (merge + status update). Useful when you want to review the PR manually first.
- **--resume** (optional): Force resume detection even if temp directory doesn't exist. Default: auto-detect.
- **--mode** (optional): Force plan mode. `auto` (default), `standard`, or `hybrid`.
- **--max-build-iterations** (optional): Override iteration budget for the build phase. Default: from plan.

## Temp File Strategy

All inter-phase state lives in temp files. Each sub-agent reads only what its phase needs.

```
/tmp/super-ralph-story-$STORY_ID/
├── context.md           # Story context: requirements, acceptance criteria, dependencies
├── plan-result.md       # Phase 1 → plan path, branch name, task count, mode
├── build-result.md      # Phase 2 → completion status, branch, test results
├── review-result.md     # Phase 3 → PR number, review status, iterations
├── verify-result.md     # Phase 4 → pass/fail, criteria results
├── final-result.md      # Phase 5 → merge status, issues closed
└── progress.md          # Live phase tracker for resume detection
```

**Why temp files?** A full story lifecycle spans ~200 turns across 5 phases. No single sub-agent can hold that context. Temp files let each phase start fresh and read only the 10-20 lines it needs from the previous phase's output.

## Workflow

Execute all phases in order. **NEVER ask for human input** — dispatch research + SME agents for all decisions.

### Step 0a: Load Project Config

Read `.claude/super-ralph-config.md` to load project-specific values. If the file does not exist, first attempt auto-init by invoking the init command logic, then tell the user to run `/super-ralph:init` manually if auto-init fails.

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

### Step 0b: Resolve Story Context

Parse the STORY argument and build the context file.

#### 0a. Detect mode via shared parser

```bash
MODE=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh detect-mode "$STORY_REF")
```

Branch on `$MODE`:
- `local` → subsection 0b (local epic file with full TDD embedded)
- `github` → subsection 0c (GitHub issue — existing behavior)
- `description` → subsection 0d (free-text — existing behavior)

#### 0b. Local Epic File (`<path>.md#story-<N>[-<be|fe|int|story>]`)

```bash
EPIC_FILE="${STORY_REF%%#*}"
FRAG="${STORY_REF#*#}"
if [ "$EPIC_FILE" = "$STORY_REF" ]; then
  echo "Local epic path without #story-N fragment — use /super-ralph:e2e for whole-epic execution" >&2
  exit 1
fi
STORY_NUM=$(echo "$FRAG" | awk -F- '{print $2}')
STORY_ID="story-${STORY_NUM}"
STORY_SLUG="$(basename "$EPIC_FILE" .md)-story-${STORY_NUM}"

STORY_BODY=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh extract-substory "$EPIC_FILE" "$STORY_NUM" story)
BE_BODY=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh    extract-substory "$EPIC_FILE" "$STORY_NUM" be)
FE_BODY=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh    extract-substory "$EPIC_FILE" "$STORY_NUM" fe)
INT_BODY=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh   extract-substory "$EPIC_FILE" "$STORY_NUM" int)
STORY_STATUS=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh get-status "$EPIC_FILE" "$STORY_NUM")
STORY_TITLE=$(grep -m1 "^### Story ${STORY_NUM}:" "$EPIC_FILE" | sed -E "s/^### Story ${STORY_NUM}: //")

# Refuse to rebuild shipped work
if [ "$STORY_STATUS" = "COMPLETED" ]; then
  echo "Story ${STORY_NUM} is already COMPLETED (see ${EPIC_FILE}). Refusing to rebuild shipped work." >&2
  exit 1
fi

if [ -w "$(git rev-parse --show-toplevel)/.claude" ]; then
  STORY_DIR="$(git rev-parse --show-toplevel)/.claude/runs/story-$STORY_ID"
else
  STORY_DIR="/tmp/super-ralph-story-$STORY_ID"
fi
mkdir -p "$STORY_DIR"

# Persist extracted sections for Phase 2 consumption
printf '%s\n' "$STORY_BODY" > "$STORY_DIR/story.md"
printf '%s\n' "$BE_BODY"    > "$STORY_DIR/be.md"
printf '%s\n' "$FE_BODY"    > "$STORY_DIR/fe.md"
printf '%s\n' "$INT_BODY"   > "$STORY_DIR/int.md"
```

#### 0c. GitHub Issue (`#42` or `42`)

```bash
STORY_ID="$ISSUE_NUMBER"
# Prefer durable .claude/runs/ over /tmp/ — survives reboots and OS /tmp cleanup.
# Fall back to /tmp/ only if the repo root isn't writable (e.g., sandboxed env).
if [ -w "$(git rev-parse --show-toplevel)/.claude" ]; then
  STORY_DIR="$(git rev-parse --show-toplevel)/.claude/runs/story-$STORY_ID"
else
  STORY_DIR="/tmp/super-ralph-story-$STORY_ID"
fi
mkdir -p "$STORY_DIR"

# Fetch issue
gh issue view $STORY_ID --repo $REPO --json number,title,body,labels,milestone,state,assignees
```

Extract from the issue:
- Title → `STORY_TITLE`
- Body → requirements, acceptance criteria (Given/When/Then), technical notes
- Labels → complexity (`size/S|M|L|XL`), area (`area/backend`, `area/frontend`)
- Milestone → for later release reference
- Parent epic reference → `Parent: #N` in body

If a parent epic exists, also read the epic issue for broader context:
```bash
PARENT_EPIC=$(gh issue view $STORY_ID --repo $REPO --json body --jq '.body' | grep -oP 'Parent:?\s*#\K\d+')
if [ -n "$PARENT_EPIC" ]; then
  gh issue view $PARENT_EPIC --repo $REPO --json number,title,body
fi
```

Derive slug: `STORY_SLUG` from title (lowercase, hyphens, no special chars).

#### 0d. Description String

Use the description directly. Derive `STORY_ID` from a slug of the description. No GitHub issue context available — plan phase will rely on codebase exploration.

#### 0e. Write Context File

Write `$STORY_DIR/context.md`:
```markdown
# Story: $STORY_TITLE

**ID:** $STORY_ID
**Slug:** $STORY_SLUG
**Branch:** super-ralph/$STORY_SLUG
**Source:** [GitHub Issue #N | Epic docs/epics/X.md#story-N | Description]
**Complexity:** [S|M|L|XL or unknown]
**Epic:** [#N or none]
**Milestone:** [name or none]

## Requirements
[story body / persona-action-outcome]

## Acceptance Criteria
[Given/When/Then blocks]

## Dependencies
[explicit dependencies or "none detected"]

## Technical Notes
[any technical notes from the story]

## Epic Context (if available)
[broader epic goals for context]
```

#### 0f. Initialize Progress Tracker

Write `$STORY_DIR/progress.md`:
```markdown
# Progress: $STORY_TITLE

| Phase | Status | Started | Completed | Notes |
|-------|--------|---------|-----------|-------|
| Plan | PENDING | - | - | |
| Build | PENDING | - | - | |
| Review-Fix | PENDING | - | - | |
| Verify | PENDING | - | - | |
| Finalise | PENDING | - | - | |

Story ID: $STORY_ID
Branch: super-ralph/$STORY_SLUG
Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)
```

### Step 1: Detect Resume State

Check if this story has prior progress to resume from. Resolve `STORY_DIR` by checking both the durable and legacy locations:

```bash
# New durable location (preferred)
NEW_DIR="$(git rev-parse --show-toplevel)/.claude/runs/story-$STORY_ID"
# Legacy /tmp/ location (fallback)
OLD_DIR="/tmp/super-ralph-story-$STORY_ID"
if [ -d "$NEW_DIR" ]; then
  STORY_DIR="$NEW_DIR"
elif [ -d "$OLD_DIR" ]; then
  STORY_DIR="$OLD_DIR"
else
  STORY_DIR="$NEW_DIR"  # fresh start → use durable location
fi
```

| File exists | Meaning | Resume from |
|-------------|---------|------------|
| `final-result.md` with `status: DONE` | Fully complete | Skip all — report done |
| `verify-result.md` | Verify done | Phase 5 (finalise) |
| `review-result.md` | Review done | Phase 4 (verify) |
| `build-result.md` with `status: COMPLETE` | Build done | Phase 3 (review-fix) |
| `plan-result.md` | Plan done | Phase 2 (build) |
| Only `context.md` | Just started | Phase 1 (plan) |
| Nothing | Fresh start | Step 0 |

Also check git state:
```bash
# Does the branch already exist?
git branch -a | grep "super-ralph/$STORY_SLUG"

# Does a PR already exist?
gh pr list --head "super-ralph/$STORY_SLUG" --repo $REPO --json number,state
```

- Branch exists + no PR → resume from review-fix
- Branch exists + open PR → resume from verify
- Branch exists + merged PR → resume from finalise or skip

When resuming, read existing result files to populate variables (PR number, plan path, etc.).

Report: `"Resuming Story $STORY_ID from Phase N ($PHASE_NAME)"`

### Phase 1: Plan

**Skip detection:** Before dispatching the plan sub-agent, check if the story source has TDD tasks already embedded:

- **Local mode** (`$MODE = local`): TDD tasks are already in `$STORY_DIR/be.md` and `$STORY_DIR/fe.md` (written in Step 0b). Write `$STORY_DIR/plan-result.md` with:
  ```
  phase: plan
  status: DONE
  mode: embedded
  source: $STORY_REF
  be_body_file: $STORY_DIR/be.md
  fe_body_file: $STORY_DIR/fe.md
  int_body_file: $STORY_DIR/int.md
  branch: super-ralph/$STORY_SLUG
  ```
  Skip the plan sub-agent entirely. Log: "Local epic TDD tasks — skipping plan phase." Proceed to Phase 2.

- **GitHub mode** (`$MODE = github`): existing detection path below.

```bash
STORY_BODY=$(gh issue view $STORY_ID --repo $REPO --json body --jq '.body')
HAS_TDD=$(echo "$STORY_BODY" | grep -c "## TDD Tasks\|### Task 0:\|### Task 1:" || true)
```

If `HAS_TDD > 0`:
1. Extract the TDD tasks section from the issue body
2. Write it to `$STORY_DIR/plan-result.md` with status: DONE and mode: embedded
3. Skip the plan sub-agent entirely
4. Log: "TDD tasks found in issue body — skipping plan phase"
5. Proceed to Phase 2 (Build)

**Also check for [FE] and [BE] sub-issues:**
```bash
FE_ISSUE=$(gh issue list --repo $REPO --json number,title,body \
  --jq "[.[] | select(.body | test(\"Parent:?\\s*#$STORY_ID\"; \"i\")) | select(.title | startswith(\"[FE]\"))] | first | .number")
BE_ISSUE=$(gh issue list --repo $REPO --json number,title,body \
  --jq "[.[] | select(.body | test(\"Parent:?\\s*#$STORY_ID\"; \"i\")) | select(.title | startswith(\"[BE]\"))] | first | .number")
```

If FE and BE sub-issues exist:
1. Read their bodies for TDD tasks
2. Build can execute FE tasks and BE tasks independently
3. Write to plan-result.md: `fe_issue: $FE_ISSUE`, `be_issue: $BE_ISSUE`

If `HAS_TDD = 0` and no FE/BE sub-issues:
1. Proceed with existing Phase 1 plan sub-agent (unchanged)

### Handling `[INT]` sub-issues

Before falling through to the standard build flow, detect whether the current target (`$STORY_ID`) is itself an `[INT]` sub-issue. `[INT]` sub-issues represent integration-level work (mock swap, Gherkin E2E) that must execute AFTER the corresponding `[BE]` and `[FE]` sub-issues have been merged.

```bash
STORY_TITLE=$(gh issue view $STORY_ID --repo $REPO --json title --jq '.title')
case "$STORY_TITLE" in
  "[INT]"*) IS_INT=true ;;
  *)        IS_INT=false ;;
esac
```

#### If the target is an `[INT]` sub-issue

1. **Verify both [BE] and [FE] sub-issues are merged.** `[INT]` declares its sibling `[BE]` and `[FE]` issues in its body (look for `Depends on: #M, #P` or sibling references under the parent epic). For each sibling:
   ```bash
   gh issue view #N --json state,labels,closedAt,timelineItems
   ```
   The sibling must be `CLOSED` with a merged PR in its `timelineItems`. If either is not merged, **pause** and instruct the user:
   > "Cannot start [INT] #N — [BE] #M or [FE] #P is still open. Complete those first."
   Exit without proceeding.

2. **Use the `skills/issue-management` skill** for all status updates on the `[INT]` issue and its siblings (comments, labels, closure). Do not hand-craft `gh issue` status mutations outside that skill.

3. **Execute the Integration Tasks** from the `[INT]` issue body:
   - **Task 0: Mock Swap** — replace any mocks introduced by `[BE]`/`[FE]` with real wiring across the now-merged contracts.
   - **Task 1: Gherkin E2E** — execute the Gherkin acceptance scenarios end-to-end against the integrated system.

4. **Execute the Verification Tasks** by invoking `/super-ralph:verify` against the integration branch's preview deployment.

5. **Open an integration PR** with `Closes #INT_NUMBER` in the body. Target the default branch (staging) like any other PR.

6. **Do NOT invoke the TDD red/green cycle.** Unit-level TDD was already completed inside the `[BE]` and `[FE]` sub-issues. `[INT]` is integration-level work only: mock swap, E2E coverage, and verification.

If `IS_INT=true`, follow this branch and skip the standard Phase 1 plan/TDD dispatch. If `IS_INT=false`, continue with the normal flow below.

**Goal:** Create a ralph-optimized implementation plan with TDD tasks.

**Dispatch sub-agent:**

```
Task tool:
  model: opus
  max_turns: 50
  description: "Plan Story $STORY_ID: $STORY_TITLE"
  prompt: |
    You are a planning agent for Story "$STORY_TITLE".

    ## Context
    Read the story context: $STORY_DIR/context.md

    ## Instructions
    Read the full planning workflow: ${CLAUDE_PLUGIN_ROOT}/commands/plan.md
    Follow it completely, with these specifics:

    1. **Explore the codebase** — Read CLAUDE.md, understand project structure, tech stack,
       existing patterns, and conventions. Pay special attention to the shared file protocol.

    2. **Research + brainstorm** — Dispatch these agents IN PARALLEL:
       - research-agent: search for best practices relevant to this feature
       - sme-brainstormer 1: task decomposition for autonomous TDD execution
       - sme-brainstormer 2: architecture patterns that fit this codebase
       Synthesize findings.

    3. **Select mode** — If story complexity is S/M: standard. L/XL: hybrid. Auto if unknown.
       Override with: $MODE_OVERRIDE

    4. **Write the plan** with Task 0 as e2e tests from acceptance criteria (outside-in TDD).
       Use the story reference for the --story flag logic in plan.md.

    5. **Validate** — Dispatch plan-reviewer agent.

    6. **Write plan** to: docs/plans/$(date +%Y-%m-%d)-$STORY_SLUG.md

    7. **Write result** to $STORY_DIR/plan-result.md:
       ```
       phase: plan
       status: DONE
       plan_path: [absolute path to plan file]
       branch: super-ralph/$STORY_SLUG
       mode: [standard|hybrid]
       task_count: [N]
       iteration_budget: [N]
       story_ref: [epic_path#story-id if available]
       ```

    NEVER ask for human input. Use research + SME agents for all decisions.
```

**After sub-agent completes:**
1. Read `$STORY_DIR/plan-result.md`
2. Verify plan file exists at the specified path
3. Update `$STORY_DIR/progress.md`: Plan → DONE
4. Extract: `PLAN_PATH`, `BRANCH`, `MODE`, `TASK_COUNT`, `ITERATION_BUDGET`

### Phase 2: Build

**Goal:** Execute the plan in an isolated worktree using TDD.

**Model selection:**
- If plan-result.md has `mode: embedded` (TDD tasks from /design): use **sonnet** — instructions are implementation-ready, agent copies and executes
- If plan-result.md has `mode: standard` or `mode: hybrid` (from /plan): use **opus** — agent needs to reason through implementation details

**Dispatch sub-agent:**

```
Task tool:
  model: [sonnet if mode=embedded, opus otherwise — see model selection above]
  max_turns: $BUILD_TURNS  # standard: task_count * 8, hybrid: task_count * 12
  description: "Build Story $STORY_ID: $STORY_TITLE"
  prompt: |
    You are a build agent executing an implementation plan.

    ## Context
    Read the story context: $STORY_DIR/context.md
    Read the plan result: $STORY_DIR/plan-result.md
    The plan file is at: $PLAN_PATH

    ## Instructions
    Read the full build workflow: ${CLAUDE_PLUGIN_ROOT}/commands/build.md
    Follow it completely, with these specifics:

    1. **Create worktree** — Use EnterWorktree with name "super-ralph/$STORY_SLUG".
       If EnterWorktree is not available, create manually:
       ```bash
       git worktree add .claude/worktrees/super-ralph-$STORY_SLUG -b super-ralph/$STORY_SLUG
       ```
       Install dependencies in the worktree.

    2. **Copy plan** into the worktree if it's untracked:
       ```bash
       PLAN_ABS=$(realpath "$PLAN_PATH")
       test -f "$PLAN_PATH" || (mkdir -p "$(dirname "$PLAN_PATH")" && cp "$PLAN_ABS" "$PLAN_PATH")
       ```

    3. **Execute mode: $MODE**

       **Standard mode:**
       Execute each task sequentially following TDD:
       - Write failing test (RED) → run test → verify FAIL
       - Implement code (GREEN) → run test → verify PASS
       - Commit with descriptive message
       Move to next task. Skip completed tasks (check git log).

       **Hybrid mode:**
       Orchestrate by dispatching sub-agents:
       - For independent tasks: dispatch UP TO 3 in parallel
       - Each sub-agent gets full task text + context
       - After each sub-agent: run spec compliance reviewer, then code quality reviewer
       - Fix issues found before proceeding

    4. **After all tasks:** Run final verification:
       ```bash
       $BE_TEST_CMD
       $FE_TEST_CMD
       ```

    5. **Push the branch:**
       ```bash
       git push -u origin super-ralph/$STORY_SLUG
       ```

    6. **Write result** to $STORY_DIR/build-result.md:
       ```
       phase: build
       status: COMPLETE|FAILED
       branch: super-ralph/$STORY_SLUG
       worktree: [path]
       mode: [standard|hybrid]
       tasks_completed: [N/M]
       tasks_failed: [list or "none"]
       test_results: [X passed, Y failed, Z skipped]
       commits: [number of commits]
       ```

    If a task fails after 3 attempts, mark it in BLOCKED.md and continue with
    independent tasks. Write FAILED status only if blocking tasks remain.

    NEVER ask for human input. Use research + SME agents for all decisions.
```

**Calculating BUILD_TURNS:**
- Standard mode: `task_count * 8` (each task ~8 turns: test + implement + verify + commit)
- Hybrid mode: `task_count * 12` (adds review gates per task)
- Minimum: 30, Maximum: 200

**After sub-agent completes:**
1. Read `$STORY_DIR/build-result.md`
2. Check status:
   - COMPLETE → proceed to Phase 3
   - FAILED → dispatch SME brainstormer to analyze failure, attempt one retry, then report
3. Update `$STORY_DIR/progress.md`: Build → DONE or FAILED

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

### Phase failures

| Phase | On failure | Recovery |
|-------|-----------|----------|
| Plan | SME can't decompose | Retry with different brainstormers. If still fails → BLOCKED. |
| Build | Task stuck 3+ iterations | Mark task BLOCKED, continue independent tasks. Report partial build. |
| Build | Tests fail after all tasks | Dispatch issue-fixer sub-agent. Retry tests. Max 2 retries. |
| Review-Fix | Oscillation detected | Dispatch sme-brainstormer for architectural fix. Max 5 iterations. |
| Review-Fix | Can't create PR | Check branch pushed, check gh auth. Report error. |
| Verify | Preview URL not found | Warn and skip verify. Suggest manual verification. |
| Verify | Criteria fail | Dispatch repair sub-agent → re-verify. Max 2 retries. |
| Finalise | Merge conflict | Rebase staging, resolve conflicts, re-push, re-merge. |
| Finalise | CI fails | Wait and retry. If persistent, investigate with SME. |

### Full retry

If the command is re-run after a failure:
1. Detect existing `$STORY_DIR` and `progress.md`
2. Find the last completed phase
3. Resume from the next phase
4. Re-use existing temp files (plan path, branch, PR number)

This makes the command **idempotent** — safe to re-run without duplicating work.

---

## Critical Rules

- **Fire and forget.** Zero human interaction. All decisions via research + SME agents.
- **One sub-agent per phase.** Each phase gets a fresh context window. No phase inherits conversation history from another — only temp file data.
- **Temp files are the handoff contract.** Every phase writes structured output. Every phase reads only what it needs. Format is `key: value` for easy parsing.
- **Maximize internal parallelism:**
  - Plan: research + 2-3 SME brainstormers in parallel
  - Build (hybrid): up to 3 independent tasks in parallel
  - Review-fix: all 6 review agents dispatched in parallel
  - Verify: sequential (browser is single-threaded)
  - Finalise: sequential (merge safety)
- **Idempotent.** Re-running detects existing progress and resumes. Never creates duplicate branches, PRs, or plans.
- **All PRs target staging.** Never merge directly to main. Staging is the default branch.
- **Shared file protocol.** Plan phase must identify shared file modifications. Build phase appends to section ends only.
- **Story executor branches:** `super-ralph/$STORY_SLUG` naming convention.
- **Cleanup worktrees.** After finalise, the worktree is removed. Build result records the path for cleanup.
- **Report progress.** Update progress.md after every phase so resume detection works.
- **Verify deployment before declaring done.** After merge to staging in Phase 5, wait for Vercel CD to complete and verify the staging deployment is healthy. Merge success != deployment success. Include `deploy_status` in final-result.md.
- **Don't over-dispatch.** The orchestrator (this command) handles sequencing. Sub-agents handle execution. Don't nest more than 2 levels of sub-agents (orchestrator → phase agent → review/fix/brainstorm agents).
