# Super-Ralph: Brief Design Mode + `/expand-story` Command

**Date:** 2026-04-19
**Status:** Draft
**Scope:** `commands/design.md`, `commands/improve-design.md`, `commands/review-design.md`, new `commands/expand-story.md`, `scripts/parse-local-epic.sh`, `skills/product-design/**`, `skills/design-review/**`, `skills/story-execution/references/phase-1-plan.md`, `README.md`, `CHANGELOG.md`

## Problem

Today `/super-ralph:design` runs the full 6-phase SADD flow for every invocation: research → epic definition → Phase 4 story-planner sub-agents producing `STORY` + `[BE]` + `[FE]` + `[INT]` bodies with full Gherkin AC, shared contracts, pre-decided implementation, and exact-code TDD tasks. That's the right output when work is ready to build — but wrong when the user is still grooming the backlog.

Backlog-grooming workflows (sprint prep, scope debate, spike scoping, vision-to-epic translation) need only a skeleton: epic framing + story titles + rough acceptance criteria. Running the full flow for that wastes tokens on BE/FE/INT bodies the team will reshape or discard, and pollutes GitHub with sub-issues that don't yet correspond to committed work.

## Goals

1. Add a `--brief` option to `/design` that produces EPIC-level planning and STORY-level skeletons (user-story line + `[HAPPY]`/`[EDGE]`/`[SECURITY]` AC bullets) — no Shared Contract, no Pre-Decided Implementation, no `[BE]`/`[FE]`/`[INT]` sub-issues.
2. Make `/improve-design` brief-aware: detect brief vs full per-story, restrict applicable change types on brief stories, and offer a clarification pointing to `/expand-story` when the user asks for edits that don't apply.
3. Add a new `/expand-story` command that promotes a single brief story (or all brief stories in an epic via `--all`) to full by running the Phase 4 story-planner for it and applying the result.
4. Make `/review-design` brief-aware: run a lite gate set on brief stories, full gates on expanded ones; mixed epics are per-story.
5. Ensure `/build-story` works unchanged on brief stories by falling through its existing `mode: standard` plan sub-agent path (fixing the local-mode hardcoded `mode: embedded` skip detection).

## Non-goals

- No bulk promotion of brief EPICs to full via a single command invocation; `/expand-story --all` iterates per-story waves.
- No changes to `/build-story`, `/e2e`, `/finalise`, `/release` command bodies. They work on brief stories via the existing plan-sub-agent path (once the local-mode fix lands).
- No migration tooling for existing full epics. Brief is a flag at design-time; it does not retroactively reshape existing work.
- No "partial brief" within a single story (e.g., brief AC but full Shared Contract). A story is either brief or full.
- No changes to `/backlog-grooming`. Users who prefer that flow can use it; `--brief` is a lower-level primitive.

## Design-level markers and detection

Detection is structural, not declarative. The HTML-comment marker on line 3 of a local epic is a hint; authoritative signals are structural (presence/absence of subsections or GitHub sub-issues).

| Mode | Epic-level marker | Story-level detection |
|------|-------------------|-----------------------|
| Local | `<!-- super-ralph: brief -->` on line 3 (after `# EPIC:` title and any `<!-- super-ralph: local-mode -->` marker) | A story is brief if its block has **no** `#### [BE]`, `#### [FE]`, or `#### [INT]` heading. Full otherwise. |
| GitHub | `brief` label on `[EPIC]` issue | A `[STORY]` is brief if it has **no** `[BE]` / `[FE]` / `[INT]` child issues (per `gh issue list --jq`). |

**Why structural:** once `/expand-story` promotes one story, other stories in the same epic remain brief. Detection must be per-story. The epic-level marker gets flipped only when every story is full (see `/expand-story --all`).

### New `parse-local-epic.sh` subcommands

```
detect-design-level <epic-file>
  → echoes "brief" | "full" | "mixed" | "not-an-epic"
    - "brief": has brief marker AND every story is brief
    - "full": no brief marker AND every story is full
    - "mixed": has brief marker but at least one story is full
    - "not-an-epic": file missing or missing "# EPIC:" heading

detect-story-level <epic-file> <N>
  → echoes "brief" | "full" | "missing"
    - "brief": story N exists, no #### [BE/FE/INT] subsections
    - "full": story N exists, has at least one of the three subsections
    - "missing": no "### Story N:" heading
```

