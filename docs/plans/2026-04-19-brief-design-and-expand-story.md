# Brief Design Mode + `/expand-story` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `--brief` flag to `/super-ralph:design` and a new `/super-ralph:expand-story` command. Brief produces EPIC + STORY skeletons (no BE/FE/INT, no TDD). Expand-story promotes a brief story to full. `/improve-design` and `/review-design` become brief-aware via structural per-story detection.

**Architecture:** Detection is structural (story is full iff it has `#### [BE/FE/INT]` subsections in local, or child sub-issues in GitHub). Two new `parse-local-epic.sh` subcommands (`detect-design-level`, `detect-story-level`) are the single source of truth. Command-level changes thread a `$DESIGN_LEVEL` / `$BRIEF_FLAG` variable through existing phase prompts rather than forking new pipelines. `/build-story`'s Phase 1 skip-detection is fixed so empty `be.md`/`fe.md` fall through to `mode: standard` instead of the hardcoded `mode: embedded`.

**Tech Stack:** Bash + POSIX awk (scripts), markdown (commands, skills, references), existing `test/test-parse-local-epic.sh` harness (bash).

**Reference spec:** `docs/specs/2026-04-19-brief-design-and-expand-story.md`

**Working directory convention:** all paths are relative to the plugin repo root `/Users/junhua/.claude/plugins/super-ralph/` unless noted.

---

## Task Sequence Overview

| # | Task | Category |
|---|------|---------|
| 1 | Add brief + mixed test fixtures | Foundation |
| 2 | Add `detect-story-level` subcommand | Script |
| 3 | Add `detect-design-level` subcommand | Script |
| 4 | Fix local-mode skip-detection in `phase-1-plan.md` | Bug fix |
| 5 | Add brief story template to `story-template.md` | Skill ref |
| 6 | Add brief story template to `epic-template.md` | Skill ref |
| 7 | Add Phase 4b brief story-planner dispatch to `sadd-workflow.md` | Skill ref |
| 8 | Add Phase 5 brief-mode branching to `sadd-workflow.md` | Skill ref |
| 9 | Add Step 11b brief marker injection to `sadd-workflow.md` | Skill ref |
| 10 | Add "Brief Mode" subsection to `product-design/SKILL.md` | Skill |
| 11 | Add `--brief` flag to `commands/design.md` | Command |
| 12 | Add BRIEF-G1..G3 gates to `gate-catalog.md` | Skill ref |
| 13 | Add brief-aware gate selection to `design-review/SKILL.md` | Skill |
| 14 | Update `commands/review-design.md` to document brief awareness | Command |
| 15 | Add Phase 0b + design-level routing to `commands/improve-design.md` | Command |
| 16 | Create `commands/expand-story.md` (single-target) | Command (new) |
| 17 | Add `--all` flow to `commands/expand-story.md` | Command |
| 18 | Update `README.md` with `--brief` + `/expand-story` | Docs |
| 19 | Update `CHANGELOG.md` + bump `plugin.json` version | Release |

Commit after every task.

---

### Task 1: Add brief + mixed test fixtures

**Files:**
- Create: `test/fixtures/brief-epic.md`
- Create: `test/fixtures/mixed-epic.md`

These fixtures are used by every later task's tests.

- [ ] **Step 1: Create the pure-brief fixture**

Create `test/fixtures/brief-epic.md` with this exact content:

```markdown
# EPIC: Brief Sample Feature

<!-- super-ralph: local-mode -->
<!-- super-ralph: brief -->

## Goal
Test fixture for brief-mode parsing.

## Business Context
Exercises brief story-level detection.

## Personas
- Developer — exercises brief fixtures

## Scope — In
- Two brief stories

## Scope — Out
- Full TDD

---

## Stories

### Story 1: Foo listing

**As a** Developer, **I want** to list foos, **So that** I can see what exists.

**Persona:** Developer   **Priority:** P0   **Size:** M   **Status:** PENDING
<!-- PR: -->
<!-- Branch: -->

#### Acceptance Criteria (Outline)

- `[HAPPY]` Given 3 foos exist, when I open /foos, then I see 3 rows within 2 seconds.
- `[EDGE]` Given no foos exist, when I open /foos, then I see an empty-state message "No foos yet".
- `[SECURITY]` Given I am not authenticated, when I open /foos, then I am redirected to /login.

---

### Story 2: Foo detail

**As a** Developer, **I want** to view a foo, **So that** I can inspect it.

**Persona:** Developer   **Priority:** P1   **Size:** S   **Status:** PENDING

#### Acceptance Criteria (Outline)

- `[HAPPY]` Given foo "abc" exists, when I open /foos/abc, then I see its name.
- `[EDGE]` Given foo "missing" does not exist, when I open /foos/missing, then I see a 404 page.
- `[SECURITY]` Given I am in org X and foo belongs to org Y, when I open /foos/Y-foo, then I get 403.
```

- [ ] **Step 2: Create the mixed-epic fixture**

Create `test/fixtures/mixed-epic.md` with this exact content:

```markdown
# EPIC: Mixed Sample Feature

<!-- super-ralph: local-mode -->
<!-- super-ralph: brief -->

## Goal
Story 1 is expanded to full; Story 2 remains brief.

## Personas
- Developer — mixes brief and full stories

---

## Stories

### Story 1: Foo listing

**As a** Developer, **I want** to list foos, **So that** I can see what exists.

**Persona:** Developer   **Priority:** P0   **Size:** M   **Status:** PENDING

#### Acceptance Criteria (Gherkin)

Feature: Foo listing
  Scenario: [HAPPY] Foos render
    Given 3 foos exist
    When I open /foos
    Then I see 3 rows
  Scenario: [EDGE] Empty list
    Given no foos exist
    When I open /foos
    Then I see an empty-state message
  Scenario: [SECURITY] Unauthorized access
    Given I am not authenticated
    When I open /foos
    Then I am redirected to /login

#### Shared Contract
```typescript
export interface Foo { id: string; name: string }
```

#### [BE] Story 1 — Backend

Mock backend section for the fixture.

#### [FE] Story 1 — Frontend

Mock frontend section for the fixture.

#### [INT] Story 1 — Integration & E2E

Mock integration section for the fixture.

---

### Story 2: Foo detail

**As a** Developer, **I want** to view a foo, **So that** I can inspect it.

**Persona:** Developer   **Priority:** P1   **Size:** S   **Status:** PENDING

#### Acceptance Criteria (Outline)

- `[HAPPY]` Given foo "abc" exists, when I open /foos/abc, then I see its name.
- `[EDGE]` Given foo "missing" does not exist, when I open /foos/missing, then I see a 404 page.
- `[SECURITY]` Given I am in org X and foo belongs to org Y, when I open /foos/Y-foo, then I get 403.
```

- [ ] **Step 3: Commit**

```bash
cd /Users/junhua/.claude/plugins/super-ralph
git add test/fixtures/brief-epic.md test/fixtures/mixed-epic.md
git commit -m "test: add brief and mixed epic fixtures"
```

---

### Task 2: Add `detect-story-level` subcommand

**Files:**
- Modify: `scripts/parse-local-epic.sh`
- Modify: `test/test-parse-local-epic.sh` (append tests)

TDD: write the test first, verify it fails, then implement the subcommand.

- [ ] **Step 1: Append failing tests for `detect-story-level`**

Append to end of `test/test-parse-local-epic.sh` (before the final `echo "--- All ..."` line):

