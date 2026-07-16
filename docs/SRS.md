# Software Requirements Specification (SRS)  
## Rails AI Build — Complete Product Requirements

| Field | Value |
|-------|-------|
| **Product** | Rails AI Build (`rails_ai_build`) |
| **Version covered** | 2.6.0+ (living document) |
| **Document status** | Normative product contract |
| **Audience** | Engineering, Product, QA, Security, GTM, Enterprise sales |
| **Related** | [CLIENT_JOURNEY_MASTER_PLAN.md](./CLIENT_JOURNEY_MASTER_PLAN.md), [FLOWS.md](./FLOWS.md), [SECURITY.md](../SECURITY.md), OpenAPI `packages/core-protocol/openapi.yaml` |

**Purpose of this SRS:** Define *every* capability a client must be able to perform after installing the gem — with API key, Cloud key, Dashboard/IDE, or paid plan — so the company never ships a silent gap. If a requirement here is unmet, that is a defect.

**Product promise:**  
*Cursor lives in your editor. We live in your app.*  
Install once → activate (BYOK / Cloud / License) → ask for anything in the codebase → agent plans, edits, verifies, and ships — within plan limits.

---

## Table of contents

1. [Introduction](#1-introduction)
2. [Stakeholders & actors](#2-stakeholders--actors)
3. [System context & distribution](#3-system-context--distribution)
4. [Entitlement & activation model](#4-entitlement--activation-model)
5. [Functional requirements — Activation & settings](#5-functional-requirements--activation--settings)
6. [Functional requirements — AI agent core](#6-functional-requirements--ai-agent-core)
7. [Functional requirements — IDE & Web UI](#7-functional-requirements--ide--web-ui)
8. [Functional requirements — Build, tasks, skills](#8-functional-requirements--build-tasks-skills)
9. [Functional requirements — Review, git, ship](#9-functional-requirements--review-git-ship)
10. [Functional requirements — Team & collaboration](#10-functional-requirements--team--collaboration)
11. [Functional requirements — Enterprise & governance](#11-functional-requirements--enterprise--governance)
12. [Functional requirements — Marketplace & MCP](#12-functional-requirements--marketplace--mcp)
13. [Functional requirements — Analytics, help, doctor](#13-functional-requirements--analytics-help-doctor)
14. [Functional requirements — Billing & cloud](#14-functional-requirements--billing--cloud)
15. [Functional requirements — CLI, SDKs, server, CI, bots](#15-functional-requirements--cli-sdks-server-ci-bots)
16. [Data requirements](#16-data-requirements)
17. [API & protocol requirements](#17-api--protocol-requirements)
18. [Non-functional requirements](#18-non-functional-requirements)
19. [Plan feature matrix (normative)](#19-plan-feature-matrix-normative)
20. [Environment & configuration](#20-environment--configuration)
21. [Acceptance, QA & release gates](#21-acceptance-qa--release-gates)
22. [Out of scope](#22-out-of-scope)
23. [Traceability & completeness checklist](#23-traceability--completeness-checklist)
24. [Glossary](#24-glossary)

---

## 1. Introduction

### 1.1 Product identity

| Item | Requirement |
|------|-------------|
| Gem name | `rails_ai_build` |
| Ruby | ≥ 3.1 |
| Rails host | ≥ 7.0 (supported through 8.x in CI) |
| License | MIT (open core) |
| Commercial layers | Pro / Team / Enterprise + Rails AI Cloud |

### 1.2 Problem statement

Teams need Cursor-class AI coding **inside** their Rails app, CI, and compliance boundary — not only in a desktop IDE. Generic AI tools lack Rails conventions, team audit, embeddable admin UX, and self-host options.

### 1.3 Goals

| ID | Goal |
|----|------|
| G-01 | Time-to-first-successful-agent-run &lt; 15 minutes after install |
| G-02 | Every Cursor-class action has an entitlement path (Free BYOK → Pro → Team → Enterprise) |
| G-03 | Paying customers keep plan across redeploys (durable entitlements) |
| G-04 | Same capability story across IDE, CLI, API, SDK, CI, bots |
| G-05 | Host can self-host and govern tools (Enterprise) |
| G-06 | Open-core distribution remains free for local BYOK forever |

### 1.4 Definitions of done (product-level)

A release is **SRS-complete** only if:

1. New install → doctor → activate → first ask works without reading more than one page  
2. Every feature in §19 is demoable end-to-end on the correct plan  
3. Plan cannot be spoofed via open settings  
4. OpenAPI matches shipped routes for activation, doctor, billing, and core AI  
5. Upgrade path exists for existing hosts (`rails generate rails_ai_build:upgrade` + migrate)

---

## 2. Stakeholders & actors

| Actor | Description | Primary surfaces |
|-------|-------------|------------------|
| **Solo developer** | Installs gem, BYOK, uses IDE/CLI | IDE, CLI, Free/Pro |
| **Team engineer** | Shared agents, PRs, Slack | IDE, bots, Team |
| **Engineering manager** | Audit, analytics, approvals | Dashboard, audit, Team+ |
| **Platform / DevOps** | CI agent, self-host, secrets | CI generator, Enterprise |
| **Security / compliance** | SSO, RBAC, audit export | Enterprise |
| **Agency / multi-project** | Multiple workspaces, seats | Team / Enterprise |
| **Open-source contributor** | Packs, community submissions | Marketplace |
| **Host application** | Rails app mounting the engine | Engine mount, auth wrapper |
| **Rails AI Cloud** | Hosted models + future org accounts | Cloud key, billing |
| **Automation / CI** | Non-interactive agent runs | GitHub Action, API token |

---

## 3. System context & distribution

### 3.1 Deployment topologies (all required)

| ID | Topology | Requirement |
|----|----------|-------------|
| TOP-01 | **Rails engine** | Gem mounts at `/rails_ai_build` when `auto_mount = true` |
| TOP-02 | **Standalone Rack server** | `server/` serves chat/tools/trust on configurable port (default 9292) |
| TOP-03 | **Python SDK** | `pip install rails-ai-build` — local tools or remote client |
| TOP-04 | **JavaScript SDK** | `npm i @rails-ai-build/sdk` — local tools or remote client |
| TOP-05 | **CI Action** | Generator installs workflow; Action can ask agent + open PR |
| TOP-06 | **Self-host Enterprise** | Docker Compose path via enterprise generator |
| TOP-07 | **Marketing / trust** | Landing + trust sandboxes demonstrate live value |

### 3.2 Capability pillars (must not have blank cells)

| Pillar | Meaning |
|--------|---------|
| **Talk** | Chat, stream, multi-turn sessions, memory |
| **See** | File tree, grep, Rails introspection tools |
| **Change** | write_file, skills, builder, multitask |
| **Review** | Diff preview, apply/reject, approval workflow |
| **Ship** | Git, PR, CI, Slack/Discord |
| **Govern** | RBAC, SSO, audit, seats, plan gates |
| **Extend** | Marketplace, MCP, custom models |
| **Operate** | Doctor, analytics, billing, settings, upgrade |

---

## 4. Entitlement & activation model

### 4.1 Three activation doors (normative)

| Door | ID | Client action | System result |
|------|-----|---------------|---------------|
| **A — BYOK** | ACT-BYOK | Paste OpenAI / Anthropic / NVIDIA / custom key | Keys encrypted at rest; provider selected; Free features unlock |
| **B — Cloud** | ACT-CLOUD | Paste Rails AI Cloud key | `cloud_api_key` stored; default provider → cloud; hosted models (Pro+) |
| **C — Paid** | ACT-PAID | License token and/or Stripe checkout | Durable plan on `rails_ai_build_activations`; features from §19 |

**Rule ACT-R1:** Client MUST be able to start productive work through **any one** door.  
**Rule ACT-R2:** Plan MUST NOT be settable via unauthenticated or open `PATCH /settings`.  
**Rule ACT-R3:** Entitlement source MUST be recorded (`free` | `license` | `billing` | `config`).

### 4.2 Plan tiers

| Plan | Price | Intent |
|------|-------|--------|
| Free | $0 | Viral adoption, local BYOK, streaming |
| Pro | $29/mo | Individual power (diffs, memory, git, MCP, hosted models) |
| Team | $99/seat/mo | Org workflow (shared agents, audit, PR, bots, analytics) |
| Enterprise | Custom | SSO, RBAC, self-host, SLA/SOC2 packaging |

### 4.3 Gating behavior

| ID | Requirement |
|----|-------------|
| GATE-01 | Missing feature raises `PlanRequiredError` |
| GATE-02 | HTTP APIs return **402** with JSON: `code=plan_required`, `feature`, `current_plan`, `suggested_plan`, `upgrade`, `checkout` |
| GATE-03 | IDE MUST open upgrade modal on 402 / plan badge / locked features |
| GATE-04 | Checkout CTA calls `POST /billing/checkout` or falls back to pricing URL |

---

## 5. Functional requirements — Activation & settings

| ID | Requirement | Priority | Plan |
|----|-------------|----------|------|
| ACT-001 | Install generator creates tables, initializer, mounts engine | Must | Free |
| ACT-002 | Upgrade generator copies activations migration if missing; stamps version | Must | Free |
| ACT-003 | Engine appends gem migrations so hosts get activations via `db:migrate` | Must | Free |
| ACT-004 | First IDE open shows Activate wizard when no keys/license | Must | Free |
| ACT-005 | Wizard doors: BYOK, Cloud key, License | Must | Free |
| ACT-006 | `POST /settings/keys` encrypts and persists API keys | Must | Free |
| ACT-007 | `POST /settings/keys` with cloud key sets `default_provider=:cloud` | Must | Free |
| ACT-008 | `POST /settings/license` verifies signed token and applies durable plan | Must | Free |
| ACT-009 | `POST /settings/wizard/complete` marks wizard done | Must | Free |
| ACT-010 | `POST /settings/bootstrap` issues settings token once | Must | Free |
| ACT-011 | Settings mutations require `X-Rails-Ai-Build-Token` when token issued | Must | Free |
| ACT-012 | `GET /settings` returns activation status; never raw secrets | Must | Free |
| ACT-013 | `PATCH /settings` updates provider/model/flags; rejects `plan` | Must | Free |
| ACT-014 | Boot loads activation row into `Configuration` | Must | Free |
| ACT-015 | Local/dev may bypass settings auth until token exists | Should | Free |
| ACT-016 | Production hosts SHOULD set `RAILS_AI_BUILD_SETTINGS_TOKEN` or bootstrap | Must | All |
| ACT-017 | Skip wizard persists preference without blocking IDE | Should | Free |
| ACT-018 | Guided first prompt after activation (e.g. health endpoint) | Must | Free |

---

## 6. Functional requirements — AI agent core

### 6.1 Providers & models

| ID | Requirement | Priority | Plan |
|----|-------------|----------|------|
| AI-001 | Support OpenAI-compatible chat + tools | Must | Free |
| AI-002 | Support Anthropic | Must | Free |
| AI-003 | Support NVIDIA NIM (`nvapi-…`) and prefer when present | Must | Free |
| AI-004 | Support custom / OpenAI-compatible (Ollama, etc.) | Must | Free |
| AI-005 | Support Cloud hosted provider | Must | Pro+ |
| AI-006 | `POST /models/test` validates credentials | Must | Free |
| AI-007 | `GET /models/providers` lists registered providers | Must | Free |
| AI-008 | Token usage tracked on all plans | Must | Free |

### 6.2 Agent loop & tools

| ID | Requirement | Priority | Plan |
|----|-------------|----------|------|
| AI-010 | Agent can `read_file`, `write_file`, `grep`, `list_files`, `shell` | Must | Free |
| AI-011 | Paths resolve relative to app root; aliases like `workspace` map correctly | Must | Free |
| AI-012 | Path traversal outside workspace MUST be blocked | Must | Free |
| AI-013 | Shell respects timeout (`shell_timeout`) | Must | Free |
| AI-014 | Boost tools: application_info, list_routes, database_schema, list_rake_tasks, read_settings, read_logs, search_rails_docs, list_models, run_rails_check, list_migrations, model_attributes | Must | Free (via boost) |
| AI-015 | `allowed_tools` config restricts tool set | Must | Free |
| AI-016 | Generator-first: IntentRouter scores catalog; prefer `run_generator` over freeform writes | Must | Free |
| AI-017 | Host Safety: syntax gate, boot ladder for critical paths, auto `rollback_session` | Must | Free |
| AI-018 | IDE Undo last run + `POST /changes/rollback_session` | Must | Free |
| AI-019 | Soft-preview boot-critical paths; Gemfile `bundle check`; migration `\d{14}_` validator | Must | Free |
| AI-020 | Optional shadow worktree promote-on-green; SSE host_safety phases; Doctor host_safety | Should | Free |
| AI-016 | RBAC further restricts tools when enabled | Must | Enterprise |
| AI-017 | Max iterations enforced per plan | Must | All |
| AI-018 | Intelligence.prepare! runs before AI requests (heal dirs/migrations/structure) | Must | Free |
| AI-019 | Humanized tool feedback in streams | Should | Free |

### 6.3 Streaming & sessions

| ID | Requirement | Priority | Plan |
|----|-------------|----------|------|
| AI-020 | SSE streaming on Free+ (`streaming` feature) | Must | Free |
| AI-021 | Stream events include status/context/session/delta/tool_call/tool_result/done | Must | Free |
| AI-022 | Multi-turn sessions via `/ai/sessions` | Must | Free |
| AI-023 | Agent memory persistence | Must | Pro+ |
| AI-024 | Sync chat fallback when streaming unavailable | Should | Free |

### 6.4 Chat / driver APIs

| ID | Requirement | Priority | Surface |
|----|-------------|----------|---------|
| AI-030 | `POST /chat` one-shot sync | Must | API |
| AI-031 | `POST /ai/chat` session-aware chat | Must | API |
| AI-032 | `POST /ai/stream` SSE agent | Must | IDE/API |
| AI-033 | `POST /stream` SSE (legacy/compat) | Must | API |
| AI-034 | Soft identity via `X-User-Id` for audit | Should | API |

---

## 7. Functional requirements — IDE & Web UI

| ID | Requirement | Priority | Plan |
|----|-------------|----------|------|
| UI-001 | IDE at `/` and `/ui/ide` | Must | Free |
| UI-002 | File explorer via workspace tree/file APIs | Must | Free |
| UI-003 | Editor view for opened files | Must | Free |
| UI-004 | Agent panel with prompt, skill, mode, provider | Must | Free |
| UI-005 | Enter sends; Shift+Enter newline; auto-grow prompt | Must | Free |
| UI-006 | Live progress / status bar during runs | Must | Free |
| UI-007 | Themes: at least Dark, Light + additional palettes | Must | Free |
| UI-008 | Plan badge shows current plan; click opens upgrade | Must | Free |
| UI-009 | Activate button reopens wizard | Must | Free |
| UI-010 | Right tabs: Tasks, Changes, Git, Doctor, Enterprise | Must | Free |
| UI-011 | Doctor tab renders `GET /support/doctor` checks | Must | Free |
| UI-012 | Upgrade modal with checkout + pricing link | Must | Free |
| UI-013 | Dashboard at `/ui` for simpler chat/ops | Must | Free |
| UI-014 | Demo at `/ui/demo` works without API key | Must | Free |
| UI-015 | Provider dropdown defaults to configured provider | Must | Free |
| UI-016 | Applied files feedback after writes | Should | Free |
| UI-017 | Mobile/responsive usable layout (core chat + prompt) | Should | Free |
| UI-018 | Empty states explain next action (no key / no git / locked feature) | Must | Free |

---

## 8. Functional requirements — Build, tasks, skills

| ID | Requirement | Priority | Plan |
|----|-------------|----------|------|
| BLD-001 | Universal builder `build` / `fix` / `test` | Must | Free |
| BLD-002 | `POST /build` and `POST /build/stream` | Must | Free |
| BLD-003 | Verify loop with configurable max attempts | Must | Free |
| BLD-004 | Skills registry: crud, auth, api, tests, refactor, migration, build, fix, feature | Must | Free |
| BLD-005 | `POST /skills/run` and CLI `rails_ai_build:skill` | Must | Free |
| BLD-006 | Multitask queue with statuses queued/running/success/failed/cancelled | Must | Free |
| BLD-007 | Concurrent task cap (`max_concurrent_tasks`) without thread storm | Must | Free |
| BLD-008 | Optional branch-per-task and auto-PR on complete | Should | Team+ |
| BLD-009 | Task SSE via `POST /tasks/:id/stream` | Must | Free |
| BLD-010 | Multi-agent orchestration planner→coder→reviewer | Must | Team+ |
| BLD-011 | `POST /orchestrate` and CLI orchestrate | Must | Team+ |
| BLD-012 | Background `AgentRunJob` for async runs | Must | Free |

---

## 9. Functional requirements — Review, git, ship

| ID | Requirement | Priority | Plan |
|----|-------------|----------|------|
| REV-001 | Diff preview queues writes when enabled | Must | Pro+ |
| REV-002 | Free plan documents auto-apply vs preview clearly | Must | Free |
| REV-003 | `GET /changes`, apply, reject, apply_all, rollback_session | Must | Pro+ |
| REV-004 | Approval workflow for high-risk changes (RBAC reviewer/admin) | Must | Team+ |
| GIT-001 | Git status/diff/commit APIs | Must | Pro+ |
| GIT-002 | IDE Git panel | Must | Pro+ |
| GIT-003 | `POST /pull_requests` creates GitHub/GitLab compare/PR | Must | Team+ |
| GIT-004 | CI generator installs workflow for PR review / dispatch | Must | Free* |
| GIT-005 | GitHub Action can run prompt with host API key | Must | Free* |

\*CI itself may run on Free with BYOK; Team features (auto PR from product) remain gated.

---

## 10. Functional requirements — Team & collaboration

| ID | Requirement | Priority | Plan |
|----|-------------|----------|------|
| TM-001 | Shared agents CRUD + run | Must | Team+ |
| TM-002 | Team dashboard / analytics | Must | Team+ |
| TM-003 | Audit log API + IDE load | Must | Team+ |
| TM-004 | Slack bot slash command | Must | Team+ |
| TM-005 | Discord interactions endpoint | Must | Team+ |
| TM-006 | Community pack submit + approve | Must | Team+ |
| TM-007 | Workspaces concept for multi-project | Should | Team+ |
| TM-008 | Soft user identity on runs for audit | Should | Team+ |
| TM-009 | Seat / invite model (org members) | Future | Team+ |
| TM-010 | Durable org account sync from Cloud | Future | Team+ |

---

## 11. Functional requirements — Enterprise & governance

| ID | Requirement | Priority | Plan |
|----|-------------|----------|------|
| ENT-001 | SSO/SAML config endpoint `GET /auth/saml` | Must | Enterprise |
| ENT-002 | SAML env-based IdP settings documented | Must | Enterprise |
| ENT-003 | RBAC roles: admin, developer, reviewer, viewer | Must | Enterprise |
| ENT-004 | RBAC enforces tool allowlists when enabled | Must | Enterprise |
| ENT-005 | Self-host Docker generator (compose + Dockerfile) | Must | Enterprise |
| ENT-006 | Air-gap / VPC deployment documented | Must | Enterprise |
| ENT-007 | Custom models registration | Must | Enterprise |
| ENT-008 | Admin generator for Devise-gated host mount | Should | Enterprise |
| ENT-009 | SOC2 / SLA packaging (ops + claims only when true) | Future | Enterprise |
| ENT-010 | Audit export JSON/CSV (`GET /audit/export`) | Must | Team+ |
| ENT-011 | Rate limits on AI endpoints (`RAILS_AI_BUILD_RATE_LIMIT`) | Must | All |

---

## 12. Functional requirements — Marketplace & MCP

| ID | Requirement | Priority | Plan |
|----|-------------|----------|------|
| MKT-001 | Built-in packs: crud-pro, rspec-writer, security-audit, hotwire-scaffold | Must | Free browse |
| MKT-002 | `GET /marketplace`, `POST /marketplace/:id/install` | Must | Free |
| MKT-003 | Community submissions require Team+ | Must | Team+ |
| MKT-004 | Paid packs + creator payouts | Future | Platform |
| MCP-001 | MCP server protocol methods: initialize, tools/list, tools/call, ping | Must | Pro+ |
| MCP-002 | `POST /mcp`, `GET /mcp/tools` | Must | Pro+ |
| MCP-003 | External MCP client connect support | Should | Pro+ |

---

## 13. Functional requirements — Analytics, help, doctor

| ID | Requirement | Priority | Plan |
|----|-------------|----------|------|
| OPS-001 | `GET /support/doctor` returns checks + activation + encryption | Must | Free |
| OPS-002 | Doctor checks: api_keys, activation, encryption, workspace, rails, gemfile, migrations, providers, tools, plan, upgrade, permissions/disk | Must | Free |
| OPS-003 | CLI `rails_ai_build:doctor` mirrors API | Must | Free |
| OPS-004 | Help topics API + CLI | Must | Free |
| OPS-005 | Topics include getting-started, api-keys, skills, diff-preview, troubleshooting, analytics, web-ui, upgrade | Must | Free |
| OPS-006 | `GET /support/contact` returns support channels | Must | Free |
| OPS-007 | Basic token tracking always on | Must | Free |
| OPS-008 | Full analytics dashboard Team+ | Must | Team+ |
| OPS-009 | `GET /analytics`, `GET /tokens` | Must | Free/Team |
| OPS-010 | CLI `rails_ai_build:stats` | Must | Free |
| OPS-011 | Compatibility & trust rake tasks for quality | Should | Free |

---

## 14. Functional requirements — Billing & cloud

| ID | Requirement | Priority | Plan |
|----|-------------|----------|------|
| BILL-001 | `POST /billing/checkout` creates Stripe session for pro/team | Must | Free→Paid |
| BILL-002 | Webhook upgrades/downgrades via durable `Activation.apply_plan!` | Must | Paid |
| BILL-003 | Clear error when Stripe not configured | Must | Free |
| BILL-004 | Customer portal / invoices via `POST /billing/portal` | Must | Paid |
| CLOUD-001 | Cloud client sends Bearer cloud API key | Must | Pro+ |
| CLOUD-002 | Hosted models gated by `hosted_models` | Must | Pro+ |
| CLOUD-003 | Configurable cloud base URL | Should | Pro+ |
| CLOUD-004 | Soft-fail messaging + BYOK CTA (no silent swap) | Must | Pro+ |
| CLOUD-005 | Live cloud accounts, metering, org sync | Future | Cloud SaaS |
| CLOUD-006 | License JWT short TTL + offline grace (Enterprise) | Future | Enterprise |

---

## 15. Functional requirements — CLI, SDKs, server, CI, bots

### 15.1 Rake / CLI

| ID | Command / capability | Priority |
|----|----------------------|----------|
| CLI-001 | `setup`, `ask`, `skill`, `build`, `fix`, `test` | Must |
| CLI-002 | `pending`, `apply`, `remember` | Must |
| CLI-003 | `doctor`, `help`, `stats`, `upgrade` | Must |
| CLI-004 | `tasks`, `orchestrate` | Must |
| CLI-005 | `fix_migrations` | Must |
| CLI-006 | Compatibility suite + trust runners | Should |

### 15.2 Generators

| ID | Generator | Priority |
|----|-----------|----------|
| GEN-001 | `install` | Must |
| GEN-002 | `upgrade` | Must |
| GEN-003 | `boost` | Must |
| GEN-004 | `admin` | Should |
| GEN-005 | `bot` (slack/discord) | Must |
| GEN-006 | `ci` | Must |
| GEN-007 | `enterprise` | Must |

### 15.3 SDKs & standalone server

| ID | Requirement | Priority |
|----|-------------|----------|
| SDK-001 | Python `ask` / `configure` / CLI parity for core chat | Must |
| SDK-002 | JS `ask` / `configure` / CLI parity for core chat | Must |
| SDK-003 | Remote client against engine or standalone server | Must |
| SDK-004 | Standalone `/health`, `/chat`, `/models/*`, `/tools` | Must |
| SDK-005 | Trust preview endpoints on standalone server | Should |
| SDK-006 | OpenAPI is source of truth for shared protocol | Must |

### 15.4 Bots & CI

| ID | Requirement | Priority | Plan |
|----|-------------|----------|------|
| BOT-001 | Slack signing secret verification when configured | Must | Team+ |
| BOT-002 | Discord interaction handler | Must | Team+ |
| CI-001 | Generated workflow_dispatch + PR review | Must | Free+ |
| CI-002 | Secrets documented (`OPENAI_API_KEY` etc.) | Must | Free+ |

---

## 16. Data requirements

### 16.1 Persistent tables (must exist after migrate)

| Table | Purpose |
|-------|---------|
| `rails_ai_build_agents` | Persisted agents |
| `rails_ai_build_conversations` | Agent conversations |
| `rails_ai_build_messages` | Messages / tool_calls |
| `rails_ai_build_model_configs` | Named model configs |
| `rails_ai_build_audit_logs` | Audit trail |
| `rails_ai_build_shared_agents` | Team shared agents |
| `rails_ai_build_usage_records` | Usage / tokens |
| `rails_ai_build_community_packs` | Community marketplace |
| `rails_ai_build_activations` | Encrypted keys, license, durable plan, wizard, settings token |

### 16.2 In-memory / ephemeral (document behavior)

| Store | Behavior requirement |
|-------|----------------------|
| AI sessions | Survive process lifetime; document restart loss unless later persisted |
| Task queue | Bounded workers; no unbounded thread spawn |
| Changes store | Pending diffs until apply/reject |
| Agent memory | Pro+; document persistence backend |
| Audit/analytics fallback | Memory if DB unavailable; prefer DB when migrated |

### 16.3 Data rules

| ID | Requirement |
|----|-------------|
| DATA-01 | API keys encrypted at rest (`rab1:` MessageEncryptor) |
| DATA-02 | Settings GET never returns decrypted secrets |
| DATA-03 | License tokens stored; plan derived from verified payload |
| DATA-04 | Migrations auto-heal duplicate/bad versions in local envs |
| DATA-05 | Install + upgrade paths keep schema complete |

---

## 17. API & protocol requirements

| ID | Requirement |
|----|-------------|
| API-01 | Engine routes listed in `config/routes.rb` are the runtime contract |
| API-02 | OpenAPI MUST document: settings (+ keys/license/wizard/bootstrap), doctor, plans, billing checkout, chat, agents, plan_required schema |
| API-03 | Breaking API changes require CHANGELOG + OpenAPI version bump |
| API-04 | JSON errors use stable `code` fields where gated (`plan_required`, `settings_auth_required`, `invalid_license`) |
| API-05 | SSE content-type and event framing consistent across stream endpoints |
| API-06 | MCP protocol version documented (`2024-11-05` or successor) |

### 17.1 Core route inventory (normative checklist)

**AI:** `/chat`, `/ai/chat`, `/ai/stream`, `/stream`, `/build`, `/build/stream`, `/ai/sessions`, `/tasks`, `/orchestrate`  
**Workspace:** `/workspace/tree`, `/workspace/file`  
**Changes/Git:** `/changes*`, `/git/*`, `/pull_requests`  
**Config:** `/settings*`, `/plans`, `/billing/*`, `/support/*`, `/help*`  
**Team:** `/shared_agents`, `/audit`, `/analytics`, `/tokens`, `/marketplace`, `/community`  
**Integrations:** `/slack/command`, `/discord/interactions`, `/mcp`, `/auth/saml`  
**UI:** `/`, `/ui`, `/ui/ide`, `/ui/demo`, `/api`

---

## 18. Non-functional requirements

### 18.1 Security

| ID | Requirement | Priority |
|----|-------------|----------|
| SEC-01 | Path jail for file tools | Must |
| SEC-02 | No secrets in logs or SSE payloads | Must |
| SEC-03 | Plan spoofing impossible via settings | Must |
| SEC-04 | Settings mutation auth when token present | Must |
| SEC-05 | Slack HMAC verification when secret set | Must |
| SEC-06 | Host MUST authenticate engine mount in production (documented) | Must |
| SEC-07 | SSRF controls on provider/custom URLs | Must |
| SEC-08 | Destructive shell/write confirmations under approval workflow | Should |
| SEC-09 | Security reporting channel & response SLAs (SECURITY.md) | Must |
| SEC-10 | Supported version policy maintained | Must |

### 18.2 Reliability & performance

| ID | Requirement | Priority |
|----|-------------|----------|
| REL-01 | Task queue cannot thrash threads (`can't create Thread`) | Must |
| REL-02 | Shell timeout bounded | Must |
| REL-03 | Agent iterations bounded by plan | Must |
| REL-04 | Intelligence prepare must not brick boot on failure (warn & continue) | Must |
| REL-05 | Doctor surfaces actionable fixes | Must |
| REL-06 | Compatibility CI across Rails 7.0–8.x and multiple DBs | Should |
| REL-07 | Time-to-first-token streaming feels interactive (&lt; 3s typical under healthy provider) | Should |

### 18.3 Usability & UX

| ID | Requirement | Priority |
|----|-------------|----------|
| UX-01 | Empty states always say what to do next | Must |
| UX-02 | Gated feature errors name the plan that unlocks them | Must |
| UX-03 | Wizard completable in &lt; 2 minutes | Must |
| UX-04 | IDE usable without reading external docs for happy path | Must |
| UX-05 | Themes persist in localStorage | Should |

### 18.4 Compatibility & portability

| ID | Requirement | Priority |
|----|-------------|----------|
| CMP-01 | Support Rails 7.0–8.x per Appraisal matrix | Must |
| CMP-02 | SQLite, PostgreSQL, MySQL tested in CI | Should |
| CMP-03 | Ruby 3.1+ | Must |
| CMP-04 | Python & JS SDK versions published with release workflow | Should |
| CMP-05 | Workspace path aliases work across OS path styles | Must |

### 18.5 Observability & supportability

| ID | Requirement | Priority |
|----|-------------|----------|
| OBS-01 | Doctor + help + contact endpoints | Must |
| OBS-02 | Audit actions for sensitive runs (Team+) | Must |
| OBS-03 | Usage records for tokens/events | Must |
| OBS-04 | Structured upgrade guide via `Upgrade.chat_guide` | Must |

### 18.6 Compliance (Enterprise packaging)

| ID | Requirement | Priority |
|----|-------------|----------|
| CMPL-01 | Self-host keeps code/data in customer VPC | Must |
| CMPL-02 | SSO/SAML integration path | Must |
| CMPL-03 | Do not claim SOC2/SLA until operationally true | Must |
| CMPL-04 | Audit export for compliance reviews | Future |

---

## 19. Plan feature matrix (normative)

| Feature key | Free | Pro | Team | Enterprise |
|-------------|:----:|:---:|:----:|:----------:|
| local_agent | ✓ | ✓ | ✓ | ✓ |
| byok / openai / anthropic / nvidia / custom_providers | ✓ | ✓ | ✓ | ✓ |
| token_tracking / basic_analytics / streaming | ✓ | ✓ | ✓ | ✓ |
| diff_preview | | ✓ | ✓ | ✓ |
| hosted_models | | ✓ | ✓ | ✓ |
| agent_memory | | ✓ | ✓ | ✓ |
| priority_models | | ✓ | ✓ | ✓ |
| git_integration | | ✓ | ✓ | ✓ |
| mcp | | ✓ | ✓ | ✓ |
| team_dashboard | | | ✓ | ✓ |
| shared_agents | | | ✓ | ✓ |
| audit_log | | | ✓ | ✓ |
| approval_workflow | | | ✓ | ✓ |
| pr_creation | | | ✓ | ✓ |
| slack_bot | | | ✓ | ✓ |
| workspaces | | | ✓ | ✓ |
| analytics (full) | | | ✓ | ✓ |
| community_submissions | | | ✓ | ✓ |
| multi_agent | | | ✓ | ✓ |
| self_hosted | | | | ✓ |
| sso / saml | | | | ✓ |
| custom_models | | | | ✓ |
| rbac | | | | ✓ |
| soc2 / sla | | | | ✓* |

\*Claim only with ops evidence.

**Limits**

| Limit | Free | Pro | Team | Enterprise |
|-------|------|-----|------|------------|
| max_iterations | 25 | 50 | 100 | 500 |
| max_agents | 3 | 10 | 100 | ∞ |
| shell | yes | yes | yes | yes (+ RBAC) |

---

## 20. Environment & configuration

### 20.1 Required / important env vars

| Variable | Purpose |
|----------|---------|
| `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` / `NVIDIA_API_KEY` | BYOK |
| `RAILS_AI_BUILD_CLOUD_KEY` or settings cloud key | Hosted models |
| `RAILS_AI_BUILD_SECRET` / `SECRET_KEY_BASE` | Encryption |
| `RAILS_AI_BUILD_LICENSE_SECRET` | License HMAC |
| `RAILS_AI_BUILD_SETTINGS_TOKEN` | Settings auth |
| `RAILS_AI_BUILD_ALLOW_OPEN_SETTINGS` | Dev bypass |
| `STRIPE_SECRET_KEY` / `STRIPE_WEBHOOK_SECRET` / `STRIPE_PRICE_*` | Billing |
| `RAILS_AI_BUILD_CLOUD_URL` | Cloud base URL |
| `SLACK_SIGNING_SECRET` | Slack verify |
| `SAML_*` | Enterprise SSO |

### 20.2 Configuration object (must remain stable or changeloged)

`default_model`, `default_provider`, `api_keys`, `allowed_tools`, `workspace_root`, `max_agent_iterations`, `shell_timeout`, `auto_mount`, `diff_preview`, `plan`, `cloud_api_key`, `audit_enabled`, `rbac_enabled`, `default_role`, `saml_enabled`, builder/multitask flags, `license_key`, `wizard_completed`, `settings_token_digest`.

---

## 21. Acceptance, QA & release gates

### 21.1 Mandatory acceptance scenarios

| ID | Scenario | Pass criteria |
|----|----------|---------------|
| QA-01 | Fresh install | migrate → doctor → wizard BYOK → ask succeeds in IDE |
| QA-02 | Existing upgrade | `rails g rails_ai_build:upgrade` → migrate → activations table exists |
| QA-03 | Plan spoof | `PATCH /settings {plan: enterprise}` → 403; plan unchanged |
| QA-04 | License | issue token → activate → plan durable after process reload (DB row) |
| QA-05 | Stripe webhook | checkout.session.completed → plan persisted |
| QA-06 | 402 shape | free → `/audit` returns `plan_required` + suggested_plan |
| QA-07 | Path jail | `read_file`/`write_file` cannot escape workspace |
| QA-08 | Thread safety | enqueue many tasks → no thread storm |
| QA-09 | Streaming | SSE emits tool_call + done |
| QA-10 | Cloud door | save cloud key → default_provider cloud |
| QA-11 | CI generator | workflow file created and documented |
| QA-12 | OpenAPI | settings/doctor/billing paths present |

### 21.2 Release checklist (must)

- [ ] VERSION + CHANGELOG updated  
- [ ] SRS §19 features still accurate  
- [ ] OpenAPI bumped if routes changed  
- [ ] Activation + doctor specs green  
- [ ] Appraisal matrix / CI green (or known waivers)  
- [ ] SECURITY.md supported versions current  
- [ ] Launch ops items tracked separately (keys, Stripe live, publish)

---

## 22. Out of scope

Explicitly **not** part of this product (do not implement under this SRS):

1. Desktop IDE competing with Cursor for general non-app coding  
2. End-user chatbot widget for the host’s customers (unless separately productized)  
3. Lead generation, Maps scraping, web crawling businesses  
4. Claiming SOC2/ISO/SLA without operational evidence  
5. Guaranteeing third-party model provider uptime or output correctness  

---

## 23. Traceability & completeness checklist

Use before major releases. Every box must map to code or an explicit Future item in this SRS.

### Activation & money
- [ ] BYOK wizard  
- [ ] Cloud key wizard  
- [ ] License activation  
- [ ] Encrypted key store  
- [ ] Settings token  
- [ ] Durable plan  
- [ ] Stripe checkout + webhook  
- [ ] Upgrade modal  

### Cursor-class loop
- [ ] Chat + stream  
- [ ] Sessions / memory  
- [ ] File tools + path intelligence  
- [ ] Boost/Rails tools  
- [ ] Skills  
- [ ] Builder + verify  
- [ ] Multitask queue  
- [ ] Diff review  
- [ ] Git + PR  
- [ ] CI agent  
- [ ] Slack/Discord  
- [ ] Multi-agent  
- [ ] MCP  

### Surfaces
- [ ] IDE  
- [ ] Dashboard  
- [ ] Demo  
- [ ] CLI/Rake  
- [ ] REST API  
- [ ] OpenAPI  
- [ ] Python SDK  
- [ ] JS SDK  
- [ ] Standalone server  
- [ ] Generators (install/upgrade/boost/admin/bot/ci/enterprise)  

### Govern & operate
- [ ] Plans matrix  
- [ ] Doctor  
- [ ] Help/contact  
- [ ] Analytics/tokens  
- [ ] Audit  
- [ ] RBAC  
- [ ] SSO/SAML  
- [ ] Self-host  
- [ ] Marketplace/community  

### Quality
- [ ] Security path jail  
- [ ] No secret leakage  
- [ ] Compatibility CI  
- [ ] Migration heal  
- [ ] Trust/compatibility tooling  

---

## 24. Glossary

| Term | Meaning |
|------|---------|
| **BYOK** | Bring Your Own Key — customer’s LLM API key |
| **Activation OS** | Day-1 wizard + encrypted store + entitlements + doctor + upgrade UX |
| **Durable entitlement** | Plan stored outside process memory (DB/license/billing) |
| **PlanRequiredError** | Structured gate error → HTTP 402 |
| **Boost tools** | Rails introspection tool pack |
| **Universal builder** | Build/fix/verify loop with optional streaming |
| **Open core** | Free gem + commercial Pro/Team/Enterprise/Cloud |
| **Host** | Customer Rails application mounting the engine |

---

## Document control

| Version | Date | Notes |
|---------|------|-------|
| 1.1 | 2026-07-16 | 2.4.0 — portal, webhook HMAC, cloud soft-fail, approval, audit export, rate limit |
| 1.0 | 2026-07-16 | Initial comprehensive SRS for Rails AI Build 2.3.0 |

**Ownership:** Product + Engineering.  
**Change rule:** Any new user-visible capability MUST add a requirement ID here in the same PR/commit as the code.  
**Conflict rule:** If code and SRS disagree, fix the gap — do not silently shrink the promise.
