# Acceptance Criteria Guide

Write acceptance criteria in Gherkin format. Every criterion is both human-readable for stakeholders and machine-executable as a test case.

## Gherkin Format (Required)

All acceptance criteria must use full Gherkin syntax. This is the primary and only supported format.

### Structure

```gherkin
Feature: [Story title -- matches the user story]
  Background:
    Given I am logged in as [persona] with orgId "[org-id]"
    And [workspace or data precondition]

  Scenario: [CATEGORY] [description]
    Given [specific precondition with concrete data]
    When [single user action]
    Then [observable outcome with specific values]
    And [additional assertion]

  Scenario Outline: [CATEGORY] [parameterized description]
    Given [precondition with <variable>]
    When [action with <input>]
    Then [outcome with <expected>]
    Examples:
      | variable | input  | expected |
      | val1     | inp1   | result1  |
      | val2     | inp2   | result2  |
```

### Category Labels (Required on Every Scenario)

Every Scenario must have a category label in brackets. No unlabeled scenarios.

| Label | Purpose | When to Use |
|-------|---------|-------------|
| `[HAPPY]` | Primary success path | Always -- at least 1 per story |
| `[EDGE]` | Boundary conditions | Always -- at least 1 per story |
| `[SECURITY]` | Auth, authz, role checks | Required for any story with role-based access |
| `[PERF]` | Latency, throughput targets | Only for performance-critical stories |

### Mandatory Rules

1. **Background is required** -- Always include auth context (persona + orgId)
2. **Max 6 scenarios per story** -- If you need more, the story is too large (apply SLICE decomposition)
3. **Concrete data only** -- `"3 agents"` not `"some agents"`; `"Vendor is required"` not `"error message"`
4. **One behavior per scenario** -- If "And" joins two unrelated outcomes, split into two scenarios
5. **API assertions in UI scenarios** -- When a UI action triggers an API call, assert both UI feedback AND API result
6. **Category label on every Scenario** -- `[HAPPY]`, `[EDGE]`, `[SECURITY]`, or `[PERF]`

## Gherkin-to-bun:test Mapping

Every Gherkin element maps to a `bun:test` construct. This table is the Rosetta Stone for translating AC into executable tests.

| Gherkin Element | bun:test Element | Code Example |
|----------------|-----------------|--------------|
| `Feature: Create Resource` | `describe("Create Resource", () => {})` | Outer test group |
| `Background: Given logged in` | `beforeEach(async () => {})` | Auth setup, fixture loading |
| `Scenario: [HAPPY] creates resource` | `test("[HAPPY] creates resource", async () => {})` | Single test case |
| `Scenario Outline:` + `Examples:` | `test.each(examples)()` | Parameterized test |
| `Given [precondition]` | Variable initialization, fixture | `const org = await createOrg()` |
| `When [action]` | API call or UI interaction | `const res = await api.post(...)` |
| `Then [outcome]` | `expect()` assertion | `expect(res.status).toBe(201)` |
| `And [after Then]` | Additional `expect()` | `expect(res.body.name).toBe("X")` |
| `And [after Given]` | Additional setup | `await seedData(...)` |

### Example: Gherkin to Test

**Gherkin:**
```gherkin
Feature: Create Resource
  Background:
    Given I am logged in as business operator with orgId "org-123"
    And the workspace has 0 resources

  Scenario: [HAPPY] Create resource with valid name
    Given I am on the resources page
    When I click "Create" and enter name "Monthly Report"
    Then a resource named "Monthly Report" appears in the list
    And its status is "active"

  Scenario: [EDGE] Reject empty name
    Given I am on the create resource form
    When I submit with an empty name field
    Then I see error: "Name is required"
    And no resource is created

  Scenario Outline: [HAPPY] Create resource with various names
    When I create a resource named "<name>"
    Then the resource list shows "<name>" with status "active"
    Examples:
      | name           |
      | Monthly Report |
      | Q4 Summary     |
      | Budget 2026    |
```