```bash
# ─── detect-story-level ───────────────────────────────────────────
BRIEF_FIX="$(cd "$(dirname "$0")" && pwd)/fixtures/brief-epic.md"
MIXED_FIX="$(cd "$(dirname "$0")" && pwd)/fixtures/mixed-epic.md"

LEVEL=$("$SCRIPT" detect-story-level "$BRIEF_FIX" 1)
[ "$LEVEL" = "brief" ] || fail "detect-story-level brief/1 → expected brief got $LEVEL"
pass "detect-story-level brief/1 → brief"

LEVEL=$("$SCRIPT" detect-story-level "$BRIEF_FIX" 2)
[ "$LEVEL" = "brief" ] || fail "detect-story-level brief/2 → expected brief got $LEVEL"
pass "detect-story-level brief/2 → brief"

LEVEL=$("$SCRIPT" detect-story-level "$FIXTURE" 1)
[ "$LEVEL" = "full" ] || fail "detect-story-level sample/1 → expected full got $LEVEL"
pass "detect-story-level sample/1 → full"

LEVEL=$("$SCRIPT" detect-story-level "$MIXED_FIX" 1)
[ "$LEVEL" = "full" ] || fail "detect-story-level mixed/1 → expected full got $LEVEL"
pass "detect-story-level mixed/1 → full"

LEVEL=$("$SCRIPT" detect-story-level "$MIXED_FIX" 2)
[ "$LEVEL" = "brief" ] || fail "detect-story-level mixed/2 → expected brief got $LEVEL"
pass "detect-story-level mixed/2 → brief"

LEVEL=$("$SCRIPT" detect-story-level "$BRIEF_FIX" 99)
[ "$LEVEL" = "missing" ] || fail "detect-story-level brief/99 → expected missing got $LEVEL"
pass "detect-story-level brief/99 → missing"
```

- [ ] **Step 2: Run tests — verify they fail**

Run: `bash test/test-parse-local-epic.sh`
Expected: FAIL on the first `detect-story-level` assertion ("Usage:" error since subcommand is unknown).

- [ ] **Step 3: Implement `detect-story-level` subcommand**

In `scripts/parse-local-epic.sh`, add this case branch BEFORE the final `*)` catch-all:

```bash
  detect-story-level)
    file="${1:?epic file required}"
    num="${2:?story number required}"
    if [ ! -f "$file" ]; then echo "missing"; exit 0; fi
    awk -v n="$num" '
      function story_num(line,   s) {
        s = line; sub(/^### Story /, "", s); return s + 0
      }
      BEGIN { in_story=0; found=0; has_sub=0 }
      /^### Story [0-9]+:/ {
        if (story_num($0) == n + 0) { in_story=1; found=1; next }
        if (in_story) { exit }
        in_story=0
        next
      }
      in_story && /^#### \[(BE|FE|INT)\] / { has_sub=1; exit }
      END {
        if (!found) { print "missing"; exit 0 }
        print (has_sub ? "full" : "brief")
      }
    ' "$file"
    ;;
```

Also update the usage line (final `*)`) to include the new subcommand:

```bash
    echo "Usage: $0 {detect-mode|list-stories|extract-story|extract-substory|get-status|set-status|detect-story-level|detect-design-level} ..." >&2
```

(The `detect-design-level` reference lands in Task 3; pre-adding it here keeps the plan DRY — it will be correct after Task 3.)

- [ ] **Step 4: Run tests — verify they pass**

Run: `bash test/test-parse-local-epic.sh`
Expected: PASS for all 6 new `detect-story-level` assertions (and all existing tests still pass).

- [ ] **Step 5: Commit**

```bash
git add scripts/parse-local-epic.sh test/test-parse-local-epic.sh
git commit -m "script: add detect-story-level subcommand to parse-local-epic.sh"
```

---

### Task 3: Add `detect-design-level` subcommand

**Files:**
- Modify: `scripts/parse-local-epic.sh`
- Modify: `test/test-parse-local-epic.sh`

- [ ] **Step 1: Append failing tests for `detect-design-level`**

Append to `test/test-parse-local-epic.sh` (before the final summary line):

```bash
# ─── detect-design-level ──────────────────────────────────────────
LEVEL=$("$SCRIPT" detect-design-level "$BRIEF_FIX")
[ "$LEVEL" = "brief" ] || fail "detect-design-level brief → expected brief got $LEVEL"
pass "detect-design-level brief → brief"

LEVEL=$("$SCRIPT" detect-design-level "$FIXTURE")
[ "$LEVEL" = "full" ] || fail "detect-design-level sample → expected full got $LEVEL"
pass "detect-design-level sample → full"

LEVEL=$("$SCRIPT" detect-design-level "$MIXED_FIX")
[ "$LEVEL" = "mixed" ] || fail "detect-design-level mixed → expected mixed got $LEVEL"
pass "detect-design-level mixed → mixed"

LEVEL=$("$SCRIPT" detect-design-level "/tmp/nonexistent-$$-epic.md")
[ "$LEVEL" = "not-an-epic" ] || fail "detect-design-level missing → expected not-an-epic got $LEVEL"
pass "detect-design-level missing → not-an-epic"

# A file that exists but lacks "# EPIC:" header
TMP=$(mktemp); echo "not an epic" > "$TMP"
LEVEL=$("$SCRIPT" detect-design-level "$TMP")
[ "$LEVEL" = "not-an-epic" ] || fail "detect-design-level non-epic → expected not-an-epic got $LEVEL"
pass "detect-design-level non-epic → not-an-epic"
rm -f "$TMP"
```

- [ ] **Step 2: Run tests — verify they fail**

Run: `bash test/test-parse-local-epic.sh`
Expected: FAIL on `detect-design-level` (unknown subcommand).

- [ ] **Step 3: Implement `detect-design-level` subcommand**

Add this case branch before the final `*)` in `scripts/parse-local-epic.sh`:

```bash
  detect-design-level)
    file="${1:?epic file required}"
    if [ ! -f "$file" ]; then echo "not-an-epic"; exit 0; fi
    if ! grep -q '^# EPIC:' "$file"; then echo "not-an-epic"; exit 0; fi

    has_marker=0
    grep -q '^<!-- super-ralph: brief -->$' "$file" && has_marker=1

    all_brief=1
    all_full=1
    story_count=0

    # Iterate story numbers from list-stories output
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      story_count=$((story_count + 1))
      # "story-N Title STATUS" — take the "N" part
      sid=$(echo "$line" | awk '{print $1}')
      n=${sid#story-}
      level=$("$0" detect-story-level "$file" "$n" 2>/dev/null || echo "missing")
      [ "$level" = "full" ] && all_brief=0
      [ "$level" = "brief" ] && all_full=0
    done < <("$0" list-stories "$file" 2>/dev/null)

    if [ "$story_count" -eq 0 ]; then
      # Epic with no stories yet — treat as brief if marker, else full
      if [ "$has_marker" -eq 1 ]; then echo "brief"; else echo "full"; fi
      exit 0
    fi

    if [ "$has_marker" -eq 1 ] && [ "$all_brief" -eq 1 ]; then echo "brief"; exit 0; fi
    if [ "$has_marker" -eq 0 ] && [ "$all_full" -eq 1 ]; then echo "full"; exit 0; fi
    echo "mixed"
    ;;
```

Note: this subcommand invokes `"$0"` recursively for `detect-story-level` and `list-stories`. This works because the script already has `$(dirname "$0")` style path resolution implicit in `$0`.

- [ ] **Step 4: Run tests — verify they pass**

Run: `bash test/test-parse-local-epic.sh`
Expected: PASS for all 5 new `detect-design-level` assertions (and all prior tests still pass).

- [ ] **Step 5: Commit**

```bash
git add scripts/parse-local-epic.sh test/test-parse-local-epic.sh
git commit -m "script: add detect-design-level subcommand to parse-local-epic.sh"
```

---

### Task 4: Fix local-mode skip-detection in `phase-1-plan.md`

**Files:**
- Modify: `skills/story-execution/references/phase-1-plan.md`

