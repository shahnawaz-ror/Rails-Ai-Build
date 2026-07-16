# Client Journey Master Plan — Rails AI Build

**Audience:** Founders, product, eng, GTM  
**Mental model:** *You use Cursor with AI models based on your plan. Our client installs the gem and does the same — inside their app, CI, and team — gated by BYOK, Cloud key, Dashboard, or Paid plan.*  
**North star:** After `bundle install`, a developer should never hit a dead end. Every Cursor-class action has a clear path: Free (BYOK) → Pro → Team → Enterprise / Cloud.

---

## 1. Founder thesis (one page)

| Cursor (desktop) | Rails AI Build (in-app) |
|------------------|-------------------------|
| Lives in the editor | Lives in the Rails app / SDK / CI |
| Individual power user | Team + infra + compliance |
| Chat → tools → edit files | Chat → tools → edit → diff → PR → Slack → audit |
| Subscription unlocks models & features | Plan + API key + dashboard unlock the same loop |

**Promise to the client:**  
“Install once. Put a key (yours or ours). Open the IDE/dashboard. Ask for anything in your codebase. The agent plans, reads, edits, tests, and ships — within the limits of the plan you paid for.”

**What “anything” means (capability pillars):**

1. **Talk** — chat, stream, multi-turn memory  
2. **See** — file tree, search, Rails introspection  
3. **Change** — write/patch, skills, multi-agent build  
4. **Review** — diffs, approvals, apply/reject  
5. **Ship** — git, PR, CI agent, bots  
6. **Govern** — RBAC, SSO, audit, usage, seats  
7. **Extend** — marketplace packs, MCP, custom models  
8. **Operate** — doctor, analytics, billing, cloud keys  

If a pillar is missing for a given entitlement path, that is a product bug, not a “nice to have.”

---

## 2. Entitlement model (three doors into power)

A client can unlock value through **any one** of these doors. Product must treat them as first-class, not afterthoughts.

```
┌──────────────────────────────────────────────────────────────────────────┐
│                     CLIENT JUST INSTALLED THE GEM                        │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
          ┌─────────────────────────┼─────────────────────────┐
          ▼                         ▼                         ▼
   DOOR A: BYOK              DOOR B: CLOUD KEY         DOOR C: PAID PLAN
   Own OpenAI /              RAILS_AI_BUILD_CLOUD_KEY  Stripe / license /
   Anthropic / NVIDIA /      → hosted models           seat entitlements
   Ollama / custom           (no vendor key needed)    → feature matrix
          │                         │                         │
          └─────────────────────────┴─────────────────────────┘
                                    │
                                    ▼
                    GEM DASHBOARD / IDE / CLI / API / CI
                    (same agent loop, different limits)
```

### Door A — Free + BYOK (land & viral)

| Must work day-1 | Detail |
|-----------------|--------|
| Install | `gem` → generator → migrate → `setup` → doctor green |
| Key setup UI | Paste NVIDIA/OpenAI/Anthropic/custom in dashboard; persist securely; test connection |
| First win < 5 min | Ask → agent edits → response visible in IDE or CLI |
| Limits | Free plan: local agent, streaming, token tracking, max agents/iterations |
| Auto-apply vs preview | Free: writes apply (or clearly labeled); Pro+: diff preview |

**Founder rule:** Free without a working key UX = dead install. Key setup is product, not docs.

### Door B — Cloud API key (expand & convert)

| Must work | Detail |
|-----------|--------|
| Account → key | Client signs up at cloud → copies key → pastes in gem settings |
| Hosted models | `default_provider = :cloud` works without OpenAI/Anthropic keys |
| Usage metering | Tokens/requests billed to cloud account; visible in dashboard |
| Soft fail | If cloud down → clear error + “use BYOK” fallback CTA |
| Plan sync | Cloud key carries Pro/Team entitlements into the gem |

