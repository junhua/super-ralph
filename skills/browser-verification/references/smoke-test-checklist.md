# Smoke Test Checklist — ForthAI Work

Default browser smoke tests for the ForthAI Work app. Use as fallback criteria when no specific acceptance criteria are provided.

## Authentication

- [ ] Login page loads at `/login` without JS errors
- [ ] OTP form accepts email input and submits
- [ ] Successful auth redirects to `/dashboard` or `/select-org`
- [ ] Logout button clears session and redirects to `/login`

## Core Pages Load

Each page must render without JS errors or failed API requests.

- [ ] `/dashboard` — Dashboard with summary cards
- [ ] `/agents` — Agent list with table/grid
- [ ] `/agents/new` — Agent builder form
- [ ] `/studio` — Studio editor interface
- [ ] `/operations` — Operations log/list
- [ ] `/approvals` — Approval queue
- [ ] `/settings` — Settings page with tabs
- [ ] `/knowledge` — Knowledge base list

## Critical Flows

- [ ] Create agent via builder → agent appears in `/agents` list
- [ ] Open agent detail → tabs (Overview, Config, Logs) load
- [ ] Navigate to studio → editor canvas loads
- [ ] Navigate between pages via sidebar → no stale content or blank screens

## System Health

- [ ] No uncaught JS errors in console across all pages
- [ ] No failed API requests (4xx/5xx) during normal navigation
- [ ] Pages load within 5 seconds on first visit
- [ ] No React hydration warnings in console

## API Health

- [ ] `GET /health` returns 200
- [ ] Protected routes return 401 without auth cookie
- [ ] Protected routes return 200 with valid auth cookie
- [ ] API responses are valid JSON (no HTML error pages)
