# Super-Ralph Local Mode + Improve-Design Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `--local` mode to `/super-ralph:design` so the full epic+stories plan lives in a single markdown file, teach `/build`, `/build-story`, `/e2e`, and `/review-design` to read that file (auto-detected by path), and introduce a new `/super-ralph:improve-design "<prompt>"` command that autonomously resolves the target epic from the prompt and applies conservative structured edits.

**Architecture:** Reuses the existing `.claude/runs/` run-state pattern and the existing `mode: embedded` skip-plan branch in `/build-story`. Adds a single bash helper `scripts/parse-local-epic.sh` that every command uses for anchor-based section extraction. No new skills; no new dependencies beyond `AskUserQuestion` for improve-design disambiguation.

**Tech Stack:** Bash (POSIX + `awk` + `grep`), Markdown with stable heading anchors (`### Story N:` + `#### [STORY|BE|FE|INT]`), Claude Code tools (`Task`, `Read`, `Edit`, `Write`, `Grep`, `Glob`, `AskUserQuestion`).

**Spec:** `docs/specs/2026-04-18-local-mode-and-improve-design.md`

---

## File Structure

### Create

| Path | Responsibility |
|------|----------------|
| `scripts/parse-local-epic.sh` | Shared parser with subcommands `detect-mode`, `list-stories`, `extract-story`, `extract-substory`, `get-status`, `set-status` |
| `test/fixtures/sample-local-epic.md` | Canonical fixture with 3 stories covering all four sub-sections |
| `test/fixtures/completed-story-epic.md` | Fixture where Story 1 is `COMPLETED` (used for shipped-immutability tests) |
| `test/test-parse-local-epic.sh` | Bash assertions for every subcommand of the parser |
| `commands/improve-design.md` | New command file with 4-phase workflow |

### Modify

| Path | Change summary |
|------|-----------------|
| `commands/design.md` | Add `--local` flag; guard GitHub phase; consolidate run-state into epic file |
| `commands/build.md` | Document new `*.md#story-N` argument shape |
| `commands/build-story.md` | Detect `*.md` path args in Step 0b; add local-mode finalise variant in Phase 5 |
| `commands/e2e.md` | Detect `*.md` path arg; swap `gh` calls for file reads in Step 0b, 1, 4a, 4c, 4d |
| `commands/review-design.md` | Detect `*.md` path arg; build synthetic issue tree from sections |
| `skills/build/SKILL.md` | Step 2 resolves `*.md#story-N` to a temp plan file |
| `commands/help.md` | Version + describe local mode + `improve-design` + `--local` flag |
| `CHANGELOG.md` | Add `v0.11.0` section documenting additions |

---

## Tasks

### Task 1: Create the canonical fixture file

**Files:**
- Create: `test/fixtures/sample-local-epic.md`

**Rationale:** Every subsequent task tests parsing against this fixture. It must cover: epic header, 3 stories of mixed priority/size, full [STORY]/[BE]/[FE]/[INT] bodies, and varied Status values (PENDING, IN_PROGRESS, COMPLETED).

- [ ] **Step 1: Create the fixture**

```bash
mkdir -p /Users/junhua/.claude/plugins/super-ralph/test/fixtures
```

Write `test/fixtures/sample-local-epic.md` with this exact structure:

```markdown
# EPIC: Sample Feature

<!-- super-ralph: local-mode -->

## Goal
Test fixture for local-mode parsing.

## Business Context
Exercises all anchor and sub-section paths used by the parser.

## Success Metrics
| Metric | Current | Target | How to Measure |
| Parse accuracy | 0% | 100% | Fixture tests pass |

## Personas
- Developer — writes commands against this fixture

## Scope — In
- Three stories with full bodies

## Scope — Out
- Real implementation — this is a fixture

## Dependencies
| Prereq | Status | Notes |
| None   | -      | -     |

## Risks
| Risk | Impact | Likelihood | Mitigation |
| Fixture drift | Low | Low | Pinned to this file |

## PM Summary

### Story Priority Table
| # | Story | Priority | Size | Can Ship Without? | Notes |
| 1 | Foo listing | P0 | M | No | Base |
| 2 | Foo detail  | P1 | S | Yes | Follows 1 |
| 3 | Foo search  | P2 | M | Yes | Optional |

### Execution Plan

#### AI-Hours Estimate
| Story | BE | FE | INT | Total |
| 1 | 2h | 1.5h | 1h | 4.5h |
| 2 | 1h | 1h | 0.5h | 2.5h |
| 3 | 1.5h | 2h | 1h | 4.5h |

#### Wave Assignments
| Wave | Stories | Parallel Slots | Estimated Hours |
| 1 | Story 1, Story 3 | 2 | 4.5h |
| 2 | Story 2 | 1 | 2.5h |

---

## Stories

### Story 1: Foo listing

**Persona:** Developer   **Priority:** P0   **Size:** M   **Status:** PENDING
<!-- PR: -->
<!-- Branch: -->

#### [STORY] Story 1

**Parent:** (local epic)

## User Story
**As a** Developer, **I want** to list foos, **So that** I can see what exists.

## User Journey
Developer opens /foos page and sees a table of foos.

## Acceptance Criteria
Feature: Foo listing
  Background:
    Given 3 foos exist
  Scenario: [HAPPY] Foos render
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

## Shared Contract
```typescript
export interface Foo { id: string; name: string }
```

## E2E Test Skeleton
```typescript
import { describe, test, expect } from "bun:test";
describe("Foo listing", () => {
  test("renders", async () => { /* TBD */ });
});
```

#### [BE] Story 1 — Backend

**Parent:** (local epic — Story 1)

## Backend Implementation

### Schema Changes
File: `work-agents/src/db/schema.ts`
Section: `// ─── Foo ────`
```typescript
export const foo = pgTable("foo", { id: text("id").primaryKey() });
```

## TDD Tasks

**Progress check:** `cd work-agents && bun test src/services/__tests__/foo.test.ts` — Expected: PASS

### Task 0: E2E Test Skeleton (Outer RED)
```bash
echo "red"
```

### Task 1: Schema + Migration
```bash
echo "schema"
```

## Completion Criteria
- [ ] BE tests pass

#### [FE] Story 1 — Frontend

**Parent:** (local epic — Story 1)

## Frontend Implementation

### Mock Data
File: `work-web/src/lib/mock/foo.ts`
```typescript
export const mockFoo = [{ id: "1", name: "one" }];
```

## TDD Tasks

**Progress check:** `cd work-web && bun test` — Expected: PASS

### Task 0: E2E Test (Outer RED)

## PM Checkpoints
| Checkpoint | When | What to Verify |
| CP1: Mock renders | After Task 1 | Renders |
| CP2: i18n complete | After Task 3 | EN+zh |
| CP3: API integrated | After BE | Real data |
| CP4: AC pass | End | Gherkin green |

## Completion Criteria
- [ ] FE tests pass

#### [INT] Story 1 — Integration & E2E

**Parent:** (local epic — Story 1)

## Gherkin User Journey
See parent Story 1 [STORY] section above.

## Integration Tasks
### Task 0: Mock Swap
### Task 1: Gherkin E2E

## Verification Tasks
### Task 2: /super-ralph:verify against staging preview

## Completion Criteria
- [ ] INT tests pass

---

### Story 2: Foo detail

**Persona:** Developer   **Priority:** P1   **Size:** S   **Status:** IN_PROGRESS
<!-- PR: #999 -->
<!-- Branch: super-ralph/foo-detail -->

#### [STORY] Story 2

**Parent:** (local epic)

## User Story
**As a** Developer, **I want** to view a foo, **So that** I can inspect it.

## User Journey
Developer clicks a row, sees detail.

## Acceptance Criteria
Feature: Foo detail
  Scenario: [HAPPY] Open detail
    Given foo "abc" exists
    When I open /foos/abc
    Then I see its name
  Scenario: [EDGE] Missing foo
    When I open /foos/missing
    Then I see 404
  Scenario: [SECURITY] Foreign org foo
    Given I am in org X and foo belongs to org Y
    When I open /foos/Y-foo
    Then I get 403

## Shared Contract
```typescript
export type FooDetail = Foo & { createdAt: string };
```

## E2E Test Skeleton
```typescript
describe("Foo detail", () => { test("opens", async () => {}); });
```

#### [BE] Story 2 — Backend

**Parent:** (local epic — Story 2)

## Backend Implementation
### Schema Changes
None.

## TDD Tasks
**Progress check:** `bun test` — Expected: PASS
### Task 0: E2E
### Task 1: Route

## Completion Criteria
- [ ] Route returns detail

#### [FE] Story 2 — Frontend

**Parent:** (local epic — Story 2)

## Frontend Implementation
### Mock Data
```typescript
export const mockFooDetail = { id: "abc", name: "abc", createdAt: "2026-01-01" };
```

## TDD Tasks
**Progress check:** `bun test` — Expected: PASS
### Task 0: E2E

## PM Checkpoints
| Checkpoint | When | What to Verify |
| CP1 | After Task 1 | render |
| CP2 | After Task 3 | i18n |
| CP3 | After BE | API |
| CP4 | End | AC |

## Completion Criteria
- [ ] Detail renders

#### [INT] Story 2 — Integration & E2E

**Parent:** (local epic — Story 2)

## Gherkin User Journey
See parent.

## Integration Tasks
### Task 0: Mock swap
### Task 1: Gherkin E2E

## Verification Tasks
### Task 2: /super-ralph:verify

## Completion Criteria
- [ ] INT green

---

### Story 3: Foo search

**Persona:** Developer   **Priority:** P2   **Size:** M   **Status:** PENDING

#### [STORY] Story 3

**Parent:** (local epic)

## User Story
**As a** Developer, **I want** to search foos, **So that** I can find one quickly.

## User Journey
Developer types in search box, list filters.

## Acceptance Criteria
Feature: Foo search
  Scenario: [HAPPY] Search returns results
  Scenario: [EDGE] No matches
  Scenario: [SECURITY] SQL-injection-safe query

## Shared Contract
```typescript
export type FooSearchQuery = { q: string };
```

## E2E Test Skeleton
```typescript
describe("Foo search", () => {});
```

#### [BE] Story 3 — Backend

**Parent:** (local epic — Story 3)

## TDD Tasks
**Progress check:** `bun test` — Expected: PASS
### Task 0: E2E
### Task 1: Search service

## Completion Criteria
- [ ] Search returns results

#### [FE] Story 3 — Frontend

**Parent:** (local epic — Story 3)

## TDD Tasks
**Progress check:** `bun test` — Expected: PASS
### Task 0: E2E

## PM Checkpoints
| Checkpoint | When | What to Verify |
| CP1 | After Task 1 | render |
| CP2 | After Task 3 | i18n |
| CP3 | After BE | API |
| CP4 | End | AC |

## Completion Criteria
- [ ] Search box works

#### [INT] Story 3 — Integration & E2E

**Parent:** (local epic — Story 3)

## Gherkin User Journey
See parent.

## Integration Tasks
### Task 0: Mock swap
### Task 1: Gherkin E2E

## Verification Tasks
### Task 2: /super-ralph:verify