**Founder rule:** Cloud key is the Cursor “subscription models” equivalent. Without live cloud + metering, Pro’s `hosted_models` is fiction.

### Door C — Paid plan (monetize)

| Plan | Client gets | Feeling |
|------|-------------|---------|
| **Pro ($29)** | Diff preview, memory, git, MCP, hosted models, higher limits | “Cursor Pro inside my app” |
| **Team ($99/seat)** | Shared agents, audit, PR, Slack/Discord, analytics, multi-agent, packs | “My whole company uses one AI layer” |
| **Enterprise** | SSO/SAML, RBAC, self-host, custom models, SLA | “Bank / health / EU can buy this” |

**Founder rule:** Paying must flip durable entitlements (account/org/license), not an in-process `config.plan = :pro` that resets on deploy.

---

## 3. Day-0 → Day-30 client journey (nothing missed)

### Phase 0 — Discover (before install)

- Landing: one sentence + one CTA + one demo video  
- Trust: live sandbox / compatibility badge (“works on real Rails apps”)  
- Pricing clarity: Free BYOK vs Pro vs Team vs Enterprise  
- Install paths: Rails gem · Python · JS · standalone server  

### Phase 1 — Install (minutes 0–5)

```
bundle add rails_ai_build
rails g rails_ai_build:install
rails db:migrate
rails rails_ai_build:setup
rails rails_ai_build:doctor   # MUST catch missing key, DB, mount, jobs
```

**Success criteria:**

- Engine mounted (`/rails_ai_build`)  
- IDE opens (`/ui/ide`)  
- Doctor reports: DB ✅ · Mount ✅ · Key ❌ or ✅ · Jobs ✅  
- Empty-state UI tells them exactly which door to open next  

### Phase 2 — Activate (minutes 5–15)

**Path A — BYOK**

1. Open Settings in dashboard  
2. Paste key → Test → Save (encrypted at rest)  
3. Pick model/provider  
4. Guided first prompt: “Add GET /health”  
5. See stream + file change  

**Path B — Cloud**

1. “Continue with Rails AI Cloud”  
2. OAuth/signup → key issued  
3. Key auto-written to settings  
4. Same guided first prompt  

**Path C — Already paid**

1. Enter license / org key / Stripe-linked email  
2. Plan badge updates in IDE top bar  
3. Pro/Team features unlock immediately  

### Phase 3 — Habit (first week)

Client should complete **all** of these at least once:

| Habit | Surface | Entitlement |
|-------|---------|-------------|
| Chat in IDE | `/ui/ide` | Free+ |
| Skill run (CRUD/auth/tests) | IDE / CLI / API | Free+ |
| Diff review + apply | Changes panel | Pro+ |
| Agent memory reuse | Multi-turn | Pro+ |
| Git status + commit helper | Git panel | Pro+ |
| Create PR | PR API / IDE | Team+ |
| Slack “/ai fix flaky test” | Bot | Team+ |
| CI review on PR | GitHub Action | Team+ (or Free with BYOK in CI) |
| Shared team agent | Dashboard | Team+ |
| Audit “who changed what” | Audit | Team+ |
| Marketplace pack install | Marketplace | Free browse / Team submit |
| MCP tool from external IDE | MCP endpoints | Pro+ |
| Usage / cost visibility | Analytics | Free basic / Team full |
| Upgrade checkout | Billing | Always visible |

### Phase 4 — Expand org (first month)

- Invite seats (Team)  
- Role mapping (Enterprise RBAC)  
- SSO (Enterprise)  
- Self-host Docker (Enterprise)  
- Org-wide shared agents + approval workflow  
- Agency / multi-workspace (Team+)  
- Case study / referral loop  

### Phase 5 — Renew & expand ARR

- Usage alerts before limit  
- Seat expansion checkout  
- Enterprise expansion pack (extra workspaces, custom models)  
- Marketplace paid packs (future)  
- Cloud overage (transparent, capped)  

---