**bun:test:**
```typescript
import { describe, test, expect, beforeEach } from "bun:test";

describe("Create Resource", () => {
  let token: string;
  const orgId = "org-123";

  beforeEach(async () => {
    // Background: logged in as business operator
    token = await login("operator@example.com");
    // Background: workspace has 0 resources
    await clearResources(orgId);
  });

  test("[HAPPY] Create resource with valid name", async () => {
    // When: create resource
    const res = await fetch(`/api/orgs/${orgId}/resources`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}` },
      body: JSON.stringify({ name: "Monthly Report" }),
    });
    // Then: resource created with active status
    expect(res.status).toBe(201);
    const body = await res.json();
    expect(body.data.name).toBe("Monthly Report");
    expect(body.data.status).toBe("active");
  });

  test("[EDGE] Reject empty name", async () => {
    // When: submit empty name
    const res = await fetch(`/api/orgs/${orgId}/resources`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}` },
      body: JSON.stringify({ name: "" }),
    });
    // Then: validation error
    expect(res.status).toBe(400);
    const body = await res.json();
    expect(body.error).toBe("Name is required");
  });

  test.each([
    ["Monthly Report"],
    ["Q4 Summary"],
    ["Budget 2026"],
  ])("[HAPPY] Create resource with name: %s", async (name) => {
    const res = await fetch(`/api/orgs/${orgId}/resources`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}` },
      body: JSON.stringify({ name }),
    });
    expect(res.status).toBe(201);
    expect((await res.json()).data.name).toBe(name);
  });
});
```

## Coverage Patterns

Every story needs scenarios covering these categories. Minimum: 1 HAPPY + 1 EDGE.

### 1. Happy Path (Required -- at least 1)

The primary success scenario.

```gherkin
  Scenario: [HAPPY] Create agent from template
    Given I am on the Guided Builder page
    When I fill in agent name "PO Validator" and select template "Purchase Order Review"
    And I click "Create"
    Then I see the agent configuration page for "PO Validator"
    And the agent appears in my agent list with status "Draft"
```

### 2. Edge Cases (Required -- at least 1)

Boundary conditions, empty states, limits, duplicates.

```gherkin
  Scenario: [EDGE] Empty state shows call-to-action
    Given I am a new user with no agents
    When I open the Operations Workspace
    Then I see: "No agents yet. Create your first agent to get started."
    And a "Create Agent" button is prominently displayed

  Scenario: [EDGE] Reject duplicate agent name
    Given an agent named "Invoice Agent" already exists
    When I try to create another agent with name "Invoice Agent"
    Then I see error: "An agent with this name already exists"

  Scenario: [EDGE] Agent limit reached
    Given I have 10 agents (maximum for my plan)
    When I try to create a new agent
    Then I see: "Agent limit reached. Upgrade your plan or archive existing agents."
    And the "Create Agent" button is disabled
```

### 3. Security / Authorization (Required for role-based stories)

What happens when a user lacks permission.

```gherkin
  Scenario: [SECURITY] Operator cannot access governance settings
    Given I am logged in as business operator (not admin)
    When I navigate to /settings/governance
    Then I see: "You don't have permission to access this page"
    And a link to request access from my admin is displayed

  Scenario: [SECURITY] Cross-org access denied
    Given I am logged in with orgId "org-123"
    When I request GET /api/orgs/org-456/resources
    Then I receive 403 Forbidden
    And no resource data is returned
```

### 4. Validation Errors (Required for form/input stories)

What happens when user input is invalid.

```gherkin
  Scenario: [EDGE] Name field required
    Given I am on the create form
    When I leave the name field empty and click "Submit"
    Then the name field shows error: "Name is required"
    And the form is not submitted

  Scenario: [EDGE] Name too long
    Given I am on the create form
    When I enter a name with 256 characters
    Then the name field shows error: "Name must be 255 characters or fewer"
