---
name: brainstorm
description: "Brainstorm product and feature improvements with autonomous CTO/CPO/CAIO perspectives and agent-native enterprise expertise"
argument-hint: "<topic> [--scope product|module|feature] [--output PATH]"
allowed-tools: ["Bash(git:*)", "Bash(gh:*)", "Read", "Write", "Glob", "Grep", "Task", "WebSearch", "WebFetch"]
---

# Super-Ralph Brainstorm Command

Autonomous, subagent-driven brainstorming for improving ForthAI Work's usability and usefulness. Dispatches parallel research agents to gather competitive intelligence and agent tech landscape, then runs CPO, CTO, and CAIO brainstormers to analyze from their perspectives. Synthesizes into ranked, opinionated, actionable recommendations.

**This command is fully autonomous.** Do NOT ask the user for input at any point. Make all decisions via research + SME agents.

## Arguments

Parse the user's input for:
- **Topic** (required): What to brainstorm — a module name, feature area, product question, pain point, or new idea
- **--scope** (optional): Force scope to `product`, `module`, or `feature` (auto-detected if omitted)
- **--output** (optional): Output path (default: `docs/brainstorms/YYYY-MM-DD-<slug>.md`)

## Workflow

Execute these steps in order. **Do NOT ask the user for input at any point.** Make all decisions autonomously using the research + SME pattern.

### Step 0: Load Project Config

Read `.claude/super-ralph-config.md` to load project-specific values. If the file does not exist, stop and tell the user to run `/super-ralph:init`.

Extract these values for use in all subsequent steps:
- `$REPO` — GitHub repo (e.g., `Forth-AI/work-ssot`)
- `$ORG` — GitHub org
- `$PROJECT_NUM` — Project board number (or `none`)
- `$PROJECT_ID` — Project board GraphQL ID
- `$STATUS_FIELD_ID` — Status field ID
- `$STATUS_TODO` / `$STATUS_IN_PROGRESS` / `$STATUS_PENDING_REVIEW` / `$STATUS_SHIPPED`
- `$BE_DIR` — Backend directory
- `$SCHEMA_FILE` — Schema file path
- `$ROUTE_REG_FILE` — Route registration file
- `$BE_SERVICES_DIR` — Services directory
- `$BE_ROUTES_DIR` — Routes directory
- `$BE_TEST_CMD` — Backend test command
- `$FE_DIR` — Frontend directory
- `$TYPES_FILE` — Types file path
- `$API_CLIENT_DIR` — API client directory
- `$I18N_BASE_FILE` — Primary i18n file
- `$I18N_SECONDARY_FILE` — Secondary i18n file (may be blank)
- `$FE_PAGES_DIR` — Pages directory
- `$FE_COMPONENTS_DIR` — Components directory
- `$FE_TEST_CMD` — Frontend test command
- `$APP_URL` — Production app URL
- `$RUNTIME` — Runtime (bun/node)

---

### Step 1: Load Brainstorming Skill

Invoke the `super-ralph:product-brainstorm` skill. Follow its methodology, personas, and quality checks.

Proceed IMMEDIATELY to Step 2.

### Step 2: Detect Scope and Build Topic Brief

1. Determine brainstorming scope from the topic:
   - Check if it matches a module name from CLAUDE.md's Functional Modules table → `module`
   - Check if it references a specific feature, workflow, or UI element → `feature`
   - Check if it's a broad product question or strategic direction → `product`

2. Build a topic brief (internal, not output):
   - Scope: product / module / feature
   - Module(s) involved (if applicable)
   - Key personas affected
   - Initial hypothesis about what to investigate

Proceed IMMEDIATELY to Step 3.

### Step 3: Gather Product Context

Read product documentation to build full context:

1. Read `docs/vision.md` — product vision, personas, principles, non-goals
2. Read `docs/roadmap.md` — current phase, shipped features, planned work
3. Read `docs/architecture.md` — system boundaries, services, tech stack
4. Read `CLAUDE.md` — functional modules table, team structure

If the topic maps to a specific module or feature, also:

5. Scan related schema: Grep `$SCHEMA_FILE` for module keywords
6. Scan related pages: Glob `$FE_PAGES_DIR/<module>/**` for existing UI
7. Scan related routes: Grep `$BE_DIR/src/` for module route files
8. Check related i18n: Grep `$I18N_BASE_FILE` for module translations
9. Check GitHub issues: `gh issue list --repo $REPO --search "<topic keywords>" --limit 15 --json number,title,labels,state`

Proceed IMMEDIATELY to Step 4.

### Step 4: Dispatch Research Agents

Launch 3 research agents in parallel:

1. **Market & Competitor Research Agent** (model: haiku, max_turns: 15):
   - Search for how leading enterprise tools (Salesforce, SAP, NetSuite, HubSpot, Rippling, Ramp) handle this area
   - Search for modern/AI-native competitors doing this differently
   - Identify proven UX patterns and differentiation opportunities
   - Return: competitor approaches, UX patterns, market gaps

2. **Agent & AI Technology Research Agent** (model: haiku, max_turns: 15):
   - Search for latest LLM/agent capabilities relevant to the topic (tool use, multi-agent, planning, memory)
   - Search for known limitations and failure modes in this domain
   - Search for real-world AI enterprise applications in this area
   - Return: what's possible now, what's coming, what's unreliable, examples

3. **Codebase & Product State Analysis Agent** (model: sonnet, max_turns: 20):
   - Analyze the current implementation state from the code gathered in Step 3
   - Map the existing user flows (page structure, components, API endpoints)
   - Identify gaps between what's built and what the vision/roadmap promises
   - Check recent git history for this area: `git log --oneline -20 -- <relevant-paths>`
   - Return: current state, gaps, recent momentum, technical debt signals

Wait for all 3 to complete. Compile their findings into a research brief.

Proceed IMMEDIATELY to Step 5.

### Step 5: Dispatch Executive Brainstormers

Launch 3 SME brainstormer agents in parallel (Task tool, model: sonnet), each wearing a different executive hat:

**Agent 1 — CPO (Chief Product Officer):**
```
You are the Chief Product Officer brainstorming improvements for [topic].

Your lens: user empathy, product-market fit, and usability.

Context:
- Product vision and personas: [from vision.md]
- Current state of this area: [from codebase analysis]
- Competitor approaches: [from market research]
- GitHub issues/feedback: [from issue search]

Analyze and provide:
1. User journey mapping: What's the user actually trying to do? Where do they get stuck?
2. Usability gaps: What takes too many clicks, causes confusion, or requires training?
3. Feature prioritization: What's P0 (must fix/build), P1 (should have), P2 (nice to have)?
4. Competitive positioning: Where do we lag competitors? Where can we leap ahead?
5. Top 3 specific recommendations with rationale

Be concise, opinionated, and specific. No vague advice. Every recommendation must describe a concrete change.
```

**Agent 2 — CTO (Chief Technology Officer):**
```
You are the Chief Technology Officer brainstorming improvements for [topic].

Your lens: technical feasibility, architecture, scalability, and simplicity.

Context:
- System architecture: [from architecture.md]
- Current implementation: [from codebase analysis]
- Tech stack: [from CLAUDE.md]
- Recent changes: [from git history]

Analyze and provide:
1. Architecture assessment: Is the current structure right for this feature area?
2. Complexity audit: What's over-engineered? What's under-built? What can be removed?
3. Build vs. integrate: Should any of this be a third-party integration instead of custom?
4. Scalability concerns: What breaks at 10x users/data?
5. Top 3 specific recommendations with rationale

Be concise, opinionated, and specific. Prefer simpler solutions. Flag anything that's engineering theater (complex but doesn't serve users).
```

**Agent 3 — CAIO (Chief AI Officer):**
```
You are the Chief AI Officer brainstorming improvements for [topic].

Your lens: agent-native design, AI capabilities and limitations, trust and transparency.

Context:
- Product vision for AI/agents: [from vision.md]
- Current agent capabilities in this area: [from codebase analysis]
- Latest agent technology: [from AI tech research]
- Agent-native patterns: [from references/agent-native-patterns.md]

Analyze and provide:
1. Agent-native assessment: Is this feature truly agent-native, or a chatbot bolted onto forms?
2. Human-in-the-loop design: Where on the autonomy spectrum should each action be?
3. Capability vs. aspiration gap: What does the feature promise vs. what current AI can deliver?
4. Trust and transparency: Will enterprise users trust the agent here? What's missing?
5. Top 3 specific recommendations with rationale

Be concise, opinionated, and specific. Call out AI theater (agent wrappers that add latency without value). Reference real agent capabilities and limitations.
```