## 4. Capability matrix — “Cursor window” parity

Map every action you do in Cursor to our product. **No blank cells allowed in vNext.**

| Cursor-class action | Free BYOK | Pro | Team | Enterprise | Surfaces |
|---------------------|-----------|-----|------|------------|----------|
| Chat with codebase | ✅ | ✅ | ✅ | ✅ | IDE, CLI, API, SDK |
| Streaming tokens | ✅ | ✅ | ✅ | ✅ | SSE |
| Read / grep / list files | ✅ | ✅ | ✅ | ✅ | Tools |
| Write / edit files | ✅ | ✅ | ✅ | ✅ | Tools |
| Shell commands | ✅ (limited) | ✅ | ✅ | ✅ + RBAC | Tools |
| Rails-aware tools (Boost) | ✅ | ✅ | ✅ | ✅ | Generator |
| Skills (CRUD, auth, API, tests) | ✅ | ✅ | ✅ | ✅ | CLI/API |
| Multi-agent (plan→code→review) | — | — | ✅ | ✅ | Orchestration |
| Diff preview / apply | — | ✅ | ✅ | ✅ | Changes |
| Agent memory | — | ✅ | ✅ | ✅ | Sessions |
| Hosted models (no BYOK) | — | ✅ | ✅ | ✅ | Cloud |
| Custom / local models | ✅ | ✅ | ✅ | ✅ + approved | Providers |
| Git integration | — | ✅ | ✅ | ✅ | IDE/API |
| PR creation | — | — | ✅ | ✅ | GitHub/GitLab |
| Slack / Discord | — | — | ✅ | ✅ | Bots |
| CI agent | ✅ BYOK | ✅ | ✅ | ✅ | Action |
| Shared agents | — | — | ✅ | ✅ | Dashboard |
| Audit log | — | — | ✅ | ✅ | UI/API |
| Analytics | Basic | Basic | Full | Full | Dashboard |
| Marketplace packs | Browse | Browse | Submit | Submit + private | Marketplace |
| MCP server | — | ✅ | ✅ | ✅ | Endpoints |
| SSO / SAML | — | — | — | ✅ | Auth |
| RBAC tool allowlists | — | — | — | ✅ | Roles |
| Self-host / air-gap | — | — | — | ✅ | Docker |
| Billing / seats | Upgrade CTA | Stripe | Seats | Contract | Billing |
| Key setup UI | ✅ must | ✅ | ✅ | ✅ | Settings |
| Doctor / help | ✅ | ✅ | ✅ | ✅ | CLI/UI |

---

## 5. Product surfaces (every place the client “does anything”)

Treat each surface as a complete product, not a demo page.

### 5.1 In-app IDE (`/rails_ai_build/ui/ide`) — primary “Cursor window”

Must include:

- File explorer + open file  
- Chat + streaming tool calls  
- Provider / model picker  
- Plan badge + upgrade CTA  
- Pending changes  
- Git / PR (gated)  
- Settings: keys, plan, theme  
- Empty states for no-key / no-plan / no-jobs  

### 5.2 Dashboard (`/ui`) — team / ops home

- Usage, recent runs, agents, billing status, invites  
- Not a second IDE; one job: operate the AI layer  

### 5.3 CLI / Rake

- `ask`, `skill`, `build`, `fix`, `test`, `pending`, `apply`, `doctor`, `stats`  
- Same entitlements as UI  

### 5.4 HTTP API + OpenAPI

- Full route coverage = OpenAPI truth  
- Auth required (API token / session) — no open plan-flip  

### 5.5 SDKs (Python / JS) + standalone server

- Same protocol; remote mode to engine or `localhost:9292`  
- Documented for non-Rails teams  

### 5.6 CI / bots / MCP

- GitHub Action, Slack, Discord, MCP clients  
- Each has setup wizard in dashboard (“Connect Slack”)  

---

## 6. Gaps that kill a million-dollar company (fix these first)

