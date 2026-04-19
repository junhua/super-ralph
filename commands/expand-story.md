---
name: expand-story
description: "Promote a brief story to full by running the Phase 4 story-planner for it — produces Shared Contract + [BE]/[FE]/[INT] subsections/sub-issues."
argument-hint: "<target> [--all]"
allowed-tools: ["Bash(gh:*)", "Bash(git:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh:*)", "Read", "Write", "Edit", "Glob", "Grep", "Task"]
---

# Super-Ralph Expand-Story Command

Promote a brief story to full. Runs the Phase 4 story-planner (from `/super-ralph:design`) on a single brief story and applies the result in-place.

## Philosophy

Brief stories are intentionally thin — they cost little to produce and exist to support backlog grooming. When the team commits to building a brief story, `/expand-story` runs the expensive planning once, producing the Gherkin AC, Shared Contract, and `[BE]`/`[FE]`/`[INT]` sub-issue bodies. After expansion, `/build-story` works normally.

## Arguments

- **target** (required): The brief story to expand, in one of two forms:
  - **GitHub mode:** `#<story-issue-number>`
  - **Local mode:** `docs/epics/<slug>.md#story-N`
- **--all** (optional): Expand every brief story under the containing epic in waves of 4 parallel. After expansion, invoke `/super-ralph:review-design` once on the epic.

## Workflow

### Step 0: Load Project Config

Read `.claude/super-ralph-config.md`. Auto-init if missing; otherwise instruct user to run `/super-ralph:init`.

### Step 0b: Load Skills

Invoke `super-ralph:product-design` and `super-ralph:issue-management` skills so the expand agent can follow canonical patterns.

### Step 1: Resolve Target

Detect mode via `${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh detect-mode "$TARGET"`.

**Local mode:**
- Extract `$EPIC_FILE` (path before `#story-N`) and `$STORY_NUM`.
- Read the `# EPIC:` heading to get `$EPIC_TITLE`.
- If the file lacks a `# EPIC:` heading, exit with: `"Target is not a valid epic file: $EPIC_FILE"`.

**GitHub mode:**
- Parse `$STORY_NUM` from `#N` form.
- `gh issue view $STORY_NUM --repo $REPO --json title,body,labels,parent`.
- Validate `title` starts with `[STORY]`. Exit with `"Target #$STORY_NUM is not a [STORY] issue"` otherwise.
- Resolve parent `[EPIC]` from issue body's `**Parent:** #N` line.

### Step 2: Verify Story is Brief

```bash
if [ "$MODE" = "local" ]; then
  STORY_LEVEL=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh detect-story-level "$EPIC_FILE" "$STORY_NUM")
else
  CHILD_COUNT=$(gh issue list --repo "$REPO" --search "Parent: #$STORY_NUM in:body" --json title \
    --jq '[.[] | select(.title | startswith("[BE]") or startswith("[FE]") or startswith("[INT]"))] | length')
  [ "$CHILD_COUNT" -eq 0 ] && STORY_LEVEL="brief" || STORY_LEVEL="full"
fi

if [ "$STORY_LEVEL" = "full" ]; then
  echo "Story is already full. Use /super-ralph:improve-design to edit."
  exit 0
fi
if [ "$STORY_LEVEL" = "missing" ]; then
  echo "Story $STORY_NUM not found in $EPIC_FILE"
  exit 1
fi
```

### Step 3: Load Story Context

**Local mode:**
```bash
STORY_BLOCK=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh extract-story "$EPIC_FILE" "$STORY_NUM")
# Plus read the epic header (everything before "## Stories") for scope/personas/dependencies
EPIC_HEADER=$(awk '/^## Stories$/ {exit} {print}' "$EPIC_FILE")
```

**GitHub mode:**
```bash
STORY_BODY=$(gh issue view "$STORY_NUM" --repo "$REPO" --json body --jq '.body')
EPIC_BODY=$(gh issue view "$EPIC_NUM" --repo "$REPO" --json body --jq '.body')
```

Extract from the story block:
- Title, persona, action, outcome (from the "**As a** ... **I want** ... **So that** ..." line)
- Priority, Size (from the metadata line)
- AC bullets (from `#### Acceptance Criteria (Outline)`)

### Step 4: Dispatch Phase 4 Story-Planner

Use the exact prompt contract from `${CLAUDE_PLUGIN_ROOT}/skills/product-design/references/story-planner-spec.md`. Choose model by size:
- S or M → sonnet
- L → opus
- XL → fail with "Story is too large — split via /improve-design first"

```
Task tool:
  model: [sonnet for S/M, opus for L]
  max_turns: 40
  description: "Expand Story $STORY_NUM: $STORY_TITLE"
  prompt: |
    [Use the exact prompt body from story-planner-spec.md Step 9,
     substituting the brief story's fields for TITLE/PERSONA/ACTION/OUTCOME/SIZE/PRIORITY.
     Pass the brief AC bullets as the "Gherkin AC Outline (from epic)" — the planner
     converts them to full Gherkin.]

    Write outputs to:
      $(git rev-parse --show-toplevel)/.claude/runs/expand-<epic-slug>/story-<STORY_NUM>-plan.md
      (fallback: /tmp/super-ralph-expand-<epic-slug>/story-<STORY_NUM>-plan.md)
```

### Step 5: Context-Budget Audit

Run the `execution-planning.md` Step 10.5 audit on the single story. If the combined body exceeds 480,000 chars (hard cap), emit:

```
SPLIT NEEDED

Story $STORY_NUM's expanded body exceeds 480,000 chars.

Primary driver: [...]

Proposed split:
- Story $STORY_NUM.a: [...]
- Story $STORY_NUM.b: [...]

Re-run via: /super-ralph:improve-design "split story $STORY_NUM into list and detail"
```

Then exit cleanly. Do NOT auto-split — expansion is idempotent; structural changes go through `/improve-design`.

### Step 6: Apply Output

**Local mode:**
1. Read the expanded plan from `story-<STORY_NUM>-plan.md`. Extract the four sections (STORY, BE, FE, INT).
2. In the epic file, replace the story block for `### Story <STORY_NUM>:` with:
   - Keep the existing `### Story N:` heading, user-story line, and metadata line.
   - Replace `#### Acceptance Criteria (Outline)` and its bullets with `#### Acceptance Criteria (Gherkin)` + the full Gherkin from the STORY body.
   - Append the Shared Contract block from the STORY body as `#### Shared Contract`.
   - Append the E2E Test Skeleton block as `#### E2E Test Skeleton`.
   - Append `#### [BE] Story <STORY_NUM> — Backend` + BE body.
   - Append `#### [FE] Story <STORY_NUM> — Frontend` + FE body.
   - Append `#### [INT] Story <STORY_NUM> — Integration & E2E` + INT body.
3. Commit:
   ```bash
   git add "$EPIC_FILE"
   git commit -m "expand: story $STORY_NUM of epic $(basename $EPIC_FILE .md)"
   ```

**GitHub mode:**
1. Update the `[STORY]` issue body: replace AC bullets with full Gherkin + Shared Contract + E2E Test Skeleton.
2. Create `[BE]` sub-issue:
   ```bash
   gh issue create --title "[BE] <Story title> — Backend" \
     --label "area/backend" \
     --body "**Parent:** #$STORY_NUM\n\n<BE body from plan>" \
     --repo "$REPO"
   ```
3. Create `[FE]` sub-issue (same pattern).
4. Create `[INT]` sub-issue (same pattern).
5. Update the `[EPIC]` issue body's Stories checklist to nest the new sub-issues under Story N.
6. Update `docs/epics/<slug>.md` summary table if needed (add `[BE]`, `[FE]`, `[INT]` issue numbers to the Story Priority Table).
7. Commit:
   ```bash
   git add docs/epics/
   git commit -m "expand: story #$STORY_NUM of epic #$EPIC_NUM"
   ```

### Step 7: Flip Epic-Level Marker if Fully Expanded

**Local mode:**
```bash
LEVEL=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh detect-design-level "$EPIC_FILE")
if [ "$LEVEL" = "full" ]; then
  # Strip the brief marker
  awk '!/^<!-- super-ralph: brief -->$/' "$EPIC_FILE" > "$EPIC_FILE.tmp" && mv "$EPIC_FILE.tmp" "$EPIC_FILE"
  git add "$EPIC_FILE"
  git commit -m "design: epic $(basename $EPIC_FILE .md) fully expanded"
fi
```

**GitHub mode:**
```bash
# Count remaining brief stories under the epic
REMAINING_BRIEF=$(gh issue list --repo "$REPO" --label "vertical-slice" --search "Parent: #$EPIC_NUM in:body" --json number,title --jq '
  .[] | select(.title | startswith("[STORY]")) | .number
' | while read n; do
  cnt=$(gh issue list --repo "$REPO" --search "Parent: #$n in:body" --json title --jq '[.[] | select(.title | startswith("[BE]") or startswith("[FE]") or startswith("[INT]"))] | length')
  [ "$cnt" -eq 0 ] && echo "$n"
done | wc -l | tr -d ' ')

if [ "$REMAINING_BRIEF" = "0" ]; then
  gh issue edit "$EPIC_NUM" --repo "$REPO" --remove-label brief
fi
```

### Step 8: Invoke `/review-design` on the Expanded Story

Dispatch as sub-agent:

```
Task tool:
  model: sonnet
  max_turns: 30
  description: "Review expanded story $STORY_NUM"
  prompt: |
    Read ${CLAUDE_PLUGIN_ROOT}/commands/review-design.md.
    Follow it for target: $TARGET (the story's parent EPIC in GitHub mode,
    or the epic file in local mode).
    Focus the review on story $STORY_NUM (now full).
    Return verdict: READY / CONDITIONAL / BLOCKED + findings summary.
```

### Step 9: Output Final Report

```markdown
# Story Expanded: $EPIC_TITLE — Story $STORY_NUM

## Target
$TARGET (mode: $MODE)

## Changes Applied
- [STORY] body updated with full Gherkin + Shared Contract + E2E Test Skeleton.
- [BE] sub-issue #$BE_NUM created (GitHub) / appended (local).
- [FE] sub-issue #$FE_NUM created (GitHub) / appended (local).
- [INT] sub-issue #$INT_NUM created (GitHub) / appended (local).

## Epic Status
[brief → full if all stories now full; still mixed with N brief stories remaining]

## Review Verdict
READY | CONDITIONAL | BLOCKED
[Findings summary if any]

## Next
/super-ralph:build-story $TARGET
```

## Critical Rules

- **Refuse on already-full stories.** Use `/super-ralph:improve-design` to edit full stories.
- **Never ask the user.** All decisions use research + SME agents per `product-design` skill.
- **No auto-split.** If the planner exceeds the context budget, emit a SPLIT NEEDED report and exit — user runs `/super-ralph:improve-design` to split.
- **Idempotent apply.** Re-running expand-story on an already-full story is safe (Step 2 exits cleanly with a clear message).
- **Preserve audit trail.** Never delete the original brief AC bullets silently — they get replaced by the expansion commit, diff is the record.