Wait for all 3 to complete.

Proceed IMMEDIATELY to Step 6.

### Step 6: Synthesize and Rank

Synthesize the three executive perspectives:

1. **Convergence** — Where do 2+ executives agree? These are high-confidence recommendations.
2. **Tensions** — Where do executives disagree? (e.g., CPO wants a feature, CTO says it's too complex, CAIO says the AI isn't ready). Resolve with evidence — if unresolvable, present the tension honestly.
3. **Unique insights** — Strong recommendations from one executive that others didn't address.

Rank all recommendations by:
- **Impact**: How much does this improve usability or usefulness?
- **Feasibility**: Can we build this with current team and technology?
- **Urgency**: Is this blocking users or losing competitive ground now?

Produce a final ranked list of 5-8 recommendations.

Proceed IMMEDIATELY to Step 7.

### Step 7: Write Brainstorm Document

Create the output document:

1. Create `docs/brainstorms/` directory if it does not exist
2. Write the brainstorm document to the output path

**Document structure:**

```markdown
# Brainstorm: [Topic]

**Date:** YYYY-MM-DD
**Scope:** product / module / feature
**Module(s):** [if applicable]

## Context

[3-5 sentences: product state, current implementation, what prompted this brainstorm]

## Research Summary

### Market & Competitors
[3-5 bullet points: key findings from competitor research]

### Agent Technology Landscape
[3-5 bullet points: relevant AI capabilities and limitations]

### Current Product State
[3-5 bullet points: what exists, gaps, recent momentum]

## Executive Perspectives

### CPO — Product & Usability
[Top 3 insights from the CPO brainstormer, each with a concrete action]

### CTO — Architecture & Feasibility
[Top 3 insights from the CTO brainstormer, each with a concrete action]

### CAIO — AI & Agent Design
[Top 3 insights from the CAIO brainstormer, each with a concrete action]

## Synthesized Recommendations

[Ranked list of 5-8 recommendations, each with:]

### 1. [Recommendation title]
**Impact:** high/medium | **Feasibility:** high/medium/low | **Urgency:** now/next/later
[2-3 sentences: what to do, why, and expected outcome]
**Consensus:** [which executives agreed and any tensions]
**Next step:** [specific action — design epic, file issue, prototype, research further]

### 2. [Recommendation title]
...

## Open Questions

[2-4 questions that emerged but couldn't be resolved — things to user-test, research deeper, or validate with data]

## Suggested Next Steps

[Concrete actions, referencing super-ralph commands where applicable:]
- `/super-ralph:design "[recommendation]"` for recommendations ready to become epics
- `/super-ralph:repair #N` for usability fixes to existing features
- Further brainstorming on unresolved open questions
```

3. Commit: `git add docs/brainstorms/<file> && git commit -m "brainstorm: [topic]"`

### Step 8: Report

Output to the user:
1. Path to the brainstorm document
2. Top 3 recommendations (one-liner each)
3. Key tension or open question that emerged
4. Suggested immediate next step

## Critical Rules

- **NEVER ask the user for input.** Use research + SME agents for all decisions.
- **All three executive perspectives are mandatory.** CPO, CTO, CAIO — never skip one.
- **Research before brainstorming.** Always dispatch research agents (Step 4) before executive brainstormers (Step 5). Brainstormers need evidence.
- **Every recommendation must be specific.** "Improve the UX" is not a recommendation. "Replace the 7-field expense form with a receipt-upload flow where the agent extracts and pre-fills all fields" is a recommendation.
- **Be opinionated.** The document takes stances. It does not present "options to consider."
- **Apply the simplicity check.** At least one recommendation should be about removing or simplifying, not adding.
- **Call out AI theater.** If a feature wraps CRUD in a chat bubble without adding agent value, say so.
- **Ground in evidence.** Every claim references research findings, codebase state, or competitive analysis.