Both subcommands implemented in POSIX awk (same style as existing subcommands).

## Brief story format (local and GitHub)

```markdown
### Story N: <Action-oriented title>

**As a** <persona>, **I want** <action>, **So that** <outcome>.

**Persona:** <X>   **Priority:** P0|P1|P2   **Size:** S|M|L   **Status:** PENDING
<!-- PR: -->
<!-- Branch: -->

#### Acceptance Criteria (Outline)

- `[HAPPY]` Given <precondition>, when <action>, then <observable outcome with concrete values>.
- `[EDGE]` Given <boundary condition>, when <action>, then <graceful handling>.
- `[SECURITY]` Given <unauthorized role>, when <action>, then <403 / "no permission" message>.

#### Notes (optional)

<free-form context: open decisions, references to past discussions, link to user feedback>
```

**Rules:**
- Minimum 3 bullets: at least one `[HAPPY]`, one `[EDGE]`, one `[SECURITY]`.
- Each bullet is a single sentence combining Given/When/Then.
- No sub-headings below `#### Notes`.
- `#### Acceptance Criteria (Outline)` heading (not `Acceptance Criteria (Gherkin)`) is the structural marker the expand flow pattern-matches on to replace with full Gherkin.

**GitHub-mode equivalent:** the `[STORY]` issue body is the block above, minus the `### Story N:` heading. The `[EPIC]` body lists stories as `- [ ] #<num> [STORY] <title>` without `[BE]`/`[FE]`/`[INT]` nesting.

## `/design --brief` workflow

### Argument parsing

Existing: `<feature-or-goal>`, `--output PATH`, `--local`.
New: `--brief` (boolean, default false).

`--brief` and `--local` are orthogonal. Matrix:

| Invocation | Epic doc | GitHub issues |
|-----------|---------|---------------|
| `/design "X"` | Full stories | `[EPIC]` + `[STORY]`+`[BE]`+`[FE]`+`[INT]` per story |
| `/design --local "X"` | Full stories | None |
| `/design --brief "X"` | Brief stories | `[EPIC]` (with `brief` label) + `[STORY]` only |
| `/design --brief --local "X"` | Brief stories | None |

### Phase changes

- **Phase 0-3 (Config, Context, Research, Epic Definition):** unchanged. The epic header (PM Summary, Scope, Personas, Dependencies, Risks, Execution Plan) is identical to full mode.
- **Phase 4 (Story Planning):** brief mode dispatches a **simplified story-planner sub-agent** (new prompt, sonnet model only, max_turns: 15) that produces ONLY the brief story block shown above. No Shared Contract. No Pre-Decided Implementation. No `[BE]`/`[FE]`/`[INT]` bodies. No context-budget audit (bodies are < 2 KB).
- **Step 10.5 (Context Budget Audit):** SKIPPED on brief. Brief bodies are trivially within budget.
- **Step 11 (Wave Assignment):** runs normally. Brief stories still have size labels (agent assigns from the AC scope) and dependencies (from the sme-brainstormer-2 tech-risk research), so waves still make sense.
- **Step 11b (Local Consolidation):** writes brief story blocks into the epic file under `## Stories`. Inserts `<!-- super-ralph: brief -->` as line 3.
- **Phase 5 (Issue Creation, GitHub mode only):** creates `[EPIC]` issue with `brief` label + one `[STORY]` per story. SKIPS `[BE]`/`[FE]`/`[INT]` creation entirely. EPIC body lists `- [ ] #<num> [STORY] <title>` without nested sub-issues.
- **Phase 6 (Review):** invokes `/review-design`, which auto-selects lite gates via `detect-design-level` (see below).

### Brief story-planner sub-agent prompt (Phase 4 branch)