## Completion Criteria
- [ ] INT green
```

- [ ] **Step 2: Create the completed-story fixture (for shipped-immutability tests)**

Copy `sample-local-epic.md` to `completed-story-epic.md`. Then edit the Story 1 status line from:

`**Persona:** Developer   **Priority:** P0   **Size:** M   **Status:** PENDING`

to:

`**Persona:** Developer   **Priority:** P0   **Size:** M   **Status:** COMPLETED`

And set `<!-- PR: -->` to `<!-- PR: #1234 -->`.

- [ ] **Step 3: Commit**

```bash
git -C /Users/junhua/.claude/plugins/super-ralph add test/fixtures/
git -C /Users/junhua/.claude/plugins/super-ralph commit -m "test: fixtures for local-mode parsing"
```

---

### Task 2: Write the shared parser script — `detect-mode` + `list-stories`

**Files:**
- Create: `scripts/parse-local-epic.sh`
- Test: `test/test-parse-local-epic.sh`

**Rationale:** Every command needs the same rules for "is this arg a local path?" and "what stories are in this file?" A single bash helper keeps the parsing identical across commands.

- [ ] **Step 1: Write failing tests first**

Create `test/test-parse-local-epic.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(dirname "$0")/../scripts/parse-local-epic.sh"
FIXTURE="$(dirname "$0")/fixtures/sample-local-epic.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

# detect-mode: numeric → github
MODE=$("$SCRIPT" detect-mode "#42")
[ "$MODE" = "github" ] || fail "detect-mode #42 → expected github got $MODE"
pass "detect-mode #42 → github"

MODE=$("$SCRIPT" detect-mode "42")
[ "$MODE" = "github" ] || fail "detect-mode 42 → expected github got $MODE"
pass "detect-mode 42 → github"

# detect-mode: *.md → local
MODE=$("$SCRIPT" detect-mode "docs/epics/foo.md")
[ "$MODE" = "local" ] || fail "detect-mode docs/epics/foo.md → expected local got $MODE"
pass "detect-mode docs/epics/foo.md → local"

MODE=$("$SCRIPT" detect-mode "docs/epics/foo.md#story-3")
[ "$MODE" = "local" ] || fail "detect-mode fragment → expected local got $MODE"
pass "detect-mode with fragment → local"

# detect-mode: description → description
MODE=$("$SCRIPT" detect-mode "Add JWT auth")
[ "$MODE" = "description" ] || fail "detect-mode description → expected description got $MODE"
pass "detect-mode free-text → description"

# list-stories: 3 stories in fixture
COUNT=$("$SCRIPT" list-stories "$FIXTURE" | wc -l | tr -d ' ')
[ "$COUNT" = "3" ] || fail "list-stories → expected 3 got $COUNT"
pass "list-stories → 3"

# list-stories returns id title status triples
FIRST=$("$SCRIPT" list-stories "$FIXTURE" | head -1)
case "$FIRST" in
  "story-1"*"Foo listing"*"PENDING"*) pass "list-stories line 1 shape ok" ;;
  *) fail "list-stories line 1 malformed: $FIRST" ;;
esac
```

Make it executable:

```bash
chmod +x /Users/junhua/.claude/plugins/super-ralph/test/test-parse-local-epic.sh
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash /Users/junhua/.claude/plugins/super-ralph/test/test-parse-local-epic.sh`

Expected: FAIL — `parse-local-epic.sh: No such file or directory`

- [ ] **Step 3: Implement the parser (detect-mode + list-stories)**

Create `scripts/parse-local-epic.sh`:

```bash
#!/usr/bin/env bash
# parse-local-epic.sh — Shared parser for local-mode epic files.
# Subcommands: detect-mode, list-stories, extract-story, extract-substory,
#              get-status, set-status
set -euo pipefail

cmd="${1:-}"; shift || true

case "$cmd" in
  detect-mode)
    arg="${1:-}"
    case "$arg" in
      '#'[0-9]*) echo "github" ;;
      [0-9]*)    echo "github" ;;
      *.md|*.md'#'*) echo "local" ;;
      *) echo "description" ;;
    esac
    ;;

  list-stories)
    # Usage: list-stories <epic-file>
    # Output: "story-N <title> <status>" per line
    file="${1:?epic file required}"
    awk '
      /^### Story [0-9]+:/ {
        # Extract story id and title
        match($0, /Story ([0-9]+): *(.*)$/, m)
        cur_id="story-" m[1]
        cur_title=m[2]
        cur_status=""
        next
      }
      /\*\*Status:\*\*/ && cur_id != "" {
        match($0, /\*\*Status:\*\*[[:space:]]*([A-Z_]+)/, s)
        cur_status=s[1]
        print cur_id " " cur_title " " cur_status
        cur_id=""
      }
    ' "$file"
    ;;

  extract-story|extract-substory|get-status|set-status)
    echo "not-yet-implemented: $cmd" >&2; exit 2 ;;

  *) echo "Unknown subcommand: $cmd" >&2
     echo "Usage: $0 {detect-mode|list-stories|extract-story|extract-substory|get-status|set-status} ..." >&2
     exit 1 ;;
esac
```

Make executable:

```bash
chmod +x /Users/junhua/.claude/plugins/super-ralph/scripts/parse-local-epic.sh
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash /Users/junhua/.claude/plugins/super-ralph/test/test-parse-local-epic.sh`

Expected: PASS × 7

- [ ] **Step 5: Commit**

```bash
git -C /Users/junhua/.claude/plugins/super-ralph add scripts/parse-local-epic.sh test/test-parse-local-epic.sh
git -C /Users/junhua/.claude/plugins/super-ralph commit -m "feat(scripts): parse-local-epic.sh with detect-mode + list-stories"
```

---

### Task 3: Parser — `extract-story` subcommand

**Files:**
- Modify: `scripts/parse-local-epic.sh`
- Modify: `test/test-parse-local-epic.sh`

**Rationale:** Commands need to extract a specific `### Story N` block (with all its sub-sections) from the file. The block ends at the next `### Story` heading or EOF.

- [ ] **Step 1: Add failing tests to the test script**

Append to `test/test-parse-local-epic.sh`:

```bash
# extract-story: pulls Story 1 block, stops before Story 2
OUT=$("$SCRIPT" extract-story "$FIXTURE" 1)
echo "$OUT" | head -1 | grep -q "^### Story 1: Foo listing$" || fail "extract-story 1 missing heading"
echo "$OUT" | grep -q "^### Story 2:" && fail "extract-story 1 leaked into Story 2"
echo "$OUT" | grep -q "^#### \[BE\] Story 1 — Backend$" || fail "extract-story 1 missing [BE] subsection"
echo "$OUT" | grep -q "^#### \[INT\] Story 1 — Integration & E2E$" || fail "extract-story 1 missing [INT] subsection"
pass "extract-story 1 bounded correctly"

# extract-story: Story 2 block
OUT=$("$SCRIPT" extract-story "$FIXTURE" 2)
echo "$OUT" | head -1 | grep -q "^### Story 2: Foo detail$" || fail "extract-story 2 missing heading"
echo "$OUT" | grep -q "^### Story 3:" && fail "extract-story 2 leaked into Story 3"
pass "extract-story 2 bounded"

# extract-story: Story 3 runs to EOF
OUT=$("$SCRIPT" extract-story "$FIXTURE" 3)
echo "$OUT" | head -1 | grep -q "^### Story 3: Foo search$" || fail "extract-story 3 missing heading"
echo "$OUT" | tail -5 | grep -q "INT green" || fail "extract-story 3 did not reach EOF"
pass "extract-story 3 to EOF"

# extract-story: missing story → empty output + non-zero exit
set +e; OUT=$("$SCRIPT" extract-story "$FIXTURE" 99); RC=$?; set -e
[ "$RC" != "0" ] || fail "extract-story missing → expected non-zero exit"
[ -z "$OUT" ] || fail "extract-story missing → expected empty output"
pass "extract-story missing → non-zero exit"
```

- [ ] **Step 2: Run tests to verify new assertions fail**

Run: `bash /Users/junhua/.claude/plugins/super-ralph/test/test-parse-local-epic.sh`

Expected: FAIL at `extract-story` with `not-yet-implemented: extract-story`

- [ ] **Step 3: Implement `extract-story` in the parser**

In `scripts/parse-local-epic.sh`, replace the `extract-story|extract-substory|get-status|set-status` line and its body with this (keeping other subcommands as placeholders):

```bash
  extract-story)
    # Usage: extract-story <epic-file> <story-num>
    file="${1:?epic file required}"
    num="${2:?story number required}"
    awk -v n="$num" '
      BEGIN { in_story=0; found=0 }
      /^### Story [0-9]+:/ {
        match($0, /Story ([0-9]+):/, m)
        if (m[1] == n) { in_story=1; found=1; print; next }
        if (in_story) { exit }
      }
      in_story { print }
      END { if (!found) exit 2 }
    ' "$file"
    ;;

  extract-substory|get-status|set-status)
    echo "not-yet-implemented: $cmd" >&2; exit 2 ;;
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash /Users/junhua/.claude/plugins/super-ralph/test/test-parse-local-epic.sh`

Expected: all 11 PASS lines

- [ ] **Step 5: Commit**

```bash
git -C /Users/junhua/.claude/plugins/super-ralph add scripts/parse-local-epic.sh test/test-parse-local-epic.sh
git -C /Users/junhua/.claude/plugins/super-ralph commit -m "feat(scripts): extract-story subcommand"
```

---

### Task 4: Parser — `extract-substory` subcommand

**Files:**
- Modify: `scripts/parse-local-epic.sh`
- Modify: `test/test-parse-local-epic.sh`

**Rationale:** `build-story` and `improve-design` need to pull just the `[BE]`, `[FE]`, `[INT]`, or `[STORY]` sub-section out of a story.

- [ ] **Step 1: Add failing tests**

Append to `test/test-parse-local-epic.sh`:

```bash
# extract-substory story-1-be
OUT=$("$SCRIPT" extract-substory "$FIXTURE" 1 be)
echo "$OUT" | head -1 | grep -q "^#### \[BE\] Story 1 — Backend$" || fail "substory 1 be heading"
echo "$OUT" | grep -q "^#### \[FE\]" && fail "substory 1 be leaked into FE"
echo "$OUT" | grep -q "^### Story 2:" && fail "substory 1 be leaked into Story 2"
pass "extract-substory 1 be"

# extract-substory story-1-story (the [STORY] block)
OUT=$("$SCRIPT" extract-substory "$FIXTURE" 1 story)
echo "$OUT" | head -1 | grep -q "^#### \[STORY\] Story 1$" || fail "substory 1 story heading"
echo "$OUT" | grep -q "^#### \[BE\]" && fail "substory 1 story leaked into BE"
pass "extract-substory 1 story"

# extract-substory story-1-int
OUT=$("$SCRIPT" extract-substory "$FIXTURE" 1 int)
echo "$OUT" | head -1 | grep -q "^#### \[INT\] Story 1 — Integration & E2E$" || fail "substory 1 int heading"
pass "extract-substory 1 int"

# missing substory kind → exit 2
set +e; "$SCRIPT" extract-substory "$FIXTURE" 1 xxx >/dev/null 2>&1; RC=$?; set -e
[ "$RC" != "0" ] || fail "substory invalid kind should fail"
pass "extract-substory invalid kind fails"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash /Users/junhua/.claude/plugins/super-ralph/test/test-parse-local-epic.sh`