The current local-mode skip-detection hardcodes `mode: embedded`. For brief stories, `$STORY_DIR/be.md` and `$STORY_DIR/fe.md` will be empty (the extract-substory step produces nothing for a brief story's non-existent `[BE]`/`[FE]` subsection). Without this fix, brief local stories crash the build sub-agent.

- [ ] **Step 1: Read the current local-mode block**

Run: `sed -n '10,30p' skills/story-execution/references/phase-1-plan.md`
Expected: shows lines 10-30 including the hardcoded `mode: embedded` block for local mode.

- [ ] **Step 2: Replace the hardcoded local-mode block**

Find this exact block in `skills/story-execution/references/phase-1-plan.md`:

```markdown
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
```

Replace with:

```markdown
- **Local mode** (`$MODE = local`): Check whether the extracted sub-story files have content. Use `detect-story-level` from `parse-local-epic.sh` to determine the story level:
  ```bash
  LEVEL=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh detect-story-level "$EPIC_FILE" "$STORY_NUM")
  ```

  **If `LEVEL = "full"`** (story has `#### [BE]` / `[FE]` / `[INT]` subsections, so `$STORY_DIR/be.md` + `$STORY_DIR/fe.md` are non-empty): write `$STORY_DIR/plan-result.md` with:
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
  Skip the plan sub-agent entirely. Log: "Local epic full story — TDD embedded, skipping plan phase." Proceed to Phase 2.

  **If `LEVEL = "brief"`** (story has only bulleted AC, no `#### [BE/FE/INT]` subsections): fall through to the Standard Plan Dispatch path below. The plan sub-agent will read `$STORY_DIR/context.md` (which holds the brief story block including AC bullets) and synthesize TDD tasks. Log: "Local epic brief story — dispatching plan sub-agent." The `$STORY_REF` is treated like a `description` for plan purposes, with the brief AC as the source of truth.
```

- [ ] **Step 3: Add a mode-selection note to Standard Plan Dispatch section**

Find the `## Standard Plan Dispatch (when TDD is not embedded)` heading in the same file. Immediately after the heading, insert:

```markdown
This path runs when:
- GitHub mode and the issue body has no `## TDD Tasks` section AND no `[BE]`/`[FE]` sibling sub-issues (existing behavior), OR
- Local mode and `detect-story-level` returns `brief` (new — see Task 4 of the brief-design plan).

The plan sub-agent reads `$STORY_DIR/context.md` for the story context (user story + AC, in Gherkin or bullets depending on source) and produces a full TDD plan.

```

- [ ] **Step 4: Verify the edit landed**

Run: `grep -n "detect-story-level" skills/story-execution/references/phase-1-plan.md`
Expected: at least 1 match inside the Phase 1 Plan section.

Run: `grep -c "LEVEL = \"brief\"" skills/story-execution/references/phase-1-plan.md`
Expected: ≥ 1.

- [ ] **Step 5: Commit**

```bash
git add skills/story-execution/references/phase-1-plan.md
git commit -m "fix(build-story): local-mode skip-detection falls through for brief stories"
```

---

### Task 5: Add brief story template to `story-template.md`

**Files:**
- Modify: `skills/product-design/references/story-template.md`

- [ ] **Step 1: Add "Brief Story Format" section**

At the TOP of `skills/product-design/references/story-template.md`, immediately after the `# Story Template` heading and the `> Config:` blockquote, insert this section:

```markdown
## Brief Story Format (for `/super-ralph:design --brief`)

Brief stories capture the user journey and acceptance criteria outline without implementation detail. Used for backlog grooming. Promote to full via `/super-ralph:expand-story #<story>`.

```markdown
### Story N: [Action-oriented title]

**As a** [persona], **I want** [action], **So that** [outcome].

**Persona:** [X]   **Priority:** P0|P1|P2   **Size:** S|M|L   **Status:** PENDING
<!-- PR: -->
<!-- Branch: -->

#### Acceptance Criteria (Outline)

- `[HAPPY]` Given [precondition], when [action], then [observable outcome with concrete values].
- `[EDGE]` Given [boundary condition], when [action], then [graceful handling].
- `[SECURITY]` Given [unauthorized role], when [action], then [403 / denial message].

#### Notes (optional)

[Free-form context: open decisions, links to discussion, user feedback.]
```

**Rules:**
- Minimum 3 AC bullets: at least one `[HAPPY]`, one `[EDGE]`, one `[SECURITY]`.
- Each bullet is a single sentence combining Given/When/Then.
- Use concrete values ("3 items", "within 2 seconds"), not vague phrases.
- Use the specific persona from the vision, never generic "user".
- No implementation detail (no file paths, no code, no API shapes).
- The `#### Acceptance Criteria (Outline)` heading is the structural marker that distinguishes brief from full (full uses `#### Acceptance Criteria (Gherkin)`).

**Forbidden in brief (enforced by BRIEF-G2 gate):**
- `#### Shared Contract` subsection
- `#### Pre-Decided Implementation` subsection
- `#### [BE]`, `#### [FE]`, `#### [INT]` subsections

---

```

(The trailing `---` separator follows so the existing content of the file begins below.)

- [ ] **Step 2: Verify the insertion**

Run: `grep -c "^## Brief Story Format" skills/product-design/references/story-template.md`
Expected: `1`

Run: `grep -c "^### Story Format" skills/product-design/references/story-template.md`
Expected: `1` (the existing section still exists, untouched).

- [ ] **Step 3: Commit**

```bash
git add skills/product-design/references/story-template.md
git commit -m "docs(design): add brief story format to story-template"
```

---

### Task 6: Add brief story template to `epic-template.md`

**Files:**
- Modify: `skills/product-design/references/epic-template.md`

- [ ] **Step 1: Add a brief block section**

Find this heading in `skills/product-design/references/epic-template.md`:

```markdown
[Continue for all stories...]
```

Immediately after that line, insert:

```markdown

### Brief story variant (for `--brief` mode)

When the EPIC is produced by `/super-ralph:design --brief`, each story block uses the bulleted AC outline format instead of full Gherkin:

```markdown
### Story N: [Action-oriented title]

**As a** [persona], **I want** [action], **So that** [outcome].

**Persona:** [X]   **Priority:** P0|P1|P2   **Size:** S|M|L   **Status:** PENDING
<!-- PR: -->
<!-- Branch: -->

#### Acceptance Criteria (Outline)

- `[HAPPY]` [single-sentence Given/When/Then with concrete values]
- `[EDGE]` [single-sentence Given/When/Then, boundary case]
- `[SECURITY]` [single-sentence Given/When/Then, auth case]
```

Brief stories have NO `#### Shared Contract`, NO `#### Pre-Decided Implementation`, and NO `#### [BE]`/`[FE]`/`[INT]` subsections. See `story-template.md` § "Brief Story Format" for the full spec.

Epic-level header: when ALL stories are brief, the epic file has `<!-- super-ralph: brief -->` on line 3 (after the `# EPIC:` heading and `<!-- super-ralph: local-mode -->` marker if present). When any story is expanded to full, the marker stays until `/super-ralph:expand-story --all` flips it off.

```

- [ ] **Step 2: Verify**

Run: `grep -c "^### Brief story variant" skills/product-design/references/epic-template.md`
Expected: `1`

- [ ] **Step 3: Commit**

```bash
git add skills/product-design/references/epic-template.md
git commit -m "docs(design): add brief story variant to epic-template"
```

---

### Task 7: Add Phase 4b brief story-planner dispatch to `sadd-workflow.md`

**Files:**
- Modify: `skills/product-design/references/sadd-workflow.md`

- [ ] **Step 1: Insert Phase 4b section**

In `skills/product-design/references/sadd-workflow.md`, find this line:

```markdown
## Phase 4 — Story Planning

See `story-planner-spec.md` for the full Phase 4 Step 9 sub-agent dispatch and output contracts.
See `execution-planning.md` for Steps 10, 10.5 (audit), and 11 (wave plan).
```

Immediately after that block, insert:

```markdown
### Phase 4b: Brief Story Planning (only when `--brief` is set)

