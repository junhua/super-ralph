# Phase 4: Story-Planner Sub-Agent Specification

> Canonical spec for the parallel story-planner dispatch in Phase 4 of the SADD flow.
> One sub-agent per story, up to 4 concurrent. Produces STORY/BE/FE/INT sub-issue bodies.
>
> See `sadd-workflow.md` for the phase-by-phase overview, `context-budget.md` for the
> budget model, and `execution-planning.md` for the post-Phase-4 audit + waves.

## When to use this file

Read this when executing Phase 4 of `/super-ralph:design`, or when building a variant flow
that needs the same per-story planning contract.

## Contract (extracted verbatim from `/super-ralph:design` Phase 4)

### Phase 4: Story Planning (parallel, 1 Sonnet per story, max 4 concurrent)

#### Step 9: Dispatch Story-Planner Sub-Agents

For each story defined in Step 7, dispatch a story-planner sub-agent. Run up to 4 in parallel.

**Orchestrator pre-work per story:** Before dispatching each agent, identify 3-5 relevant existing file paths by Grep/Glob for related code (routes, services, components, tests).

**Model selection per story:**
- Size S or M → `sonnet` (well-defined scope, few TDD tasks, pattern-following)
- Size L → `opus` (complex schema, state machines, 6+ TDD tasks, architectural decisions)
- Size XL → must be split before dispatching (SLICE decomposition failure if reached)

**Each story-planner agent:**