Expected: FAIL at `extract-substory`

- [ ] **Step 3: Implement `extract-substory`**

In `scripts/parse-local-epic.sh`, add this subcommand body:

```bash
  extract-substory)
    # Usage: extract-substory <epic-file> <story-num> <kind: story|be|fe|int>
    file="${1:?epic file required}"
    num="${2:?story number required}"
    kind="${3:?kind required}"
    case "$kind" in story|be|fe|int) ;; *) echo "invalid kind: $kind" >&2; exit 2 ;; esac
    # Uppercase label matches the fixture heading text (BE, FE, INT, STORY)
    label=$(echo "$kind" | tr '[:lower:]' '[:upper:]')
    awk -v n="$num" -v lbl="$label" '
      BEGIN { in_story=0; in_sub=0; found=0 }
      /^### Story [0-9]+:/ {
        match($0, /Story ([0-9]+):/, m)
        in_story = (m[1] == n) ? 1 : 0
        in_sub = 0
        next
      }
      in_story && /^#### \[/ {
        match($0, /^#### \[([A-Z]+)\]/, s)
        if (s[1] == lbl) { in_sub=1; found=1; print; next }
        if (in_sub) { exit }
        in_sub=0
      }
      in_sub { print }
      END { if (!found) exit 2 }
    ' "$file"
    ;;
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash /Users/junhua/.claude/plugins/super-ralph/test/test-parse-local-epic.sh`

Expected: all 15 PASS lines

- [ ] **Step 5: Commit**

```bash
git -C /Users/junhua/.claude/plugins/super-ralph add scripts/parse-local-epic.sh test/test-parse-local-epic.sh
git -C /Users/junhua/.claude/plugins/super-ralph commit -m "feat(scripts): extract-substory subcommand"
```

---

### Task 5: Parser — `get-status` + `set-status` subcommands

**Files:**
- Modify: `scripts/parse-local-epic.sh`
- Modify: `test/test-parse-local-epic.sh`

**Rationale:** Finalise in local mode needs to flip `PENDING` → `COMPLETED` atomically. Improve-design needs to read status to enforce the "shipped is immutable" rule.

- [ ] **Step 1: Add failing tests**

Append to `test/test-parse-local-epic.sh`:

```bash
# get-status
S=$("$SCRIPT" get-status "$FIXTURE" 1); [ "$S" = "PENDING" ] || fail "get-status 1 → expected PENDING got $S"
pass "get-status 1"
S=$("$SCRIPT" get-status "$FIXTURE" 2); [ "$S" = "IN_PROGRESS" ] || fail "get-status 2 → expected IN_PROGRESS got $S"
pass "get-status 2"

# set-status (use a temp copy)
TMP=$(mktemp); cp "$FIXTURE" "$TMP"
"$SCRIPT" set-status "$TMP" 1 COMPLETED
S=$("$SCRIPT" get-status "$TMP" 1)
[ "$S" = "COMPLETED" ] || fail "set-status 1 COMPLETED → get-status=$S"
pass "set-status 1 COMPLETED"

# set-status must leave other stories untouched
S=$("$SCRIPT" get-status "$TMP" 2); [ "$S" = "IN_PROGRESS" ] || fail "set-status 1 broke story 2 (got $S)"
pass "set-status leaves other stories untouched"
rm -f "$TMP"
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL at `get-status` with `not-yet-implemented`

- [ ] **Step 3: Implement `get-status` + `set-status`**

Replace the `extract-substory|get-status|set-status` placeholder in `scripts/parse-local-epic.sh` with the real bodies (the `extract-substory` case is already implemented from Task 4; add these two alongside it):

```bash
  get-status)
    file="${1:?epic file required}"
    num="${2:?story number required}"
    awk -v n="$num" '
      /^### Story [0-9]+:/ {
        match($0, /Story ([0-9]+):/, m)
        in_story = (m[1] == n) ? 1 : 0
      }
      in_story && /\*\*Status:\*\*/ {
        match($0, /\*\*Status:\*\*[[:space:]]*([A-Z_]+)/, s)
        print s[1]; exit
      }
    ' "$file"
    ;;

  set-status)
    file="${1:?epic file required}"
    num="${2:?story number required}"
    new="${3:?new status required}"
    case "$new" in PENDING|IN_PROGRESS|READY|COMPLETED) ;;
      *) echo "invalid status: $new" >&2; exit 2 ;; esac
    tmp=$(mktemp)
    awk -v n="$num" -v new="$new" '
      /^### Story [0-9]+:/ {
        match($0, /Story ([0-9]+):/, m)
        in_story = (m[1] == n) ? 1 : 0
      }
      in_story && /\*\*Status:\*\*/ {
        sub(/\*\*Status:\*\*[[:space:]]*[A-Z_]+/, "**Status:** " new)
        in_story = 0
      }
      { print }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
    ;;
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash /Users/junhua/.claude/plugins/super-ralph/test/test-parse-local-epic.sh`

Expected: all 19 PASS lines

- [ ] **Step 5: Commit**

```bash
git -C /Users/junhua/.claude/plugins/super-ralph add scripts/parse-local-epic.sh test/test-parse-local-epic.sh
git -C /Users/junhua/.claude/plugins/super-ralph commit -m "feat(scripts): get-status + set-status subcommands"
```

---

### Task 6: `/design` — add `--local` flag parsing + collision check

**Files:**
- Modify: `commands/design.md`

**Rationale:** `--local` is the entry point. Parse it early, guard against overwriting an existing epic, and emit the local-mode marker into the epic doc.

- [ ] **Step 1: Update the `## Arguments` section**

In `commands/design.md`, find the `## Arguments` section. Replace its body with:

```markdown
Parse the user's input for:
- **Feature or goal description** (required): What to design — can be a feature idea, business goal, user feedback, or OKR
- **--output** (optional): Output path (default: `docs/epics/YYYY-MM-DD-<slug>.md`)
- **--local** (optional, boolean): Produce a self-contained local epic file; SKIP GitHub issue creation entirely. Downstream commands (`/build-story`, `/e2e`, `/review-design`) must then be invoked with the epic file path rather than an issue number. Default: false.

When `--local` is set:
- Resolve the target path to `docs/epics/YYYY-MM-DD-<slug>.md` (same rules as default).
- If the file already exists, EXIT with `"Epic file already exists at <path>. Use /super-ralph:improve-design to modify, or delete the file first."` — do not overwrite.
```

- [ ] **Step 2: Verify the change**

Run: `grep -c '^- \*\*--local\*\*' /Users/junhua/.claude/plugins/super-ralph/commands/design.md`

Expected: `1`

Run: `grep -c "Epic file already exists" /Users/junhua/.claude/plugins/super-ralph/commands/design.md`

Expected: `1`

- [ ] **Step 3: Commit**

```bash
git -C /Users/junhua/.claude/plugins/super-ralph add commands/design.md
git -C /Users/junhua/.claude/plugins/super-ralph commit -m "feat(design): parse --local flag with collision guard"
```

---

### Task 7: `/design` — Phase 3 local-mode marker + Phase 4 consolidation

**Files:**
- Modify: `commands/design.md`

**Rationale:** Phase 3 writes the epic doc. In `--local` mode it must include the `<!-- super-ralph: local-mode -->` marker so `/review-design` can validate we're operating on a local epic. Phase 4 must consolidate the run-state per-story plans into the epic file after all story-planners finish.

- [ ] **Step 1: Modify Phase 3 / Step 8**

In `commands/design.md`, find `#### Step 8: Write Epic Doc`. Replace its list with:

```markdown
1. Create `docs/epics/` directory if it does not exist
2. Write the epic document to `docs/epics/YYYY-MM-DD-<slug>.md` using the template from `${CLAUDE_PLUGIN_ROOT}/skills/product-design/references/epic-template.md`
3. If `--local` is set, prepend `<!-- super-ralph: local-mode -->` as the second line of the file (right after the `# EPIC: <title>` heading).
4. Include all stories with their Gherkin AC (written in Phase 4, but the epic doc structure is defined here)
5. Commit:
   ```bash
   git add docs/epics/<file>
   git commit -m "epic: [title]$( [ -n "$LOCAL_FLAG" ] && echo ' (local-mode draft)')"
   ```
```

- [ ] **Step 2: Add a consolidation step at the end of Phase 4**

In `commands/design.md`, after `#### Step 11: Compute Execution Plan`, insert a new step before Phase 5:

```markdown
#### Step 11b: Consolidate Story Plans into Epic File (only if `--local`)

When `--local` is set, SKIP Phase 5 entirely and instead:

1. For each story N (in numerical order):
   - Read the run-state plan file: `.claude/runs/design-<EPIC_SLUG>/story-N-plan.md`
   - Extract the four sections (STORY Issue Body, BE Sub-Issue Body, FE Sub-Issue Body, INT Sub-Issue Body)
   - Append a block to the epic file under `## Stories` using this exact shape:

     ```markdown
     ### Story N: <Title>

     **Persona:** <X>   **Priority:** <P0|P1|P2>   **Size:** <S|M|L|XL>   **Status:** PENDING
     <!-- PR: -->
     <!-- Branch: -->

     #### [STORY] Story N

     <STORY body from run-state file, verbatim>

     #### [BE] Story N — Backend

     <BE body from run-state file, verbatim>

     #### [FE] Story N — Frontend

     <FE body from run-state file, verbatim>

     #### [INT] Story N — Integration & E2E

     <INT body from run-state file, verbatim>

     ---
     ```

2. Commit:
   ```bash
   git add docs/epics/<file>
   git commit -m "epic: populate stories into local epic <slug>"
   ```

3. SKIP Phase 5 entirely. Proceed directly to Phase 6 with the epic file path as the review target.
```

- [ ] **Step 3: Verify the change**

Run: `grep -c "Step 11b: Consolidate" /Users/junhua/.claude/plugins/super-ralph/commands/design.md`

Expected: `1`

- [ ] **Step 4: Commit**

```bash
git -C /Users/junhua/.claude/plugins/super-ralph add commands/design.md
git -C /Users/junhua/.claude/plugins/super-ralph commit -m "feat(design): --local Phase 3 marker + Phase 4 consolidation"
```

---

### Task 8: `/design` — Phase 5 skip + Phase 6 path + Phase 7 report

**Files:**
- Modify: `commands/design.md`

- [ ] **Step 1: Guard Phase 5 (Issue Creation) behind non-local check**

In `commands/design.md`, find `### Phase 5: Issue Creation (sequential)` and replace its opening line (immediately before `#### Step 12`) with:

```markdown
### Phase 5: Issue Creation (sequential)

**Skip this entire phase when `--local` is set.** The epic lives in the markdown file; no GitHub issues are created.
```

- [ ] **Step 2: Update Phase 6 to accept file path**

