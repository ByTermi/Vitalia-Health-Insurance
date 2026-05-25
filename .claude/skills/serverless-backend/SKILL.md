---
name: serverless-backend
description: "Scaffold, develop, and deploy serverless backends on AWS Lambda, Azure Functions, or Google Cloud Functions. Covers API design, auth, database wiring, cost optimization, and CI/CD. Trigger: /serverless-backend"
trigger: /serverless-backend
---

# /serverless-backend

End-to-end serverless backend skill. Goes from zero to deployed API with the right architecture for your cloud provider, runtime, and use case — including auth, database, observability, and CI/CD.

## Usage

```
/serverless-backend                           # interactive setup wizard
/serverless-backend --provider aws            # AWS Lambda + API Gateway
/serverless-backend --provider azure          # Azure Functions
/serverless-backend --provider gcp            # Google Cloud Functions / Cloud Run
/serverless-backend --runtime node            # Node.js (default)
/serverless-backend --runtime python          # Python
/serverless-backend --runtime go              # Go
/serverless-backend --framework serverless    # Serverless Framework (default for AWS)
/serverless-backend --framework sam           # AWS SAM
/serverless-backend --framework terraform     # Terraform IaC
/serverless-backend --auth jwt                # JWT auth middleware
/serverless-backend --auth cognito            # AWS Cognito
/serverless-backend --auth firebase           # Firebase Auth
/serverless-backend --db dynamo               # DynamoDB
/serverless-backend --db postgres             # Serverless PostgreSQL (Aurora / Neon / Supabase)
/serverless-backend --db firestore            # Firestore
/serverless-backend --audit                   # audit existing serverless project for issues
/serverless-backend --cost                    # analyze current config for cost optimization
```

## What /serverless-backend Delivers

A production-ready serverless backend is not just "a Lambda that runs code." It requires:

1. **Cold start minimization** — bundle size, init code placement, Provisioned Concurrency decisions
2. **IAM least-privilege** — one role per function, no `*` Actions in prod
3. **Observability** — structured logs, distributed tracing, error alerting wired from day one
4. **Cost control** — timeout limits, memory tuning, concurrency caps, reserved capacity
5. **Local dev parity** — the ability to run and test functions locally before deploying

---

## What You Must Do When Invoked

If no flags were given, run the setup wizard (Step 1). If flags are present, skip to the relevant step.

---

### Step 1 — Setup wizard (when no flags given)

Ask the user exactly these questions, one message:

```
To scaffold your serverless backend, I need a few details:

1. Cloud provider: AWS / Azure / GCP
2. Primary runtime: Node.js / Python / Go / other
3. What does this backend do? (REST API / event processor / scheduled job / websocket / all of the above)
4. Authentication needed? (None / JWT / OAuth / Cognito / Firebase Auth)
5. Database? (None / DynamoDB / PostgreSQL / MongoDB Atlas / Firestore / Redis)
6. Deployment tool preference: Serverless Framework / AWS SAM / Terraform / CDK / (I'll pick the best one)
```

Wait for answers before proceeding.

---

### Step 2 — Project scaffold

Based on the chosen provider and runtime, generate the project structure:

#### AWS Lambda + Serverless Framework (Node.js)

```
project/
├── serverless.yml          # service definition
├── src/
│   ├── functions/
│   │   ├── hello/
│   │   │   ├── handler.ts
│   │   │   └── schema.ts   # Zod / Joi input schema
│   │   └── users/
│   │       ├── create.ts
│   │       ├── get.ts
│   │       └── schema.ts
│   ├── lib/
│   │   ├── db.ts           # database client (singleton, outside handler)
│   │   ├── auth.ts         # JWT / Cognito verifier
│   │   ├── middleware.ts    # error handling, CORS, logging wrapper
│   │   └── response.ts     # standardized API response helpers
│   └── types/
│       └── index.ts
├── tests/
│   ├── unit/
│   └── integration/
├── package.json
├── tsconfig.json
└── .env.example
```

Generate each file with working, production-quality code — not stubs.