When `$BRIEF_FLAG = true`, replace the Phase 4 story-planner dispatch with the brief-story-planner dispatch below. Skip Steps 10.5 (context-budget audit) — brief bodies are trivially under budget. Step 11 (wave assignment) still runs normally.

**Brief story-planner sub-agent (parallel, 1 sonnet per story, max 4 concurrent):**

```
Task tool:
  model: sonnet
  max_turns: 15
  description: "Brief plan Story N: [Title]"
  prompt: |
    You are a brief-story-planner agent. Produce ONE brief story block for backlog grooming.

    ## Story
    - Title: [TITLE]
    - Persona: [PERSONA]
    - Action: [ACTION]
    - Outcome: [OUTCOME]
    - Priority: [P0|P1|P2]
    - Size: [S|M|L]

    ## Epic Scope
    - In scope: [LIST]
    - Out of scope: [LIST]

    ## Product context
    [Paste 200-word vision/persona summary from Phase 2 synthesis]

    ## Output format

    Write ONLY the markdown block below. No TDD, no shared contract, no implementation detail, no file paths, no code.

    ```
    ### Story [N]: [Title]

    **As a** [persona], **I want** [action], **So that** [outcome].

    **Persona:** [persona]   **Priority:** [P?]   **Size:** [S|M|L]   **Status:** PENDING
    <!-- PR: -->
    <!-- Branch: -->

    #### Acceptance Criteria (Outline)

    - `[HAPPY]` Given [precondition], when [action], then [observable outcome with concrete values].
    - `[EDGE]` Given [boundary condition], when [action], then [graceful handling].
    - `[SECURITY]` Given [unauthorized role], when [action], then [403 / denial message].
    ```

    Rules:
    - Exactly one bullet for each of `[HAPPY]`, `[EDGE]`, `[SECURITY]` (more allowed, but all three labels MUST appear).
    - Each bullet is one sentence combining Given/When/Then with concrete values.
    - Use the specific persona from the vision, never generic "user".
    - No implementation detail (no file paths, no code, no API shapes).
    - No `#### Shared Contract`, `#### Pre-Decided Implementation`, or `#### [BE/FE/INT]` subsections.

    Write output to:
      $(git rev-parse --show-toplevel)/.claude/runs/design-<EPIC_SLUG>/story-<N>-brief.md
      (fallback: /tmp/super-ralph-design-<EPIC_SLUG>/story-<N>-brief.md)

    NEVER ask for human input. Output must be ready to paste directly into the epic file.
```

**Orchestrator consolidation:** after all brief sub-agents complete, read `story-N-brief.md` files and use them as story block content for Step 11b (local mode) or Phase 5 (GitHub mode — see brief-mode branching).

### Skip Step 10.5 in brief mode

Step 10.5 (Context Budget Audit) is SKIPPED entirely when `$BRIEF_FLAG = true`. Brief bodies (typically 500-1000 chars) cannot red-line the budget. Write a minimal budget report to `.claude/runs/design-<slug>/context-budget.md`:

```markdown
# Context Budget Report (brief mode)

Brief design — no budget audit performed. Bodies are STORY-only, < 2 KB each.
Stories: N
```

```

- [ ] **Step 2: Verify**

Run: `grep -c "^### Phase 4b: Brief Story Planning" skills/product-design/references/sadd-workflow.md`
Expected: `1`

- [ ] **Step 3: Commit**

```bash
git add skills/product-design/references/sadd-workflow.md
git commit -m "docs(design): add Phase 4b brief story-planner dispatch"
```

---

### Task 8: Add Phase 5 brief-mode branching to `sadd-workflow.md`

**Files:**
- Modify: `skills/product-design/references/sadd-workflow.md`

- [ ] **Step 1: Add brief-mode branch to Step 12 (Create EPIC Parent Issue)**

Find this line in `sadd-workflow.md`:

```markdown
### Step 12: Create EPIC Parent Issue
```

Immediately after the heading, insert:

```markdown

**Brief mode:** when `$BRIEF_FLAG = true`, the `[EPIC]` issue is created with the `brief` label added to the label set, and the body section "Story Priority Table" lists stories without nested `[BE]/[FE]/[INT]` sub-issue placeholders. See "Step 13 (brief mode)" below for story creation.

```

- [ ] **Step 2: Add brief-mode branch to Step 13 (Create Story + Sub-Issues)**

Find the `### Step 13: Create Story + Sub-Issues (4 issues per story)` heading. Immediately after the existing intro paragraph (before `**a. [STORY] issue:**`), insert:

```markdown

**Brief mode (`$BRIEF_FLAG = true`):** SKIP steps (b), (c), (d). Only create the `[STORY]` issue per story — no `[BE]`, no `[FE]`, no `[INT]`. The story issue body is the brief block verbatim (title, user-story line, metadata, AC outline). The EPIC body's "Stories" section lists stories as:

```
- [ ] #<story-num> [STORY] Story 1
- [ ] #<story-num> [STORY] Story 2
```

(No nested sub-issue bullets.)

```

- [ ] **Step 3: Update Step 12 EPIC body to mention `brief` label**

In the `gh issue create` invocation inside Step 12, find this line:

```bash
gh issue create --title "[EPIC] <title>" \
  --label "area/<backend|frontend|fullstack>" \
```

Replace with:

```bash
gh issue create --title "[EPIC] <title>" \
  --label "area/<backend|frontend|fullstack>${BRIEF_FLAG:+,brief}" \
```

Add a comment immediately above:

```bash
# When BRIEF_FLAG=true, append "brief" to the label list so /improve-design and /review-design can detect brief epics.
```

- [ ] **Step 4: Verify**

Run: `grep -c "Brief mode" skills/product-design/references/sadd-workflow.md`
Expected: ≥ 2.

Run: `grep -c "BRIEF_FLAG:+,brief" skills/product-design/references/sadd-workflow.md`
Expected: `1`.

- [ ] **Step 5: Commit**

```bash
git add skills/product-design/references/sadd-workflow.md
git commit -m "docs(design): add Phase 5 brief-mode branching"
```

---

### Task 9: Add Step 11b brief marker injection to `sadd-workflow.md`

**Files:**
- Modify: `skills/product-design/references/sadd-workflow.md`

- [ ] **Step 1: Update Step 11b (Local Mode Consolidation) with brief handling**

Find this line in `sadd-workflow.md`:

```markdown
### Step 11b: Consolidate Story Plans into Epic File (only if `--local`)
```

In the step body, find:

```markdown
1. For each story N (in numerical order):
```

Immediately BEFORE that numbered list, insert:

```markdown

**Brief mode (`$BRIEF_FLAG = true`):** the source files are `story-N-brief.md` (not `story-N-plan.md`). Each file contains a single story block (no STORY/BE/FE/INT sections). Consolidation rules below:

1. For each story N in numerical order, read `.claude/runs/design-<EPIC_SLUG>/story-N-brief.md` and append its contents verbatim under the epic's `## Stories` section. Insert a `---` horizontal rule between stories.
2. Insert `<!-- super-ralph: brief -->` as line 3 of the epic file (after `# EPIC: <title>` and the existing `<!-- super-ralph: local-mode -->` marker):
   ```bash
   # POSIX sed — insert after line 2
   awk 'NR==2 { print; print "<!-- super-ralph: brief -->"; next } { print }' "$EPIC_FILE" > "$EPIC_FILE.tmp" && mv "$EPIC_FILE.tmp" "$EPIC_FILE"
   ```
3. Commit:
   ```bash
   git add docs/epics/<file>
   git commit -m "epic: populate brief stories into local epic <slug>"
   ```
4. SKIP Phase 5. Proceed directly to Phase 6.

**Full mode (`$BRIEF_FLAG = false`):** original steps below.

