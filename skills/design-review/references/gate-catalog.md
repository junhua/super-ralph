# Design Review Gate Catalog

> Canonical catalog of enforcement gates applied by `/super-ralph:review-design`.
> The skill body (`../SKILL.md`) points here for gate definitions; per-story review
> agents (Step 3) and the final classification/reporting (Steps 5-6) live in the
> skill body.

## Per-Issue Gates (from review-design.md Step 2.5)

#### STORY Gates

| Gate | Rule | How to check |
|------|------|--------------|
| STORY-G1 | Body contains `## User Journey` (or `## User Journey (narrative)`) section | `grep -q "^## User Journey" <body>` |
| STORY-G2 | Body contains Gherkin block with ≥3 scenarios AND at least one line matching `Scenario: \[SECURITY\]` | `grep -c "^  Scenario:" <gherkin_block>` ≥ 3 AND `grep -q "Scenario: \[SECURITY\]"` |
| STORY-G3 | Body lists 3 sub-issues: `[BE] #N`, `[FE] #N`, `[INT] #N` | regex each label present in `## Sub-Issues` block |

#### [BE] Gates

| Gate | Rule | How to check |
|------|------|--------------|
| BE-G1 | Body contains `## TDD Tasks` section | `grep -q "^## TDD Tasks" <body>` |
| BE-G2 | TDD Tasks contain at least 2 `**Progress check:**` lines AND no disallowed placeholders | `grep -c "Progress check:" <body>` ≥ 2 AND `! grep -E "(TODO|\.\.\.|implement X here)" <body>` |

#### [FE] Gates

| Gate | Rule | How to check |
|------|------|--------------|
| FE-G1 | Body contains `## Mock Data` section | `grep -q "^## Mock Data" <body>` |
| FE-G2 | Body contains `## PM Checkpoints` with 4 checkpoints (CP1, CP2, CP3, CP4) | `grep -c "CP[1-4]" <body>` ≥ 4 |

#### [INT] Gates

| Gate | Rule | How to check |
|------|------|--------------|
| INT-G1 | Body contains `## Gherkin User Journey` referencing parent story | `grep -q "^## Gherkin User Journey" <body>` AND `grep -q "See parent #" <body>` |
| INT-G2 | Body contains `## Verification Tasks` with `/super-ralph:verify` invocation | `grep -q "/super-ralph:verify" <body>` |

#### BRIEF Gates (apply to brief stories only)

Applied when `detect-story-level` returns `brief`. These gates replace STORY-G2, STORY-G3, BE-G*, FE-G*, INT-G*, CTX-G* for that story.

| Gate | Rule | How to check |
|------|------|--------------|
| BRIEF-G1 | Body contains `#### Acceptance Criteria (Outline)` section with ≥3 bullets; each of `[HAPPY]`, `[EDGE]`, `[SECURITY]` labels appears at least once | `grep -q "^#### Acceptance Criteria (Outline)"` AND `grep -c '^- \`\[HAPPY\]\`'` ≥ 1 AND `grep -c '^- \`\[EDGE\]\`'` ≥ 1 AND `grep -c '^- \`\[SECURITY\]\`'` ≥ 1 |
| BRIEF-G2 | Body does NOT contain `#### Shared Contract`, `#### Pre-Decided Implementation`, `#### [BE]`, `#### [FE]`, or `#### [INT]` subsections | `! grep -qE "^#### (Shared Contract\|Pre-Decided Implementation\|\[BE\]\|\[FE\]\|\[INT\])"` |
| BRIEF-G3 | GitHub mode: the `[STORY]` issue has no `[BE]`/`[FE]`/`[INT]` child issues | `gh issue list --search "Parent: #<N> in:body"` returns no `[BE]`/`[FE]`/`[INT]`-prefixed titles |

#### Context Budget Gates (per story group)

Every execution-level issue will be loaded by a `/super-ralph:build-story` subagent into a fresh 200k-token context window. Design-time sizing is the only lever — enforce it here.

Char thresholds assume `1 token ≈ 4 chars`. Measure body size via `echo "$BODY" | wc -c`.

| Gate | Rule | How to check |
|------|------|--------------|
| CTX-G1 | Each individual issue body under hard cap | STORY ≤ 120,000 chars; BE ≤ 160,000 chars; FE ≤ 160,000 chars; INT ≤ 80,000 chars |
| CTX-G2 | Combined STORY + BE + FE + INT for a given story group ≤ 480,000 chars (~120k tok) | Sum the four body char counts; must be ≤ 480,000 |
| CTX-G3 | "Relevant Existing Files" / "Patterns to Follow" list ≤ 8 file refs per BE or FE body | `grep -cE "^- \`?\\\$[A-Z_]+_(DIR\|FILE)" <body>` ≤ 8 |