In `commands/design.md`, find `#### Step 15: Invoke Design Review`. Replace the prompt body with:

```
Task tool:
  model: sonnet
  max_turns: 30
  description: "Review design quality for EPIC <target>"
  prompt: |
    You are a design-reviewer agent.

    Read the review-design command: ${CLAUDE_PLUGIN_ROOT}/commands/review-design.md
    Follow it completely for:
      - `<epic-number>` when `--local` was NOT set
      - `docs/epics/<slug>.md` when `--local` WAS set

    Run all PM Gates, Developer Gates, and Cross-Issue Checks.
    Return a structured verdict: READY / CONDITIONAL / BLOCKED.
```

- [ ] **Step 3: Update Phase 7 Step 17 Report launch commands**

In `commands/design.md`, find `## Launch Commands` inside the Step 17 report template. Replace that block with:

```markdown
## Launch Commands
When `--local` was set:
  Wave 1 (parallel):
  - `/super-ralph:build-story docs/epics/<slug>.md#story-1`
  - `/super-ralph:build-story docs/epics/<slug>.md#story-3`

  Wave 2 (after Wave 1):
  - `/super-ralph:build-story docs/epics/<slug>.md#story-2`
  - `/super-ralph:build-story docs/epics/<slug>.md#story-4`

When `--local` was NOT set:
  Wave 1 (parallel):
  - `/super-ralph:build-story #<story-1-number>`
  - `/super-ralph:build-story #<story-3-number>`

  Wave 2 (after Wave 1):
  - `/super-ralph:build-story #<story-2-number>`
  - `/super-ralph:build-story #<story-4-number>`
```

- [ ] **Step 4: Verify all changes**

Run: `grep -c "Skip this entire phase when.--local" /Users/junhua/.claude/plugins/super-ralph/commands/design.md`

Expected: `1`

Run: `grep -c "docs/epics/<slug>.md#story-" /Users/junhua/.claude/plugins/super-ralph/commands/design.md`

Expected: `≥4`

- [ ] **Step 5: Commit**

```bash
git -C /Users/junhua/.claude/plugins/super-ralph add commands/design.md
git -C /Users/junhua/.claude/plugins/super-ralph commit -m "feat(design): skip Phase 5 + path-based review/report when --local"
```

---

### Task 9: `/build` skill — accept `*.md#story-N` argument

**Files:**
- Modify: `skills/build/SKILL.md`

**Rationale:** The build skill's Step 2 resolves a plan path. It needs to detect the epic-section shape and write the extracted section to a temp plan file before handing off to ralph-loop.

- [ ] **Step 1: Update Step 2 to handle epic-section paths**

In `skills/build/SKILL.md`, find `### 2. Resolve Path & Create Worktree`. Replace its body (everything between the heading and `### 3. Read Plan Header`) with:

```markdown
Extract the plan path argument. Detect three shapes:

1. **Epic-section path** — matches `*.md#story-<N>` (or `*.md#story-<N>-<be|fe|int|story>`).
   Use the shared parser to extract the section(s) to a temp plan file:
   ```bash
   EPIC_FILE="${PLAN_ARG%%#*}"
   FRAG="${PLAN_ARG#*#}"
   SLUG=$(basename "$EPIC_FILE" .md)
   STORY_NUM=$(echo "$FRAG" | awk -F- '{print $2}')
   KIND=$(echo "$FRAG" | awk -F- '{print $3}')  # may be empty
   RUN_DIR="$(git rev-parse --show-toplevel)/.claude/runs/build-${SLUG}-story-${STORY_NUM}"
   mkdir -p "$RUN_DIR"
   if [ -z "$KIND" ]; then
     # Whole story → concatenate [BE] + [FE] TDD sections
     ${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh extract-substory "$EPIC_FILE" "$STORY_NUM" be  >  "$RUN_DIR/plan.md"
     echo                                                                                         >> "$RUN_DIR/plan.md"
     ${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh extract-substory "$EPIC_FILE" "$STORY_NUM" fe >> "$RUN_DIR/plan.md"
   else
     ${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh extract-substory "$EPIC_FILE" "$STORY_NUM" "$KIND" > "$RUN_DIR/plan.md"
   fi
   PLAN_ABS_PATH="$RUN_DIR/plan.md"
   PLAN_SLUG="${SLUG}-story-${STORY_NUM}${KIND:+-$KIND}"
   ```

2. **Direct plan path** — `*.md` without fragment. Current behavior unchanged:
   ```bash
   PLAN_ABS_PATH=$(realpath "<plan_path>")
   PLAN_SLUG=$(basename "<plan_path>" .md | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//')
   ```

3. **Anything else** — error and exit with `"Unrecognized plan argument: <arg>. Expected <path.md> or <path.md>#story-<N>."`

Then (same as before, for all three shapes):

Call `EnterWorktree` with `name="super-ralph/$PLAN_SLUG"`. If already in a worktree, skip and use current directory.

Then:
```bash
git branch -m "super-ralph/$PLAN_SLUG" 2>/dev/null || true
test -f "<relative-plan-path>" || (mkdir -p "$(dirname "<relative-plan-path>")" && cp "$PLAN_ABS_PATH" "<relative-plan-path>")
# install dependencies
if [ -f bun.lock ] || [ -f bun.lockb ]; then bun install; elif [ -f package.json ]; then npm install; fi
```

Report: `"Worktree ready at <cwd> on branch super-ralph/$PLAN_SLUG. Proceeding with build."`
```

- [ ] **Step 2: Verify the change**

Run: `grep -c "Epic-section path" /Users/junhua/.claude/plugins/super-ralph/skills/build/SKILL.md`

Expected: `1`

Run: `grep -c "parse-local-epic.sh" /Users/junhua/.claude/plugins/super-ralph/skills/build/SKILL.md`

Expected: `≥2`

- [ ] **Step 3: Commit**

```bash
git -C /Users/junhua/.claude/plugins/super-ralph add skills/build/SKILL.md
git -C /Users/junhua/.claude/plugins/super-ralph commit -m "feat(build): accept epic-section plan args (*.md#story-N)"
```

---

### Task 10: `/build` command doc — document new argument shape

**Files:**
- Modify: `commands/build.md`

- [ ] **Step 1: Update argument-hint and usage line**

In `commands/build.md`, change the frontmatter `argument-hint`:

```yaml
argument-hint: "<plan-path | epic-file.md#story-N> [--max-iterations N] [--mode standard|hybrid]"
```

In the Usage section:

```markdown
**Usage:**
- `/super-ralph:build <plan-path>` — execute a standalone plan from `docs/plans/`
- `/super-ralph:build <epic-file.md>#story-N` — execute a specific story from a local epic (extracts BE+FE TDD tasks)
- `/super-ralph:build <epic-file.md>#story-N-<be|fe|int>` — execute a specific sub-body only

Optional: `[--max-iterations N] [--mode standard|hybrid]`
```

- [ ] **Step 2: Verify**

Run: `grep -c "epic-file.md" /Users/junhua/.claude/plugins/super-ralph/commands/build.md`

Expected: `≥2`

- [ ] **Step 3: Commit**

```bash
git -C /Users/junhua/.claude/plugins/super-ralph add commands/build.md
git -C /Users/junhua/.claude/plugins/super-ralph commit -m "docs(build): document epic-section path argument"
```

---

### Task 11: `/build-story` — detect local mode in Step 0b

**Files:**
- Modify: `commands/build-story.md`

**Rationale:** `build-story` already parses epic-file references loosely in Step 0b. Tighten the detection to use the shared parser and populate the context/plan-result the same way as today, but mark `mode: embedded` and skip Phase 1.

- [ ] **Step 1: Update Step 0b argument detection**

In `commands/build-story.md`, find the three-case detection at Step 0b (the sections labeled `0a. GitHub Issue`, `0b. Epic Story Reference`, `0c. Description String`). Replace them with this block (preserve everything before and after):

```markdown
#### 0a. Detect mode via shared parser

```bash
MODE=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh detect-mode "$STORY_REF")
```

Branch on `$MODE`:

- `local` → subsection 0b (local epic file)
- `github` → subsection 0c (GitHub issue)
- `description` → subsection 0d (free-text)

#### 0b. Local Epic File (`<path>.md` or `<path>.md#story-<N>[-<be|fe|int|story>]`)

```bash
EPIC_FILE="${STORY_REF%%#*}"
FRAG="${STORY_REF#*#}"
# If no fragment (raw .md), require the user to specify a story — error out.
if [ "$EPIC_FILE" = "$STORY_REF" ]; then
  echo "Local epic path without #story-N fragment — use /super-ralph:e2e for whole-epic execution" >&2
  exit 1
fi
STORY_NUM=$(echo "$FRAG" | awk -F- '{print $2}')
STORY_ID="story-${STORY_NUM}"
STORY_SLUG="$(basename "$EPIC_FILE" .md)-story-${STORY_NUM}"

# Extract context pieces
STORY_BODY=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh extract-substory "$EPIC_FILE" "$STORY_NUM" story)
BE_BODY=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh extract-substory "$EPIC_FILE" "$STORY_NUM" be)
FE_BODY=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh extract-substory "$EPIC_FILE" "$STORY_NUM" fe)
INT_BODY=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh extract-substory "$EPIC_FILE" "$STORY_NUM" int)
STORY_STATUS=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh get-status "$EPIC_FILE" "$STORY_NUM")
STORY_TITLE=$(grep -m1 "^### Story ${STORY_NUM}:" "$EPIC_FILE" | sed -E "s/^### Story ${STORY_NUM}: //")

# Refuse to build a COMPLETED story
if [ "$STORY_STATUS" = "COMPLETED" ]; then
  echo "Story ${STORY_NUM} is already COMPLETED (see ${EPIC_FILE}). Refusing to rebuild shipped work." >&2
  exit 1
fi
```

Derive directory, context file, and plan-result (with `mode: embedded`, `source: $STORY_REF`) using these variables instead of the GitHub issue body.

#### 0c. GitHub Issue (`#42` or `42`)

[CURRENT 0a BODY PRESERVED VERBATIM — rename its heading from "0a" to "0c"]

#### 0d. Description String

[CURRENT 0c BODY PRESERVED VERBATIM — rename its heading from "0c" to "0d"]
```

Also update the `#### 0d. Write Context File` and `#### 0e. Initialize Progress Tracker` headings to `0e` and `0f` (they follow 0b/0c/0d now).

When writing the context file under `0e`, add a new top line when in local mode:

```markdown
**Source:** Local epic — $EPIC_FILE#$FRAG
```

And when in GitHub mode, keep the existing `**Source:** [GitHub Issue #N | ...]` format.

- [ ] **Step 2: Update Phase 1 skip logic to accept local embedded mode**

Find the `Skip detection` block in Phase 1. Replace it with:

```markdown
**Skip detection:** Before dispatching the plan sub-agent, check if the story source has TDD tasks already embedded:

- **Local mode**: if `$MODE = local`, TDD tasks are already embedded in `$BE_BODY` and `$FE_BODY`. Write plan-result.md with `mode: embedded`, `source: $STORY_REF`, `be_body_file: $STORY_DIR/be.md`, `fe_body_file: $STORY_DIR/fe.md`, `int_body_file: $STORY_DIR/int.md`. Write those three files from the shell variables captured in Step 0b. Skip the plan sub-agent.
- **GitHub mode**: existing logic — check if the issue body contains `## TDD Tasks` / `### Task 0:` / `### Task 1:` markers. If found, skip the plan sub-agent.

