---
name: init
description: "Auto-detect project structure and generate .claude/super-ralph-config.md for all super-ralph commands"
argument-hint: "[--force] [--interactive]"
allowed-tools: ["Bash(git:*)", "Bash(gh:*)", "Bash(ls:*)", "Bash(jq:*)", "Bash(cat:*)", "Bash(head:*)", "Bash(wc:*)", "Read", "Write", "Glob", "Grep"]
---

# Super-Ralph Init Command

Generate `.claude/super-ralph-config.md` by introspecting the current project. All other super-ralph commands depend on this config file. This command runs automatically on first use of any super-ralph command — you should not need to invoke it manually.

## Arguments

- **--force**: Regenerate config even if it already exists (overwrites all values)
- **--interactive**: Pause after detection and show the user what was found before writing (default: write immediately)

## Guards

1. If `.claude/super-ralph-config.md` already exists and `--force` was NOT passed, report "Config already exists" and stop.
2. Ensure `gh` CLI is authenticated: `gh auth status`. If not, tell the user to run `gh auth login`.

## Auto-Init Procedure

Follow these steps in order. **Do NOT ask the user for input** unless `--interactive` was passed.

---

### Step 1: Detect Repository

```bash
# Get repo in owner/name format
gh repo view --json nameWithOwner -q .nameWithOwner
```

- `$REPO` ← the full `owner/name` result (e.g., `zyk-ai/kira-zero`)
- `$ORG` ← the owner part before `/` (e.g., `zyk-ai`)

If `gh repo view` fails, fall back to parsing `git remote get-url origin`.

---

### Step 2: Detect Runtime

Check lockfiles in the project root:

| File found | Runtime |
|------------|---------|
| `bun.lockb` or `bun.lock` | `bun` |
| `pnpm-lock.yaml` | `pnpm` (set runtime to `node`) |
| `yarn.lock` | `yarn` (set runtime to `node`) |
| `package-lock.json` | `node` |
| None | `node` (default) |

- `$RUNTIME` ← detected runtime

---

### Step 3: Detect Project Board

```bash
# List org projects
gh project list --owner $ORG --format json --limit 20 2>/dev/null
```

If projects exist:
1. Pick the first project (or the one whose title matches the repo name)
2. Extract `$PROJECT_NUM` from the `number` field
3. Get the project GraphQL ID and status field:

```bash
# Get project ID
PROJECT_ID=$(gh project view $PROJECT_NUM --owner $ORG --format json | jq -r '.id')

# Get status field and options
gh project field-list $PROJECT_NUM --owner $ORG --format json
```

4. From the field list, find the field named "Status" (case-insensitive):
   - `$STATUS_FIELD_ID` ← the field's `id`
   - `$STATUS_TODO` ← option ID where name matches `Todo` or `To Do`
   - `$STATUS_IN_PROGRESS` ← option ID where name matches `In Progress`
   - `$STATUS_PENDING_REVIEW` ← option ID where name matches `Pending Review` or `Review` or `In Review`
   - `$STATUS_SHIPPED` ← option ID where name matches `Done` or `Shipped` or `Complete`

If no projects exist or the command fails, set all to `none`.

---

### Step 4: Detect Backend Structure

#### 4a. Find the primary backend directory

Search for the backend entry point using these signals (in priority order):

1. **Drizzle config**: Glob `**/drizzle.config.{ts,js,mjs}` — the directory containing this owns migrations and is likely the primary backend
2. **Hono/Express app**: Grep for `new Hono()` or `express()` in `**/src/index.ts` or `**/src/app.ts`
3. **package.json with server script**: Glob `**/package.json`, grep for `"start"` or `"dev"` scripts containing `hono` or `express` or `fastify`
4. **Convention**: Look for directories named `backend/`, `server/`, `api/`, `core/backend/`

Set `$BE_DIR` to the directory path relative to the repo root (e.g., `core/backend/config-service`).

#### 4b. Find schema file

From `$BE_DIR` or the monorepo root:

1. If a `drizzle.config.ts` exists, read it and extract the `schema` field — that's the schema source
2. Glob `**/core-schemas/**/index.ts` or `**/schemas/**/index.ts` or `**/schema.ts`
3. Look for files importing from `drizzle-orm/pg-core`

Set `$SCHEMA_FILE` to the path (e.g., `packages/core-schemas/src/tables/index.ts`).

#### 4c. Find route registration file

From `$BE_DIR`:

1. Look for `src/routes/index.ts` or `src/routes.ts` — the file that aggregates all route modules
2. Grep for `.route(` or `.basePath(` patterns (Hono route mounting)

Set `$ROUTE_REG_FILE` to the path.

#### 4d. Find services and routes directories

From `$BE_DIR`:

1. `$BE_SERVICES_DIR` ← Glob for `src/services/` directory
2. `$BE_ROUTES_DIR` ← Glob for `src/routes/` directory

#### 4e. Detect backend test command

Check `$BE_DIR/package.json` for a `test` script. Construct the command:

- If `$RUNTIME` is `bun`: `cd $BE_DIR && bun test`
- If using vitest in the root: `$RUNTIME run test` or `bunx vitest run`

Set `$BE_TEST_CMD`.

---

### Step 5: Detect Frontend Structure

#### 5a. Find the primary frontend directory

