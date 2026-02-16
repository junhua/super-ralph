---
name: design
description: "Create epics and user stories with BDD acceptance criteria from product vision, business goals, or user feedback"
argument-hint: "<feature-or-goal> [--output PATH]"
allowed-tools: ["Bash(git:*)", "Read", "Write", "Glob", "Grep", "Task", "WebSearch", "WebFetch"]
---

# Super-Ralph Design Command

Translate product vision, business goals, or user feedback into structured epics with user stories and BDD acceptance criteria. Produces artifacts that feed directly into `/super-ralph:plan` for implementation.

## Arguments

Parse the user's input for:
- **Feature or goal description** (required): What to design — can be a feature idea, business goal, user feedback, or OKR
- **--output** (optional): Output path (default: `docs/epics/YYYY-MM-DD-<slug>.md`)

## Workflow

Execute these steps in order. **Do NOT ask the user for input at any point.** Make all decisions autonomously using the research + SME pattern.

### Step 1: Load Product Design Skill

Invoke the `super-ralph:product-design` skill. Follow its instructions for epic structure, story format, and acceptance criteria.

### Step 2: Gather Product Context

Read product documentation to understand vision, architecture, and current state:

1. Read `docs/vision.md` — product vision, target users, core principles, non-goals
2. Read `docs/roadmap.md` — current phase, what's done, what's planned
3. Read `docs/architecture.md` — system boundaries, services, tech stack
4. Read `docs/brand-cn.md` (if exists) — terminology glossary, bilingual considerations
5. Read `CLAUDE.md` — project conventions, development patterns
6. Use Glob/Grep to scan for existing epics in `docs/epics/` and plans in `docs/plans/`

### Step 3: Research and Brainstorm

Launch agents in parallel:

1. **Dispatch research-agent** (Task tool, subagent_type: general-purpose, model: haiku):
   - Search web for UX patterns, competitor approaches, and best practices relevant to the feature
   - Search codebase for existing related code, tests, and data models
   - Return findings with source URLs

2. **Dispatch 2-3 sme-brainstormer agents** (Task tool, subagent_type: general-purpose) in parallel:
   - Agent 1 focus: "User experience — what stories would delight the target personas? What are the key user journeys?"
   - Agent 2 focus: "Scope and priority — what's P0 vs P1 vs P2? What should be explicitly excluded?"
   - Agent 3 focus (if complex): "Risks and dependencies — what could block this? What existing capabilities are prerequisites?"

3. Synthesize findings from all agents.

### Step 4: Define Epic Scope

Based on research and brainstorming:

1. Define the epic's business context and success metrics
2. Identify the personas involved (from product vision)
3. Set scope boundaries (in scope / out of scope)
4. List dependencies on existing capabilities
5. Identify risks with mitigation strategies

### Step 5: Write Stories with Acceptance Criteria

For each story in the epic:

1. Write in "As a [persona], I want [action], so that [outcome]" format
2. Assign priority (P0/P1/P2) and complexity (S/M/L/XL)
3. Write BDD acceptance criteria (Given/When/Then):
   - At minimum: happy path + one validation error + one system error
   - Include edge cases for complex stories
   - Use concrete values, not vague terms
4. Generate e2e test skeleton from the acceptance criteria
5. Add technical notes if architecture implications exist

### Step 6: Validate the Epic

Dispatch a sme-brainstormer agent (Task tool, sonnet model) to review the epic:

```
Review this epic for completeness and quality:
1. Are success metrics measurable?
2. Does every story have a clear persona and outcome?
3. Are acceptance criteria specific enough to automate as e2e tests?
4. Is scope well-bounded (clear in/out)?
5. Are P0 stories truly must-have?
6. Do stories follow a logical dependency order?
7. Is the epic sized appropriately (not too large)?
```

Fix any issues identified.

### Step 7: Write Output

1. Create `docs/epics/` directory if it does not exist
2. Write the epic to the output path using the epic template from `${CLAUDE_PLUGIN_ROOT}/skills/product-design/references/epic-template.md`
3. Commit: `git add docs/epics/<file> && git commit -m "epic: [title]"`

### Step 8: Report

Output:
1. Path to the epic file
2. Summary: number of stories, P0/P1/P2 breakdown, total acceptance criteria count
3. Suggested next steps:
   - `/super-ralph:plan --story docs/epics/<file>#story-1` for the first P0 story
   - Or `/super-ralph:plan --story docs/epics/<file>#story-1,story-2` for multiple independent stories

## Critical Rules

- **NEVER ask the user for input** during epic creation. Use research + SME agents for all decisions.
- **Every acceptance criterion must be automatable.** If it can't be expressed as an e2e test, rewrite it.
- **Use product vision personas.** Never write "As a user" — always use specific personas from the vision doc.
- **Respect non-goals.** If the vision doc says something is out of scope, the epic must not include it.
- **Concrete over vague.** "Shows 3 templates" not "shows templates." "Within 2 seconds" not "quickly."
- **Stories must be independently plannable.** Each story should be deliverable via one `/super-ralph:plan` invocation.