```
Task tool:
  model: sonnet
  max_turns: 15
  description: "Brief plan Story N: <Title>"
  prompt: |
    You are a brief-story-planner agent. Produce ONE brief story block for backlog grooming.

    ## Story
    - Title: <TITLE>
    - Persona: <PERSONA>
    - Action: <ACTION>
    - Outcome: <OUTCOME>
    - Priority: <P0|P1|P2>
    - Size: <S|M|L>

    ## Epic Scope
    - In: <LIST>
    - Out: <LIST>

    ## Output format

    Write ONLY the block below. No TDD, no shared contract, no implementation detail.

    ```
    ### Story <N>: <Title>

    **As a** <persona>, **I want** <action>, **So that** <outcome>.

    **Persona:** <persona>   **Priority:** <P?>   **Size:** <S|M|L>   **Status:** PENDING
    <!-- PR: -->
    <!-- Branch: -->

    #### Acceptance Criteria (Outline)

    - `[HAPPY]` <one-sentence Given/When/Then with concrete values>
    - `[EDGE]` <one-sentence Given/When/Then, boundary case>
    - `[SECURITY]` <one-sentence Given/When/Then, auth case>
    ```

    Rules:
    - Exactly one `[HAPPY]`, `[EDGE]`, `[SECURITY]` bullet each (more is allowed, but all three labels MUST appear)
    - Each bullet fits on one line
    - Use concrete values ("3 items", "within 2 seconds") not vague phrases
    - Use the specific persona from the vision, never generic "user"
    - No implementation detail (no file paths, no code, no API shapes)

    Write output to:
      .claude/runs/design-<EPIC_SLUG>/story-<N>-brief.md
```

## `/expand-story <target>` workflow (new command)

### Arguments

- `<target>` (required): `#<story-issue-number>` (GitHub mode) or `docs/epics/<slug>.md#story-N` (local mode).
- `--all` (optional): expand every brief story under the containing epic. Resolves the epic from the target, iterates in waves of 4 parallel, invokes `/review-design` once at the end.

### Workflow

1. **Load config** (same as `/design`).
2. **Load skills:** `product-design`, `issue-management`.
3. **Resolve target.** For `#N`: `gh issue view` → detect `[STORY]` title and parent `[EPIC]`. For path: parse `docs/epics/<slug>.md#story-N`.
4. **Detect mode** via `parse-local-epic.sh detect-mode`.
5. **Verify story is brief:**
   ```bash
   LEVEL=$(parse-local-epic.sh detect-story-level "$EPIC_FILE" "$N")  # local
   # or: LEVEL=$(gh issue list --parent #N ... | count child [BE]/[FE]/[INT]) # github
   if [ "$LEVEL" = "full" ]; then
     echo "Story is already full. Use /improve-design to edit."; exit 0
   fi
   ```
6. **Load story context.** Local: `extract-substory` for story N. GitHub: issue body. Also load epic scope/personas/dependencies for the planner prompt.
7. **Dispatch Phase 4 story-planner sub-agent** using the exact prompt from `story-planner-spec.md` (sonnet for S/M, opus for L). Output goes to `.claude/runs/expand-<slug>/story-N-plan.md`.
8. **Context-budget audit** on the expanded plan (same thresholds as `/design` Step 10.5). If over hard cap: emit SPLIT_NEEDED sentinel and instruct user to run `/improve-design "split story N"`. Do NOT auto-split (expansion is idempotent; splitting is structural).
9. **Apply output:**
   - **Local:**
     - Replace the brief AC bullets block (`#### Acceptance Criteria (Outline)` section) with `#### Acceptance Criteria (Gherkin)` plus the full Gherkin from the planner's STORY body.
     - Append `#### Shared Contract`, `#### E2E Test Skeleton`, `#### [BE] Story N — Backend`, `#### [FE] Story N — Frontend`, `#### [INT] Story N — Integration & E2E` subsections (verbatim from planner output).
     - Remove the `#### Notes` section if the planner surfaced any open decisions as resolved in the expanded content (preserve otherwise).
   - **GitHub:**
     - Edit `[STORY]` body: replace AC bullets with full Gherkin and add Shared Contract + E2E Skeleton sections.
     - `gh issue create` `[BE]`, `[FE]`, `[INT]` sub-issues (same as `/design` Step 13).
     - Edit `[EPIC]` body checklist to nest the new sub-issues under the story.
10. **Commit:**
    ```bash
    git add docs/epics/<slug>.md  # local
    git commit -m "expand: story N of epic <slug>"
    # github mode:
    git add docs/epics/<slug>.md  # summary table reflects expansion
    git commit -m "expand: story N of epic #<epic-num>"
    ```