These are commercialization and trust gaps, not “more agent tools.”

| Gap | Why it kills ARR | Target state |
|-----|------------------|--------------|
| **Plan is in-process config** | Customer pays; next deploy they’re Free again | Durable org entitlement via Cloud license or signed JWT / Stripe customer id |
| **Engine routes unauthenticated** | Anyone who can hit `/settings` can set `plan: enterprise` | API keys / session auth / Devise mount; never trust client for plan |
| **Cloud is waitlist-only** | Pro “hosted models” cannot convert | Live `cloud.railsaibuild.com`: signup, keys, metering, model proxy |
| **Stripe scaffolding only** | No real checkout → no revenue | Live products, webhooks, seat sync, portal |
| **Key setup buried in ENV** | Non-founders bounce | First-run Settings wizard with Test Connection |
| **OpenAPI lag** | SDK/partners break | Spec = routes; CI check |
| **Marketplace not commerce** | No ecosystem flywheel | Pack install + (later) paid packs + payouts |
| **SSO/RBAC scaffolding** | Enterprise won’t PO | Real IdP login + enforced tool allowlists |
| **No seat / invite model** | Team plan unenforceable | Org → members → roles → billing seats |
| **Weak first-run aha** | Churn before habit | Guided mission: health endpoint → green check in UI |

---

## 7. Security, trust, compliance (enterprise buyers)

Without this, Team/Enterprise deals stall.

1. **Authn** — session or API token on every mutating route  
2. **Authz** — plan + RBAC before tools (especially `shell`, `write_file`)  
3. **Secrets** — encrypt API keys; never echo in logs/SSE  
4. **Audit** — who ran what prompt, which files changed, apply/reject  
5. **Sandbox** — workspace root jail; deny paths outside app  
6. **Approval** — Pro/Team: high-risk tools require apply  
7. **Data residency / self-host** — Enterprise Docker path documented + supported  
8. **SOC2 narrative** — policies + audit export (claim only when real)  
9. **Prompt injection defenses** — tool allowlists, confirm destructive ops  
10. **Abuse limits** — rate limits per key/org; CI spike protection  

---

## 8. Monetization system design

```
Customer Account (Cloud)
  └── Organization
        ├── Plan: free | pro | team | enterprise
        ├── Seats + roles
        ├── Cloud API keys (scoped)
        ├── BYOK keys (optional, encrypted)
        ├── Usage meters (tokens, runs, seats)
        └── Stripe customer / subscription / license file
                 │
                 ▼
        Gem / Engine polls or verifies entitlement
        (signed license JWT, short TTL, offline grace for Enterprise)
```

**Pricing UX rules:**

- Free forever for local BYOK (distribution moat)  
- Upgrade moments: hit agent limit, want diff preview, want PR/Slack, want hosted models  
- Never dark-pattern: show what failed and the exact plan that unlocks it  
- Customer portal: cancel, invoices, seats  

---

## 9. GTM aligned to the journey

| Motion | Who | Offer | Success metric |
|--------|-----|-------|----------------|
| Open-core viral | Indie Rails devs | Free gem + NVIDIA BYOK | Installs, doctor green rate |
| Product-led Pro | Solo / small shop | $29 hosted models + diffs | Trial → paid < 7 days |
| Team land | Agencies, product squads | $99/seat shared agents + audit | Seat expansion |
| Enterprise | Regulated / large | Self-host + SSO + SLA | Pilot → ACV |
| Platform | All | Marketplace + MCP + SDKs | Ecosystem retention |

**Design partners (first 10):** 3 agencies, 5 product companies, 2 enterprises — free Team for feedback, case study rights.

---

## 10. Execution roadmap (by dependency, not calendar)

### Track A — Make every install succeed

1. First-run wizard (key / cloud / skip)  
2. `doctor` + UI health panel  
3. Guided first task + success celebration  
4. Secure settings persistence for keys  

### Track B — Make money real