If neither applies, fall through to the existing Phase 1 plan sub-agent dispatch.
```

- [ ] **Step 3: Verify**

Run: `grep -c "detect-mode" /Users/junhua/.claude/plugins/super-ralph/commands/build-story.md`

Expected: `≥1`

Run: `grep -c "Local Epic File" /Users/junhua/.claude/plugins/super-ralph/commands/build-story.md`

Expected: `1`

Run: `grep -c "Refusing to rebuild shipped work" /Users/junhua/.claude/plugins/super-ralph/commands/build-story.md`

Expected: `1`

- [ ] **Step 4: Commit**

```bash
git -C /Users/junhua/.claude/plugins/super-ralph add commands/build-story.md
git -C /Users/junhua/.claude/plugins/super-ralph commit -m "feat(build-story): detect local-mode story paths in Step 0b"
```

---

### Task 12: `/build-story` — Phase 5 finalise local-mode variant

**Files:**
- Modify: `commands/build-story.md`

**Rationale:** Local-mode finalise must skip `gh issue close` + `gh project item-edit` and instead flip `**Status:**` to `COMPLETED` in the epic file, while still running the full PR-merge + deployment-health path.

- [ ] **Step 1: Insert a Phase 5 mode switch near the top**

In `commands/build-story.md`, find `### Phase 5: Finalise`. Immediately after its opening paragraph (before `1. **Ensure on staging:**`), insert:

```markdown
**Mode-specific finalise branches:**

- When `$MODE = local` (local epic file): execute steps 1-5 below, then SKIP step 6 (issue close) + step 7 (project-board move) + step 9 (epic file story status update via git-log introspection). Instead perform local-mode step 9L below.
- When `$MODE = github`: execute all steps 1-9 as today.

### Local-mode finalise step 9L

After step 5 (deployment health verified) and step 8 (plan status), replace the current step 9 with:

```bash
EPIC_FILE="$(echo "$STORY_REF" | cut -d'#' -f1)"
STORY_NUM=$(echo "${STORY_REF#*#}" | awk -F- '{print $2}')
${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh set-status "$EPIC_FILE" "$STORY_NUM" COMPLETED
# Stamp PR + branch into the epic file under the story status line
sed -i.bak -E "/^### Story ${STORY_NUM}:/,/^### Story [0-9]+:/{
  s|<!-- PR: -->|<!-- PR: #${PR_NUMBER} -->|
  s|<!-- Branch: -->|<!-- Branch: super-ralph/${STORY_SLUG} -->|
}" "$EPIC_FILE"
rm -f "$EPIC_FILE.bak"
git add "$EPIC_FILE"
git commit -m "docs: mark Story ${STORY_NUM} as COMPLETED in $(basename "$EPIC_FILE" .md)"
git push origin staging
```

Then check if all stories in the epic are COMPLETED:

```bash
PENDING_COUNT=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh list-stories "$EPIC_FILE" \
  | awk '{print $NF}' | grep -vc COMPLETED || true)
if [ "$PENDING_COUNT" = "0" ]; then
  echo "Epic complete. Ready for: /super-ralph:release"
fi
```

**In local mode, also modify step 2 (PR body):** omit `Closes #<STORY_ID>`. Instead include a human-readable pointer: `Closes local epic ${EPIC_FILE}#story-${STORY_NUM}`.

```

- [ ] **Step 2: Update the PR-body generation in Phase 3 Review-Fix**

Find the `gh pr create` block inside Phase 3 (the `Closes #$STORY_ID` line). Replace the PR body template with:

```bash
if [ "$MODE" = "local" ]; then
  CLOSES_LINE="Closes local epic $STORY_REF"
else
  CLOSES_LINE="Closes #$STORY_ID"
fi

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
```

- [ ] **Step 3: Verify**

Run: `grep -c "Local-mode finalise" /Users/junhua/.claude/plugins/super-ralph/commands/build-story.md`

Expected: `1`

Run: `grep -c "set-status.*COMPLETED" /Users/junhua/.claude/plugins/super-ralph/commands/build-story.md`

Expected: `≥1`

Run: `grep -c "Closes local epic" /Users/junhua/.claude/plugins/super-ralph/commands/build-story.md`

Expected: `≥1`

- [ ] **Step 4: Commit**

```bash
git -C /Users/junhua/.claude/plugins/super-ralph add commands/build-story.md
git -C /Users/junhua/.claude/plugins/super-ralph commit -m "feat(build-story): local-mode finalise + PR body Closes local epic"
```

---

### Task 13: `/e2e` — detect local mode + parse epic file

**Files:**
- Modify: `commands/e2e.md`

- [ ] **Step 1: Add local-mode branch in Step 0b**

In `commands/e2e.md`, find `### Step 0b: Load Epic Context`. At the top of that section (right after the heading), insert:

```markdown
**Mode detection:**
```bash
MODE=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh detect-mode "$EPIC_REF")
```
Branch:
- `local` (arg is `docs/epics/<slug>.md`) → use "Local" variant below
- `github` (arg is numeric or `#N`) → use existing variant below (current behavior)
- `description` → error out: `"/super-ralph:e2e requires a #EPIC_NUMBER or docs/epics/<file>.md, not a free-form description."`

**Local variant:**

1. Read `$EPIC_REF` once into memory.
2. Validate it contains `<!-- super-ralph: local-mode -->` — if not, error: `"$EPIC_REF is not a local-mode epic."`
3. Derive `EPIC_ID` = `$(basename "$EPIC_REF" .md)`.
4. Derive `EPIC_TITLE` = first line matching `^# EPIC:` with the prefix stripped.
5. Read story list:
   ```bash
   ${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh list-stories "$EPIC_REF"
   ```
   Each line is `story-N <title...> <STATUS>` — treat `story-N` as the synthetic story number, the title as the story title, and status to drive filtering in Step 1.
6. Create run directory:
   ```bash
   E2E_DIR="$(git rev-parse --show-toplevel)/.claude/runs/e2e-${EPIC_ID}"
   mkdir -p "$E2E_DIR/stories"
   ```
7. Write `$E2E_DIR/epic-context.md` with the file-derived fields (title, body summary from the header sections, story table).
8. Write each story's brief:
   ```bash
   for line in "${STORIES[@]}"; do
     STORY_NUM=...
     mkdir -p "$E2E_DIR/stories/story-${STORY_NUM}"
     ${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh extract-substory "$EPIC_REF" "$STORY_NUM" story \
       > "$E2E_DIR/stories/story-${STORY_NUM}/brief.md"
   done
   ```
9. Report: `"Epic $EPIC_REF (local) — $STORY_COUNT stories, $PENDING_COUNT pending."`

**GitHub variant:** (everything below remains unchanged — current Step 0b 1-7)
```

- [ ] **Step 2: Filter in Step 1 uses status from the file**

In `commands/e2e.md`, replace `### Step 1: Filter Actionable Stories` body with:

```markdown
Remove stories that don't need execution:
- **GitHub mode**:
  - Already closed → skip (work already done)
  - Has merged PR → skip
  - Has open PR → include but skip plan+build phases (resume from review-fix)
- **Local mode**:
  - Status `COMPLETED` → skip
  - Status `IN_PROGRESS` / `READY` → include (resume detection in build-story picks up the right phase)
  - Status `PENDING` → include

Write the filtered list to `$E2E_DIR/actionable-stories.md`.
```

- [ ] **Step 3: Update Step 4a to pass path-based arg in local mode**

In `commands/e2e.md`, find the Story Executor dispatch block (`Task tool:` inside Step 4a). Change `$STORY_NUMBER` to compute the correct executor arg:

```bash
if [ "$MODE" = "local" ]; then
  EXECUTOR_ARG="${EPIC_REF}#story-${STORY_NUM}"
else
  EXECUTOR_ARG="#${STORY_NUMBER}"
fi
```

And update the executor prompt text to pass `$EXECUTOR_ARG` as the story identifier.

- [ ] **Step 4: Update Step 4c to skip gh calls in local mode**

In Step 4c (Sequential Finalise), wrap the `gh issue close`, `gh project item-edit`, and related calls in:

```bash
if [ "$MODE" = "github" ]; then
  # existing gh issue close + gh project item-edit + parent-epic auto-close
fi
```

For local mode, rely on `/super-ralph:build-story` (already local-aware from Task 12) to flip status to `COMPLETED` in the epic file as part of its own finalise. The e2e orchestrator still runs sequential `gh pr merge` + deployment verification for each story.

- [ ] **Step 5: Update Step 4d to skip `docs/plans/` commit in local mode**

In Step 4d, wrap the `git add docs/plans/` half of the commit command in a mode check:

```bash
if [ "$MODE" = "github" ]; then
  git add docs/plans/ docs/epics/
else
  git add docs/epics/
fi
git commit -m "docs: mark Wave $WAVE_NUM stories as completed for Epic $EPIC_ID"
```

- [ ] **Step 6: Verify**

Run: `grep -c "Local variant:" /Users/junhua/.claude/plugins/super-ralph/commands/e2e.md`

Expected: `1`

Run: `grep -c 'MODE=.*detect-mode' /Users/junhua/.claude/plugins/super-ralph/commands/e2e.md`

Expected: `1`

- [ ] **Step 7: Commit**

```bash
git -C /Users/junhua/.claude/plugins/super-ralph add commands/e2e.md
git -C /Users/junhua/.claude/plugins/super-ralph commit -m "feat(e2e): local-mode — parse epic file, filter by status, path-based dispatch"
```

---

### Task 14: `/review-design` — local-mode file ingestion

**Files:**
- Modify: `commands/review-design.md`

- [ ] **Step 1: Add local-mode branch at Step 1**

In `commands/review-design.md`, find `### Step 1: Resolve EPIC`. Replace its body with:

```markdown
**Mode detection:**
```bash
MODE=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh detect-mode "$EPIC_REF")
```

**GitHub mode:** (existing behavior)
```bash
gh issue view $EPIC_REF --repo $REPO --json number,title,body,labels,milestone,state
EPIC_DOC=$(gh issue view $EPIC_REF --repo $REPO --json body --jq '.body' \
  | grep -oE 'docs/epics/[a-zA-Z0-9._-]+\.md' | head -1)
```

**Local mode:**
```bash
EPIC_DOC="$EPIC_REF"
# Validate local-mode marker
grep -q '<!-- super-ralph: local-mode -->' "$EPIC_DOC" \
  || { echo "$EPIC_DOC is not a local-mode epic."; exit 1; }
EPIC_TITLE=$(grep -m1 '^# EPIC:' "$EPIC_DOC" | sed -E 's/^# EPIC: //')
```

Read the EPIC (issue body in github mode, file in local mode) and extract:
- EPIC title and goal
- Story list with identifiers (issue numbers in github mode, `story-N` synthetic IDs in local mode)
- Execution plan (waves, AI-hours)
- PM Summary (priority table, decision points)
```

