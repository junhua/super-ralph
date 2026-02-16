# Severity Classification Rules

Detailed guide for classifying PR review findings into severity levels. Used by review agents and the review-fix loop to determine which issues block completion and which are logged for reference.

## Classification Framework

Every finding must be classified by two dimensions:

1. **Severity** — How impactful is the issue?
2. **Confidence** — How certain are we this is a real issue (not a false positive)?

Both dimensions determine the final classification.

---

## Critical (Must Fix — Blocks Completion)

**Confidence threshold:** >= 90% certain this is a real issue.

Critical issues are defects that would cause user-facing failures, security breaches, or data loss if the code were merged.

### Categories

**Definite Bugs**
- Logic errors that produce wrong results
- Off-by-one errors in loops or array access
- Null/undefined dereference on common code paths
- Incorrect conditional logic (inverted conditions, missing cases)
- Type mismatches that cause runtime errors

```typescript
// Critical: off-by-one, processes one fewer item than expected
for (let i = 0; i < items.length - 1; i++) { // should be items.length
  process(items[i]);
}
```

**Security Vulnerabilities**
- SQL injection, XSS, command injection
- Authentication bypass (missing auth checks on protected routes)
- Secret exposure (API keys, tokens in code or logs)
- Insecure deserialization
- Path traversal

```typescript
// Critical: SQL injection
const query = `SELECT * FROM users WHERE id = '${userId}'`;
```

**Data Loss Risks**
- Missing database transactions where atomicity is needed
- Race conditions on write operations
- Destructive operations without confirmation or backup
- Silent data truncation or corruption

```typescript
// Critical: no transaction, partial failure leaves inconsistent state
await db.delete("orders", orderId);
await db.delete("order_items", orderId); // if this fails, orphaned order
```

**Broken Core Functionality**
- Feature does not work as specified in the PR description
- API returns wrong status codes for error cases
- Missing required fields in responses
- Business logic contradicts requirements

**Crash-Causing Issues**
- Unhandled exceptions in request handlers (causes 500)
- Stack overflow from unbounded recursion
- Memory leaks that crash the process over time
- Deadlocks in concurrent code

### Edge Cases for Critical

- **Potential null dereference on uncommon path:** If the null case is rare (< 1% of requests), downgrade to Important. If it is on a main code path, keep Critical.
- **Security issue with mitigating controls:** If another layer prevents exploitation (e.g., WAF blocks the injection), still classify as Critical — defense in depth.
- **Bug in error-handling code:** If the bug only manifests when another error occurs, it is still Critical — error paths must work correctly.

---

## Important (Should Fix — Blocks Completion)

**Confidence threshold:** >= 80% certain this matters.

Important issues are problems that degrade code quality, maintainability, or reliability but may not cause immediate user-facing failures.

### Categories

**Architecture Problems**
- Wrong abstraction level (god class, feature envy)
- Circular dependencies between modules
- Leaky abstractions (implementation details in public API)
- Violation of single responsibility principle (when egregious)

```typescript
// Important: UserService handles auth, profile, billing, and notifications
class UserService {
  async login() { /* ... */ }
  async updateProfile() { /* ... */ }
  async chargeBilling() { /* ... */ }
  async sendNotification() { /* ... */ }
}
```

**Missing Error Handling (User-Facing)**
- API endpoint catches errors but returns generic 500 instead of specific 400/404
- Missing try/catch around external API calls
- Promise rejection not handled (will crash in strict mode)
- Error messages that expose internal details to users

```typescript
// Important: unhandled promise rejection, no error response to client
app.get("/users/:id", async (c) => {
  const user = await db.getUser(c.req.param("id")); // can throw
  return c.json(user);
});
```

**Test Coverage Gaps**
- No test for the primary happy path of a new feature
- No test for the main error case
- Test exists but does not assert the correct behavior (testing mock, not real code)
- Regression-prone code path without test

**Convention Violations**
- Explicit CLAUDE.md rules violated (e.g., "use Bun not Node" but code uses `npm`)
- Project naming conventions broken (e.g., `camelCase` in a `snake_case` project)
- Architectural boundaries crossed (e.g., UI code importing database module directly)
- Documented patterns ignored (e.g., project uses repository pattern but new code does raw SQL)

**Type Safety Issues**
- Unsafe type casts (`as any`, `as unknown as T`) in critical code
- `any` type used where a proper type is feasible
- Missing null checks where TypeScript strict mode would catch them
- Generic types that are too broad (accepting everything)

### Edge Cases for Important