```

(Keep the existing `1. For each story N...` list as "Full mode" content — no other structural change needed.)

- [ ] **Step 2: Verify**

Run: `grep -c "<!-- super-ralph: brief -->" skills/product-design/references/sadd-workflow.md`
Expected: ≥ 1.

- [ ] **Step 3: Commit**

```bash
git add skills/product-design/references/sadd-workflow.md
git commit -m "docs(design): add brief-mode consolidation to Step 11b"
```

---

### Task 10: Add "Brief Mode" subsection to `product-design/SKILL.md`

**Files:**
- Modify: `skills/product-design/SKILL.md`

- [ ] **Step 1: Insert Brief Mode subsection**

Find this line in `skills/product-design/SKILL.md`:

```markdown
## The Outside-In Pipeline
```

Immediately BEFORE that heading, insert:

```markdown
## Brief Mode

`/super-ralph:design --brief` produces an EPIC with brief story skeletons for backlog grooming:
- Title + user-story line + metadata (priority, size, persona, status)
- 3-bullet AC outline (`[HAPPY]` / `[EDGE]` / `[SECURITY]`) — single-sentence Given/When/Then each
- No Shared Contract, no Pre-Decided Implementation, no `[BE]`/`[FE]`/`[INT]` sub-issues

**When to use brief:**
- Sprint prep / backlog grooming before committing to implementation
- Scope debates where stories will reshape
- Quick capture of user feedback into candidate stories

**Promoting brief to full:** `/super-ralph:expand-story #<story>` runs the full Phase 4 story-planner for one story. Use `--all` to expand every brief story under an epic.

**Mixed epics:** after partial expansion, an epic can contain both brief and full stories. Detection is per-story (via `parse-local-epic.sh detect-story-level`); the epic-level `<!-- super-ralph: brief -->` marker is advisory. `/improve-design` and `/review-design` route per-story.

See `references/sadd-workflow.md` § "Phase 4b: Brief Story Planning" for the sub-agent dispatch spec.

```

- [ ] **Step 2: Verify**

Run: `grep -c "^## Brief Mode" skills/product-design/SKILL.md`
Expected: `1`.

- [ ] **Step 3: Commit**

```bash
git add skills/product-design/SKILL.md
git commit -m "docs(design): add Brief Mode subsection to product-design skill"
```

---

### Task 11: Add `--brief` flag to `commands/design.md`

**Files:**
- Modify: `commands/design.md`

- [ ] **Step 1: Add `--brief` to the argument spec**

In `commands/design.md`, find this line in the `## Arguments` section:

```markdown
- **--local** (optional, boolean): Produce a self-contained local epic file; SKIP GitHub issue creation entirely. Downstream commands (`/build-story`, `/e2e`, `/review-design`) must then be invoked with the epic file path rather than an issue number. Default: false.
```

Immediately after that line, insert:

```markdown
- **--brief** (optional, boolean): Produce a brief epic (EPIC header + story skeletons with bulleted AC). SKIPS Phase 4 full story-planner, Step 10.5 context-budget audit, and `[BE]`/`[FE]`/`[INT]` sub-issue creation. Combines with `--local`. Default: false.

When `--brief` is set:
- Phase 4 dispatches brief-story-planner sub-agents (see `skills/product-design/references/sadd-workflow.md` § Phase 4b).
- Step 10.5 (context-budget audit) is skipped; minimal budget report written to `.claude/runs/design-<slug>/context-budget.md`.
- Phase 5 creates `[EPIC]` (with `brief` label) + `[STORY]` issues only. NO `[BE]`/`[FE]`/`[INT]` sub-issues.
- Step 11b (local consolidation) inserts `<!-- super-ralph: brief -->` as line 3 of the epic file.
- Phase 6 (review) uses lite BRIEF-G1..G3 gates via `/review-design`'s auto-detection; the READY verdict becomes `READY FOR EXPAND`.
```

- [ ] **Step 2: Update header argument-hint**

Find this line in the frontmatter at the top of `commands/design.md`:

```markdown
argument-hint: "<feature-or-goal> [--output PATH] [--local]"
```

Replace with:

```markdown
argument-hint: "<feature-or-goal> [--output PATH] [--local] [--brief]"
```

- [ ] **Step 3: Update Step 1 (Load Skills) if needed**

No change needed — `product-design` skill now documents both modes (Task 10).

- [ ] **Step 4: Add brief-mode note at Phase 4 reference**

Find this line in the `### Step 2: Execute the 6-Phase SADD Flow` section:

```markdown
- **`${CLAUDE_PLUGIN_ROOT}/skills/product-design/references/story-planner-spec.md`** — Phase 4 Step 9 (dispatch parallel story-planner sub-agents; produces STORY/BE/FE/INT bodies with pre-decided implementation + exact TDD tasks).
```

Immediately after, insert:

```markdown
- **When `--brief` is set:** dispatch brief-story-planner sub-agents instead; skip `story-planner-spec.md`. See `sadd-workflow.md` § "Phase 4b: Brief Story Planning" for the prompt.
```

- [ ] **Step 5: Verify**

Run: `grep -c "^- \*\*--brief\*\*" commands/design.md`
Expected: `1`.

Run: `grep -c "argument-hint.*--brief" commands/design.md`
Expected: `1`.

- [ ] **Step 6: Commit**

```bash
git add commands/design.md
git commit -m "feat(design): add --brief flag for backlog-grooming output"
```

---

### Task 12: Add BRIEF-G1..G3 gates to `gate-catalog.md`

**Files:**
- Modify: `skills/design-review/references/gate-catalog.md`

- [ ] **Step 1: Add BRIEF Gates subsection**

In `skills/design-review/references/gate-catalog.md`, find this heading:

```markdown
#### Context Budget Gates (per story group)
```

Immediately BEFORE that line, insert:

```markdown
#### BRIEF Gates (apply to brief stories only)

Applied when `detect-story-level` returns `brief`. These gates replace STORY-G2, STORY-G3, BE-G*, FE-G*, INT-G*, CTX-G* for that story.

| Gate | Rule | How to check |
|------|------|--------------|
| BRIEF-G1 | Body contains `#### Acceptance Criteria (Outline)` section with ≥3 bullets; each of `[HAPPY]`, `[EDGE]`, `[SECURITY]` labels appears at least once | `grep -q "^#### Acceptance Criteria (Outline)"` AND `grep -c '^- \`\[HAPPY\]\`'` ≥ 1 AND `grep -c '^- \`\[EDGE\]\`'` ≥ 1 AND `grep -c '^- \`\[SECURITY\]\`'` ≥ 1 |
| BRIEF-G2 | Body does NOT contain `#### Shared Contract`, `#### Pre-Decided Implementation`, `#### [BE]`, `#### [FE]`, or `#### [INT]` subsections | `! grep -qE "^#### (Shared Contract\|Pre-Decided Implementation\|\[BE\]\|\[FE\]\|\[INT\])"` |
| BRIEF-G3 | GitHub mode: the `[STORY]` issue has no `[BE]`/`[FE]`/`[INT]` child issues | `gh issue list --search "Parent: #<N> in:body"` returns no `[BE]`/`[FE]`/`[INT]`-prefixed titles |

```

- [ ] **Step 2: Add brief-aware gate selection section**

At the end of the file (after the last existing gate table), append:

```markdown

## Brief-aware gate selection

Per-story gate selection is determined by `parse-local-epic.sh detect-story-level <epic> <N>` (local mode) or the presence of child `[BE]`/`[FE]`/`[INT]` issues (GitHub mode).

| Story level | Gates applied |
|-------------|--------------|
| brief | STORY-G1, BRIEF-G1, BRIEF-G2, BRIEF-G3 |
| full | STORY-G1, STORY-G2, STORY-G3, BE-G1, BE-G2, FE-G1, FE-G2, INT-G1, INT-G2, CTX-G1, CTX-G2, CTX-G3 |

### Cross-Issue checks in brief mode