- [ ] **Step 2: Local-mode Step 2 — synthesize sub-issue tree from sections**

Append after the existing Step 2 body:

```markdown
**Local mode Step 2:** build a synthetic tree from the epic file sections:

```bash
mapfile -t STORY_LINES < <(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh list-stories "$EPIC_DOC")
for line in "${STORY_LINES[@]}"; do
  STORY_NUM=$(echo "$line" | awk -F'[ -]' '{print $2}')
  STORY_BODY=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh extract-substory "$EPIC_DOC" "$STORY_NUM" story)
  BE_BODY=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh   extract-substory "$EPIC_DOC" "$STORY_NUM" be)
  FE_BODY=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh   extract-substory "$EPIC_DOC" "$STORY_NUM" fe)
  INT_BODY=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh  extract-substory "$EPIC_DOC" "$STORY_NUM" int)
  # Treat each body as a virtual issue with number "story-N-<kind>"
done
```

For every gate reference to "issue number" below, substitute the local anchor `story-N-<kind>`. All gate rules (STORY-G1..3, BE-G1..2, FE-G1..2, INT-G1..2) apply unchanged because they are pure text matches on body content.
```

- [ ] **Step 3: Step 6 `--fix` — edit epic file instead of gh issue edit in local mode**

Replace the Step 6 process block with:

```markdown
**Process:**
1. For each auto-fixable finding, apply the fix:
   - **GitHub mode:**
     ```bash
     gh issue edit <number> --body "<fixed body>" --repo $REPO
     ```
   - **Local mode:** splice the fix into `$EPIC_DOC` using `Edit` tool against the relevant `#### [BE|FE|INT|STORY] Story N` sub-section. Use `${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh extract-substory` first to locate the byte range, then compute the replacement via the Edit tool.
2. If the fix involves the epic doc header (either mode), edit the file and commit:
   ```bash
   git add $EPIC_DOC
   git commit -m "fix(design): [what was fixed]"
   ```
3. Mark the finding as FIXED in the report.
```

- [ ] **Step 4: Step 7 verdict — output path-based launch commands in local mode**

Find the `#### READY` verdict template (Wave Plan table). Add a sibling block:

```markdown
**In local mode:** launch commands use file paths:

#### Wave 1 (start immediately, parallel)
| Story | Command | AI-Hours |
|-------|---------|----------|
| Story 1: [Title] | `/super-ralph:build-story docs/epics/<slug>.md#story-1` | Xh |
```

- [ ] **Step 5: Verify**

Run: `grep -c 'is not a local-mode epic' /Users/junhua/.claude/plugins/super-ralph/commands/review-design.md`

Expected: `1`

Run: `grep -c 'build-story docs/epics/<slug>.md#story-' /Users/junhua/.claude/plugins/super-ralph/commands/review-design.md`

Expected: `≥1`

- [ ] **Step 6: Commit**

```bash
git -C /Users/junhua/.claude/plugins/super-ralph add commands/review-design.md
git -C /Users/junhua/.claude/plugins/super-ralph commit -m "feat(review-design): local-mode — read epic file, synthesize gates"
```

---

### Task 15: New command `/super-ralph:improve-design` — scaffold + Phase 0a

**Files:**
- Create: `commands/improve-design.md`

**Rationale:** Scaffold the new command file with frontmatter, arguments, and the target-resolver phase. Subsequent tasks add the feedback interpreter and apply/commit/re-validate phases.

- [ ] **Step 1: Write the command file**

Create `commands/improve-design.md`:

````markdown
---
name: improve-design
description: "Make targeted adjustments to an existing design (local or GitHub) from a single natural-language prompt. Autonomously resolves the target epic, interprets feedback, applies conservative structured edits, and re-validates."
argument-hint: "\"<prompt>\""
allowed-tools: ["Bash(gh:*)", "Bash(git:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh:*)", "Read", "Write", "Edit", "Glob", "Grep", "Task", "AskUserQuestion"]
---

# Super-Ralph Improve-Design Command

Make targeted adjustments to an existing design — either a local epic file or a GitHub `[EPIC]` — from a single natural-language prompt. The command autonomously resolves the target, interprets the feedback into structured changes, applies them, and re-validates via `/super-ralph:review-design`.

## Philosophy

Unlike `/design` and `/e2e` which are fire-and-forget, `/improve-design` may pause once for user disambiguation (Phase 0a) and once to surface a clarification question (Phase 1). These are the only interactive points. All other phases run autonomously.

## Arguments

Parse the user's input as a single quoted prompt containing both:
- Target identifier — a file path (`docs/epics/foo.md`), a `#NNN` issue reference, or absent (in which case Phase 0a infers it)
- Feedback text — free-form description of the desired change

Example prompts:
- `/super-ralph:improve-design "Split Story 5 in docs/epics/2026-04-18-foo.md into list + detail"`
- `/super-ralph:improve-design "Add SSO to epic #531"`
- `/super-ralph:improve-design "The module catalog epic needs a SECURITY scenario in Story 1"`
- `/super-ralph:improve-design "Improve the latest epic: add error handling"`

## Workflow

### Step 0: Load Project Config

Read `.claude/super-ralph-config.md` to load project-specific values. If the file does not exist, first attempt auto-init by invoking the init command logic, then tell the user to run `/super-ralph:init` manually if auto-init fails.

Extract: `$REPO`, `$ORG`.

### Phase 0a: Resolve target from prompt

Extraction order:

1. **Explicit file path:**
   ```bash
   TARGET_PATH=$(echo "$PROMPT" | grep -oE 'docs/epics/[^[:space:]]+\.md' | head -1)
   ```
   If non-empty: `TARGET=$TARGET_PATH`, `MODE=local`.

2. **Explicit issue reference:**
   ```bash
   TARGET_NUM=$(echo "$PROMPT" | grep -oE '#[0-9]+|\bEPIC[[:space:]]*#?[0-9]+' | head -1 | grep -oE '[0-9]+')
   ```
   If non-empty: `TARGET="#$TARGET_NUM"`, `MODE=github`.

