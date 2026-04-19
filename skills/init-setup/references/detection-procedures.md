# Init Detection Procedures

Step-by-step detection logic for every field in `.claude/super-ralph-config.md`. Invoked from `SKILL.md` Step 3. Each subsection is independent — if detection fails, leave the variable blank and continue.

---

## 1. Repository (`$REPO`, `$ORG`)

```bash
gh repo view --json nameWithOwner -q .nameWithOwner
```

- `$REPO` ← the full `owner/name` result (e.g., `zyk-ai/kira-zero`)
- `$ORG` ← the owner part before `/` (e.g., `zyk-ai`)

**Fallback:** If `gh repo view` fails, parse `git remote get-url origin` and extract `owner/name` from the SSH or HTTPS URL.

---

## 2. Runtime (`$RUNTIME`)

Check lockfiles in the project root (in priority order — first match wins):

| File found | `$RUNTIME` value |
|------------|------------------|
| `bun.lockb` or `bun.lock` | `bun` |
| `pnpm-lock.yaml` | `node` (but note pnpm in `$PKG_MANAGER` if you track it) |
| `yarn.lock` | `node` |
| `package-lock.json` | `node` |
| None found | `node` (default) |

---

## 3. Project Board (`$PROJECT_NUM`, `$PROJECT_ID`, `$STATUS_*`)

```bash
gh project list --owner $ORG --format json --limit 20 2>/dev/null
```

If projects exist:

1. Pick the first project, OR the one whose title case-insensitively matches the repo name (prefer the name-matched one).
2. Extract `$PROJECT_NUM` from the `number` field.
3. Fetch project GraphQL ID and field list:

```bash
PROJECT_ID=$(gh project view $PROJECT_NUM --owner $ORG --format json | jq -r '.id')
gh project field-list $PROJECT_NUM --owner $ORG --format json
```

4. Find the field named "Status" (case-insensitive) and extract:
   - `$STATUS_FIELD_ID` ← the field's `id`
   - `$STATUS_TODO` ← option ID where name matches `Todo` or `To Do`
   - `$STATUS_IN_PROGRESS` ← option ID where name matches `In Progress`
   - `$STATUS_PENDING_REVIEW` ← option ID where name matches `Pending Review`, `Review`, or `In Review`
   - `$STATUS_SHIPPED` ← option ID where name matches `Done`, `Shipped`, or `Complete`

**Fallback:** If no projects exist or the command fails, set all project-board variables to the literal string `none`.

---

## 4. Backend

### 4a. `$BE_DIR` (primary backend directory)

Search for the backend entry point using these signals in priority order:

1. **Drizzle config:** Glob `**/drizzle.config.{ts,js,mjs}` — the directory containing this file owns migrations and is almost certainly the primary backend.
2. **Hono/Express app:** Grep for `new Hono()` or `express()` in `**/src/index.ts` or `**/src/app.ts`.
3. **`package.json` with server script:** Glob `**/package.json`, grep for `"start"` or `"dev"` scripts containing `hono`, `express`, or `fastify`.
4. **Convention:** Directories named `backend/`, `server/`, `api/`, `core/backend/`.

Set `$BE_DIR` to the path relative to the repo root (e.g., `core/backend/config-service`).

### 4b. `$SCHEMA_FILE` (schema source)

From `$BE_DIR` or the monorepo root:

1. If a `drizzle.config.ts` exists in `$BE_DIR`, read it and extract the `schema` field — that's the schema source.
2. Glob `**/core-schemas/**/index.ts`, `**/schemas/**/index.ts`, or `**/schema.ts`.
3. Look for files importing from `drizzle-orm/pg-core`.

Set `$SCHEMA_FILE` to the path (e.g., `packages/core-schemas/src/tables/index.ts`).

### 4c. `$ROUTE_REG_FILE` (route registration file)

From `$BE_DIR`:

1. Look for `src/routes/index.ts` or `src/routes.ts` — the file that aggregates all route modules.
2. Grep for `.route(` or `.basePath(` patterns (Hono route mounting).

### 4d. Services + routes directories

From `$BE_DIR`:

- `$BE_SERVICES_DIR` ← `src/services/` (glob match)
- `$BE_ROUTES_DIR` ← `src/routes/` (glob match)

### 4e. `$BE_TEST_CMD` (backend test command)

Read `$BE_DIR/package.json` and look for a `test` script. Construct the command based on `$RUNTIME`:

- `bun`: `cd $BE_DIR && bun test`
- `node` + vitest: `cd $BE_DIR && npm test` (or `npm run test`, or `bunx vitest run`)

If no test script exists, set to an empty string.

---

## 5. Frontend

### 5a. `$FE_DIR`

Signals in priority order:

1. Glob `**/src/pages/**/*.{tsx,jsx}` or `**/app/**/page.{tsx,jsx}` — the root of this tree is the FE dir.
2. Directories named `frontend/`, `web/`, `app/`, `client/`, `dashboard/`.
3. `vite.config.ts`, `next.config.{ts,js,mjs}`, `remix.config.ts`.
4. In monorepos, a `packages/*` with React dependencies.

If no clear frontend exists, set `$FE_DIR` to `none`.

### 5b. `$TYPES_FILE` (shared types)

1. Grep for shared type exports in `**/types/index.ts`, `**/types.ts` in shared packages.
2. Look for `@*/shared` or similar shared package types.
3. Check `$FE_DIR/src/types/` directory.

### 5c. `$API_CLIENT_DIR`

From within `$FE_DIR`:

1. Glob `**/api/`, `**/client/`, `**/services/`.
2. Grep for `fetch(` or `axios` call patterns or API client class patterns.

### 5d. i18n files

1. Glob `**/*i18n*/**/*.{ts,json}`, `**/locales/**/*.{ts,json}`, `**/messages/**/*.{ts,json}`.
2. Primary language is typically `en.ts`/`en.json`; secondary is `zh.ts`/`zh-CN.ts` or similar.

- `$I18N_BASE_FILE` ← primary language file (English by default)
- `$I18N_SECONDARY_FILE` ← secondary language file (leave blank if none)

### 5e. Pages + components directories

From `$FE_DIR`:

- `$FE_PAGES_DIR` ← `src/pages/` or `app/`
- `$FE_COMPONENTS_DIR` ← `src/components/`

### 5f. `$FE_TEST_CMD`

Check `$FE_DIR/package.json` or the root `package.json` for a frontend test script (vitest, jest, playwright, etc.). Construct the command analogously to `$BE_TEST_CMD`.

---

## 6. App URL (`$APP_URL`)

Check these sources in priority order:

1. `CLAUDE.md` — grep for `https://` URLs that look like app URLs (production domains).
2. `.env`, `.env.production`, `.env.staging` — grep for `APP_URL`, `NEXT_PUBLIC_URL`, `VITE_APP_URL`, `BASE_URL`.
3. Deployment configs: `azure.yaml`, `fly.toml`, `vercel.json`, `Procfile` — extract target URLs.
4. `package.json` `homepage` field.

If not found, set to empty string.

---

## 7. Team (best-effort)

Check these sources:

1. `.github/CODEOWNERS` — extract usernames by role if roles are encoded (e.g., `# pm: @user`).
2. Recent `gh pr list --author` patterns to infer who ships what.
3. `package.json` `contributors` field.

Set `$PM_USER`, `$TECH_LEAD`, `$TESTERS` if detectable. Otherwise leave blank — these are optional and can be filled in manually later.

---

## Detection Errors

If any step's primary command fails, fall back to the listed alternatives, then leave the variable blank. Never halt the whole init on a single detection failure — write a partial config and list the missed sections in the final report.
