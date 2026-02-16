# Acceptance Criteria Guide

Detailed guide for writing acceptance criteria that are both human-readable and machine-verifiable. Every criterion must be expressible as an automated test.

## The Dual Purpose

Acceptance criteria serve two audiences simultaneously:

1. **Stakeholders** — "Is this story done?" → Read the criteria, check the boxes
2. **Test automation** — "Does this work?" → Each criterion = one e2e test case

Writing criteria that serve both audiences requires precision without jargon.

## Given/When/Then Structure

### Given (Precondition)

Establishes the starting state. Be specific about:
- **Who:** Which persona/role is acting
- **Where:** Which page/screen/endpoint
- **What state:** What data or conditions exist

```markdown
# Good — specific and reproducible
**Given** I am a business operator logged into the Operations Workspace
      **And** I have 3 agents with status "Active"

# Bad — vague, not reproducible
**Given** I am a user with some agents
```

### When (Action)

The specific user action or system event. One action per criterion.

```markdown
# Good — single, concrete action
**When** I click the "Pause" button on the "Invoice Agent" card

# Bad — multiple actions bundled
**When** I click Pause and then confirm the dialog and then check the status
```

If an action requires multiple steps (click → confirm dialog), treat the multi-step sequence as one logical action only if the intermediate steps are trivial (confirmation dialogs). Otherwise, split into separate criteria.

### Then (Observable Result)

What the user can see, hear, or measure after the action. Never reference internal state.

```markdown
# Good — observable by the user
**Then** the agent card shows status "Paused"
**And** a notification appears: "Invoice Agent paused"
**And** no new runs appear in the Operations Workspace for this agent

# Bad — internal state, not observable
**Then** the agent.status field in the database is set to "paused"
**And** the WebSocket connection is closed
```

## Coverage Patterns

Every story needs criteria covering these categories:

### 1. Happy Path (Required)

The primary success scenario. What happens when everything works correctly.

```markdown
- [ ] **Given** I am on the Guided Builder page
      **When** I fill in the agent name "PO Validator" and select template "Purchase Order Review"
      **And** I click "Create"
      **Then** I see the agent configuration page for "PO Validator"
      **And** the agent appears in my agent list with status "Draft"
```

### 2. Validation Errors (Required)

What happens when user input is invalid. Cover the most common validation cases.

```markdown
- [ ] **Given** I am creating a new agent
      **When** I leave the name field empty and click "Create"
      **Then** the name field shows error: "Agent name is required"
      **And** the form is not submitted

- [ ] **Given** I am creating a new agent
      **When** I enter a name that already exists ("Invoice Agent")
      **Then** the name field shows error: "An agent with this name already exists"
```

### 3. Error Handling (Required for API-dependent stories)

What happens when the system encounters an unexpected error.

```markdown
- [ ] **Given** I am deploying an agent
      **When** the API returns a server error
      **Then** I see: "Deployment failed. Please try again. If the problem persists, contact support."
      **And** the agent remains in "Draft" status
      **And** a retry button is available
```

### 4. Edge Cases (As needed)

Boundary conditions, limits, empty states.

```markdown
# Empty state
- [ ] **Given** I am a new user with no agents
      **When** I open the Operations Workspace
      **Then** I see an empty state: "No agents yet. Create your first agent to get started."
      **And** a "Create Agent" button is prominently displayed

# Boundary
- [ ] **Given** I have 99 runs in my history (page limit is 100)
      **When** a new run completes
      **Then** the new run appears at the top of the list
      **And** the oldest run is still visible (100 items shown)
      **And** a "Load more" option appears
```

### 5. Authorization (For multi-role stories)

What happens when a user lacks permission.

```markdown
- [ ] **Given** I am a business operator (not an admin)
      **When** I try to access the Governance Settings page
      **Then** I see: "You don't have permission to access this page"
      **And** a link to request access from my admin
```

## Anti-Patterns

### Criterion tests implementation, not behavior

```markdown
# Bad — tests HOW, not WHAT
- [ ] **Given** the React component renders
      **When** useState is called with initial value
      **Then** the state variable equals the initial value

# Good — tests WHAT the user experiences
- [ ] **Given** I open the agent builder
      **When** the page loads
      **Then** the template list shows 5 available templates
```

### Criterion is too vague to automate

```markdown
# Bad — "appropriate" is subjective
- [ ] **When** I create an agent **Then** appropriate feedback is shown

# Good — specific, automatable
- [ ] **When** I create an agent **Then** a success message appears: "Agent created successfully"
      **And** the message disappears after 5 seconds
```

### Criterion bundles multiple behaviors

```markdown
# Bad — three behaviors in one criterion
- [ ] **When** I submit the form **Then** it validates, saves, and redirects

# Good — split into testable units
- [ ] **When** I submit with valid data **Then** a loading indicator appears
- [ ] **When** saving completes **Then** a success message appears
- [ ] **When** I dismiss the message **Then** I am redirected to the agent list
```

### Criterion uses relative terms

```markdown
# Bad — "quickly", "many", "appropriate"
- [ ] **Then** the page loads quickly with many agents

# Good — concrete values
- [ ] **Then** the page loads within 2 seconds
      **And** the first 20 agents are displayed
      **And** a "Load more" button appears if more exist
```

## From Criteria to E2E Tests

### Mapping Rules

| Criterion Element | Test Element |
|---|---|
| **Given** | Test setup / beforeEach |
| **When** | Test action (API call, UI interaction) |
| **Then** | Assertion (expect) |
| **And** (after Then) | Additional assertion |
| **And** (after Given) | Additional setup |

### API-Level E2E Test Example

```typescript
test("creates agent from template", async () => {
  // Given: authenticated business operator
  const token = await login("operator@example.com");

  // When: create agent from template
  const response = await fetch("/api/agents", {
    method: "POST",
    headers: { Authorization: `Bearer ${token}` },
    body: JSON.stringify({
      name: "PO Validator",
      templateId: "purchase-order-review",
    }),
  });

  // Then: agent created with Draft status
  expect(response.status).toBe(201);
  const agent = await response.json();
  expect(agent.name).toBe("PO Validator");
  expect(agent.status).toBe("draft");
});
```

### UI-Level E2E Test Example (Playwright-style)

```typescript
test("creates agent from builder UI", async ({ page }) => {
  // Given: on agent builder page
  await page.goto("/builder");

  // When: select template and create
  await page.click('[data-template="purchase-order-review"]');
  await page.fill('[name="agent-name"]', "PO Validator");
  await page.click('button:has-text("Create")');

  // Then: redirected to config, agent in list
  await expect(page).toHaveURL(/\/agents\/[\w-]+\/configure/);
  await page.goto("/agents");
  await expect(page.locator("text=PO Validator")).toBeVisible();
});
```

## Confidence Levels

Not all acceptance criteria carry equal weight. Mark confidence when criteria are aspirational:

| Confidence | Meaning | Use When |
|---|---|---|
| **Certain** (default) | Must pass for story to be done | Core functionality |
| **Expected** | Should pass, but may need iteration | Complex interactions |
| **Aspirational** | Stretch goal, nice to have | Performance targets, UX polish |

Mark aspirational criteria explicitly:

```markdown
- [ ] *(Aspirational)* **Given** the agent list has 1000 agents
      **When** I open the page
      **Then** the first 20 agents render within 500ms
```

Aspirational criteria are NOT included in e2e test completion gates — they inform optimization stories.