| Check | Brief (all stories) | Mixed | Full |
|-------|---------------------|-------|------|
| CX-1 persona consistency | RUN | RUN | RUN |
| CX-2 shared contract consistency | SKIP | RUN (only over full stories) | RUN |
| CX-3 wave DAG validity | RUN | RUN | RUN |
| CX-4 no duplicate titles/personas | RUN | RUN | RUN |
| CX-5 i18n key namespace uniqueness | SKIP | RUN (only over stories with FE sub-issue) | RUN |

## Verdict classification (brief-aware)

- **All stories brief, no BRIEF-G failures:** `READY FOR EXPAND`. Final report lists `/super-ralph:expand-story` commands in wave order instead of `/super-ralph:build-story`.
- **All stories full, no failures:** `READY` (existing verdict).
- **Mixed epic, no failures:** `READY — MIXED`. Final report lists `/super-ralph:expand-story` commands for brief stories and `/super-ralph:build-story` commands for full stories.
- **Any BRIEF-G failure:** `CONDITIONAL`.
- **Any CX-1/CX-3/CX-4 Critical failure:** `BLOCKED`.
- **Any STORY-G1 failure on brief:** `CONDITIONAL` (story needs the outline section before expansion can run).
```

- [ ] **Step 3: Verify**

Run: `grep -c "^#### BRIEF Gates" skills/design-review/references/gate-catalog.md`
Expected: `1`.

Run: `grep -c "READY FOR EXPAND" skills/design-review/references/gate-catalog.md`
Expected: ≥ 1.

- [ ] **Step 4: Commit**

```bash
git add skills/design-review/references/gate-catalog.md
git commit -m "docs(review): add BRIEF-G1..G3 gates and brief-aware verdict classification"
```

---

### Task 13: Add brief-aware gate selection to `design-review/SKILL.md`

**Files:**
- Modify: `skills/design-review/SKILL.md`

- [ ] **Step 1: Insert Brief-Aware Review section**

In `skills/design-review/SKILL.md`, find the heading that introduces the per-story review dispatch (search for `Per-Story Review` or similar). If no such heading exists, find the first `## ` heading after the skill description.

Near the top of the skill body (after the overview paragraph), insert:

```markdown
## Brief-Aware Review

Before dispatching per-story review sub-agents, the skill computes the design level:

```bash
# Local mode
DESIGN_LEVEL=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh detect-design-level "$TARGET")

# GitHub mode
HAS_BRIEF_LABEL=$(gh issue view "$TARGET" --repo "$REPO" --json labels --jq '.labels[] | select(.name=="brief") | .name' | head -1)
# Additionally compute per-story level by checking child issues:
#   gh issue list --repo "$REPO" --search "Parent: #<N>" --json title --jq '[.[] | select(.title | startswith("[BE]") or startswith("[FE]") or startswith("[INT]"))] | length'
```

For each story N, compute `LEVEL_N` (`brief` or `full`):
- Local: `parse-local-epic.sh detect-story-level "$EPIC_FILE" "$N"`
- GitHub: `brief` if no `[BE]`/`[FE]`/`[INT]` child issues, `full` otherwise

Select gates per story from `references/gate-catalog.md` § "Brief-aware gate selection". Dispatch the per-story review sub-agent with the selected gate subset.

Cross-issue checks run per `references/gate-catalog.md` § "Cross-Issue checks in brief mode".

Verdict classification: see `references/gate-catalog.md` § "Verdict classification (brief-aware)".

```

- [ ] **Step 2: Verify**

Run: `grep -c "^## Brief-Aware Review" skills/design-review/SKILL.md`
Expected: `1`.

- [ ] **Step 3: Commit**

```bash
git add skills/design-review/SKILL.md
git commit -m "docs(review): add Brief-Aware Review section to design-review skill"
```

---

### Task 14: Update `commands/review-design.md` to document brief awareness

**Files:**
- Modify: `commands/review-design.md`

- [ ] **Step 1: Add brief-aware note to Step 2**

In `commands/review-design.md`, find this line:

```markdown
- **`${CLAUDE_PLUGIN_ROOT}/skills/design-review/SKILL.md`** — Step 1 (Resolve EPIC), Step 2 (Load sub-issues), Step 2.5 (Apply enforcement gates from `references/gate-catalog.md`), Step 3 (Dispatch per-story review agents in parallel), Step 4 (Cross-issue checks CX-1..CX-5), Step 5 (Classify findings), Step 6 (Auto-fix if `--fix`), Step 7 (Emit verdict).
```

Replace with:

```markdown
- **`${CLAUDE_PLUGIN_ROOT}/skills/design-review/SKILL.md`** — Step 1 (Resolve EPIC), Step 1.5 (Compute design level and per-story level via `parse-local-epic.sh detect-design-level` / `detect-story-level`), Step 2 (Load sub-issues), Step 2.5 (Apply enforcement gates from `references/gate-catalog.md` — including brief-aware selection), Step 3 (Dispatch per-story review agents in parallel with per-story gate subset), Step 4 (Cross-issue checks CX-1..CX-5 with brief-mode adjustments), Step 5 (Classify findings), Step 6 (Auto-fix if `--fix`), Step 7 (Emit verdict — `READY`, `READY FOR EXPAND`, `READY — MIXED`, `CONDITIONAL`, or `BLOCKED`).
```

- [ ] **Step 2: Add brief-aware verdict note to Step 3**

Find this block in `commands/review-design.md`:

```markdown
6. **Verdict** — one of READY / CONDITIONAL / BLOCKED:
   - **READY:** output the Wave Plan with exact `/super-ralph:build-story <target>` launch commands in wave order.
   - **CONDITIONAL:** list stories that can start now + blocked stories with fix required; recommend re-running after fixes.
   - **BLOCKED:** list all Critical findings with fix required; recommend re-running after fixes.
```

Replace with:

```markdown
6. **Verdict** — one of READY / READY FOR EXPAND / READY — MIXED / CONDITIONAL / BLOCKED:
   - **READY:** all stories full, no failures. Output Wave Plan with exact `/super-ralph:build-story <target>` launch commands in wave order.
   - **READY FOR EXPAND:** all stories brief, no BRIEF-G failures. Output Wave Plan with `/super-ralph:expand-story <target>` commands instead.
   - **READY — MIXED:** mixed epic (some brief, some full), no failures. Output Wave Plan with `/super-ralph:expand-story` for brief stories and `/super-ralph:build-story` for full stories.
   - **CONDITIONAL:** list stories that can start now + blocked stories with fix required; recommend re-running after fixes.
   - **BLOCKED:** list all Critical findings with fix required; recommend re-running after fixes.
```

- [ ] **Step 3: Verify**

Run: `grep -c "READY FOR EXPAND" commands/review-design.md`
Expected: ≥ 2.

Run: `grep -c "brief-aware" commands/review-design.md`
Expected: ≥ 1.

- [ ] **Step 4: Commit**

```bash
git add commands/review-design.md
git commit -m "docs(review): document brief-aware verdict classification"
```

---

### Task 15: Add Phase 0b + design-level routing to `commands/improve-design.md`

**Files:**
- Modify: `commands/improve-design.md`

- [ ] **Step 1: Add Phase 0b**

In `commands/improve-design.md`, find this line:

```markdown
### Phase 1: Interpret feedback (1 Sonnet sub-agent)
```

Immediately BEFORE it, insert:

```markdown
### Phase 0b: Detect design level

Compute `$DESIGN_LEVEL` based on mode:

```bash
if [ "$MODE" = "local" ]; then
  DESIGN_LEVEL=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh detect-design-level "$TARGET")
else
  HAS_BRIEF=$(gh issue view "$TARGET" --repo $REPO --json labels --jq '.labels[] | select(.name=="brief") | .name' | head -1)
  if [ -n "$HAS_BRIEF" ]; then DESIGN_LEVEL="brief"; else DESIGN_LEVEL="full"; fi
