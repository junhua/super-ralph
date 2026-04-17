---
name: browser-verification
description: "Verify web app features in a real browser via claude-in-chrome against Gherkin acceptance criteria. Use when /super-ralph:verify is invoked, or when user mentions 'smoke test', 'verify deployment', 'test in browser', 'check preview URL', 'browser check', 'visual verify', 'verify PR', 'verify against acceptance criteria', 'UI verification', 'live preview', 'playwright test', 'check vercel preview'."
---

# Browser Verification

## Overview

Verify web app features in a real browser using claude-in-chrome MCP tools. Maps Given/When/Then acceptance criteria to navigate/interact/assert browser actions. Captures GIF evidence and health metrics for every verification run.

**Announce at start:** "I'm using the browser-verification skill to verify deployed features against acceptance criteria in a real browser."

## Browser Session Setup

### Initialize Session

```
1. tabs_context_mcp          → get current browser state
2. tabs_create_mcp           → open new tab
3. resize_window(1280, 800)  → consistent viewport
4. navigate(url)             → load target URL
```

### Get Vercel Preview URL

```bash
gh api repos/$REPO/issues/$PR_NUMBER/comments \
  --jq '[.[] | select(.user.login == "vercel[bot]")] | last | .body' \
  | grep -oE 'https://[a-zA-Z0-9._-]+\.vercel\.app'
```

### Authentication Patterns

| Option | When | Method |
|--------|------|--------|
| A: Test bypass | Local dev (`localhost`) | Navigate to `/api/auth/test-login` or set test cookie |
| B: OTP flow | Deployed preview | `find` email input → `form_input` email → submit → wait for OTP → `form_input` OTP → submit |
| C: Cookie injection | When OTP is unavailable | `javascript_tool` to set `document.cookie` with valid session token |

**Detection:** After navigating to the target URL, use `read_page` to check if the current page is a login page (look for "sign in", "login", "email" form elements). If so, authenticate before proceeding.

## Mapping Criteria to Browser Actions

| Criterion Element | Browser Action | Primary Tool | Fallback Tool |
|---|---|---|---|
| **Given** (precondition) | Navigate to route, set up state | `navigate` | `javascript_tool` |
| **When** (action) | Click button, type text, submit form | `computer`, `form_input` | `find` + `computer` |
| **Then** (assertion) | Check visible content, element state | `get_page_text`, `read_page` | `find` |
| **And** (after Then) | Additional checks — console, network | `read_console_messages`, `read_network_requests` | `javascript_tool` |

### Action Patterns

**Navigate to route:**
```
navigate(url: "https://preview.vercel.app/dashboard")
```

**Click a button or link:**
```
find(description: "Create Agent button")  → get coordinates
computer(action: "click", x: N, y: N)
```

**Fill a form field:**
```
form_input(label: "Agent Name", value: "Test Agent")
```

**Submit a form:**
```
find(description: "Submit button")
computer(action: "click", x: N, y: N)
```

**Wait for navigation/loading:**
```
# After click, re-read page to confirm navigation
read_page()  → check URL changed or content loaded
```

## Assertion Patterns

| What to Check | How | Pass Condition |
|---|---|---|
| Text visible on page | `get_page_text` → search for string | String found in page text |
| Element exists | `find(description: "element description")` | Element located with coordinates |
| Element absent | `find(description: "element")` → expect not found | Element NOT located |
| No JS errors | `read_console_messages` → filter pattern `"error"` | Count = 0 |
| API succeeded | `read_network_requests` → filter by endpoint | Status 200-299 |
| API not called | `read_network_requests` → filter by endpoint | No matching request |
| Redirect occurred | `read_page` → check current URL | URL matches expected route |
| Page loaded fast | `read_network_requests` → check timing | Load < 5000ms |

### Assertion Example

```
# Then: Dashboard shows agent count
page_text = get_page_text()
assert "3 agents" in page_text → PASS
# If not found → FAIL with note: "Expected '3 agents' but page text contains: [excerpt]"
```

## Evidence Capture

### GIF Recording

```
gif_creator(action: "start", filename: "verify-pr-45")   → before first interaction
# ... all verification steps ...
gif_creator(action: "stop")                                → after last assertion
```

Output: `verify-pr-45.gif` saved locally.

### Console Messages

```
messages = read_console_messages()
errors = [m for m in messages if m.level == "error"]
# Report: "Console errors: [count] — [first 3 error messages]"
```

### Network Requests

```
requests = read_network_requests()
failures = [r for r in requests if r.status >= 400]
# Report: "Network failures: [count] — [method] [url] [status] for each"
```

## Verification Report Format

```markdown
## Verification Report

| # | Criterion | Status | Notes |
|---|-----------|--------|-------|
| 1 | [text] | PASS | [evidence] |
| 2 | [text] | FAIL | [what went wrong] |

### Health
- Console errors: [N]
- Network failures: [N]

### Verdict: PASS / FAIL
Evidence: [GIF filename]
```

**PASS** requires: all criteria PASS + console errors = 0 + network failures = 0.

## References

- `references/smoke-test-checklist.md` — Default smoke tests for ForthAI Work app
- The verify command (`commands/verify.md`) orchestrates the full workflow
- The browser-verifier agent (`agents/browser-verifier.md`) executes browser interactions
