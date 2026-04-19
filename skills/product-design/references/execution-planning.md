# Execution Planning & Context Budget Audit

> Canonical reference for post-Phase-4 execution planning: DAG construction, context-budget
> audit, wave assignment, and AI-hour estimation. See `context-budget.md` for the budget
> model itself and `story-planner-spec.md` for how the plan files are produced.

## Step 10 — Collect and Build Dependency DAG

After all story-planner agents complete:

1. Read all run-state files from `.claude/runs/design-[EPIC_SLUG]/story-N-plan.md` (fallback: `/tmp/super-ralph-design-[EPIC_SLUG]/story-N-plan.md`)
2. Build a dependency DAG:
   - Schema stories before service stories
   - Service stories before route stories
   - BE stories can run in parallel with FE stories (FE uses mock data)
   - Stories modifying the same shared file section must be sequential
3. Detect cycles — if found, reorder to break them

## Step 10.5 — Post-Plan Context Budget Audit

Before computing the execution plan, audit every story's generated bodies against the Execution Context Budget. Any story that red-lines the budget must be split and re-planned — or the build subagent will fail.

**a. Handle planner-declared splits first:**

```bash
PLAN_DIR="$(git rev-parse --show-toplevel)/.claude/runs/design-[EPIC_SLUG]"
[ -d "$PLAN_DIR" ] || PLAN_DIR="/tmp/super-ralph-design-[EPIC_SLUG]"

SPLIT_FILES=$(ls "$PLAN_DIR"/story-*-split-needed.md 2>/dev/null || true)
if [ -n "$SPLIT_FILES" ]; then
  for f in $SPLIT_FILES; do
    # Read the planner's proposed split, update the epic's story list,
    # renumber remaining stories, and RE-DISPATCH Step 9 for each sub-story.
    echo "Planner flagged split needed: $f"
  done
fi
```

For each `story-N-split-needed.md`:
1. Parse the "Proposed split" section to extract the new sub-stories (N.a, N.b, …).
2. Replace Story N in the epic's story list with the sub-stories.
3. Renumber downstream stories only if necessary (prefer sub-numbering N.a/N.b to keep DAG refs stable).
4. Re-dispatch Step 9 story-planner agents for each new sub-story (no larger than size M).
5. Delete the `story-N-split-needed.md` sentinel once the sub-story plans are written.

**b. Measure every completed plan file:**

For each `story-N-plan.md` that exists and is not a split sentinel, extract the four body sections and measure them:

```bash
for f in "$PLAN_DIR"/story-*-plan.md; do
  [ -f "$f" ] || continue
  N=$(basename "$f" | sed -E 's/^story-([0-9A-Za-z.]+)-plan\.md$/\1/')
  STORY_BYTES=$(awk '/^## STORY Issue Body$/{f=1;next}/^## BE Sub-Issue Body$/{f=0}f' "$f" | wc -c | tr -d ' ')
  BE_BYTES=$(awk    '/^## BE Sub-Issue Body$/{f=1;next}/^## FE Sub-Issue Body$/{f=0}f' "$f" | wc -c | tr -d ' ')
  FE_BYTES=$(awk    '/^## FE Sub-Issue Body$/{f=1;next}/^## INT Sub-Issue Body$/{f=0}f' "$f" | wc -c | tr -d ' ')
  INT_BYTES=$(awk   '/^## INT Sub-Issue Body$/{f=1}f' "$f" | wc -c | tr -d ' ')
  TOTAL=$((STORY_BYTES + BE_BYTES + FE_BYTES + INT_BYTES))
  # Token estimate: chars / 4
  TOTAL_TOK=$((TOTAL / 4))
  echo "Story $N: STORY=${STORY_BYTES}c BE=${BE_BYTES}c FE=${FE_BYTES}c INT=${INT_BYTES}c TOTAL=${TOTAL}c (~${TOTAL_TOK} tok)"
done
```

**c. Apply thresholds (chars, using 4 chars ≈ 1 token):**

| Measurement | Target | Hard cap | Action if over hard cap |
|-------------|--------|----------|--------------------------|
| STORY body chars | ≤ 80,000 | 120,000 | Trim prose; if still over, split story |
| BE body chars | ≤ 120,000 | 160,000 | Split BE along CRUD lines or extract sub-story |
| FE body chars | ≤ 120,000 | 160,000 | Split by surface (list vs detail vs form) |
| INT body chars | ≤ 60,000 | 80,000 | Reduce to mock-swap + reference parent Gherkin |
| Combined body chars | ≤ 360,000 | 480,000 | Split story — always the right fix when combined is over |

**d. Remediate over-budget stories:**

For each over-budget story, pick the cheapest remediation in order:

1. **Trim safely:** prose paragraphs, verbose commit-message templates, duplicated Gherkin inside BE/FE. Do this only if the overage is ≤ 10%.
2. **Replace pasted patterns with references:** if the planner embedded long excerpts of existing files ("here is the existing knowledge.ts service…"), replace with `Pattern: $BE_SERVICES_DIR/knowledge.ts` path references. Typical savings: 30-60% on bloated bodies.
3. **Split the story:** if still over after (1) and (2), dispatch a splitter agent with the plan file as input and the split-needed template as output, then re-dispatch Step 9 for each sub-story. This is mandatory for any story over the combined hard cap.

**e. Record budget report:**

Write `$PLAN_DIR/context-budget.md` summarizing all stories, their sizes, and any splits triggered. Include this report in the final design report (Step 17).

```markdown
# Context Budget Report

| Story | STORY tok | BE tok | FE tok | INT tok | Combined | Verdict |
|-------|-----------|--------|--------|---------|----------|---------|
| 1 | 4.2k | 12.8k | 18.1k | 6.0k | 41.1k | OK |
| 2 | 5.0k | 28.4k | 31.2k | 7.5k | 72.1k | OK |
| 3 | 6.1k | 45.0k | 52.3k | 9.8k | 113.2k | SPLIT → 3.a, 3.b |

**Splits triggered:** 1
**Hard-cap violations after split:** 0
```

If any story still exceeds the hard cap after splitting, STOP and emit a BLOCKED report — do not proceed to Issue Creation.

## Step 11 — Compute Execution Plan

Calculate total effort and optimal execution order.

### AI-Hours per Size

| Size | AI-Hours |
|------|----------|
| XS | 0.25 |
| S | 0.75 |
| M | 2 |
| L | 4.5 |
| XL | 9 |

### Wave Assignment

1. Sum AI-hours across all stories (STORY + BE + FE sub-issues)
2. Topological sort the dependency DAG
3. Assign stories to execution waves:
   - Wave 1: All P0 stories with no dependencies
   - Wave 2: P0 stories dependent on Wave 1 + independent P1 stories
   - Wave 3: Remaining P1 + P2 stories
4. Identify the critical path (longest chain of dependent stories)
   4a. Within each story, `[INT]` is always ONE wave after its parent's `[BE]` + `[FE]` (can't start until both merge).

### Parallel Speedup

5. Calculate parallel speedup (how many stories can run concurrently per wave).