#### Key `serverless.yml` patterns to always include:

```yaml
service: my-service
frameworkVersion: '3'

provider:
  name: aws
  runtime: nodejs20.x
  region: ${opt:region, 'us-east-1'}
  stage: ${opt:stage, 'dev'}
  memorySize: 512          # tune per function — default 512, not 1024
  timeout: 10              # never leave at 30s default for API functions
  logRetentionInDays: 14
  tracing:
    lambda: true           # X-Ray tracing
  environment:
    STAGE: ${self:provider.stage}
    # secrets via SSM Parameter Store, not plaintext
    DB_URL: ${ssm:/myapp/${self:provider.stage}/db-url}
  iam:
    role:
      statements:
        - Effect: Allow
          Action:
            - dynamodb:GetItem
            - dynamodb:PutItem
            - dynamodb:UpdateItem
            - dynamodb:DeleteItem
            - dynamodb:Query
          Resource:
            - !GetAtt UsersTable.Arn
            - !Sub '${UsersTable.Arn}/index/*'

functions:
  getUser:
    handler: src/functions/users/get.handler
    events:
      - httpApi:
          path: /users/{id}
          method: GET
    memorySize: 256         # override per function when justified
```

---

### Step 3 — Handler pattern

Every handler must follow this pattern. Generate it for the user's chosen runtime:

#### Node.js TypeScript (AWS)

```typescript
import { APIGatewayProxyHandlerV2 } from 'aws-lambda'
import { z } from 'zod'
import { db } from '../../lib/db'
import { ok, err, parseBody } from '../../lib/response'
import { requireAuth } from '../../lib/auth'

const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
})

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  const user = requireAuth(event)   // throws 401 if invalid
  const body = parseBody(event, CreateUserSchema)  // throws 400 if invalid

  const result = await db.put({
    TableName: process.env.USERS_TABLE!,
    Item: { id: crypto.randomUUID(), email: body.email, name: body.name, createdAt: new Date().toISOString() },
  })

  return ok({ id: result.id })
}
```

Rules enforced in the pattern:
- Database client initialized **outside** the handler (singleton across warm invocations)
- Input validated before any business logic
- Auth checked before any business logic
- Errors thrown (caught by middleware wrapper), not returned manually
- No `console.log` — use structured logger (`pino` / `winston`)

---

### Step 4 — Auth wiring

#### JWT (provider-agnostic)

```typescript
// src/lib/auth.ts
import { APIGatewayProxyEventV2 } from 'aws-lambda'
import { createRemoteJWKSet, jwtVerify } from 'jose'

const JWKS = createRemoteJWKSet(new URL(process.env.JWKS_URI!))

export async function requireAuth(event: APIGatewayProxyEventV2) {
  const token = event.headers.authorization?.replace('Bearer ', '')
  if (!token) throw Object.assign(new Error('Unauthorized'), { statusCode: 401 })

  const { payload } = await jwtVerify(token, JWKS, {
    issuer: process.env.JWT_ISSUER,
    audience: process.env.JWT_AUDIENCE,
  })
  return payload
}
```

#### AWS Cognito (preferred for AWS-native projects)

Use a Lambda Authorizer or HTTP API JWT authorizer — do not implement token verification in every function. Generate the `serverless.yml` authorizer config.

---

### Step 5 — Database client pattern

#### DynamoDB (AWS)

```typescript
// src/lib/db.ts — initialized ONCE outside handler
import { DynamoDBClient } from '@aws-sdk/client-dynamodb'
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb'

const client = new DynamoDBClient({})
export const db = DynamoDBDocumentClient.from(client, {
  marshallOptions: { removeUndefinedValues: true },
})
```

#### PostgreSQL (serverless-safe)

Use `@neondatabase/serverless` (Neon) or `postgres` with connection pooling via RDS Proxy or PgBouncer. Never use `pg` directly against RDS without a proxy — connection exhaustion will happen under Lambda concurrency.

```typescript
import { neon } from '@neondatabase/serverless'

const sql = neon(process.env.DATABASE_URL!)  // connection created per invocation, pooled internally
```