**Soft-warn (not BLOCKED):** combined size > 360,000 chars (~90k tok) emits a CONDITIONAL warning — ship is allowed but remediation is recommended before re-running `/super-ralph:build-story`.

#### Gate Evaluation Example

## Gate Evaluation Example

#### Context Budget Gates (per story group)

Every execution-level issue will be loaded by a `/super-ralph:build-story` subagent into a fresh 200k-token context window. Design-time sizing is the only lever — enforce it here.

Char thresholds assume `1 token ≈ 4 chars`. Measure body size via `echo "$BODY" | wc -c`.

| Gate | Rule | How to check |
|------|------|--------------|
| CTX-G1 | Each individual issue body under hard cap | STORY ≤ 120,000 chars; BE ≤ 160,000 chars; FE ≤ 160,000 chars; INT ≤ 80,000 chars |
| CTX-G2 | Combined STORY + BE + FE + INT for a given story group ≤ 480,000 chars (~120k tok) | Sum the four body char counts; must be ≤ 480,000 |
| CTX-G3 | "Relevant Existing Files" / "Patterns to Follow" list ≤ 8 file refs per BE or FE body | `grep -cE "^- \`?\\\$[A-Z_]+_(DIR\|FILE)" <body>` ≤ 8 |

**Soft-warn (not BLOCKED):** combined size > 360,000 chars (~90k tok) emits a CONDITIONAL warning — ship is allowed but remediation is recommended before re-running `/super-ralph:build-story`.

#### Gate Evaluation Example

For each STORY in the epic:
```bash
STORY_BODY=$(gh issue view $STORY_NUMBER --repo $REPO --json body --jq '.body')

# STORY-G1
if ! echo "$STORY_BODY" | grep -q "^## User Journey"; then
  FAILURES+=("STORY-G1: #$STORY_NUMBER missing User Journey narrative")
fi

# STORY-G2
SCENARIO_COUNT=$(echo "$STORY_BODY" | grep -c "^  Scenario:" || echo 0)
HAS_SECURITY=$(echo "$STORY_BODY" | grep -c "Scenario: \[SECURITY\]" || echo 0)
if [ "$SCENARIO_COUNT" -lt 3 ] || [ "$HAS_SECURITY" -lt 1 ]; then
  FAILURES+=("STORY-G2: #$STORY_NUMBER has $SCENARIO_COUNT scenarios, [SECURITY]=$HAS_SECURITY (need ≥3 and ≥1 SECURITY)")
fi

# STORY-G3
if ! echo "$STORY_BODY" | grep -q "\[INT\] #"; then
  FAILURES+=("STORY-G3: #$STORY_NUMBER missing [INT] sub-issue reference")
fi

# ... repeat for BE, FE, INT issues

# CTX-G1 / CTX-G2: Context budget audit per story group
STORY_CHARS=$(echo "$STORY_BODY" | wc -c | tr -d ' ')
BE_CHARS=$(echo "$BE_BODY"       | wc -c | tr -d ' ')
FE_CHARS=$(echo "$FE_BODY"       | wc -c | tr -d ' ')
INT_CHARS=$(echo "$INT_BODY"     | wc -c | tr -d ' ')
COMBINED=$((STORY_CHARS + BE_CHARS + FE_CHARS + INT_CHARS))

[ "$STORY_CHARS" -gt 120000 ] && FAILURES+=("CTX-G1: #$STORY_NUMBER STORY body $STORY_CHARS chars exceeds 120,000 cap")
[ "$BE_CHARS"    -gt 160000 ] && FAILURES+=("CTX-G1: #$STORY_NUMBER BE body $BE_CHARS chars exceeds 160,000 cap")
[ "$FE_CHARS"    -gt 160000 ] && FAILURES+=("CTX-G1: #$STORY_NUMBER FE body $FE_CHARS chars exceeds 160,000 cap")
[ "$INT_CHARS"   -gt 80000  ] && FAILURES+=("CTX-G1: #$STORY_NUMBER INT body $INT_CHARS chars exceeds 80,000 cap")
[ "$COMBINED"    -gt 480000 ] && FAILURES+=("CTX-G2: #$STORY_NUMBER combined bodies $COMBINED chars exceed 480,000 cap — split story")
[ "$COMBINED"    -gt 360000 ] && [ "$COMBINED" -le 480000 ] && WARNINGS+=("CTX-G2: #$STORY_NUMBER combined $COMBINED chars over soft target — consider trim")
```


