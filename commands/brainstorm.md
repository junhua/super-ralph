---
name: brainstorm
description: "Brainstorm product and feature improvements with autonomous CTO/CPO/CAIO perspectives and agent-native enterprise expertise"
argument-hint: "<topic> [--scope product|module|feature] [--output PATH]"
allowed-tools: ["Bash(git:*)", "Bash(gh:*)", "Read", "Write", "Glob", "Grep", "Task", "WebSearch", "WebFetch"]
---

# Super-Ralph Brainstorm Command

Autonomous, subagent-driven brainstorming for improving the product's usability and usefulness. Dispatches parallel research agents (market + agent-tech + codebase state), then runs CPO, CTO, and CAIO SME brainstormers to analyze from their perspectives. Synthesizes into ranked, opinionated, actionable recommendations.

**This command is fully autonomous.** Do NOT ask the user for input at any point. Make all decisions via research + SME agents.

## Arguments

- **Topic** (required): What to brainstorm — a module name, feature area, product question, pain point, or new idea.
- **`--scope`** (optional): Force scope to `product`, `module`, or `feature` (auto-detected if omitted).
- **`--output`** (optional): Output path (default: `docs/brainstorms/YYYY-MM-DD-<slug>.md`).

## Workflow

Execute the 7-step brainstorm flow defined by the `super-ralph:product-brainstorm` skill.

### Step 0: Load Project Config & Skill

Read `.claude/super-ralph-config.md` to load every `$VARIABLE` used by the skill and its references (same set as `/super-ralph:design`).

Invoke the `super-ralph:product-brainstorm` skill for the methodology, analytical lenses, and agent-native patterns.

### Step 1: Execute the 7-Step Brainstorm Flow

Follow `${CLAUDE_PLUGIN_ROOT}/skills/product-brainstorm/references/brainstorm-flow.md`:

1. Detect scope and build topic brief (product / module / feature)
2. Gather product context (vision, roadmap, architecture, CLAUDE.md, related code + issues)
3. Dispatch 3 research agents in parallel (market/competitor, AI/agent tech, codebase/product state)
4. Dispatch 3 executive brainstormers in parallel with the prompts from `executive-personas.md` (CPO, CTO, CAIO)
5. Synthesize — convergence, tensions, unique insights; rank by Impact × Feasibility × Urgency
6. Write the brainstorm document (template in `brainstorm-flow.md` § Step 7)

### Step 2: Report & Suggest Next Command

After writing the document, emit a short summary with next-step suggestions from the skill's integration table:
- Feature recommendation ready to build → `/super-ralph:design "[recommendation]"`
- Usability fix identified → `/super-ralph:repair "[fix description]"`
- Unresolved research question → dispatch research-agent for deeper investigation

## Critical Rules

- **NEVER ask for input.** All decisions flow from the research + SME brainstormers. Ambiguity is resolved by evidence, not user questioning.
- **Three executives, parallel.** CPO + CTO + CAIO are dispatched concurrently; their perspectives must be synthesized, not averaged.
- **Surface tensions honestly.** If two executives disagree, present the disagreement with evidence — don't paper over it.
- **Every recommendation is concrete.** "Improve UX" is not a recommendation. "Replace the 4-step vendor-create form with a single-input agent flow" is.
- **Rank by Impact × Feasibility × Urgency.** High-impact + infeasible recommendations belong in Parking Lot, not top of list.
- **Outputs feed other commands.** A brainstorm ends with a suggested `/super-ralph:design` or `/super-ralph:repair` command when applicable.