11. **Flip epic-level marker** if all stories are now full:
    ```bash
    if [ "$(detect-design-level $EPIC_FILE)" = "full" ]; then
      # remove the <!-- super-ralph: brief --> line
      sed -i.bak '/^<!-- super-ralph: brief -->$/d' "$EPIC_FILE" && rm "$EPIC_FILE.bak"
      git add "$EPIC_FILE"
      git commit -m "design: epic <slug> fully expanded"
    fi
    ```
    GitHub equivalent: remove `brief` label from `[EPIC]` issue when all stories have `[BE]`/`[FE]`/`[INT]` children.
12. **Invoke `/review-design`** for the newly-full story (full gate set). Report verdict in final output.

### `--all` flow

Identical per-story logic, but iterates:
- Step 6: collect all story numbers where `detect-story-level = brief`.
- Steps 7-10: dispatch in waves of 4 parallel (matching `/design` Phase 4 concurrency).
- Step 11: always runs at the end (since all stories become full).
- Step 12: invokes `/review-design` once on the epic.

### Final report shape

```markdown
# Story Expanded: <Epic Title>

## Stories Expanded
| # | Title | Size | Verdict |
|---|-------|------|---------|
| 3 | Vendor list page | M | READY |

## Epic Status
Brief → Full (all stories expanded) | Still mixed (N brief remaining)

## Review Verdict
READY | CONDITIONAL | BLOCKED

## Next
- /super-ralph:build-story docs/epics/<slug>.md#story-3
```

## `/improve-design` changes

### Detection

Before dispatching the feedback-interpreter sub-agent, compute:

```bash
if [ "$MODE" = "local" ]; then
  DESIGN_LEVEL=$(parse-local-epic.sh detect-design-level "$TARGET")
else
  # github: check 'brief' label presence on the EPIC issue
  HAS_BRIEF_LABEL=$(gh issue view "$TARGET" --json labels --jq '.labels[] | select(.name=="brief") | .name' | head -1)
  DESIGN_LEVEL=$([ -n "$HAS_BRIEF_LABEL" ] && echo "brief" || echo "full")
fi
```

Pass `$DESIGN_LEVEL` into both the feedback-interpreter and apply-change sub-agent prompts.

### Allowed change types by level

| Change type | Brief story | Full story |
|-------------|-------------|------------|
| ADD_STORY | ✓ (as brief) | ✓ (as full) |
| REMOVE_STORY | ✓ | ✓ |
| SPLIT_STORY | ✓ (both halves brief) | ✓ (both halves full) |
| MERGE_STORIES | ✓ | ✓ |
| EDIT_AC | ✓ (bullets) | ✓ (Gherkin) |
| EDIT_TDD | ✗ — interpreter returns clarification | ✓ |
| EDIT_SHARED_CONTRACT | ✗ — interpreter returns clarification | ✓ |
| EDIT_SCOPE | ✓ | ✓ |
| RE_WAVE | ✓ | ✓ |
| EDIT_METADATA | ✓ | ✓ |

When the interpreter maps feedback to a disallowed change type on a brief story, it returns:

```
clarification_needed: true
clarification_question: "This story is brief — it has no TDD tasks yet. Expand it first with: /super-ralph:expand-story <target>. Then re-run improve-design."
```

### Mixed epics

If an epic contains both brief and full stories, `/improve-design` routes per-story: a change targeting story 3 (brief) gets brief rules; a change targeting story 5 (full) gets full rules. The epic-level marker is advisory; per-story detection is authoritative.

### `ADD_STORY` default level

- **Pure brief epic** (`DESIGN_LEVEL=brief`) → new story added as brief.
- **Pure full epic** (`DESIGN_LEVEL=full`) → new story added as full (runs the Phase 4 story-planner inline, same as `/design`).
- **Mixed epic** (`DESIGN_LEVEL=mixed`) → default is **brief** (we assume active grooming). User can override with `"... as full"` in the prompt; interpreter returns a clarification suggesting `/expand-story` afterward if they don't want full expansion inline.

No new change type needed. `ADD_STORY` details include `level: brief | full` so the apply-change agent picks the right template.

## `/review-design` changes

### Gate selection per story

Before dispatching per-story review agents (Step 3), run:

```bash
for N in $STORY_NUMBERS; do
  LEVEL=$(detect-story-level "$EPIC_FILE" "$N")   # or github equivalent
  if [ "$LEVEL" = "brief" ]; then
    GATES_FOR_N="STORY-G1 BRIEF-G1 BRIEF-G2 BRIEF-G3"
  else
    GATES_FOR_N="STORY-G1 STORY-G2 STORY-G3 BE-G1 BE-G2 FE-G1 FE-G2 INT-G1 INT-G2 CTX-G1 CTX-G2 CTX-G3"
  fi
done
```

Cross-issue checks (CX-1..CX-5) always run, but some apply differently to brief:
- **CX-1** (persona consistency across stories) — applies to brief and full
- **CX-2** (shared contract consistency across stories) — SKIPPED if ALL stories are brief; runs when any story is full
- **CX-3** (wave DAG validity) — applies to both
- **CX-4** (no duplicate story titles/personas) — applies to both
- **CX-5** (i18n key namespace uniqueness across FE sub-issues) — SKIPPED if no story has FE sub-issue (pure brief epics have no FE)

### New gates (add to `gate-catalog.md`)

```markdown
#### BRIEF Gates (apply to brief stories only)

| Gate | Rule | How to check |
|------|------|--------------|
| BRIEF-G1 | Body contains `#### Acceptance Criteria (Outline)` section with ≥3 bullets, each prefixed with ` [HAPPY]`, ` [EDGE]`, or ` [SECURITY]`, and each of the three labels appears at least once | `grep -q "^#### Acceptance Criteria (Outline)"` AND `grep -c "^- \`\[HAPPY\]\`"` ≥ 1 AND `grep -c "^- \`\[EDGE\]\`"` ≥ 1 AND `grep -c "^- \`\[SECURITY\]\`"` ≥ 1 |
| BRIEF-G2 | Body does NOT contain `#### Shared Contract`, `#### Pre-Decided Implementation`, `#### [BE]`, `#### [FE]`, or `#### [INT]` subsections (keeps brief brief) | `! grep -E "^#### (Shared Contract\|Pre-Decided Implementation\|\[BE\]\|\[FE\]\|\[INT\])" <body>` |
| BRIEF-G3 | GitHub mode: `[STORY]` issue has no `[BE]`/`[FE]`/`[INT]` child issues | `gh issue list --search "Parent: #<N>"` returns no results with `[BE]/[FE]/[INT]` titles |
```

### Verdict classification

Brief epics cannot yield a READY-for-build verdict (build requires TDD); instead:
- All brief gates pass → `READY FOR EXPAND` (not `READY`). Final report lists `/expand-story` commands in wave order instead of `/build-story`.
- Any BRIEF-G failure → `CONDITIONAL` with fix guidance.
- CX-1/CX-3/CX-4 Critical failure → `BLOCKED`.

Mixed epics yield a hybrid verdict: per-story "ready for build" or "ready for expand" commands in the final report.

## `/build-story` local-mode fix

### Current behavior (bug for brief)

`skills/story-execution/references/phase-1-plan.md` line 14:

> "Local mode (`$MODE = local`): TDD tasks are already in `$STORY_DIR/be.md` and `$STORY_DIR/fe.md` (written in Step 0b). Write `$STORY_DIR/plan-result.md` with … `mode: embedded`."

This is hardcoded. For a brief story, `extract-substory story-N be` returns empty, `be.md` would be an empty file, and the build sub-agent would fail.

### Fix

Change the local-mode skip-detection to check file presence + non-empty:

```
Local mode:
1. parse-local-epic.sh extract-substory <epic> <N> story → $STORY_DIR/story.md
2. parse-local-epic.sh extract-substory <epic> <N> be    → $STORY_DIR/be.md (may be empty)
3. parse-local-epic.sh extract-substory <epic> <N> fe    → $STORY_DIR/fe.md (may be empty)
4. parse-local-epic.sh extract-substory <epic> <N> int   → $STORY_DIR/int.md (may be empty)
5. If be.md AND fe.md are both non-empty → mode: embedded, skip plan sub-agent.
6. Else → mode: standard, proceed with plan sub-agent dispatch (same as GitHub brief path).
```

`extract-substory` needs to tolerate missing subsections — current behavior is "extract the section matching the label or empty". Confirm by reading the script; add a test if ambiguous.

The plan sub-agent dispatch in standard mode already supports local stories (it reads `context.md` which has the full story block). No further changes needed to the standard-mode prompt.

## Command file changes

### `commands/design.md`

Add `--brief` to the argument spec and the `allowed-tools` block is unchanged. Insert a "Brief mode" subsection after the existing `--local` documentation:

```markdown
- **--brief** (optional, boolean): Produce a brief epic (EPIC header + story skeletons with bulleted AC). SKIPS Phase 4 full story-planners, Step 10.5 context-budget audit, and `[BE]`/`[FE]`/`[INT]` sub-issue creation. Combines with `--local`. Default: false.