## Verdict Logic

- Any gate failure → **BLOCKED** (list all failures in report)
- CTX soft-warn (combined body size between 360k and 480k chars) with no other failures → **CONDITIONAL** (emit warning, allow ship, recommend trim/reference-by-path before re-running `/super-ralph:build-story`)
- CTX hard-cap violation → **BLOCKED** — split the story and re-run `/super-ralph:design` or `/super-ralph:improve-design` before creating issues
- No failures → continue to existing Steps 3+
- With `--strict`: treat `[PERF]` missing as BLOCKED as well; also treat CTX soft-warn as BLOCKED
- With `--fix`: auto-append missing sections using templates (experimental, default off)

---

### Step 3: Dispatch Per-Story Review Agents (parallel)

## Cross-Issue Checks (from review-design.md Step 4)

### Step 4: Cross-Issue Checks (orchestrator, inline)

After all per-story review agents complete, run cross-issue consistency checks inline (no sub-agent needed).

#### CX-1: Shared File Conflicts

Check if 2+ BE sub-issues modify the same section of a shared file:

```
Shared files to check:
- $SCHEMA_FILE — section markers
- $ROUTE_REG_FILE — route registration
- $BE_DIR/src/db/test-helpers.ts — table registration
- $TYPES_FILE — type sections
- $I18N_BASE_FILE — feature keys
- $I18N_SECONDARY_FILE — feature keys
```

For each shared file, scan all BE/FE sub-issue bodies. If 2+ issues modify the same section marker:
- **PASS** if they append to the END of different sections
- **FAIL** if they modify the SAME section (conflict risk)
- **FAIL** if they insert in the middle (protocol violation)

#### CX-2: Dependency DAG Cycle-Free

Parse the EPIC body's dependency graph. Verify:
- No circular dependencies (A depends on B depends on A)
- All referenced story numbers exist in the EPIC
- Wave assignments respect dependencies (no story in Wave N depends on a story in Wave N+1)

#### CX-3: AC-to-Test 1:1 Coverage

For each STORY, count:
- Number of Gherkin scenarios in the AC section
- Number of test cases in the e2e test skeleton (STORY) + Task 0 tests (BE + FE)

**PASS** if test count >= scenario count.
**FAIL** if any scenario has no corresponding test case.

#### CX-4: Wave Plan Consistency

Verify the EPIC's wave assignments match priority:
- All P0 stories must be in Wave 1 or Wave 2 (never Wave 3+)
- All P1 stories must be in Wave 1, 2, or 3
- P2 stories can be in any wave
- No story is assigned to a wave before its dependencies

#### CX-5: Epic Doc and GitHub Issues in Sync

Compare the epic document (`docs/epics/*.md`) with the EPIC GitHub issue:
- Same number of stories in both
- Same story titles in both
- Same priority assignments in both
- Issue numbers in EPIC body are not `#??` placeholders

---

### Step 5: Classify Findings

Aggregate all findings from per-story reviews (Step 3) and cross-issue checks (Step 4). Classify each:

## Gate Tracking Table Template

| Issue | Gates | Verdict |
|-------|-------|---------|
| #N [STORY] | STORY-G1..3 | PASS / BLOCKED (reason) |
| #N [BE] | BE-G1..2 | PASS / BLOCKED (reason) |
| #N [FE] | FE-G1..2 | PASS / BLOCKED (reason) |
| #N [INT] | INT-G1..2 | PASS / BLOCKED (reason) |
| #N group | CTX-G1..3 | PASS / CONDITIONAL (soft-warn chars) / BLOCKED (over hard cap — split) |

## Brief-aware gate selection

Per-story gate selection is determined by `parse-local-epic.sh detect-story-level <epic> <N>` (local mode) or the presence of child `[BE]`/`[FE]`/`[INT]` issues (GitHub mode).

| Story level | Gates applied |
|-------------|--------------|
| brief (local) | BRIEF-G1, BRIEF-G2 |
| brief (GitHub) | BRIEF-G1, BRIEF-G2, BRIEF-G3 |
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
- **Any BRIEF-G1 failure on brief:** `CONDITIONAL` (story needs the `#### Acceptance Criteria (Outline)` section with all three category labels before expansion can run).
