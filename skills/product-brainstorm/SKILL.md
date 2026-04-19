---
name: product-brainstorm
description: This skill should be used when brainstorming product-level or feature-level improvements for agent-native enterprise software. Triggers when /super-ralph:brainstorm is invoked, or when the user mentions "brainstorm", "product ideas", "feature ideas", "improve usability", "improve usefulness", "what should we build", "product thinking", or wants to explore product directions with AI expertise. Provides structured brainstorming methodology with CTO/CPO/CAIO perspectives and domain knowledge about agent-native enterprise patterns.
---

# Product Brainstorming — Agent-Native Enterprise Software

## Overview

Autonomous, subagent-driven brainstorming for improving ForthAI Work's usability and usefulness. Dispatches research agents for competitive intelligence and agent tech landscape, then runs three executive brainstormers (CPO, CTO, CAIO) in parallel. Synthesizes into ranked, opinionated, actionable recommendations.

**Announce at start:** "I'm using the product-brainstorm skill to run a structured brainstorming session with CPO, CTO, and CAIO perspectives."

**Core philosophy:** Every insight must be actionable. "This could be better" is not an insight. "Replace the 5-step form with a receipt-upload flow where the agent extracts and pre-fills all fields from the image" is an insight.

## Executive Personas

Three parallel brainstormers, each with a distinct lens:

### CPO — Chief Product Officer

**Owns:** User empathy, product-market fit, usability, feature prioritization, competitive positioning.

Thinks about:
- What is the user actually trying to accomplish? What's in their way?
- How many clicks/steps before the user gets value?
- What's the failure mode when things go wrong?
- How do competitors solve this? Where can we leap ahead?
- What's P0 (must fix/build now) vs P1 vs P2?

Spots:
- Features requiring training to use (bad)
- System concepts exposed instead of domain concepts (bad)
- Context switches between modules to complete one task (bad)
- Technical error messages shown to business users (bad)

### CTO — Chief Technology Officer

**Owns:** Technical feasibility, architecture, scalability, simplicity, build vs. integrate.

Thinks about:
- Is the current architecture right for this feature area?
- What's over-engineered? What's under-built? What can be removed?
- Should this be custom code or a third-party integration?
- What breaks at 10x users, 100x data, or multi-region deployment?
- What's the development cost and complexity?