---

### Step 6 — Local development

Generate a `package.json` script and configuration for local invocation:

```json
{
  "scripts": {
    "dev": "serverless offline --stage local",
    "invoke:local": "serverless invoke local --function",
    "test": "vitest run",
    "test:integration": "vitest run tests/integration",
    "deploy:dev": "serverless deploy --stage dev",
    "deploy:prod": "serverless deploy --stage prod"
  }
}
```

For AWS SAM: `sam local start-api` with Docker.
For Azure: `func start`.
For GCP: `functions-framework`.

---

### Step 7 — Observability

Always wire these three:

**Structured logging** (not `console.log`):
```typescript
import pino from 'pino'
export const logger = pino({ level: process.env.LOG_LEVEL ?? 'info' })
// Usage: logger.info({ userId, action: 'createUser' }, 'User created')
```

**Error tracking**: Add Sentry or PowerTools Logger depending on scale. For AWS, Lambda PowerTools is the standard:
```typescript
import { Logger } from '@aws-lambda-powertools/logger'
import { Tracer } from '@aws-lambda-powertools/tracer'
```

**Alerting**: Generate a CloudWatch alarm for function error rate > 1% and duration > 80% of timeout.

---

### Step 8 — Cost optimization checklist

Print this after scaffold:

```
Cost levers for this project:
  [ ] Memory: set per-function, not globally (use Lambda Power Tuning to find optimal)
  [ ] Timeout: API functions → 10s max. Async processors → 60-300s.
  [ ] Concurrency: set reserved concurrency on critical functions to prevent runaway costs
  [ ] DynamoDB: use on-demand billing for dev, switch to provisioned + auto-scaling in prod
  [ ] Log retention: set logRetentionInDays (default is NEVER = costs accumulate forever)
  [ ] X-Ray: sample at 5% in prod (not 100%) to control tracing costs
  [ ] Dead Letter Queues: wire DLQ on async functions to catch and inspect failures cheaply
```

---

### Step 9 — CI/CD

Generate a GitHub Actions workflow (or ask which CI the user uses):

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - run: npm test

  deploy-dev:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - run: npx serverless deploy --stage dev
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

---

### For --audit (existing project)

Read the existing `serverless.yml` / `template.yaml` / `terraform/` and check:

- Functions with `timeout: 30` or higher on HTTP endpoints → flag
- Functions with `memorySize: 1024` or higher without justification → flag
- IAM statements with `Action: "*"` or `Resource: "*"` → CRITICAL
- No `logRetentionInDays` set → flag
- Environment variables containing secrets as plaintext (not SSM refs) → CRITICAL
- No error monitoring or alerting configured → flag
- Single IAM role for all functions → flag (recommend per-function roles)

---

### For --cost

Analyze current configuration and estimate monthly cost based on approximate invocation volume (ask user if unknown):

```
Cost estimate (1M invocations/month, 512MB, 200ms avg duration):
  Compute:  $0.83/month  (free tier covers first 400K GB-seconds)
  Requests: $0.20/month  (free tier covers first 1M)
  API GW:   $3.50/month  (HTTP API, not REST API — 70% cheaper)
  DynamoDB: $1.25/month  (on-demand, 1M reads + 500K writes)
  Total:    ~$5.78/month

Optimization opportunities:
  → Switch REST API to HTTP API: saves $8/month at 2M req/month
  → Reduce memory from 1024MB to 512MB on 3 functions: saves $0.40/month
  → Enable DynamoDB auto-scaling: prevents $40+ spike under load
```

---

## Honesty Rules

- Never hardcode secrets. Always use SSM Parameter Store, Secrets Manager, or env-specific secret backends.
- Never set IAM `Resource: "*"` — always scope to specific resource ARNs.
- Never use `console.log` for structured logging — always use a proper logger.
- Flag cold start times over 1s as a real UX problem, not just a metric.
- If the user's architecture has a pattern that will cause cold-start or cost issues at scale, say so before generating the code.