Search for the frontend entry point:

1. Glob `**/src/pages/**/*.{tsx,jsx}` or `**/app/**/page.{tsx,jsx}` — the root of this tree is the FE dir
2. Look for directories named `frontend/`, `web/`, `app/`, `client/`, `dashboard/`
3. Look for `vite.config.ts`, `next.config.{ts,js,mjs}`, `remix.config.ts`
4. Check monorepo `packages/` for a UI package with React dependencies

Set `$FE_DIR` to the directory path. If no clear frontend exists, set to `none`.

#### 5b. Find types file

1. Grep for shared type exports: `**/types/index.ts`, `**/types.ts` in shared packages
2. Look for `@kira/shared` or similar shared package types
3. Check for `src/types/` directory

Set `$TYPES_FILE`.

#### 5c. Find API client directory

1. Glob `**/api/`, `**/client/`, `**/services/` inside `$FE_DIR`
2. Grep for `fetch(` or `axios` or API client patterns

Set `$API_CLIENT_DIR`.

#### 5d. Find i18n files

1. Glob `**/*i18n*/**/*.{ts,json}`, `**/locales/**/*.{ts,json}`, `**/messages/**/*.{ts,json}`
2. Look for `en.ts`/`en.json` as base, `zh.ts`/`zh-CN.ts` as secondary

- `$I18N_BASE_FILE` ← primary language file (usually English)
- `$I18N_SECONDARY_FILE` ← secondary language file (if exists, else blank)

#### 5e. Find pages and components directories

From `$FE_DIR`:

1. `$FE_PAGES_DIR` ← `src/pages/` or `app/` directory
2. `$FE_COMPONENTS_DIR` ← `src/components/` directory

#### 5f. Detect frontend test command

Check `$FE_DIR/package.json` or root `package.json` for frontend test scripts.

Set `$FE_TEST_CMD`.

---

### Step 6: Detect App URL

Check these sources (in order):

1. `CLAUDE.md` — grep for `https://` URLs that look like app URLs
2. `.env`, `.env.production`, `.env.staging` — grep for `APP_URL`, `NEXT_PUBLIC_URL`, `VITE_APP_URL`, `BASE_URL`
3. Deployment configs (`azure.yaml`, `fly.toml`, `vercel.json`, `Procfile`) — extract target URLs
4. `package.json` `homepage` field

Set `$APP_URL`. If not found, set to blank.

---

### Step 7: Detect Team (best-effort)

Check these sources:

1. `.github/CODEOWNERS` — extract usernames
2. Recent `gh pr list --author` patterns
3. `package.json` `contributors` field

Set `$PM_USER`, `$TECH_LEAD`, `$TESTERS` if detectable. Otherwise leave blank — these are optional and can be filled in manually later.

---

### Step 8: Write Config File

Write `.claude/super-ralph-config.md` using this exact template, substituting all detected values:

```markdown
# Super-Ralph Project Config

> Auto-generated by `/super-ralph:init` on YYYY-MM-DD. Edit values to customize.

## Repository

- `$REPO`: `<detected>`
- `$ORG`: `<detected>`

## Project Board

- `$PROJECT_NUM`: `<detected or none>`
- `$PROJECT_ID`: `<detected or none>`
- `$STATUS_FIELD_ID`: `<detected or none>`
- `$STATUS_TODO`: `<detected or none>`
- `$STATUS_IN_PROGRESS`: `<detected or none>`
- `$STATUS_PENDING_REVIEW`: `<detected or none>`
- `$STATUS_SHIPPED`: `<detected or none>`

## Backend

- `$BE_DIR`: `<detected>`
- `$SCHEMA_FILE`: `<detected>`
- `$ROUTE_REG_FILE`: `<detected>`
- `$BE_SERVICES_DIR`: `<detected>`
- `$BE_ROUTES_DIR`: `<detected>`
- `$BE_TEST_CMD`: `<detected>`

## Frontend

- `$FE_DIR`: `<detected or none>`
- `$TYPES_FILE`: `<detected>`
- `$API_CLIENT_DIR`: `<detected>`
- `$I18N_BASE_FILE`: `<detected>`
- `$I18N_SECONDARY_FILE`: `<detected>`
- `$FE_PAGES_DIR`: `<detected>`
- `$FE_COMPONENTS_DIR`: `<detected>`
- `$FE_TEST_CMD`: `<detected>`

## Production

- `$APP_URL`: `<detected>`
- `$RUNTIME`: `<detected>`

## Team

- `$PM_USER`: `<detected>`
- `$TECH_LEAD`: `<detected>`
- `$TESTERS`: `<detected>`
```

Replace `<detected>` with actual values. Use empty string `` (empty backticks) for values that couldn't be detected. Use `none` for project board fields when no board exists.

---

### Step 9: Report

Output a summary of what was detected:

```markdown
## Super-Ralph Init Complete

Config written to `.claude/super-ralph-config.md`.

| Section | Status |
|---------|--------|
| Repository | $REPO |
| Project Board | detected / none |
| Backend | $BE_DIR |
| Frontend | $FE_DIR or none |
| Runtime | $RUNTIME |

**Values that need manual review:**
- [list any values set to blank or uncertain]

Edit `.claude/super-ralph-config.md` to adjust any values.
To regenerate: `/super-ralph:init --force`
```