```

### 5. System Errors (Required for API-dependent stories)

What happens when the system fails.

```gherkin
  Scenario: [EDGE] API failure during save
    Given I am saving a new resource
    When the API returns a 500 error
    Then I see: "Save failed. Please try again."
    And a "Retry" button is available
    And my form data is preserved
```

### 6. Performance (Only for perf-critical stories)

```gherkin
  Scenario: [PERF] List page loads within budget
    Given I have 500 resources in my workspace
    When I open the resources list page
    Then the first 20 resources render within 2 seconds
    And a "Load more" button appears
```

## Anti-Patterns

### Tests implementation, not behavior

```gherkin
# BAD -- tests HOW (React internals)
  Scenario: Component renders
    Given the React component mounts
    When useState initializes
    Then state equals initial value

# GOOD -- tests WHAT the user sees
  Scenario: [HAPPY] Page shows template list
    Given I open the agent builder
    When the page loads
    Then the template list shows 5 available templates
```

### Too vague to automate

```gherkin
# BAD -- "appropriate" is subjective
  Scenario: Create shows feedback
    When I create an agent
    Then appropriate feedback is shown

# GOOD -- specific, automatable
  Scenario: [HAPPY] Create shows success toast
    When I create an agent named "Invoice Bot"
    Then a success message appears: "Agent 'Invoice Bot' created"
    And the message disappears after 5 seconds
```

### Bundles multiple behaviors

```gherkin
# BAD -- three behaviors in one scenario
  Scenario: Submit form
    When I submit the form
    Then it validates, saves, and redirects

# GOOD -- one behavior per scenario
  Scenario: [HAPPY] Valid submission shows loading
    When I submit with valid data
    Then a loading indicator appears

  Scenario: [HAPPY] Successful save shows confirmation
    Given I submitted valid data
    When saving completes
    Then a success message appears: "Saved successfully"

  Scenario: [HAPPY] After save redirects to list
    Given I saved successfully
    When I dismiss the success message
    Then I am redirected to the resource list
```

### Uses relative terms

```gherkin
# BAD -- "quickly", "many", "appropriate"
  Scenario: Page loads
    Then the page loads quickly with many agents

# GOOD -- concrete values
  Scenario: [PERF] Page loads within budget
    Given I have 100 agents
    When I open the agent list
    Then the page loads within 2 seconds
    And the first 20 agents are displayed
    And a "Load more" button appears
```

## Confidence Levels

Not all scenarios carry equal weight. Mark aspirational scenarios explicitly.

| Confidence | Meaning | Use When |
|---|---|---|
| **(default)** | Must pass for story to be done | Core functionality |
| **Expected** | Should pass, may need iteration | Complex interactions |
| **Aspirational** | Stretch goal | Performance targets, UX polish |

Mark aspirational scenarios explicitly:

```gherkin
  # Aspirational -- not in e2e gate
  Scenario: [PERF] Sub-second render with 1000 items
    Given I have 1000 resources
    When I open the list page
    Then the first 20 render within 500ms
```

Aspirational scenarios are NOT included in e2e test completion gates. They inform optimization stories.

## Legacy Format (Deprecated)

> **Note:** The bullet-point Given/When/Then format is deprecated. Existing stories with bullet-point AC remain valid, but all **new** stories must use full Gherkin `Feature/Background/Scenario` syntax. When updating existing stories, convert bullet-point AC to Gherkin format.

Example of deprecated format (do not use for new stories):
```markdown
- [ ] **Given** I am on the builder page
      **When** I click Create
      **Then** an agent is created
```

Convert to:
```gherkin
Feature: Agent Builder
  Background:
    Given I am logged in as business operator with orgId "org-123"

  Scenario: [HAPPY] Create agent
    Given I am on the builder page
    When I click "Create"
    Then an agent named "New Agent" is created with status "Draft"
```