- **Minor convention violation:** If the convention is informal (not in CLAUDE.md), downgrade to Minor.
- **Test gap for edge case:** If the happy path is tested but an unusual edge case is not, downgrade to Minor.
- **Architecture concern in throwaway code:** If the PR explicitly says "prototype" or "spike", downgrade to Minor.

---

## Minor (Logged — Does NOT Block Completion)

**Confidence threshold:** >= 50%.

Minor issues are real but do not warrant blocking the PR. They are logged in the review output but the review-fix loop does not fix them.

### Categories

**Code Style Inconsistencies**
- Inconsistent naming within the PR (not matching project convention — that would be Important)
- Inconsistent formatting not caught by linter
- Import ordering
- Comment style variations

**Performance Optimizations**
- Unnecessary re-renders in UI components (unless measurably impactful)
- N+1 queries on small datasets (< 100 rows)
- Unnecessary object copies or allocations in non-hot paths
- Synchronous operations that could be async but are fast enough

**Minor DRY Violations**
- Same 2-3 lines duplicated in 2 places (not systemic)
- Similar but not identical logic that could be abstracted
- Copy-paste code that works correctly

**Non-Critical Naming**
- Variable name could be more descriptive
- Function name is acceptable but not ideal
- File name follows convention but could be more specific

### Edge Cases for Minor

- **DRY violation in 3+ places:** Upgrade to Important — this is systemic.
- **Performance issue in hot path:** Upgrade to Important if measurably impactful.
- **Style issue that causes confusion:** Upgrade to Important if it could lead to bugs.

---

## Suggestions (Logged — Does NOT Block Completion)

No confidence threshold — these are advisory.

### Categories

**Documentation Improvements**
- JSDoc comments that could be added
- README updates for new features
- API documentation for new endpoints
- Code comments explaining non-obvious logic

**Refactoring Opportunities**
- Code that works but could be structured better for future changes
- Opportunities to extract shared utilities
- Simplification opportunities that are not urgent

**Nice-to-Have Features**
- Additional validation that would be helpful but is not required
- Logging improvements
- Better error messages for debugging
- Metrics or observability hooks

**Alternative Approaches**
- Different algorithms that might be better
- Libraries that could simplify the code
- Design patterns worth considering for future iterations

---

## Confidence Calibration

Confidence is about how certain the reviewer is that the issue is REAL (not a false positive), not about how severe it would be if real.

| Confidence | Meaning | When to Assign |
|---|---|---|
| 95-100% | Certain — can point to the exact bug | Logic error visible in diff, proven by test |
| 90-94% | Very likely — strong evidence | Pattern is almost certainly wrong, would need context to be safe |
| 80-89% | Likely — reasonable evidence | Issue is probable but depends on runtime behavior |
| 60-79% | Possible — some evidence | Could be an issue but might be handled elsewhere |
| 50-59% | Uncertain — weak evidence | Smells wrong but cannot confirm without deep investigation |
| < 50% | Speculative | Do not report — too likely to be a false positive |

### Confidence Adjustments

**Increase confidence when:**
- The issue is visible directly in the diff (no need to check other files)
- Multiple indicators point to the same problem
- The pattern is a known anti-pattern with well-documented consequences
- Similar code in the project has had bugs before (check git blame)

**Decrease confidence when:**
- The issue might be handled by code not visible in the diff
- The pattern is unusual but might be intentional (e.g., performance optimization)
- The reviewer is unfamiliar with the specific library or framework
- The code is in a test or prototype (lower quality bar)

---

## Severity Override Rules

Certain patterns always map to a specific severity regardless of other factors:

| Pattern | Always | Reason |
|---|---|---|
| Exposed secrets (API keys, passwords) | Critical | Security — no exceptions |
| SQL/command injection | Critical | Security — no exceptions |
| Missing auth on protected endpoint | Critical | Security — no exceptions |
| Empty catch block on user-facing code | Important | Silent failures cause hard-to-debug issues |
| `as any` in type-critical code | Important | Type safety is a project-level decision |
| TODO without ticket reference | Minor | Acceptable if tracked |
| Console.log in production code | Minor | Usually caught by linter |

---

## Review Agent Instructions

When configuring review agents, include this classification guidance in their prompts. Agents should:

1. State the severity level explicitly
2. State their confidence percentage
3. Explain WHY this severity (what is the user impact?)
4. Provide a suggested fix approach
5. If confidence is borderline (e.g., 78% for Important), note the uncertainty

This ensures the review-fix loop can accurately determine which issues block completion and which are informational.