When `--brief` is set:
- Phase 4 dispatches brief-story-planner sub-agents (prompt in `skills/product-design/references/sadd-workflow.md` § Phase 4b).
- Step 10.5 (context-budget audit) is skipped.
- Phase 5 creates `[EPIC]` (with `brief` label) + `[STORY]` issues only. No `[BE]`/`[FE]`/`[INT]`.
- Step 11b (local consolidation) inserts `<!-- super-ralph: brief -->` as line 3 of the epic file.
- Phase 6 (review) uses lite gates via `/review-design`'s auto-detection.
```

### `commands/improve-design.md`

Insert `DESIGN_LEVEL` detection immediately after Phase 0a target resolution:

```
### Phase 0b: Detect design level
DESIGN_LEVEL=$(parse-local-epic.sh detect-design-level "$TARGET")  # local
# or check 'brief' label for github mode
```

Pass `$DESIGN_LEVEL` into the feedback-interpreter prompt and the apply-change prompts. Document the change-type matrix in a new "Design Level Rules" section.

### `commands/review-design.md`

No argument changes. Document the per-story gate selection in a new "Brief-Aware Gate Selection" section, referencing `gate-catalog.md` for the BRIEF-G definitions.

### `commands/expand-story.md` (new)

Full workflow (steps 1-12 above) + final report format. Reuses `skills/product-design/references/story-planner-spec.md` verbatim for Phase 4 sub-agent dispatch.

## Skill reference changes

### `skills/product-design/SKILL.md`

Add a "Brief mode" subsection under "The Outside-In Pipeline":

```markdown
## Brief Mode

`/super-ralph:design --brief` produces an EPIC with brief story skeletons (bulleted AC, no TDD, no sub-issues). Use for backlog grooming, sprint prep, or scope debates. Promote individual stories to full via `/super-ralph:expand-story #<story>`.

Brief vs full is per-story (detected structurally). Mixed epics are supported.
```

### `skills/product-design/references/sadd-workflow.md`

Add "Phase 4b: Brief Story Planning" after Phase 4. Document the simplified sub-agent dispatch, the brief story block format, and the skip of Step 10.5.

### `skills/product-design/references/epic-template.md`

Add a "Brief Story Template" section after the full story template, showing the bulleted AC format.

### `skills/product-design/references/story-template.md`

Add a "Brief Story Format" section at the top with the full bullet shape.

### `skills/design-review/SKILL.md`

Add a "Brief-Aware Review" subsection documenting per-story gate selection.

### `skills/design-review/references/gate-catalog.md`

Add BRIEF-G1..G3 gates (spec above). Update the "Verdict" section to mention `READY FOR EXPAND`.

### `skills/story-execution/references/phase-1-plan.md`

Replace the hardcoded local-mode `mode: embedded` block with the "file presence + non-empty" check above.

## Script changes

### `scripts/parse-local-epic.sh`

Add two new subcommands:

```bash
detect-design-level() {
  local epic="$1"
  [ -f "$epic" ] || { echo "not-an-epic"; return; }
  grep -q "^# EPIC:" "$epic" || { echo "not-an-epic"; return; }
  local has_marker=0
  grep -q "^<!-- super-ralph: brief -->" "$epic" && has_marker=1

  local all_brief=1 all_full=1
  while IFS= read -r n; do
    level=$(detect-story-level "$epic" "$n")
    [ "$level" = "full" ] && all_brief=0
    [ "$level" = "brief" ] && all_full=0
  done < <(list-stories "$epic" | awk '{print $1}' | sed 's/^story-//')

  if [ $has_marker -eq 1 ] && [ $all_brief -eq 1 ]; then echo "brief"; return; fi
  if [ $has_marker -eq 0 ] && [ $all_full -eq 1 ]; then echo "full"; return; fi
  echo "mixed"
}