fi
```

Also compute a per-story level map `$STORY_LEVELS_JSON` for the interpreter prompt (Phase 1) and a per-target `$STORY_LEVEL_FOR_TARGET` for each apply-change agent (Phase 2).

```bash
# Local mode — build JSON map of {story_num: level}
STORY_LEVELS_JSON="{"
FIRST=1
for line in $(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh list-stories "$TARGET"); do
  sid=$(echo "$line" | awk '{print $1}')
  n=${sid#story-}
  level=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh detect-story-level "$TARGET" "$n")
  [ "$FIRST" = "1" ] || STORY_LEVELS_JSON="$STORY_LEVELS_JSON, "
  STORY_LEVELS_JSON="$STORY_LEVELS_JSON\"$n\": \"$level\""
  FIRST=0
done
STORY_LEVELS_JSON="$STORY_LEVELS_JSON}"

# GitHub mode — enumerate child [STORY] issues under the target EPIC
# and check child [BE]/[FE]/[INT] count for each
EPIC_NUM="${TARGET#\#}"
STORY_NUMS=$(gh issue list --repo $REPO --search "Parent: #$EPIC_NUM in:body" --json number,title \
  --jq '.[] | select(.title | startswith("[STORY]")) | .number')
# For each story_num, compute level — same shape as above
```

Pass `$DESIGN_LEVEL` and `$STORY_LEVELS_JSON` into Phase 1; pass the specific `$STORY_LEVEL_FOR_TARGET` into each Phase 2 apply-change prompt.

```

- [ ] **Step 2: Update Phase 1 interpreter prompt**

Find the Phase 1 sub-agent prompt block. Insert this block immediately after the `TARGET: $TARGET (mode: $MODE)` line:

```markdown
    DESIGN_LEVEL: $DESIGN_LEVEL (brief | full | mixed)
    Per-story levels: $STORY_LEVELS_JSON (e.g., {"1": "full", "2": "brief"})
```

In the same prompt, find the `Map the feedback to one or more structured change entries using ONLY these types:` block and append this paragraph immediately after the list of change types:

```markdown
    **Brief-aware routing:**
    - If the feedback targets a story where `STORY_LEVEL = brief` AND the feedback maps to `EDIT_TDD` or `EDIT_SHARED_CONTRACT`, set `clarification_needed: true` with this question: "Story <N> is brief — it has no TDD or Shared Contract yet. Expand it first with `/super-ralph:expand-story <target>`. Then re-run improve-design."
    - If the feedback is `ADD_STORY` and `DESIGN_LEVEL ∈ {brief, mixed}`, default `level: brief` in the details (unless the feedback explicitly says "as full", in which case set `level: full` — the apply-change agent will run the Phase 4 story-planner inline for that one story).
    - If the feedback is `SPLIT_STORY` on a brief story, both halves inherit `level: brief`.
    - If the feedback is `EDIT_AC` on a brief story, produce bulleted AC outline format (not Gherkin).
    - If the feedback is `EDIT_AC` on a full story, produce full Gherkin scenarios.
```

Also append the allowed change-type matrix as a reference appendix in the same prompt:

```markdown
    **Allowed change types by story level:**
    | Change type | brief | full |
    |-------------|-------|------|
    | ADD_STORY | ✓ (default level=brief) | ✓ (default level=full) |
    | REMOVE_STORY | ✓ | ✓ |
    | SPLIT_STORY | ✓ (both halves brief) | ✓ (both halves full) |
    | MERGE_STORIES | ✓ | ✓ |
    | EDIT_AC | ✓ (bullets) | ✓ (Gherkin) |
    | EDIT_TDD | ✗ — clarification | ✓ |
    | EDIT_SHARED_CONTRACT | ✗ — clarification | ✓ |
    | EDIT_SCOPE | ✓ | ✓ |
    | RE_WAVE | ✓ | ✓ |
    | EDIT_METADATA | ✓ | ✓ |
```

- [ ] **Step 3: Update Phase 2 apply-change prompt**

Find the Phase 2 apply-change sub-agent prompt block. Insert immediately after the `Change to apply:` block:

```markdown
    STORY_LEVEL: $STORY_LEVEL_FOR_TARGET
    Output format rules depend on STORY_LEVEL:
    - brief: use bulleted AC outline (`- \`[HAPPY]\` ...`), no Shared Contract, no `[BE]`/`[FE]`/`[INT]` subsections.
    - full: use full Gherkin, Shared Contract block, TDD subsections per story-template.md.
```

- [ ] **Step 4: Verify**

Run: `grep -c "^### Phase 0b" commands/improve-design.md`
Expected: `1`.

Run: `grep -c "STORY_LEVEL" commands/improve-design.md`
Expected: ≥ 3.

- [ ] **Step 5: Commit**

```bash
git add commands/improve-design.md
git commit -m "feat(improve-design): brief-aware change-type routing"
```

---

### Task 16: Create `commands/expand-story.md` (single-target flow)

**Files:**
- Create: `commands/expand-story.md`

This is the biggest new artifact. Keep the single-target flow complete; `--all` lands in Task 17.

- [ ] **Step 1: Create the command file**

Create `commands/expand-story.md` with this exact content:

````markdown
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
````

- [ ] **Step 2: Verify**

Run: `head -5 commands/expand-story.md`
Expected: frontmatter with `name: expand-story`.

Run: `grep -c "^### Step" commands/expand-story.md`
Expected: ≥ 9.

- [ ] **Step 3: Commit**

```bash
git add commands/expand-story.md
git commit -m "feat(expand-story): new command to promote brief stories to full"
```

---

### Task 17: Add `--all` flow to `commands/expand-story.md`

**Files:**
- Modify: `commands/expand-story.md`

- [ ] **Step 1: Append `--all` flow section**

At the end of the "Critical Rules" section in `commands/expand-story.md`, append:

````markdown

## `--all` Flow

When `--all` is passed, the target must be an `[EPIC]` (either file path or issue number). The workflow:

### Step 1 (modified): Enumerate brief stories under the epic

**Local mode:**
```bash
# Target is the epic file (with or without #story-N suffix — strip it)
EPIC_FILE="${TARGET%%#*}"
BRIEF_STORIES=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh list-stories "$EPIC_FILE" | while read line; do
  sid=$(echo "$line" | awk '{print $1}')
  n=${sid#story-}
  level=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh detect-story-level "$EPIC_FILE" "$n")
  [ "$level" = "brief" ] && echo "$n"
done)
```

**GitHub mode:**
```bash
# Target is the EPIC issue number
EPIC_NUM="${TARGET#\#}"
STORY_NUMS=$(gh issue list --repo "$REPO" --search "Parent: #$EPIC_NUM in:body" --json number,title \
  --jq '.[] | select(.title | startswith("[STORY]")) | .number')
BRIEF_STORIES=$(echo "$STORY_NUMS" | while read n; do
  cnt=$(gh issue list --repo "$REPO" --search "Parent: #$n in:body" --json title \
    --jq '[.[] | select(.title | startswith("[BE]") or startswith("[FE]") or startswith("[INT]"))] | length')
  [ "$cnt" -eq 0 ] && echo "$n"
done)
```

If `$BRIEF_STORIES` is empty, print `"No brief stories to expand under $TARGET"` and exit cleanly.

### Step 2-5 (per story, in waves of 4 parallel)

For each brief story, run Steps 2-5 of the single-target flow in parallel, using Task tool with up to 4 concurrent sub-agents. Each sub-agent's prompt body is the Phase 4 story-planner dispatch (see Step 4 above).

Orchestrator collects all plan files, audits budget per story, and skips any story whose audit emits SPLIT NEEDED (report those to user at end).

### Step 6 (per story, sequential)

Apply outputs one story at a time (sequential to avoid git conflicts on the epic file).

### Step 7: Flip epic marker (once, at end)

Run the flip logic from Step 7 of the single-target flow once at the end.

### Step 8: Invoke `/review-design` on the epic

Dispatch ONE review-design sub-agent for the whole epic (not per story):

```
Task tool:
  model: sonnet
  max_turns: 30
  description: "Review epic after --all expansion"
  prompt: |
    Read ${CLAUDE_PLUGIN_ROOT}/commands/review-design.md.
    Follow it for target: $TARGET.
    Return verdict + findings summary.
