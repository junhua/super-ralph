# Story Execution State Machine

> Canonical reference for how `/super-ralph:build-story` holds state across its 5 phases.
> The command body is a thin orchestrator; this file describes the run-state layout,
> temp-file bridges, resume detection, and progress tracker.
>
> Each phase is documented in its own reference:
> - `phase-1-plan.md`, `phase-2-build.md`, `phase-3-review-fix.md`,
>   `phase-4-verify.md`, `phase-5-finalise.md`.

## Step 0a: Load Project Config

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

## Step 0b: Resolve Story Context

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

## Step 1: Detect Resume State

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

## Handling `[INT]` sub-issues

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

## Step 6: Summary (final report)

After all phases complete, emit the summary report. See `phase-5-finalise.md` for the content.
