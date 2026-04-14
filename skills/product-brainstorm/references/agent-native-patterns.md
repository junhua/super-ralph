# Agent-Native Enterprise Software Patterns

Patterns that distinguish agent-native enterprise applications from traditional enterprise software. Use these when evaluating whether a feature truly leverages agents or is just a thin wrapper over CRUD.

## What "Agent-Native" Means

An agent-native feature is one where an AI agent is a first-class actor — not a chatbot stapled onto a form. The agent understands context, takes actions, makes decisions within guardrails, and improves over time. If you can remove the agent and the feature still works as a form/table/dashboard, it's not agent-native.

## Core Patterns

### 1. Proactive vs. Reactive

| Traditional | Agent-Native |
|---|---|
| User searches for data | Agent surfaces relevant data before asked |
| User creates reports | Agent detects anomalies and alerts |
| User manually assigns tasks | Agent triages and routes based on context |

**Key question:** Does the feature wait for the user, or does the agent anticipate needs?

### 2. Conversational Workflows

Instead of multi-step forms with rigid field sequences, agent-native workflows are conversational:
- User states intent in natural language
- Agent asks clarifying questions only when needed
- Agent fills in defaults from context (org settings, user history, related records)
- User reviews and confirms, not fills in

**Anti-pattern:** A "conversational" UI that's actually a form with a chat bubble skin.

### 3. Human-in-the-Loop Spectrum

Not everything should be automated. The spectrum:

| Level | Pattern | Example |
|---|---|---|
| Full autonomy | Agent acts, logs for audit | Auto-categorize expense line items |
| Notify | Agent acts, notifies human | Auto-reconcile bank transactions, send summary |
| Approve | Agent proposes, human confirms | Agent drafts journal entry, accountant approves |
| Assist | Agent suggests, human decides | Agent recommends GL accounts during data entry |
| Observe | Agent watches, learns patterns | Agent learns from manual categorization choices |

**Key question:** Where on this spectrum is each action? Over-automating erodes trust. Under-automating wastes the agent's value.

### 4. Context Accumulation

Agents get smarter with context. Enterprise patterns:
- **Org memory:** Agent learns company-specific terminology, preferences, policies
- **User memory:** Agent adapts to individual work patterns and communication style
- **Process memory:** Agent learns from approval/rejection patterns to improve proposals
- **Cross-module context:** Agent in Finance knows about Sales deals closing (affects forecasting)

### 5. Trust & Transparency

Enterprise users won't trust a black box. Required patterns:
- **Explainable actions:** "I categorized this as Office Supplies because similar items from this vendor were categorized the same way in the last 6 months"
- **Audit trail:** Every agent action is logged with reasoning, reversible where possible
- **Confidence signals:** Agent indicates certainty level — high-confidence actions auto-execute, low-confidence ones escalate
- **Guardrails:** Hard limits the agent cannot override (approval thresholds, regulatory constraints)
- **Override & correct:** User can always override agent decisions, and the agent learns from corrections

### 6. Graceful Degradation

When the agent can't help (ambiguous input, missing context, edge case):
- Fall back to structured UI, not error messages
- Preserve any partial work the agent did
- Let the user complete manually without starting over
- Agent learns from the manual resolution

## Enterprise-Specific Considerations

### Multi-Tenancy
- Agent behavior is scoped to the organization
- No data leakage between tenants
- Org-specific customization (terminology, policies, thresholds)

### Compliance & Audit
- Agent actions must be auditable (who, what, when, why)
- Regulatory constraints are hard guardrails, not suggestions
- Data retention and deletion policies apply to agent memory too

### Integration Complexity
- Agents must work with existing enterprise systems (ERP, CRM, HRIS)
- API rate limits, auth flows, data mapping are agent concerns
- Partial failures in multi-system workflows need graceful handling

### Permission Model
- Agent actions are subject to the same RBAC as human actions
- Agent cannot escalate privileges
- Delegation model: "agent acts on behalf of user" with user's permissions

## Current Agent Technology Capabilities (2025-2026)

### What Works Well
- Natural language understanding and generation
- Structured data extraction from unstructured input
- Pattern recognition across large datasets
- Multi-step reasoning with tool use
- Code generation and data transformation
- Document summarization and analysis

### Current Limitations
- **Hallucination:** Agents can generate plausible-sounding but incorrect information — critical for financial/legal contexts
- **Context windows:** Large but finite — agents can't process unlimited history
- **Latency:** LLM calls add latency — not suitable for sub-100ms hot paths
- **Cost:** Per-token pricing means high-volume, low-value operations may not be cost-effective
- **Determinism:** Same input can produce different outputs — challenging for compliance
- **Real-time:** Agents don't inherently monitor in real-time; they respond to triggers
- **Multi-modal:** Vision/audio capabilities are improving but less reliable than text

### Emerging Capabilities
- Tool use and function calling (mature)
- Multi-agent orchestration (maturing)
- Long-term memory and learning (early)
- Computer use / UI automation (early)
- Reasoning and planning (improving rapidly)
