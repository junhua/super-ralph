# Domain-Specific Fix Patterns

Detailed guidance per domain for the repair command. These patterns supplement the generic TDD workflow with domain-aware constraints.

---

## Frontend

### Search Patterns
```bash
# Component files
Glob: "work-web/src/components/**/*.tsx"
Glob: "work-web/src/app/**/*.tsx"

# Styles
Glob: "work-web/src/**/*.css"
Grep: "className=" in work-web/

# State management
Grep: "useState|useReducer|useContext" in work-web/src/

# i18n
Glob: "work-web/src/i18n/*.ts"
```

### Fix Constraints
- **Shared file protocol:** Never modify `app-sidebar.tsx` nav arrays — only Junhua modifies those. Propose sidebar changes in the PR description instead.
- **i18n mandatory:** Every user-facing string must have EN + zh-CN translations. Add keys to BOTH `en.ts` and `zh-CN.ts`.
- **Component props:** Use explicit TypeScript interfaces for all component props — no inline types.
- **Accessibility:** Every interactive element needs `aria-*` attributes. Buttons need labels. Images need alt text.
- **Responsive:** Test at 360px, 768px, 1280px breakpoints.

### Test Patterns
```bash
# Run frontend tests
cd work-web && bun test

# Run specific component test
cd work-web && bun test src/components/MyComponent.test.tsx

# Type check
cd work-web && bunx tsc --noEmit
```

### Review Focus
- Visual regressions (layout shifts, overflow, z-index)
- Unhandled loading/error states in data fetching
- Missing `key` props in lists
- Stale closures in hooks
- Unnecessary re-renders

---

## Backend

### Search Patterns
```bash
# API routes
Glob: "work-agents/src/routes/**/*.ts"

# Services
Glob: "work-agents/src/services/**/*.ts"

# Database schema and queries
Glob: "work-agents/src/db/**/*.ts"

# Middleware
Glob: "work-agents/src/middleware/**/*.ts"
```

### Fix Constraints
- **Shared file protocol:** Append to section-delimited regions in `schema.ts`, never insert in the middle.
- **Route registration:** Append new routes at the END of the protected routes section in `src/index.ts`.
- **Error responses:** Always return structured JSON errors: `{ error: string, code: string }`.
- **Database migrations:** Schema changes need migration files — never modify production schema directly.
- **Input validation:** All route handlers must validate request body/params before processing.

### Test Patterns
```bash
# Run backend tests
cd work-agents && bun test

# Run specific test
cd work-agents && bun test src/services/myservice.test.ts

# Run with verbose output
cd work-agents && bun test --verbose
```

### Review Focus
- Unhandled promise rejections
- Missing database transaction boundaries
- N+1 query patterns
- Race conditions in concurrent operations
- Missing input validation on route handlers

---

## Security

### Search Patterns
```bash
# Auth middleware
Grep: "auth|session|jwt|token|bcrypt|argon" in work-agents/src/

# CORS config
Grep: "cors|origin|Access-Control" in work-agents/

# Input sanitization
Grep: "sanitize|escape|validate|zod" in work-agents/src/

# CSP headers
Grep: "Content-Security-Policy|helmet|csp" in work-agents/src/
```

### Fix Constraints
- **NEVER log credentials.** No passwords, tokens, API keys, or session IDs in logs.
- **NEVER weaken security for convenience.** No `*` CORS origins, no disabled CSRF, no `any` cast on auth types.
- **Token expiry mandatory.** JWTs and sessions must have finite expiry. No indefinite tokens.
- **Input validation at system boundary.** All user input must be validated before processing. Use Zod or equivalent.
- **Output encoding.** All data rendered in HTML must be escaped. All data in SQL must be parameterized.
- **Principle of least privilege.** Auth middleware must check the minimum required role. No `admin` checks where `user` suffices.

### Test Patterns
```bash
# Run all tests (security bugs can manifest anywhere)
cd work-agents && bun test
cd work-web && bun test

# Focus on auth tests
cd work-agents && bun test src/middleware/auth.test.ts
cd work-agents && bun test src/routes/auth.test.ts
```

### Review Focus (CRITICAL — all findings are high severity)
- Authentication bypass paths
- Authorization gaps (missing role checks)
- Injection vulnerabilities (SQL, XSS, command)
- Sensitive data exposure in responses or logs
- CORS misconfiguration
- Missing rate limiting on auth endpoints
- Timing attacks on token comparison

---

## DevOps

### Search Patterns
```bash
# CI/CD workflows
Glob: ".github/workflows/**/*.yml"

# Deployment config
Glob: "vercel.json"
Glob: "vercel.ts"
Glob: "**/Dockerfile*"
Glob: "**/docker-compose*.yml"

# Next.js config
Glob: "**/next.config.*"

# Package scripts
Grep: "scripts" in package.json
```

### Fix Constraints
- **No hardcoded secrets.** All credentials go through environment variables or Vercel env.
- **Path-filtered CI.** Changes in `work-web/` should only trigger work-web CI, etc. Don't break path filters.
- **Pin dependency versions.** Use exact versions in Dockerfiles and CI workflows. No `latest` tags.
- **Idempotent deployments.** Deploy scripts must be safe to re-run.

### Test Patterns
```bash
# Validate GitHub Actions workflows (if actionlint is installed)
actionlint .github/workflows/*.yml

# Validate Dockerfile
docker build --check .

# Validate next.config
cd work-web && bunx next lint

# Validate vercel.json
cat vercel.json | python3 -m json.tool > /dev/null
```

### Review Focus
- Leaked secrets in workflow files
- Missing environment variable references
- Broken path filters in CI
- Incorrect build commands
- Missing caching configuration

---

## Cloud Infrastructure

### Search Patterns
```bash
# Terraform
Glob: "**/*.tf"

# Pulumi
Glob: "**/Pulumi*.yaml"
Glob: "**/pulumi/**/*.ts"

# CDK
Glob: "**/cdk/**/*.ts"

# Cloud configs
Grep: "aws-sdk|@google-cloud|@azure" in **/package.json
```

### Fix Constraints
- **Least privilege.** IAM policies must grant minimum required permissions.
- **No public access by default.** Storage buckets, databases, and APIs should be private unless explicitly justified.
- **Cost awareness.** Don't over-provision resources. Check instance sizes.
- **Region consistency.** All resources should be in the same region unless there's a latency reason.

### Test Patterns
```bash
# Terraform
terraform validate
terraform plan

# Pulumi
pulumi preview

# CDK
cdk synth
```

### Review Focus
- Overly permissive IAM policies
- Publicly accessible resources
- Missing encryption at rest or in transit
- Hardcoded regions or account IDs
- Missing tags for cost tracking