1. Cloud accounts + API keys  
2. Hosted model proxy + metering  
3. Stripe live + webhook → org plan  
4. Entitlement verification in gem (signed)  
5. Billing portal + upgrade CTAs in IDE  

### Track C — Make teams buy

1. Auth on engine routes  
2. Orgs, invites, seats  
3. Shared agents + audit enforced  
4. Slack/PR setup wizards  
5. Analytics that managers care about  

### Track D — Make enterprises sign

1. Real SAML login  
2. RBAC enforced on tools  
3. Hardened self-host install  
4. Audit export + retention policies  
5. Support SLA packaging  

### Track E — Make the loop unbeatable

1. Agent quality (Rails conventions, tests, migrations)  
2. Multi-agent reliability  
3. MCP + external IDE bridges  
4. Marketplace quality bar  
5. Compatibility / trust sandbox always green  

---

## 11. Success metrics (company-grade)

| Funnel | Metric | Healthy signal |
|--------|--------|----------------|
| Install | Gem installs / week | Growing WoW |
| Activate | % installs with doctor green + 1 successful run in 24h | > 40% |
| Habit | Weekly active apps with ≥5 agent runs | Growing |
| Convert | Free → Pro/Team | > 3% of WAUs |
| Expand | Seats / org | > 1.5 over 90 days |
| Revenue | MRR, net revenue retention | NRR > 110% Team+ |
| Trust | Critical bugs in agent write path | Near zero |
| Support | Time-to-first-success for new orgs | < 15 minutes |

---

## 12. Non-goals (stay sharp)

- Not a desktop IDE competitor for general coding outside the app  
- Not a generic chatbot widget for end-users of the client’s product (unless separately productized)  
- Not lead-gen / Maps / web scraping — different company  
- Not “claim SOC2 / SLA” before ops exists  

---

## 13. Founder checklist — “Did we miss a single stuff?”

Use this as a release gate for any major version:

- [ ] New client can install without reading more than one page  
- [ ] Key setup works in UI (BYOK) and via Cloud key  
- [ ] First prompt succeeds and is visible in IDE  
- [ ] Every plan feature in `Plans::PLANS` is demoable end-to-end  
- [ ] Paying customer keeps plan across redeploys  
- [ ] Cannot spoof plan via open `/settings`  
- [ ] Upgrade path is one click from any gated feature error  
- [ ] CLI, IDE, API, SDK, CI all share the same capability story  
- [ ] Team can see who did what (audit)  
- [ ] Enterprise can SSO + RBAC + self-host  
- [ ] Doctor explains the next fix when something breaks  
- [ ] Billing, keys, and usage are visible without SSH  
- [ ] OpenAPI matches reality  
- [ ] Landing → install → aha → pay is a continuous story  

---

## 14. Immediate next build slice (recommended)

**Slice name:** “Day-1 Activation OS”

1. Authenticated settings + encrypted key store  
2. First-run wizard in IDE (BYOK / Cloud / License)  
3. Durable entitlement stub (even if Cloud is thin: signed license file)  
4. Gated feature errors → upgrade modal with checkout  
5. Doctor panel embedded in IDE  

Ship that, and the gem stops feeling like a library and starts feeling like a product people pay for — the same way Cursor feels the moment the window opens.

---

## Related docs

- [FLOWS.md](./FLOWS.md) — current integration flows  
- [BUSINESS_PLAN.md](./BUSINESS_PLAN.md) — market & phases  
- [PRODUCT_ROADMAP.md](./PRODUCT_ROADMAP.md) — feature checklist  
- [LAUNCH.md](./LAUNCH.md) — publish / Stripe / marketing ops  
- [IDE_UI.md](./IDE_UI.md) — in-app Cursor surface  
- [GTM_PLAYBOOK.md](./GTM_PLAYBOOK.md) — go-to-market  
- `lib/rails_ai_build/plans.rb` — source of truth for plan matrix  