Spots:
- Engineering theater (complex solutions that don't serve users)
- Missing abstractions that cause repeated boilerplate
- Premature optimization or premature abstraction
- Build-everything-yourself bias when integrations exist

### CAIO — Chief AI Officer

**Owns:** Agent-native design, AI capabilities and limitations, human-in-the-loop design, trust and transparency.

Thinks about:
- Is this feature truly agent-native, or a chatbot bolted onto forms?
- Where on the autonomy spectrum should each action be? (Full autonomy → Notify → Approve → Assist → Observe)
- What does the feature promise vs. what current AI can reliably deliver?
- Will enterprise users trust the agent here? What builds or breaks trust?
- What context does the agent need to act well? Where does it accumulate intelligence?

Spots:
- AI theater (agent wrappers that add latency without value)
- Over-automation that erodes user trust or removes needed control
- Under-automation where agents could reliably handle routine work
- Missing guardrails, audit trails, or explainability
- Hallucination risks in high-stakes domains (finance, compliance)

## Information Sources

The brainstorming draws from these sources (gathered autonomously by research agents):

### Internal Sources
1. **Product vision** (`docs/vision.md`) — personas, principles, non-goals
2. **Roadmap** (`docs/roadmap.md`) — phases, shipped features, planned work
3. **Architecture** (`docs/architecture.md`) — system boundaries, services
4. **Codebase** — schema, routes, pages, i18n, components
5. **GitHub issues** — bugs, feature requests, user feedback
6. **Git history** — recent changes, momentum, active areas

### External Sources
7. **Competitor analysis** — how leading enterprise tools handle this area
8. **Agent tech landscape** — latest LLM/agent capabilities, limitations, trends
9. **UX research** — enterprise UX patterns, accessibility, best practices
10. **Industry trends** — market direction, regulatory changes, user expectations

## Brainstorming Methodology

### Phase 1: Context (Steps 2-3 of the command)

Gather all internal sources. Build a topic brief with scope, affected personas, and initial hypotheses.

### Phase 2: Research (Step 4 of the command)

Three parallel research agents (haiku, fast):
1. Market & competitor research
2. Agent & AI technology research
3. Codebase & product state analysis

### Phase 3: Executive Brainstorming (Step 5 of the command)

Three parallel executive brainstormers (sonnet), each with their perspective, all receiving the same research context. Each produces their top 3 recommendations.

### Phase 4: Synthesis (Step 6 of the command)

Cross-reference the three perspectives:
- **Convergence:** 2+ executives agree → high-confidence recommendation
- **Tension:** Executives disagree → present the tension, resolve with evidence
- **Unique:** Strong insight from one executive → include if evidence supports it

Rank by impact × feasibility × urgency. Produce 5-8 final recommendations.

## Scope Detection

| Input Pattern | Scope | Lens Priority |
|---|---|---|
| Module name (Finance, Sales/CRM, Agent Builder...) | Module | All three equally |
| Specific feature or workflow | Feature | CAIO + CPO weighted higher |
| Broad product question | Product | CPO + CTO weighted higher |
| Pain point or usability complaint | Feature | CPO weighted highest |
| New capability idea | Feature | CAIO + CTO weighted higher |

## Quality Checks

Before finalizing the brainstorm document:

- [ ] Every recommendation has a concrete action (not vague advice)
- [ ] Recommendations are opinionated (clear stances, not "options to consider")
- [ ] Agent capability claims are accurate (reference real capabilities and known limitations)
- [ ] User empathy is grounded (references real personas from vision.md, not abstract "users")
- [ ] Enterprise considerations are practical (multi-tenant, audit, permissions)
- [ ] At least one recommendation is about simplifying or removing, not adding
- [ ] AI theater is called out where it exists
- [ ] Tensions between executives are acknowledged honestly, not papered over
- [ ] Research evidence backs every major claim

## Agent-Native Assessment Framework

When evaluating any feature, apply this test:

1. **Remove the agent.** Does the feature still work as a form/table/dashboard?
   - If yes → It's not agent-native. Either make it truly agent-native OR build it as a great traditional feature.
   - If no → It's agent-native. Evaluate the agent's value-add.

2. **Add latency.** The agent adds 1-3 seconds of response time. Is the value worth the wait?
   - If the user could do it faster manually → the agent is adding friction, not value.
   - If the agent saves the user 30+ seconds of work → the latency is justified.

3. **Break the agent.** What happens when the AI gives a wrong answer?
   - If the consequence is minor (wrong category suggestion, easy to correct) → acceptable.
   - If the consequence is major (wrong financial amount, compliance violation) → needs guardrails.

## Integration with Super-Ralph Pipeline

Brainstorm outputs feed into:

| Brainstorm Output | Next Command |
|---|---|
| Feature recommendation ready to build | `/super-ralph:design "[recommendation]"` |
| Usability fix identified | `/super-ralph:repair "[fix description]"` |
| Unresolved research question | Dispatch research-agent for deeper investigation |
| Architecture concern | File GitHub issue with findings |
| Competitive gap identified | Add to roadmap consideration |

## References

- `references/brainstorm-flow.md` — 7-step procedure executed by `/super-ralph:brainstorm` (scope detection → research → executive agents → synthesize → write document)
- `references/executive-personas.md` — CPO / CTO / CAIO SME brainstormer prompts dispatched in Step 5
- `references/agent-native-patterns.md` — Agent-native enterprise software patterns, capabilities, and limitations
- `references/brainstorm-lenses.md` — Six analytical perspectives with synthesis methodology

### Sibling skills

- `../product-design/SKILL.md` — Brainstorm outputs feed into `/super-ralph:design` for epic creation
- `../repair-domains/SKILL.md` — Backs `/super-ralph:repair` for fast-track fixes identified during brainstorming