```

### Step 9: Final report

```markdown
# Epic Expanded: $EPIC_TITLE (all stories)

## Stories Expanded
| # | Title | Size | Sub-issues | Verdict |
|---|-------|------|------------|---------|
| 1 | Foo listing | M | BE #N, FE #N, INT #N | READY |
| 2 | Foo detail | S | BE #N, FE #N, INT #N | READY |

## Stories Skipped (split required)
| # | Title | Reason |
|---|-------|--------|
| [if any] | [...] | Split via /improve-design |

## Epic Status
brief → full (all stories expanded)

## Review Verdict
READY | CONDITIONAL | BLOCKED

## Next
[/super-ralph:build-story commands for each expanded story, in wave order]
```
````

- [ ] **Step 2: Verify**

Run: `grep -c "^## \`--all\` Flow" commands/expand-story.md`
Expected: `1`.

- [ ] **Step 3: Commit**

```bash
git add commands/expand-story.md
git commit -m "feat(expand-story): add --all flow for bulk epic expansion"
```

---

### Task 18: Update `README.md` with `--brief` + `/expand-story`

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add `--brief` to the `/design` section**

In `README.md`, find the section that documents `/super-ralph:design` (search for `design` header). Find the argument table or bulleted list of options. Add a new entry:

```markdown
- `--brief` — Produce a brief epic (EPIC + STORY skeletons with bulleted AC; no BE/FE/INT sub-issues, no TDD). Use for backlog grooming. Promote individual stories to full via `/super-ralph:expand-story`.
```

- [ ] **Step 2: Add `/expand-story` to the command list**

In `README.md`, find the list of commands (search for `## Commands` or a table of commands). Add:

```markdown
- **`/super-ralph:expand-story <target> [--all]`** — Promote a brief story (or all brief stories in an epic via `--all`) to full by running the Phase 4 story-planner. Creates the `[BE]`/`[FE]`/`[INT]` sub-issues and replaces bulleted AC with full Gherkin.
```

- [ ] **Step 3: Add a "Brief Design Flow" section**

Add a new top-level section to `README.md` (under the existing command docs):

```markdown
## Brief Design Flow

For backlog grooming and sprint prep, run `/super-ralph:design` with `--brief`:

```
# Local brief (everything in a single markdown file)
/super-ralph:design --local --brief "Phase 3 knowledge refresh"

# GitHub brief (EPIC + STORY issues on GitHub, with `brief` label)
/super-ralph:design --brief "Phase 3 knowledge refresh"
```

Brief stories have bulleted `[HAPPY]`/`[EDGE]`/`[SECURITY]` AC — no shared contract, no TDD. When a brief story is ready to build, promote it:

```
/super-ralph:expand-story docs/epics/2026-04-19-knowledge-refresh.md#story-3
# or on GitHub:
/super-ralph:expand-story #531
```

`/super-ralph:improve-design` works on both brief and full stories; it routes per-story and refuses `EDIT_TDD`/`EDIT_SHARED_CONTRACT` on brief stories (with a helpful pointer to `/expand-story`).

`/super-ralph:review-design` applies lite `BRIEF-G1..G3` gates on brief stories and full gates on expanded ones. A pure brief epic yields verdict `READY FOR EXPAND` instead of `READY`.
```

- [ ] **Step 4: Verify**

Run: `grep -c "^## Brief Design Flow" README.md`
Expected: `1`.

Run: `grep -c "expand-story" README.md`
Expected: ≥ 3.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs(readme): document --brief flag and /expand-story command"
```

---

### Task 19: Update `CHANGELOG.md` and bump `plugin.json` version

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `.claude-plugin/plugin.json`

- [ ] **Step 1: Add changelog entry**

At the TOP of `CHANGELOG.md` (below the `# Changelog` heading, above the most recent entry), insert:

```markdown
## 0.14.0 — Brief design mode + /expand-story

### Added
- `--brief` flag on `/super-ralph:design` for backlog-grooming output (EPIC + STORY skeletons with bulleted `[HAPPY]`/`[EDGE]`/`[SECURITY]` AC, no BE/FE/INT, no TDD). Combines with `--local`.
- `/super-ralph:expand-story <target> [--all]` command to promote brief stories to full by running the Phase 4 story-planner. Auto-creates `[BE]`/`[FE]`/`[INT]` sub-issues and replaces bulleted AC with full Gherkin.
- `BRIEF-G1`, `BRIEF-G2`, `BRIEF-G3` gates in `/super-ralph:review-design`. New verdicts `READY FOR EXPAND` (all brief) and `READY — MIXED` (hybrid).
- `parse-local-epic.sh detect-story-level` and `detect-design-level` subcommands — structural detection of brief vs full per story and per epic.

### Changed
- `/super-ralph:improve-design` is now brief-aware: detects per-story level and refuses `EDIT_TDD`/`EDIT_SHARED_CONTRACT` on brief stories with a clarification pointing to `/expand-story`.

### Fixed
- `/super-ralph:build-story` local-mode Phase 1 skip-detection previously hardcoded `mode: embedded`. It now falls through to `mode: standard` when the story is brief (empty `be.md`/`fe.md`), unblocking brief local stories. This is also a latent-bug fix: a full epic with accidentally-empty sub-sections would previously crash the build sub-agent.
```

- [ ] **Step 2: Bump plugin.json version**

Find this line in `.claude-plugin/plugin.json`:

```json
  "version": "0.13.0",
```

Replace with:

```json
  "version": "0.14.0",
```

- [ ] **Step 3: Verify**

Run: `grep -c "^## 0.14.0" CHANGELOG.md`
Expected: `1`.

Run: `grep '"version"' .claude-plugin/plugin.json`
Expected: `"version": "0.14.0",`.

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md .claude-plugin/plugin.json
git commit -m "chore(release): 0.14.0 — brief design mode + /expand-story"
```

---

## Post-Implementation Verification

After all tasks commit, run the full test harness one more time:

```bash
cd /Users/junhua/.claude/plugins/super-ralph
bash test/test-parse-local-epic.sh
```

Expected: all assertions PASS (existing + new `detect-story-level` + `detect-design-level`).

Then do a manual smoke test:

```bash
# Sanity: the design command mentions --brief in argument-hint
grep -E '^argument-hint.*--brief' commands/design.md

# Sanity: expand-story command exists with proper frontmatter
head -6 commands/expand-story.md

# Sanity: README lists Brief Design Flow
grep -A 1 "^## Brief Design Flow" README.md

# Sanity: CHANGELOG has 0.14.0 entry
head -20 CHANGELOG.md
```

All four should succeed.

End-to-end validation — run these against a scratch repo (not tracked in the plan, but a known-good canary):

1. `/super-ralph:design --brief --local "Scratch feature for smoke test"` — produces brief epic file.
2. `/super-ralph:review-design docs/epics/<slug>.md` — returns `READY FOR EXPAND`.
3. `/super-ralph:expand-story docs/epics/<slug>.md#story-1` — expands to full.
4. `/super-ralph:review-design docs/epics/<slug>.md` — returns `READY — MIXED`.
5. `/super-ralph:expand-story docs/epics/<slug>.md#story-2 --all` — expands remaining stories; marker flips.
6. `/super-ralph:review-design docs/epics/<slug>.md` — returns `READY`.

If all 6 succeed, the feature is working end-to-end.
