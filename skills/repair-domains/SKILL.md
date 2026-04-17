---
name: repair-domains
description: "Detect the domain of a bug/repair task (frontend, backend, devops, cloud-infra, security) and route to appropriate skills, review agents, test suites, and fix patterns. Use when /super-ralph:repair is invoked, or when user mentions 'fix bug', 'hotfix', 'debug issue', 'repair', 'bug report', 'which area is affected', 'frontend or backend bug', 'production issue', 'incident', 'broken feature', 'regression', 'error in UI', 'API error', 'deployment failing'."
---

# Repair Domains Skill

Detect the domain of a repair task and route to the correct skills, review agents, test commands, and fix patterns. A repair can span multiple domains — always identify primary and secondary.

## Domain Detection

Run detection in this order. The first match sets the **primary domain**; subsequent matches become **secondary domains**.

### Step 1: Label-Based Detection (fastest)

If the repair originates from a GitHub issue (`#N`), read labels:

| Label | Domain |
|-------|--------|
| `area/frontend` | frontend |
| `area/backend` | backend |
| `area/fullstack` | frontend + backend |
| `security` | security |
| `devops`, `ci`, `infra` | devops |
| `priority/critical`, `priority/urgent` | (flag for `--hotfix` auto-detection, not a domain) |

### Step 2: File-Path Detection

Search the codebase for files related to the problem statement. Classify by path:

| Path pattern | Domain |
|-------------|--------|
| `work-web/src/components/**`, `work-web/src/app/**` | frontend |
| `work-web/src/styles/**`, `*.css`, `*.scss`, `tailwind.*` | frontend |
| `work-web/src/hooks/**`, `work-web/src/contexts/**` | frontend |
| `work-agents/src/routes/**`, `work-agents/src/services/**` | backend |
| `work-agents/src/db/**`, `**/schema.ts`, `**/migrations/**` | backend |
| `work-agents/src/middleware/**` | backend (or security if auth-related) |
| `.github/workflows/**`, `Dockerfile*`, `docker-compose*` | devops |
| `vercel.json`, `vercel.ts`, `next.config.*` | devops |
| `**/terraform/**`, `**/pulumi/**`, `**/cdk/**` | cloud-infra |
| `**/auth/**`, `**/session/**`, `**/cors.*`, `**/csp.*` | security |
| `work-web/src/lib/api-client.*` | frontend (API client layer) |
| `work-agents/src/index.ts` | backend (route registration) |

### Step 3: Content-Based Detection

If file paths are ambiguous, read the problem statement and relevant files for domain signals:

| Content signal | Domain |
|---------------|--------|
| CSS classes, Tailwind utilities, JSX/TSX markup, `className` | frontend |
| `useState`, `useEffect`, `useRouter`, component props | frontend |
| SQL queries, Drizzle ORM, `db.select()`, `db.insert()` | backend |
| API route handlers, `Hono`, `c.json()`, `c.req.param()` | backend |
| `CORS`, `helmet`, `csrf`, `XSS`, `sanitize`, `escape` | security |
| JWT, session tokens, `bcrypt`, `argon2`, `crypto` | security |
| CI pipeline, GitHub Actions YAML, deploy scripts | devops |
| Cloud provider SDKs, IAM, S3, CloudFront | cloud-infra |

### Step 4: Default

If no signals detected: `backend` (most common repair domain in this codebase).

## Domain Routing Table

After detection, use this table to configure the repair:

| Domain | Skills to load | Review agents | Test command | Fix patterns |
|--------|---------------|---------------|-------------|-------------|
| **frontend** | `frontend-design:frontend-design` | code-reviewer, type-design-analyzer, code-simplifier | `cd work-web && bun test` | See domain-patterns.md |
| **backend** | (none extra) | code-reviewer, silent-failure-hunter, pr-test-analyzer | `cd work-agents && bun test` | See domain-patterns.md |
| **security** | (none extra) | code-reviewer, silent-failure-hunter, pr-test-analyzer | Both test suites + security-specific tests | See domain-patterns.md |
| **devops** | `vercel:vercel-functions` (if Vercel) | code-reviewer | Validate configs + CI lint | See domain-patterns.md |
| **cloud-infra** | (none extra) | code-reviewer | `terraform validate` / `pulumi preview` | See domain-patterns.md |
| **fullstack** | `frontend-design:frontend-design` | ALL review agents | Both test suites | Combine frontend + backend patterns |

## Domain-Specific Review Agent Selection

When dispatching review agents during the review-fix phase, select based on domain:

### Frontend
```
- code-reviewer: focus on component logic, prop handling, state management
- type-design-analyzer: only if new types or interfaces are added/modified
- code-simplifier: always — frontend code benefits most from simplification
```

### Backend
```
- code-reviewer: focus on API correctness, data integrity, query efficiency
- silent-failure-hunter: ALWAYS — backend error handling is critical
- pr-test-analyzer: ALWAYS — backend needs high test coverage
```

### Security
```
- code-reviewer: focus on auth/authz logic, input validation, output encoding
- silent-failure-hunter: CRITICAL — silenced auth errors are vulnerabilities
- pr-test-analyzer: verify auth edge cases are tested (expired tokens, missing roles, injection)
```

### DevOps
```
- code-reviewer: focus on config correctness, no hardcoded secrets, proper env var usage
```

### Cloud Infra
```
- code-reviewer: focus on resource sizing, IAM least-privilege, network rules
```

## Hotfix Auto-Detection

A repair should automatically suggest `--hotfix` mode when:

1. Issue has label `priority/critical` or `priority/urgent`
2. Issue has label `security` with severity indicators
3. Problem statement mentions "production", "prod", "live site", "customer-facing"
4. The affected files are on the `main` branch but NOT on `staging` (rare but possible after a direct main fix)
5. The `--url` points to a production domain (`app.forthai.work`, `forthai.work`, `work.forth.ai`)

When auto-detected, report: `"Auto-detected hotfix: [reason]. Branching from main."`

## Integration with Repair Command

The repair command should:

1. Run domain detection (Steps 1-4 above)
2. Report detected domain(s): `"Domain: frontend (primary), security (secondary)"`
3. Load domain-specific skills (if any — use Skill tool)
4. Apply domain-specific search patterns during codebase research
5. Pass domain info to review-fix phase for agent selection
6. Pass domain info to verify phase for appropriate testing
