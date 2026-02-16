# Autonomous Decision Pattern

This pattern replaces ALL human decision points in the ralph-loop workflow. Whenever the workflow would normally pause to ask a question, request clarification, or seek approval — this pattern is used instead.

## Core Principle

Ralph-loop is fire-and-forget. The user walks away. There is no human to ask. Every decision must be made autonomously using evidence gathered by subagents.

## The Pattern

When a decision is needed (architecture choice, library selection, error resolution, API design, approach ambiguity, mode selection, or any fork in the road):

### Step 1: Dispatch Research Agent

Dispatch a research-agent via the Task tool (haiku model):

```
Task prompt:
"Research: [specific question or decision to be made].

Search the codebase for existing patterns and conventions related to this decision.
Search the web for official documentation, best practices, and community guidance.

Return:
- Key findings (with sources)
- Recommendation based on evidence"
```

The research-agent searches the web and codebase for:
- Official documentation relevant to the decision
- Established patterns and conventions in the project
- Community best practices and proven solutions
- Prior art in similar projects

### Step 2: Dispatch SME Brainstormer Agents

Dispatch 1-3 sme-brainstormer agents in parallel via the Task tool (sonnet model). The number depends on decision complexity:

- **1 agent** — Simple choices (e.g., naming convention, minor API design)
- **2 agents** — Moderate decisions (e.g., library choice, error handling strategy)
- **3 agents** — Significant architectural decisions (e.g., service boundaries, data model design, communication patterns)

Each agent gets a different analytical angle:

```
Agent 1 — Architecture perspective:
"Analyze [decision] from an architecture perspective.
Given these research findings: [paste research-agent output]
Consider: maintainability, scalability, separation of concerns, existing patterns.
Recommend an approach with reasoning."

Agent 2 — Testing perspective:
"Analyze [decision] from a testing perspective.
Given these research findings: [paste research-agent output]
Consider: testability, edge cases, failure modes, mock complexity.
Recommend an approach with reasoning."

Agent 3 — Performance/Pragmatism perspective:
"Analyze [decision] from a pragmatic implementation perspective.
Given these research findings: [paste research-agent output]
Consider: implementation complexity, time to complete, risk of failure, performance implications.
Recommend an approach with reasoning."
```

### Step 3: Synthesize and Decide

After all agents return:

1. Read each agent's recommendation and reasoning
2. Identify consensus — if 2+ agents agree, that is the strongest signal
3. If agents disagree, weigh by evidence quality:
   - Recommendations backed by official docs > blog posts
   - Recommendations aligned with existing codebase patterns > novel approaches
   - Simpler approaches > complex ones (when evidence is equal)
4. Pick the option with strongest evidence + expert consensus

### Step 4: Document the Decision

Record the decision briefly:
- In a code comment if it affects a specific implementation
- In the commit message if it shapes a task's approach
- In the plan file if it affects multiple tasks

Format: `// Decision: [choice] — [1-sentence rationale based on evidence]`

### Step 5: Proceed Immediately

Move on. Do not second-guess. Do not revisit unless a concrete failure proves the decision wrong.

If a decision later proves incorrect (tests fail, build breaks), the ralph-loop will naturally iterate back to it. The autonomous decision pattern can be re-applied with the new evidence (the failure itself becomes data).

## When to Apply

Apply this pattern whenever you encounter ANY of:

- "Should I use X or Y?"
- "How should this be structured?"
- "What's the right approach for...?"
- "I'm not sure whether to..."
- "The plan doesn't specify..."
- "There are multiple ways to..."
- "This error could be caused by A or B"
- "The library docs suggest X but the codebase uses Y"
- Any decision that would normally prompt a question to the user

## Scaling Guidelines

| Decision Type | Research Agent | SME Agents | Total Agents |
|---|---|---|---|
| Naming, formatting, minor style | Skip | 1 | 1 |
| Library choice, API design | 1 | 1-2 | 2-3 |
| Architecture, data model, service boundaries | 1 | 2-3 | 3-4 |
| Technology stack, framework selection | 1 | 3 | 4 |

For trivial decisions (variable naming, formatting), a single sme-brainstormer without research may suffice. Use judgment — the pattern should accelerate decisions, not create overhead for obvious choices.

## Anti-Patterns

- **Skipping research:** Dispatching brainstormers without evidence leads to opinion-based decisions. Always research first (unless the decision is trivial).
- **Over-engineering:** Dispatching 3 SME agents for a variable name. Scale the pattern to the decision's impact.
- **Ignoring consensus:** If 3 agents agree and you pick the outlier, you need a strong reason.
- **Asking the user anyway:** The whole point is autonomy. If you find yourself wanting to ask, apply this pattern instead.
- **Not documenting:** Future iterations have no memory. If the decision is not in code or commits, it is lost.

## Example: Choosing Between REST and gRPC

1. **Research agent** finds: project uses Hono (HTTP framework), team has no gRPC setup, existing services use REST, gRPC would require protobuf toolchain.

2. **SME Agent 1 (Architecture):** "REST aligns with existing services. gRPC adds complexity for internal-only communication. Recommend REST with structured response types."

3. **SME Agent 2 (Performance):** "gRPC offers better performance for high-throughput inter-service calls. However, the service handles <100 req/s. REST is sufficient. Recommend REST."

4. **Synthesis:** Both agents recommend REST. Evidence: existing patterns use REST, no gRPC toolchain exists, performance needs don't justify the migration cost.

5. **Decision:** `// Decision: REST API — aligns with existing Hono services, gRPC overhead not justified at current scale`

6. **Proceed** with REST implementation.