3. **Fuzzy match (target-resolver sub-agent)** — only if neither above yielded a target. Dispatch:

   ```
   Task tool:
     model: sonnet
     max_turns: 10
     description: "Resolve epic target from improvement prompt"
     prompt: |
       User prompt: "$PROMPT"

       Available local epics (path + first `# EPIC:` heading + mtime):
       [glob docs/epics/*.md and for each, read line 1 + `stat -f %m`]

       Available GitHub EPICs:
       [output of: gh issue list --repo $REPO --label epic --state open --json number,title]

       Identify which epic the prompt most likely refers to.
       Return JSON on stdout:
       {
         "best_match": "docs/epics/foo.md" | "#123" | null,
         "confidence": "high" | "medium" | "low",
         "candidates": [{"target": "...", "reason": "..."}],
         "feedback_stripped": "<prompt minus target-identifying words>"
       }
   ```

4. **Disambiguation gate:**
   - `confidence: high` + single candidate → proceed silently with that target.
   - `confidence: medium` OR 2+ candidates → invoke `AskUserQuestion` listing the candidates. Exit after the user picks (the picked target becomes `TARGET`).
   - `confidence: low` or null → exit with: `"Could not identify which epic to improve. Please include the file path or #EPIC_NUMBER in your prompt."`

After this phase you MUST have:
- `TARGET` (string)
- `MODE` (`local` or `github`)
- `FEEDBACK` (the prompt with any target-identifying words stripped — use `feedback_stripped` if resolver ran, otherwise the original prompt)

### Phase 1: Interpret feedback

(Placeholder — to be implemented in Task 16.)

### Phase 2: Apply changes

(Placeholder — to be implemented in Task 17.)

### Phase 3: Commit changes

(Placeholder — to be implemented in Task 18.)

### Phase 4: Re-validate

(Placeholder — to be implemented in Task 18.)

## Critical Rules

- **No silent target guesses.** If neither explicit nor high-confidence fuzzy match, ask the user (or exit with an explicit error).
- **Never modify a story with `**Status:** COMPLETED` (local) or a CLOSED `[STORY]` issue (GitHub).** Refuse the edit.
- **No deletion on GitHub.** Removed stories close with `reason: not_planned`, preserving audit trail.
- **No renumbering.** Leaving holes preserves cross-references.
- **Re-validate after edit.** Phase 4 always runs `/review-design`.
````

- [ ] **Step 2: Verify**

Run: `test -f /Users/junhua/.claude/plugins/super-ralph/commands/improve-design.md && echo OK`

Expected: `OK`

Run: `grep -c '^name: improve-design$' /Users/junhua/.claude/plugins/super-ralph/commands/improve-design.md`

Expected: `1`

Run: `grep -c "Phase 0a" /Users/junhua/.claude/plugins/super-ralph/commands/improve-design.md`

Expected: `1`

- [ ] **Step 3: Commit**

```bash
git -C /Users/junhua/.claude/plugins/super-ralph add commands/improve-design.md
git -C /Users/junhua/.claude/plugins/super-ralph commit -m "feat(improve-design): scaffold + Phase 0a target resolver"
```

---

### Task 16: `/improve-design` — Phase 1 feedback interpreter

**Files:**
- Modify: `commands/improve-design.md`

- [ ] **Step 1: Replace the Phase 1 placeholder**

In `commands/improve-design.md`, replace `### Phase 1: Interpret feedback\n\n(Placeholder — to be implemented in Task 16.)` with:

````markdown
### Phase 1: Interpret feedback (1 Sonnet sub-agent)

Dispatch a feedback-interpreter sub-agent:

```
Task tool:
  model: sonnet
  max_turns: 15
  description: "Interpret improve-design feedback into structured changes"
  prompt: |
    TARGET: $TARGET (mode: $MODE)
    FEEDBACK: "$FEEDBACK"

    CURRENT DESIGN:
    [if MODE=local: full contents of $TARGET]
    [if MODE=github: issue body + all child STORY/BE/FE/INT bodies (fetch with gh)]

    Map the feedback to one or more structured change entries using ONLY these types:
    - ADD_STORY
    - REMOVE_STORY
    - SPLIT_STORY
    - MERGE_STORIES
    - EDIT_AC
    - EDIT_TDD
    - EDIT_SHARED_CONTRACT
    - EDIT_SCOPE
    - RE_WAVE
    - EDIT_METADATA (priority, size, persona)

    For each change, include:
    - `target`: either `story-N` (local) or `#issue-number` (github) or `epic-header` for scope/wave edits
    - `type`: one of the above
    - `details`: type-specific fields (what to add/change, exact wording if user provided it)

    Return JSON on stdout (single object):
    {
      "clarification_needed": false | true,
      "clarification_question": "<string if true>",
      "changes": [
        {"type": "...", "target": "...", "details": { ... }}
      ]
    }

    If the feedback cannot be mapped to any supported change type (e.g., "make Story 3 simpler" with no specifics), set clarification_needed=true and return a focused question — do NOT guess.
```

Parse the JSON output:
- If `clarification_needed=true`: print the question verbatim and exit cleanly (exit code 0, no changes applied).
- If `changes` is empty: print `"No actionable changes identified in feedback."` and exit.
- Otherwise: proceed to Phase 2 with the changes array.

Persist the changes array to `$(git rev-parse --show-toplevel)/.claude/runs/improve-$(basename $TARGET .md)/changes.json` for audit and Phase 3 consumption.
````

- [ ] **Step 2: Verify**

Run: `grep -c "Phase 1: Interpret feedback" /Users/junhua/.claude/plugins/super-ralph/commands/improve-design.md`

Expected: `1`

Run: `grep -c "clarification_needed" /Users/junhua/.claude/plugins/super-ralph/commands/improve-design.md`

Expected: `≥2`

- [ ] **Step 3: Commit**

```bash
git -C /Users/junhua/.claude/plugins/super-ralph add commands/improve-design.md
git -C /Users/junhua/.claude/plugins/super-ralph commit -m "feat(improve-design): Phase 1 feedback interpreter"
```

---

### Task 17: `/improve-design` — Phase 2 apply-change sub-agents

**Files:**
- Modify: `commands/improve-design.md`

- [ ] **Step 1: Replace the Phase 2 placeholder**

In `commands/improve-design.md`, replace the Phase 2 placeholder with:

````markdown
### Phase 2: Apply changes (up to 3 Opus sub-agents in parallel)

For each change entry in `.claude/runs/improve-<slug>/changes.json`, dispatch an apply-change sub-agent. Run up to 3 in parallel (match `/design` Phase 4 concurrency).

**Pre-flight per change (orchestrator):**

Before dispatching, the orchestrator itself checks shipped-immutability:

```bash
if [ "$MODE" = "local" ]; then
  STATUS=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh get-status "$TARGET" "$STORY_NUM")
  if [ "$STATUS" = "COMPLETED" ]; then
    SKIPPED+=("story-$STORY_NUM: REFUSED — Status=COMPLETED")
    continue
  fi
else
  STATE=$(gh issue view "#$STORY_NUM" --repo $REPO --json state --jq '.state')
  if [ "$STATE" = "CLOSED" ]; then
    SKIPPED+=("#$STORY_NUM: REFUSED — issue CLOSED")
    continue
  fi
fi
```

Changes targeting `epic-header` (scope, waves) bypass this check.

**Each apply-change sub-agent:**

```
Task tool:
  model: opus
  max_turns: 40
  description: "Apply improve-design change N: <type> <target>"
  prompt: |
    Change to apply:
      type: $CHANGE_TYPE
      target: $CHANGE_TARGET
      details: $CHANGE_DETAILS

    Mode: $MODE ($TARGET)

    Current section(s) to modify:
    [if MODE=local: extracted via parse-local-epic.sh]
    [if MODE=github: fetched via gh issue view for the target issue(s)]

    Relevant templates:
      Story templates: ${CLAUDE_PLUGIN_ROOT}/skills/product-design/references/story-template.md
      Epic templates:  ${CLAUDE_PLUGIN_ROOT}/skills/product-design/references/epic-template.md
      AC guide:        ${CLAUDE_PLUGIN_ROOT}/skills/product-design/references/acceptance-criteria-guide.md

    Produce the new/edited section text(s) following the same format conventions as `/design`:
      - Gherkin AC: full Feature/Background/Scenario, ≥3 scenarios, ≥1 [SECURITY]
      - TDD Tasks: exact code, expected outputs, commit messages
      - Mock data included in [FE] bodies
      - i18n in both base + secondary locale files

    Write outputs to:
      .claude/runs/improve-<slug>/change-N-new-<target>.md  (replacement content)
      .claude/runs/improve-<slug>/change-N-meta.json        (operation metadata: path_in_file, issue_number_to_edit, issue_numbers_to_close, etc.)

    NEVER ask the user. Use research/SME agents if architectural decisions are needed.
```

After all apply-change sub-agents complete, the orchestrator has a directory full of `change-N-new-*.md` files and `change-N-meta.json` metadata ready for Phase 3.
````

- [ ] **Step 2: Verify**

Run: `grep -c "Phase 2: Apply changes" /Users/junhua/.claude/plugins/super-ralph/commands/improve-design.md`

Expected: `1`

Run: `grep -c "REFUSED.*Status=COMPLETED" /Users/junhua/.claude/plugins/super-ralph/commands/improve-design.md`

Expected: `1`

- [ ] **Step 3: Commit**

```bash
git -C /Users/junhua/.claude/plugins/super-ralph add commands/improve-design.md
git -C /Users/junhua/.claude/plugins/super-ralph commit -m "feat(improve-design): Phase 2 apply-change with shipped-immutability"
```

---

### Task 18: `/improve-design` — Phase 3 commit + Phase 4 re-validate + final report

**Files:**
- Modify: `commands/improve-design.md`

- [ ] **Step 1: Replace Phase 3 + Phase 4 placeholders**

In `commands/improve-design.md`, replace Phase 3 and Phase 4 placeholders with:

````markdown
### Phase 3: Commit changes

**Local mode:**

For each `change-N-meta.json`, apply the new section text to `$TARGET` using the `Edit` tool:

- `ADD_STORY`: append `<!-- new ### Story N+1: ... block -->` to the file, before any trailing horizontal rule.
- `REMOVE_STORY`: locate `### Story N:` section, remove from that heading to the next `### Story` heading (leave the number hole).
- `SPLIT_STORY`: replace the `### Story N:` section with two new sections (agent provides both).
- `MERGE_STORIES`: replace primary; remove secondary (leave the secondary's number as a hole).
- `EDIT_*`: locate the sub-section (via `parse-local-epic.sh extract-substory`), replace its body text with the new content.
- `RE_WAVE`: edit the `#### Wave Assignments` table in the epic header.
- `EDIT_METADATA`: edit the `**Persona:**  **Priority:**  **Size:**  **Status:**` line.

Update the Story Priority Table and Wave Assignments tables in the epic header to reflect any structural changes.

Commit:
```bash
git add "$TARGET"
git commit -m "design: improve epic $(basename $TARGET .md) — $FEEDBACK_SUMMARY"
```

Where `$FEEDBACK_SUMMARY` is a ≤60-char one-line summary distilled from the change types (e.g., `split story 5; add [SECURITY] to story 1`).

**GitHub mode:**

For each change:
- `ADD_STORY`: `gh issue create` new `[STORY]` + `[BE]` + `[FE]` + `[INT]` sub-issues. Update EPIC body to reference them.
- `REMOVE_STORY`: `gh issue close <num> --reason not_planned` for STORY + all sub-issues. Do not delete. Update EPIC body.
- `SPLIT_STORY`: close original STORY (+ sub-issues) with `not_planned`, create 2 new STORYs + sub-issue families.
- `MERGE_STORIES`: close secondary STORY with `not_planned`, edit primary STORY body to incorporate merged AC/TDD.
- `EDIT_*`: `gh issue edit <num> --body "<new body>"`.
- `RE_WAVE`: update EPIC body's wave assignment table.

Also edit the `docs/epics/<slug>.md` summary table file to reflect structural changes. Commit the doc change:
```bash
git add docs/epics/
git commit -m "design: improve epic #$TARGET_NUM — $FEEDBACK_SUMMARY"
```

### Phase 4: Re-validate

Automatically invoke `/super-ralph:review-design "$TARGET"` on the updated design:

```
Task tool:
  model: sonnet
  max_turns: 30
  description: "Re-validate after improve-design"
  prompt: |
    Read ${CLAUDE_PLUGIN_ROOT}/commands/review-design.md.
    Follow it for target: $TARGET
    Return the verdict: READY / CONDITIONAL / BLOCKED with findings summary.
```

Capture the verdict + findings summary.

## Final Report

Output the structured report:

```markdown
# Design Improved: $EPIC_TITLE

## Target
$TARGET (mode: $MODE)

## Changes Applied
| # | Type | Target | Result |
|---|------|--------|--------|
[one row per successful change]

## Skipped
| Target | Reason |
|--------|--------|
[one row per skipped change, e.g., REFUSED shipped]

## Re-Validation Verdict
READY | CONDITIONAL | BLOCKED
[findings summary if any]

## Next
[if local: `/super-ralph:build-story $TARGET#story-N` per new/modified story]
[if github: `/super-ralph:build-story #<new-story-num>` per new/modified story]
```
````

- [ ] **Step 2: Verify**

Run: `grep -c "Phase 3: Commit changes" /Users/junhua/.claude/plugins/super-ralph/commands/improve-design.md`

Expected: `1`

Run: `grep -c "Phase 4: Re-validate" /Users/junhua/.claude/plugins/super-ralph/commands/improve-design.md`

Expected: `1`

Run: `grep -c "Final Report" /Users/junhua/.claude/plugins/super-ralph/commands/improve-design.md`

Expected: `1`

- [ ] **Step 3: Commit**

```bash
git -C /Users/junhua/.claude/plugins/super-ralph add commands/improve-design.md
git -C /Users/junhua/.claude/plugins/super-ralph commit -m "feat(improve-design): Phase 3 commit + Phase 4 re-validate + final report"
```

---

### Task 19: Update `commands/help.md` — version + local mode + improve-design

**Files:**
- Modify: `commands/help.md`

- [ ] **Step 1: Bump version in help header**

In `commands/help.md`, change line 14:

`# Super-Ralph v0.9.2 — Design-First Autonomous Development`

to:

`# Super-Ralph v0.11.0 — Design-First Autonomous Development`

- [ ] **Step 2: Update Pipelines section**

Find the `## Pipelines` block and replace it with:

```
## Pipelines

  Design-first (GitHub):     design → build-story → review-fix → verify → finalise
  Design-first (local file): design --local → build-story <path> → review-fix → verify → finalise
  Design-adjust:             improve-design → review-design → (re-run build-story for changed stories)
  Epic (GitHub):             e2e <epic#> (parallel build-story per story, then release)
  Epic (local):              e2e <epic.md> (parallel build-story per story-N, then release)
  Ad-hoc:                    plan → build → review-fix → verify → finalise
  Reactive:                  repair → review-fix → verify → finalise
  Hotfix:                    repair --hotfix → review-fix → verify → finalise on main
  Release:                   release (QA → Codex review → merge staging→main → tag)
  Quality:                   review-design (validate all issues against quality gates)
  Brainstorm:                brainstorm (research → CPO+CTO+CAIO → recommendations)
```

- [ ] **Step 3: Update `/super-ralph:design` help block to mention `--local`**

Find `### /super-ralph:design <feature-or-goal> [--output PATH]`. Change its signature line to:

`### /super-ralph:design <feature-or-goal> [--output PATH] [--local]`

Append to its body (after `Stories are immediately buildable — no /plan step needed.`):

```
  --local: Write the full epic+stories into docs/epics/<slug>.md with no GitHub
           issues created. Downstream commands (build-story, e2e, review-design)
           then operate on the file path instead of an issue number.
```

- [ ] **Step 4: Insert `/super-ralph:improve-design` section before `/super-ralph:build`**

Insert a new help block right before `### /super-ralph:build <plan-path> [--max-iterations N]`:

```
### /super-ralph:improve-design "<prompt>"

  Adjust an existing design (local file or GitHub EPIC) from a single prompt.
  Autonomously resolves the target epic from the prompt, interprets the feedback,
  applies conservative structured edits (add/remove/split/merge/edit_ac/edit_tdd/
  edit_scope/re_wave), and re-validates via /review-design.

  Shipped stories (Status=COMPLETED or CLOSED issue) are immutable — the command
  refuses edits and tells you to cut a new story instead.

  Example:
    /super-ralph:improve-design "Add a SECURITY scenario to Story 1 of the module catalog epic"
    /super-ralph:improve-design "Split Story 5 in docs/epics/2026-04-18-foo.md into list + detail"
    /super-ralph:improve-design "Drop Story 3 from epic #531 — out of scope"

```

- [ ] **Step 5: Update `/super-ralph:build <plan-path>` to show new arg shape**

Change its signature line to:

`### /super-ralph:build <plan-path | epic.md#story-N> [--max-iterations N]`

Append to its body:

```
  Epic-section invocation:
    /super-ralph:build docs/epics/2026-04-18-foo.md#story-3      # whole story (BE+FE)
    /super-ralph:build docs/epics/2026-04-18-foo.md#story-3-be   # just backend
```

- [ ] **Step 6: Update `/super-ralph:build-story <STORY>` input-formats list**

Find the block listing its input formats and replace with:

```
  Input formats:
    /super-ralph:build-story #42                        # GitHub issue number
    /super-ralph:build-story docs/epics/gl.md#story-3   # Local epic — single story
    /super-ralph:build-story "Add JWT auth endpoints"   # Description string
```

- [ ] **Step 7: Update `/super-ralph:e2e` signature + example**

Change to:

`### /super-ralph:e2e <EPIC_NUMBER | docs/epics/<slug>.md> [--max-parallel N]`

Append to body:

```
  Local mode:
    /super-ralph:e2e docs/epics/2026-04-18-foo.md
```

- [ ] **Step 8: Update `/super-ralph:review-design` signature**

Change to:

`### /super-ralph:review-design <EPIC_NUMBER | docs/epics/<slug>.md> [--fix] [--strict]`

- [ ] **Step 9: Verify**

Run: `grep -c 'v0.11.0' /Users/junhua/.claude/plugins/super-ralph/commands/help.md`

Expected: `1`

Run: `grep -c '/super-ralph:improve-design' /Users/junhua/.claude/plugins/super-ralph/commands/help.md`

Expected: `≥3`

Run: `grep -c 'design --local' /Users/junhua/.claude/plugins/super-ralph/commands/help.md`

Expected: `≥1`

- [ ] **Step 10: Commit**

```bash
git -C /Users/junhua/.claude/plugins/super-ralph add commands/help.md
git -C /Users/junhua/.claude/plugins/super-ralph commit -m "docs(help): v0.11.0 — local mode + improve-design"
```

---

### Task 20: Update `CHANGELOG.md`

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Prepend a new v0.11.0 section**

In `CHANGELOG.md`, insert immediately after the `# Super-Ralph Changelog` heading:

```markdown
## v0.11.0 — Local Mode + Improve-Design (2026-04-18)

### Added
- `/super-ralph:design --local` flag — writes the full epic + all stories into a single markdown file at `docs/epics/<slug>.md` and SKIPS GitHub issue creation entirely.
- Path-based invocation for downstream commands:
  - `/super-ralph:build-story docs/epics/<slug>.md#story-N`
  - `/super-ralph:e2e docs/epics/<slug>.md`
  - `/super-ralph:review-design docs/epics/<slug>.md`
  - `/super-ralph:build docs/epics/<slug>.md#story-N` (and `#story-N-<be|fe|int>`)
- New command `/super-ralph:improve-design "<prompt>"` — autonomously resolves the target epic (local or GitHub) from a single natural-language prompt, interprets feedback into structured changes (add/remove/split/merge/edit_ac/edit_tdd/edit_scope/re_wave/edit_metadata), applies conservative edits, and re-validates via `/review-design`.
- Shared parser `scripts/parse-local-epic.sh` with subcommands `detect-mode`, `list-stories`, `extract-story`, `extract-substory`, `get-status`, `set-status`.
- Test fixtures and assertion suite: `test/fixtures/sample-local-epic.md`, `test/fixtures/completed-story-epic.md`, `test/test-parse-local-epic.sh`.

### Safety
- `/improve-design` refuses to edit stories with `Status: COMPLETED` (local) or a CLOSED `[STORY]` issue (GitHub).
- Removed stories close with `reason: not_planned` on GitHub (no deletion) and leave numbering holes in local files (preserves cross-references).
- Target disambiguation uses `AskUserQuestion` when confidence is not high; no silent guessing.

### Notes
- All existing GitHub-mode workflows are unchanged. Local mode is additive and default off.
- No migration needed for existing open epics.

```

- [ ] **Step 2: Verify**

Run: `grep -c '^## v0.11.0' /Users/junhua/.claude/plugins/super-ralph/CHANGELOG.md`

Expected: `1`

- [ ] **Step 3: Commit**

```bash
git -C /Users/junhua/.claude/plugins/super-ralph add CHANGELOG.md
git -C /Users/junhua/.claude/plugins/super-ralph commit -m "docs(changelog): v0.11.0 local mode + improve-design"
```

---

### Task 21: Integration smoke test (manual)

**Files:** (none created or modified — verification only)

**Rationale:** Command-file edits are prompts to an LLM; the only automatable regression test is the parser suite from Tasks 2-5. Run the end-to-end flow against a throwaway fixture to smoke-test that the assembled command prompts hang together.

- [ ] **Step 1: Verify all parser tests still pass**

Run: `bash /Users/junhua/.claude/plugins/super-ralph/test/test-parse-local-epic.sh`

Expected: all 19 PASS lines, exit code 0.

- [ ] **Step 2: Grep-sanity check the modified command files**

Run each check; none should fail:

```bash
PLUGIN=/Users/junhua/.claude/plugins/super-ralph

# design.md — four markers
grep -q 'argument-hint: "<feature-or-goal>' $PLUGIN/commands/design.md  # frontmatter preserved
grep -q '^- \*\*--local\*\*' $PLUGIN/commands/design.md
grep -q 'Step 11b: Consolidate' $PLUGIN/commands/design.md
grep -q 'Skip this entire phase when.--local' $PLUGIN/commands/design.md

# build.md — arg hint updated
grep -q 'epic-file.md' $PLUGIN/commands/build.md

# build-story.md — local branch + Closes local epic
grep -q 'Local Epic File' $PLUGIN/commands/build-story.md
grep -q 'Closes local epic' $PLUGIN/commands/build-story.md
grep -q 'Refusing to rebuild shipped work' $PLUGIN/commands/build-story.md

# e2e.md — local variant
grep -q 'Local variant:' $PLUGIN/commands/e2e.md

# review-design.md — local mode
grep -q 'is not a local-mode epic' $PLUGIN/commands/review-design.md

# improve-design.md — new command with 4 phases
grep -q '^name: improve-design$' $PLUGIN/commands/improve-design.md
grep -q 'Phase 0a' $PLUGIN/commands/improve-design.md
grep -q 'Phase 1: Interpret feedback' $PLUGIN/commands/improve-design.md
grep -q 'Phase 2: Apply changes' $PLUGIN/commands/improve-design.md
grep -q 'Phase 3: Commit changes' $PLUGIN/commands/improve-design.md
grep -q 'Phase 4: Re-validate' $PLUGIN/commands/improve-design.md

# help.md — version + commands listed
grep -q 'v0.11.0' $PLUGIN/commands/help.md
grep -q '/super-ralph:improve-design' $PLUGIN/commands/help.md

# CHANGELOG.md — version entry
grep -q '^## v0.11.0' $PLUGIN/CHANGELOG.md

echo "All smoke checks passed."
```

Expected: `All smoke checks passed.`

- [ ] **Step 3: Live smoke test — `/design --local` against a tiny feature**

Invoke manually in a Claude Code session (not part of this plan's automated steps):

```
/super-ralph:design "Internal toy feature — store 3 quotes and render them" --local
```

Verify: the epic file exists at `docs/epics/<today>-internal-toy-feature-*.md`, contains the local-mode marker, and has at least one `### Story N:` section with full [STORY]/[BE]/[FE]/[INT] sub-sections.

- [ ] **Step 4: Live smoke test — `/review-design` against the file**

```
/super-ralph:review-design docs/epics/<today>-internal-toy-feature-*.md
```

Verify: returns a verdict (READY/CONDITIONAL/BLOCKED) and cites sections via `docs/epics/...#story-N` anchors.

- [ ] **Step 5: Live smoke test — `/improve-design` asks clarification on vague prompt**

```
/super-ralph:improve-design "Make the toy feature better"
```

Verify: Phase 1 returns `clarification_needed=true` and the command prints the question without touching the file.

- [ ] **Step 6: Clean up the smoke-test epic file**

```bash
rm /Users/junhua/Workspace/ForthAI/Tech/products/work/docs/epics/<today>-internal-toy-feature-*.md
```

- [ ] **Step 7: Final commit (only if smoke tests revealed any doc fixes)**

If Steps 2-5 surfaced problems that required doc tweaks, commit them:

```bash
git -C /Users/junhua/.claude/plugins/super-ralph add -u
git -C /Users/junhua/.claude/plugins/super-ralph commit -m "docs: smoke-test adjustments for v0.11.0"
```

---

## Self-Review Checklist

(Applied inline before handing off to execution.)

**Spec coverage:**
- AC-1 (`/design --local` produces self-contained file) → Tasks 6, 7, 8
- AC-2 (`/build-story` operates on local file) → Tasks 11, 12
- AC-3 (`/e2e` operates on local file) → Task 13
- AC-4 (`/review-design` validates local file) → Task 14
- AC-5 (`/improve-design` resolves target from prompt) → Tasks 15, 16, 17, 18
- AC-6 (`/improve-design` refuses shipped edits) → Task 17 (pre-flight check)
- AC-7 (`/improve-design` asks on low confidence) → Task 15 (Phase 0a disambiguation)
- AC-8 (`/build` accepts epic-section path) → Task 9
- AC-9 (GitHub auto-detect fallthrough) → Task 2 (parser) + Tasks 11, 13, 14 (use parser)
- AC-10 (modes independently toggleable) → no state carried between invocations; no task needed

**Placeholder scan:** No "TBD", "TODO", "implement later" in any task body. Bash code blocks are complete. `commands/improve-design.md` contains `(Placeholder — to be implemented in Task N)` markers inside Tasks 15-18 but these are explicitly named phased placeholders that Tasks 16-18 replace.

**Type consistency:** `MODE` values (`local`, `github`, `description`) are consistent across Tasks 2, 11, 13, 14, 15. Parser subcommand names (`detect-mode`, `list-stories`, `extract-story`, `extract-substory`, `get-status`, `set-status`) are the exact names defined in Task 2 and referenced identically in every consuming command. Status values (`PENDING`, `IN_PROGRESS`, `READY`, `COMPLETED`) are consistent between the fixture, the parser, the finalise steps, and the review gates.
