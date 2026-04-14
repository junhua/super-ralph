# Brainstorming Lenses

Six perspectives to apply when brainstorming product and feature improvements. Apply 2-4 lenses per topic — not all lenses apply to every discussion.

## Lens 1: User Empathy

**Question:** What is the user actually trying to accomplish, and what's in their way?

Apply when:
- Evaluating existing feature usability
- Designing new workflows
- Prioritizing between features

How to use:
1. Identify the persona (accountant, sales rep, admin, IT manager)
2. Map their daily workflow — where does this feature fit?
3. What's the context switch cost? (How many clicks/steps before value?)
4. What information do they need that they don't have?
5. What's the failure mode? (What happens when it goes wrong?)

Red flags:
- Feature requires training to use
- Feature exposes system concepts instead of domain concepts
- User needs to context-switch between modules to complete a task
- Error messages are technical, not actionable

## Lens 2: Agent-Native Thinking

**Question:** What can the agent do that the user shouldn't have to?

Apply when:
- Any feature involving data entry, categorization, or routing
- Workflow automation decisions
- Deciding between manual and automated approaches

How to use:
1. List every manual step in the current workflow
2. For each step: can the agent do this reliably? (See agent-native-patterns.md)
3. Where on the human-in-the-loop spectrum should each step be?
4. What context does the agent need to act well?
5. What's the cost of the agent being wrong vs. the cost of always asking?

Red flags:
- Agent is used as a chatbot for CRUD operations (forms would be faster)
- Agent automates things users want control over
- Agent requires more input than the manual alternative
- No feedback loop for the agent to improve

## Lens 3: Enterprise Reality

**Question:** Will this work in a real enterprise environment with compliance, permissions, and scale?

Apply when:
- Any feature touching financial data, PII, or regulated processes
- Multi-user or multi-role workflows
- Integration with external systems

How to use:
1. Who needs to see/use this? Who must NOT see/use this?
2. Is there an audit trail? Can actions be reversed?
3. What happens at 100x scale? (100 users, 10K records, 1M transactions)
4. Does this respect existing approval hierarchies?
5. Can this be configured per-organization without code changes?

Red flags:
- Feature assumes single-user or single-org
- No consideration for data access control
- Audit trail is an afterthought
- Feature breaks with large datasets

## Lens 4: Market Positioning

**Question:** How do competitors solve this, and what's our differentiated approach?

Apply when:
- Designing new modules or major features
- Evaluating build vs. integrate decisions
- Prioritizing roadmap items

How to use:
1. What do traditional enterprise tools (SAP, Salesforce, NetSuite) do here?
2. What do modern alternatives (Rippling, Ramp, HubSpot) do differently?
3. What do AI-native tools (if any) do here?
4. Where is the gap? What's unsolved or poorly solved?
5. What's our unfair advantage? (Agent-native, integrated platform, etc.)

Red flags:
- Copying a competitor's feature without understanding why they built it
- Building features because "enterprise software needs X" without user pull
- Ignoring proven UX patterns for the sake of being different

## Lens 5: Technical Feasibility

**Question:** Can we actually build this reliably with current technology?

Apply when:
- Features involving AI/agent capabilities
- Real-time or high-frequency operations
- Complex integrations or data pipelines

How to use:
1. What's the latency budget? (Sub-second? Async OK?)
2. What's the reliability requirement? (Can we tolerate occasional errors?)
3. What's the data volume? (Cost implications of LLM calls at scale)
4. Does this need deterministic output? (Compliance, financial calculations)
5. What's the fallback when the AI fails?

Red flags:
- Feature requires capabilities agents don't reliably have yet
- No fallback for AI failure modes
- Cost per operation makes the feature uneconomical at scale
- Latency makes the UX unacceptable

## Lens 6: Simplicity

**Question:** Can we remove something instead of adding something?

Apply when:
- Always. This lens should be the default counter-pressure.

How to use:
1. What's the simplest version that solves the core problem?
2. What features can we NOT build and still deliver value?
3. Is this complexity essential (inherent to the domain) or accidental (our design)?
4. Can two features be merged into one simpler one?
5. What would we cut if we had half the time?

Red flags:
- Feature has settings nobody will change
- Feature handles edge cases that occur <1% of the time with complex UI
- Multiple ways to do the same thing
- Feature requires a tutorial or tooltip to understand

## Synthesis

After applying lenses, synthesize by:
1. **Conflicts:** Where do lenses disagree? (e.g., simplicity vs. enterprise reality)
2. **Convergence:** Where do multiple lenses point the same direction? (High confidence)
3. **Gaps:** What did no lens cover? (Might need research)
4. **Priority:** Which insight has the highest impact-to-effort ratio?