```
Task tool:
  model: [sonnet for S/M, opus for L — see model selection above]
  max_turns: 40
  description: "Plan Story N: [Title]"
  prompt: |
    You are a story-planner agent. Produce complete STORY, [BE], [FE], and [INT]
    sub-issue bodies for autonomous execution.

    ## Story
    - Title: [STORY TITLE]
    - Persona: [PERSONA]
    - Action: [ACTION]
    - Outcome: [OUTCOME]
    - Priority: [P0/P1/P2]
    - Size: [S/M/L]

    ## Gherkin AC Outline (from epic)
    [PASTE THE AC OUTLINE FROM STEP 7]

    ## Epic Scope Boundaries
    - In scope: [LIST]
    - Out of scope: [LIST]

    ## Execution Context Budget (HARD CONSTRAINT)

    Each output body you produce will later be loaded by a build subagent into a
    fresh 200,000-token context window, alongside the existing files the agent
    must read to follow patterns. You MUST produce bodies small enough that the
    build subagent has working room:

    | Per output body | Target | Hard cap |
    |-----------------|--------|----------|
    | STORY body | ≤ 20,000 tok (~80,000 chars) | 30,000 tok |
    | BE body     | ≤ 30,000 tok (~120,000 chars) | 40,000 tok |
    | FE body     | ≤ 30,000 tok (~120,000 chars) | 40,000 tok |
    | INT body    | ≤ 15,000 tok (~60,000 chars) | 20,000 tok |
    | **STORY + BE + FE + INT combined** | **≤ 90,000 tok (~360,000 chars)** | **≤ 120,000 tok** |

    Rules:
    - Put EXACT code in the TDD tasks — but keep per-task code blocks focused on
      ONE layer (schema OR service OR route, not all three). If you find yourself
      writing a 500-LOC single TDD task, the story is too big — STOP and emit
      SPLIT_NEEDED (see below).
    - Reference existing files by path + line hint instead of quoting them in full.
      Example: `Service pattern: $BE_SERVICES_DIR/knowledge.ts` (path only).
    - Limit the "Relevant Existing Files" / "Patterns to Follow" list to
      **≤ 8 files**, each ≤ 500 LOC. If you need more, the story is too big.
    - Do NOT paste long existing-file excerpts. The build agent will Read them.
    - Prefer concise tables over narrative prose. Every table row is cheap;
      every prose paragraph costs ~50-100 tokens you could spend on code.

    ### If the story cannot fit

    If after your initial exploration you estimate the combined bodies will
    exceed the hard cap (120,000 tok ≈ 480,000 chars), DO NOT produce bloated
    bodies. Instead, write a split-sentinel file to the SAME run-state directory
    you would have used for the plan file (see "File Output" below), with the
    filename pattern:

    ```
    story-N-split-needed.md
    ```
    (full path: `$(git rev-parse --show-toplevel)/.claude/runs/design-[EPIC_SLUG]/story-N-split-needed.md`,
    fallback `/tmp/super-ralph-design-[EPIC_SLUG]/story-N-split-needed.md`)

    with this exact shape:

    ```markdown
    # SPLIT_NEEDED: Story N — [Title]

    ## Reason
    Estimated combined body size: ~NNN,NNN chars (over 480,000 char cap).
    Primary driver: [schema with 4 tables / page with 900 LOC of controls / etc.]

    ## Proposed split
    - Story N.a: [sub-title] — [scope]
    - Story N.b: [sub-title] — [scope]
    - (Story N.c if needed)

    ## Per-split estimate
    | Sub-story | BE body | FE body | INT body | Combined |
    |-----------|---------|---------|----------|----------|
    | N.a       | ~Xk     | ~Yk     | ~Zk      | ~Tk tok  |
    | N.b       | ~Xk     | ~Yk     | ~Zk      | ~Tk tok  |
    ```

    Then STOP — do not write a plan file for Story N. The orchestrator will
    re-dispatch the split sub-stories.

    ## Project Conventions
    - Runtime: Bun (not Node.js)
    - Language: TypeScript
    - Package manager: bun install, bun run
    - Monorepo: $BE_DIR/ (backend), $FE_DIR/ (frontend)
    - DB: Drizzle ORM, PostgreSQL
    - Tests: bun:test with describe/test/expect
    - i18n: $I18N_BASE_FILE + $I18N_SECONDARY_FILE with feature namespace keys

    ## Shared File Protocol
    - $SCHEMA_FILE — append tables in section: // ─── [Feature] ────
    - $ROUTE_REG_FILE — append route registration at END of protected routes
    - $TYPES_FILE — append types in section: // ── [Feature] Types ────
    - $I18N_BASE_FILE + $I18N_SECONDARY_FILE — add top-level key per feature
    - $BE_DIR/src/db/test-helpers.ts — append imports and tables.set() at end
    - RULE: Always APPEND to END of section. Never insert in middle.

    ## Relevant Existing Files
    [3-5 FILE PATHS PRE-SELECTED BY ORCHESTRATOR]

    ## Instructions

    Use Read, Grep, Glob to explore the relevant files and understand existing patterns.
    Then produce THREE outputs:

    ### Output 1: STORY Issue Body

    Write the full GitHub issue body for a [STORY] issue:

    ```markdown
    **Parent:** #EPIC_NUMBER

    ## User Story
    **As a** [persona],
    **I want** [action],
    **So that** [outcome].

    ## Acceptance Criteria

    Write COMPLETE Gherkin for each criterion using this format:

    ### AC-N: [Criterion name]
    Feature: [Feature name]
      Background:
        Given [shared precondition]

      Scenario: [Happy path / error / edge case name]
        Given [specific precondition]
        When [user action]
        Then [expected result]
        And [additional assertion]

    Rules:
    - Minimum 3 scenarios per story: happy path + error + edge case
    - Use concrete values ("3 items", "within 2 seconds")
    - Use specific personas (never "user")
    - Every scenario must be automatable as an e2e test

    ## Shared Contract

    Define the TypeScript types that both FE and BE will use:

    ```typescript
    // Types shared between FE and BE for this story
    // These go in $TYPES_FILE AND inform BE route types

    export interface [EntityName] {
      id: string;
      // ... all fields with types
    }

    export type [ActionPayload] = {
      // ... request body type
    };

    export type [ActionResponse] = {
      // ... response body type
    };
    ```

    ## E2E Test Skeleton

    ```typescript
    // tests/e2e/[story-slug].test.ts
    import { describe, test, expect } from "bun:test";

    describe("[Story title]", () => {
      // Map each AC scenario to a test case
      test("[AC-1 scenario name]", async () => {
        // Given: [precondition]
        // When: [action]
        // Then: [assertion]
      });
      // ... one test per scenario
    });
    ```
    ```

    ### Output 2: [BE] Sub-Issue Body

    Write the full GitHub issue body for a [BE] sub-issue:

    ```markdown
    **Parent:** #STORY_NUMBER

    ## Backend Implementation

    ### Schema Changes
    File: `$SCHEMA_FILE`
    Section: `// ─── [Feature] ────`

    ```typescript
    // EXACT code to append — no placeholders
    export const [tableName] = pgTable("[table_name]", {
      id: text("id").primaryKey().$defaultFn(() => createId()),
      // ... all columns with types, constraints, defaults
    });
    ```

    ### Service
    File: `$BE_SERVICES_DIR/[feature].ts` (Create)

    ```typescript
    // EXACT service code — no placeholders, no "implement X here"
    import { db } from "../db";
    import { [table] } from "../db/schema";

    export const [featureName]Service = {
      async list(orgId: string) {
        // ... exact implementation
      },
      async create(orgId: string, data: [Type]) {
        // ... exact implementation
      },
      // ... all methods
    };
    ```

    ### Route
    File: `$BE_ROUTES_DIR/[feature].ts` (Create)

    ```typescript
    // EXACT route code
    import { Hono } from "hono";

    export const [feature]Routes = new Hono()
      .get("/", async (c) => {
        // ... exact implementation
      })
      .post("/", async (c) => {
        // ... exact implementation
      });
    ```

    ### Route Registration
    File: `$ROUTE_REG_FILE`
    Action: APPEND to end of protected routes section

    ```typescript
    app.route("/api/[feature]", [feature]Routes);
    ```

    ### Test Helpers
    File: `$BE_DIR/src/db/test-helpers.ts`
    Action: APPEND at end

    ```typescript
    import { [table] } from "./schema";
    tables.set("[table_name]", [table]);
    ```

    ### TDD Tasks

    #### Task 0: E2E Test Skeleton (Outer RED)
    ```bash
    # Create e2e test from AC
    cat > tests/e2e/[story-slug].test.ts << 'TESTEOF'
    [EXACT TEST CODE FROM STORY AC]
    TESTEOF

    # Run — expected: FAIL (nothing implemented yet)
    bun test tests/e2e/[story-slug].test.ts
    # Expected: FAIL — 0 passed, N failed

    git add tests/e2e/[story-slug].test.ts
    git commit -m "test: add e2e tests for [story] (outer red)"
    ```

    #### Task 1: Schema + Migration
    ```bash
    # Add schema to $SCHEMA_FILE
    # [EXACT code to append — shown above in Schema Changes]

    # Write unit test
    cat > $BE_SERVICES_DIR/__tests__/[feature].test.ts << 'TESTEOF'
    import { describe, test, expect } from "bun:test";
    import { db } from "../../db";
    import { [table] } from "../../db/schema";

    describe("[feature] schema", () => {
      test("table exists and accepts inserts", async () => {
        // [EXACT test code]
      });
    });
    TESTEOF

    # Run — expected: FAIL (schema not added yet)
    cd $BE_DIR && $BE_TEST_CMD src/services/__tests__/[feature].test.ts
    # Expected: FAIL

    # Implement — add schema code
    # Run — expected: PASS
    cd $BE_DIR && $BE_TEST_CMD src/services/__tests__/[feature].test.ts
    # Expected: PASS — 1 passed

    git add $SCHEMA_FILE $BE_SERVICES_DIR/__tests__/[feature].test.ts
    git commit -m "feat([feature]): add schema and migration"
    ```

    #### Task 2: Service Layer
    [Same TDD structure: test file, run FAIL, implement, run PASS, commit]

    #### Task 3: Route Layer
    [Same TDD structure]

    #### Task 4: Route Registration + Test Helpers
    [Same TDD structure]

    ### Completion Criteria
    - [ ] `cd $BE_DIR && $BE_TEST_CMD` — 0 failures
    - [ ] `bun test tests/e2e/[story-slug].test.ts` — BE scenarios pass
    ```

    ### Output 3: [FE] Sub-Issue Body

    Write the full GitHub issue body for a [FE] sub-issue:

    ```markdown
    **Parent:** #STORY_NUMBER

    ## Frontend Implementation

    ### Mock Data (for concurrent dev without BE)
    File: `$FE_DIR/src/lib/mock/[feature].ts` (Create)

    ```typescript
    // Mock data matching the Shared Contract types
    // FE dev can start immediately — no BE dependency
    import type { [EntityName] } from "../types";

    export const mock[Feature]List: [EntityName][] = [
      {
        id: "mock-1",
        // ... realistic mock data matching schema
      },
      {
        id: "mock-2",
        // ... second item for list rendering
      },
    ];

    export const mock[Feature]Empty: [EntityName][] = [];

    export const mock[Feature]Error = {
      message: "Failed to load [feature]",
      status: 500,
    };
    ```

    ### API Client
    File: `$API_CLIENT_DIR/[feature].ts` (Create)

    ```typescript
    // EXACT API client code
    import { apiClient } from "./client";
    import type { [EntityName], [ActionPayload], [ActionResponse] } from "../types";

    export const [feature]Api = {
      async list(): Promise<[EntityName][]> {
        const res = await apiClient.get("/api/[feature]");
        return res.json();
      },
      async create(data: [ActionPayload]): Promise<[ActionResponse]> {
        const res = await apiClient.post("/api/[feature]", { json: data });
        return res.json();
      },
      // ... all methods
    };
    ```

    ### Types
    File: `$TYPES_FILE`
    Section: `// ── [Feature] Types ────`
    Action: APPEND at end of section

    ```typescript
    // ── [Feature] Types ────
    export interface [EntityName] { /* from Shared Contract */ }
    export type [ActionPayload] = { /* from Shared Contract */ };
    export type [ActionResponse] = { /* from Shared Contract */ };
    ```

    ### i18n
    File: `$I18N_BASE_FILE` — add top-level key:
    ```typescript
    [feature]: {
      title: "[Feature Title]",
      description: "[Feature description]",
      // ... all user-facing strings
      errors: {
        loadFailed: "Failed to load [feature]",
        createFailed: "Failed to create [feature]",
        // ... all error messages
      },
    },
    ```

    File: `$I18N_SECONDARY_FILE` — add matching key:
    ```typescript
    [feature]: {
      title: "[Chinese title]",
      description: "[Chinese description]",
      // ... all user-facing strings in Chinese
      errors: {
        loadFailed: "[Chinese error]",
        createFailed: "[Chinese error]",
      },
    },
    ```

    ### Components
    File: `$FE_PAGES_DIR/[path]/page.tsx` (Create)

    ```typescript
    // EXACT page component code
    "use client";
    // ... imports, hooks, JSX — complete implementation
    ```

    File: `$FE_COMPONENTS_DIR/[feature]/[Component].tsx` (Create, if needed)
    ```typescript
    // EXACT component code
    ```

    ### TDD Tasks

    #### Task 0: E2E Test — FE Scenarios (Outer RED)
    ```bash
    # Extend e2e test with FE-specific scenarios
    # [EXACT test additions]

    bun test tests/e2e/[story-slug].test.ts
    # Expected: FAIL — FE not implemented yet

    git add tests/e2e/[story-slug].test.ts
    git commit -m "test: add FE e2e scenarios for [story] (outer red)"
    ```

    #### Task 1: Types + Mock Data
    ```bash
    # [EXACT code, test, run FAIL, implement, run PASS, commit]
    ```

    #### Task 2: API Client
    ```bash
    # [EXACT code, test, run FAIL, implement, run PASS, commit]
    ```

    #### Task 3: i18n (en + zh-CN)
    ```bash
    # [EXACT i18n entries for both languages, test, commit]
    ```

    #### Task 4: Page Component
    ```bash
    # [EXACT component code, test, commit]
    ```

    ### PM Checkpoints

    | Checkpoint | When | What to Verify |
    |-----------|------|----------------|
    | CP1: Mock renders | After Task 1-2 | Component renders with mock data, layout correct |
    | CP2: i18n complete | After Task 3 | All strings display in EN and zh-CN |
    | CP3: API integrated | After BE is ready | Real data flows, loading/error states work |
    | CP4: AC pass | After all tasks | All Gherkin scenarios pass as e2e tests |

    ### Completion Criteria
    - [ ] `cd $FE_DIR && $FE_TEST_CMD` — 0 failures
    - [ ] `bun test tests/e2e/[story-slug].test.ts` — FE scenarios pass
    - [ ] i18n: both $I18N_BASE_FILE and $I18N_SECONDARY_FILE have [feature] key
    - [ ] Mock data: `$FE_DIR/src/lib/mock/[feature].ts` exists
    ```

    ### Output 4: [INT] Sub-Issue Body

    Write the full GitHub issue body for an [INT] sub-issue:

    ```markdown
    **Parent:** #STORY_NUMBER
    **Depends on:** [BE] #BE_NUMBER (merged), [FE] #FE_NUMBER (merged)

    ## Scope
    Integration and verification: swap FE mocks for real API, run Gherkin scenarios as e2e tests, verify staging preview.

    ## Gherkin User Journey (from parent [STORY])
    See parent #STORY_NUMBER — Acceptance Criteria (Gherkin) section. The 3+ scenarios in that section are the exact user journeys to verify here.

    ## Integration Tasks

    ### Task 0: Mock Swap
    **Progress check:** `! grep -rn "mock[Feature]" $FE_PAGES_DIR/[feature]`
    **Files:** Modify $FE_PAGES_DIR/[feature]/page.tsx; delete $FE_DIR/src/lib/mock/[feature].ts

    Step 1: Replace mock import with API client call. EXACT code diff:
    ```diff
    - import { mock[Feature]List } from "@/lib/mock/[feature]";
    + import { [feature]Api } from "@/lib/api/[feature]";
    ```
    Step 2: Replace usage inside component:
    ```diff
    - const data = mock[Feature]List;
    + const { data } = useQuery({ queryKey: ["[feature]"], queryFn: [feature]Api.list });
    ```
    Step 3: Delete mock file:
    ```bash
    rm $FE_DIR/src/lib/mock/[feature].ts
    ```
    Step 4: Run typecheck — Expected: PASS
    ```bash
    cd $FE_DIR && $RUNTIME run typecheck
    ```
    Step 5: Commit
    ```bash
    git add $FE_PAGES_DIR/[feature]/page.tsx
    git rm $FE_DIR/src/lib/mock/[feature].ts
    git commit -m "chore: swap [feature] mocks for real API"
    ```

    ### Task 1: Gherkin Scenarios as E2E Tests
    **Progress check:** `grep -c "test(" tests/e2e/[story-slug].test.ts` — Expected: ≥3 (one per Gherkin scenario)
    **File:** Modify tests/e2e/[story-slug].test.ts

    For each scenario in the parent [STORY] Gherkin, implement a runnable test. EXACT code for each:

    ```typescript
    test("[HAPPY] [scenario name from Gherkin]", async () => {
      // Given: [precondition from Gherkin]
      // ... concrete setup code
      // When: [action from Gherkin]
      // ... concrete action code
      // Then: [assertion from Gherkin]
      // ... concrete assertion with specific values
    });

    test("[EDGE] [scenario name]", async () => { /* exact code */ });

    test("[SECURITY] [scenario name]", async () => { /* exact code */ });
    ```

    Run: `$RUNTIME test tests/e2e/[story-slug].test.ts`
    Expected (before implementation): some FAIL
    Expected (after): PASS — 3+ passed

    Commit: `git commit -m "test: [feature] gherkin scenarios as runnable e2e"`

    ## Verification Tasks

    ### Task 2: `/super-ralph:verify` Against Staging Preview
    **Progress check:** Verification report at `.claude/runs/verify-[story-slug]/report.md`
    Step 1: Identify preview URL (Vercel/staging) from the merged PRs of [BE] and [FE]
    Step 2: Invoke verifier:
    ```bash
    /super-ralph:verify <preview-url> --story #STORY_NUMBER
    ```
    Expected: verifier returns GREEN for all 3+ Gherkin scenarios
    If RED: open `[FIX]` issue, link here, block integration PR.

    ### Task 3: Integration PR
    Push branch, open PR with:
    - Title: `int: [feature] integration and e2e`
    - Body: `Closes #INT_NUMBER\n\nCloses #STORY_NUMBER (when all sub-issues merge)\n\n## Verification Report\n[paste summary from verifier]`

    ## Completion Criteria
    - [ ] Mock file deleted
    - [ ] `$RUNTIME test tests/e2e/[story-slug].test.ts` — 0 failures, ≥3 scenarios passing
    - [ ] `/super-ralph:verify` report is GREEN
    - [ ] Integration PR merged to main/dev
    ```

    ## File Output

    Write all four outputs to a run-state file:
    `$(git rev-parse --show-toplevel)/.claude/runs/design-[EPIC_SLUG]/story-N-plan.md`
    (fallback: `/tmp/super-ralph-design-[EPIC_SLUG]/story-N-plan.md` if .claude not writable)

    Format:
    ```markdown
    # Story N: [Title]

    ## STORY Issue Body
    [Output 1]

    ## BE Sub-Issue Body
    [Output 2]

    ## FE Sub-Issue Body
    [Output 3]

    ## INT Sub-Issue Body
    [Output 4]
    ```

    NEVER ask for human input. Use Read/Grep/Glob to explore files.
    NEVER use placeholders like "implement X here" or "...".
    Every code block must be EXACT, copy-pasteable code.
```

## Constraints summary

The planner MUST:
- Never ask for human input
- Use Read/Grep/Glob to explore files
- Never use placeholders like "implement X here" or "..."
- Emit exact, copy-pasteable code
- Respect the in-prompt Execution Context Budget (see `context-budget.md` for the broader budget model)
- Emit `story-N-split-needed.md` sentinel instead of bloated bodies when over cap