detect-story-level() {
  local epic="$1" n="$2"
  extract-story "$epic" "$n" > /tmp/.sr-story-$$.md 2>/dev/null || { echo "missing"; return; }
  if grep -qE "^#### (\[BE\]|\[FE\]|\[INT\]) Story $n" /tmp/.sr-story-$$.md; then
    echo "full"
  else
    echo "brief"
  fi
  rm -f /tmp/.sr-story-$$.md
}
```

Written in POSIX awk/shell to match existing conventions.

## Testing

Add tests under `test/` (directory already exists):

- `test/brief-design.test.sh` — dispatches `/design --brief "dummy feature"` on a fixture repo, asserts epic file has brief marker + bulleted AC + no TDD.
- `test/brief-design-github.test.sh` — same but without `--local`; asserts `[EPIC]` has `brief` label and no `[BE]`/`[FE]`/`[INT]` sub-issues were created.
- `test/expand-story.test.sh` — on a brief epic fixture, runs `/expand-story`, asserts Gherkin replaces bullets, sub-sections are added, epic marker flips after all stories expand.
- `test/detect-level.test.sh` — unit tests for `detect-design-level` and `detect-story-level` on fixture files (pure brief, pure full, mixed).
- `test/improve-design-brief.test.sh` — runs `/improve-design "edit TDD in story 2"` on a brief epic, asserts clarification is returned, no edits applied.
- `test/review-design-brief.test.sh` — runs `/review-design` on a brief epic, asserts BRIEF-G gates run + `READY FOR EXPAND` verdict.
- `test/build-story-brief-local.test.sh` — integration test: on a brief local epic, runs `/build-story docs/epics/<slug>.md#story-1`, asserts Phase 1 picks `mode: standard` (not `embedded`) and plan sub-agent runs.

## Documentation

- `README.md` — add `--brief` to the `/design` arg table, add `/expand-story` to the command list, add a "Brief Design Flow" section with a minimal example.
- `CHANGELOG.md` — entry for `0.14.0`:
  ```
  ## 0.14.0 — Brief design mode + /expand-story
  - Added `--brief` flag to `/design` for backlog-grooming output (EPIC + STORY skeletons, bulleted AC, no BE/FE/INT).
  - Added `/expand-story <target> [--all]` command to promote brief stories to full via the Phase 4 story-planner.
  - Made `/improve-design` brief-aware: restricts change types on brief stories, redirects EDIT_TDD/EDIT_SHARED_CONTRACT to `/expand-story`.
  - Added BRIEF-G1..G3 gates to `/review-design`; added `READY FOR EXPAND` verdict for pure brief epics.
  - Fixed `/build-story` local-mode to fall through to `mode: standard` when TDD subsections are empty (previously hardcoded to `mode: embedded`).
  ```

## Rollout and risk

- **Backwards-compatible.** Existing `/design`, `/improve-design`, `/review-design`, `/build-story` flows work identically when `--brief` is absent. The only functional change to existing flows is the local-mode skip-detection fix in `phase-1-plan.md`, which is a strict improvement (it was a latent bug — if a full local epic somehow had empty `be.md`/`fe.md`, the build would fail; now it falls through to standard plan).
- **No migration needed.** Existing full epics have no brief marker and every story has `[BE]`/`[FE]`/`[INT]` subsections → `detect-design-level = full` → current behavior.
- **Risk: brief-style drift.** If a user manually edits a brief story to add a Shared Contract, `detect-story-level` still says `brief` (no `[BE]`/`[FE]`/`[INT]` subsection). BRIEF-G2 catches this at review time.
- **Risk: `/expand-story` flakiness.** The Phase 4 story-planner can emit SPLIT_NEEDED for stories that turn out too big when expanded. We don't auto-split (expansion is idempotent; splitting is a structural change). Users get a clear error pointing to `/improve-design "split story N"`.
- **Token savings:** a brief `/design` run is ~5-10x cheaper than a full run (sonnet only, short prompts, no context-budget audit, no sub-issue creation).

## Open questions

None. Design is ready for implementation plan.
