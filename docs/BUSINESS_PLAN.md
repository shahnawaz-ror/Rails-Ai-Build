# Rails AI Build — Business Plan

**Mission:** Every Rails developer ships 10x faster without leaving their stack.

**Vision:** Become the default AI layer for Ruby on Rails — the company that powers intelligent development for 500,000+ Rails developers worldwide.

**Tagline:** *"Cursor lives in your editor. We live in your app."*

---

## The Opportunity

### Problem

| Pain | Who feels it |
|------|--------------|
| Cursor/VS Code AI is outside the Rails workflow | Teams on RubyMine, Vim, or plain VS Code without Cursor |
| No team visibility into what AI changed | Engineering managers, agencies, compliance teams |
| Can't embed AI into staging/review/CI | DevOps, platform teams |
| Enterprise won't send code to third-party IDEs | Banks, healthcare, government, EU companies |
| Rails-specific context is generic in general AI tools | Senior Rails devs who waste tokens explaining conventions |

### Market size (bottom-up)

| Segment | Estimate | Willingness to pay |
|---------|----------|-------------------|
| Active Rails developers globally | ~500,000 | — |
| Professional Rails devs (full-time) | ~150,000 | $29–99/mo |
| Rails agencies & consultancies | ~8,000 firms | $199–999/mo per team |
| Rails enterprises (500+ employees) | ~2,000 companies | $2,000–50,000/yr |

**Conservative Year 3 target:** 5,000 paying seats × $49/mo avg = **$2.94M ARR**

**Aggressive Year 5 target:** 15,000 seats + 200 enterprise deals = **$12M+ ARR**

---

## Positioning: Not Cursor — Better for Rails Teams

```
┌─────────────────────────────────────────────────────────────────┐
│                        CURSOR                                    │
│  Desktop IDE · Individual developer · General-purpose AI         │
│  "I code alone in an AI-powered editor"                        │
├─────────────────────────────────────────────────────────────────┤
│                     RAILS AI BUILD                               │
│  Inside your Rails app · Team + CI · Rails-native AI           │
│  "Our entire team has AI in our workflow, our infra, our rules"│
└─────────────────────────────────────────────────────────────────┘
```

### Our unfair advantages

1. **Rails-native** — Understands generators, conventions, ActiveRecord, Hotwire, Sidekiq, RSpec patterns out of the box
2. **Embeddable** — Mount in any Rails app; works in admin panels, internal tools, CI pipelines
3. **Self-hostable** — Enterprise keeps code on their VPC (huge moat vs Cursor for regulated industries)
4. **Team-first** — Shared agents, audit logs, approval workflows, billing per team
5. **Open core** — Gem is free → massive adoption → upsell to hosted cloud

---

## Product Strategy: Open Core → Platform → Ecosystem

### Phase 1: Land (Months 1–6) — **Free gem, viral adoption**

**Goal:** 10,000 gem installs / GitHub stars, 500 weekly active developers

| Deliverable | Purpose |
|-------------|---------|
| `rails_ai_build` gem (done) | Core agent, tools, providers |
| Python + JS SDKs (done) | Polyglot teams, microservices |
| Rails generators & conventions | Zero-config for new Rails 7+ apps |
| "Rails Agent" skill pack | Pre-built prompts for CRUD, auth, API, tests |
| Dev.to / Ruby Weekly launch | Community awareness |
| 10 showcase integrations | `--rails-ai-build` one-liner demos |

**Monetization:** $0. Build trust and distribution.

---

### Phase 2: Expand (Months 6–12) — **Rails AI Cloud (hosted SaaS)**

**Goal:** $30K MRR (~600 paying teams)

#### Product: **Rails AI Cloud** — `cloud.railsaibuild.com`

Hosted platform that the gem connects to for teams who don't want to manage API keys, models, or infrastructure.

| Feature | Free (OSS gem) | Pro $29/dev/mo | Team $99/seat/mo | Enterprise |
|---------|----------------|----------------|------------------|------------|
| Local agent | ✅ | ✅ | ✅ | ✅ |
| OpenAI/Anthropic BYOK | ✅ | ✅ | ✅ | ✅ |
| Hosted models (no API key) | — | ✅ | ✅ | ✅ |
| Team dashboard | — | — | ✅ | ✅ |
| Shared agents & prompts | — | — | ✅ | ✅ |
| Audit log & rollback | — | — | ✅ | ✅ |
| CI/CD agent (GitHub Actions) | — | — | ✅ | ✅ |
| SSO / SAML | — | — | — | ✅ |
| Self-hosted license | — | — | — | ✅ |
| SLA + dedicated support | — | — | — | ✅ |

**Killer feature for Rails devs:** **"Agent in your admin"**

```ruby
# config/routes.rb — mount AI panel for your team
mount RailsAiBuild::Engine => "/dev/ai"  # internal only
```

Your PM, designer, or junior dev asks: *"Add a CSV export to the orders index"* — agent does it, opens a PR, Slack notifies the team.

---

### Phase 3: Scale (Year 2) — **Rails AI Studio + Marketplace**

**Goal:** $250K MRR

#### Rails AI Studio (web product)

- Visual agent builder (no code)
- Drag-and-drop workflow: *Read ticket → Plan → Code → Test → PR*
- Integration gallery: Linear, Jira, GitHub, Slack, Honeybadger

#### Agent Marketplace (take rate: 20–30%)

| Agent pack | Price | Creator |
|------------|-------|---------|
| "Rails 8 CRUD Generator Pro" | $19/mo | Community |
| "RSpec Test Writer" | $9/mo | Community |
| "Security Audit Agent" | $49/mo | Rails AI Build |
| "Hotwire + Stimulus Scaffold" | $15/mo | Community |
| "Agency Client Onboarding" | $99/mo | Partner |

**Revenue flywheel:** Developers build agents → sell on marketplace → we take cut → more developers join.

---

### Phase 4: Dominate (Year 3–5) — **The Rails AI Platform**

**Goal:** $3M–12M ARR, acquisition target or Series A

| Product line | Revenue model |
|--------------|---------------|
| Rails AI Cloud | SaaS subscriptions |
| Enterprise self-hosted | $24K–120K/yr licenses |
| Marketplace | 20–30% transaction fee |
| Rails AI for CI | Per-build pricing ($0.10/build) |
| Certification & training | $499/course ("Rails AI Certified Developer") |
| Agency white-label | $499/mo per agency brand |

---

## Go-to-Market: How RoR Developers Find Us

### Channel 1: Community (low CAC, high trust)

| Tactic | Expected outcome |
|--------|------------------|
| Launch on Ruby Weekly, Rails Changelog, r/rails | 5K–20K first-month visitors |
| YouTube: "Add Cursor-like AI to your Rails app in 5 minutes" | Viral dev content |
| Open-source gem → GitHub stars → credibility | Top 10 Rails gems list |
| RailsConf / RubyConf talk sponsorship | Brand authority |
| DHH / Rails influencer seeding | 1 endorsement = 10K installs |

### Channel 2: Agencies (high LTV)

**Target:** 8,000 Rails consultancies worldwide (thoughtbot-style shops)

**Pitch:** *"Bill more hours on features, not boilerplate. White-label AI for every client project."*

| Agency tier | Price | Value |
|-------------|-------|-------|
| Starter (5 devs) | $299/mo | Shared agents, client project templates |
| Growth (15 devs) | $799/mo | White-label, per-client workspaces |
| Scale (50+ devs) | Custom | Dedicated infra, SLA |

**One agency = $10K–50K LTV over 3 years.**

### Channel 3: Enterprise (highest ACV)

**Target:** Companies that **cannot** use Cursor:

- Regulated: fintech, healthcare, insurance
- EU data residency requirements
- Air-gapped / on-prem deployments
- Existing RubyMine + self-hosted GitLab workflows

**Pitch:** *"AI coding agents inside your VPC. Your code never leaves your network."*

**Deal size:** $24K–120K/year. **10 enterprise deals = $500K+ ARR.**

### Channel 4: Product-led growth (PLG)

```
gem install → wow moment in 5 min → hit API limits → upgrade to Cloud
```

**Wow moment:** Developer runs one command, agent adds a feature with tests in 2 minutes.

```bash
rails ai:ask "Add Stripe checkout to the billing page with tests"
```

---

## Revenue Model Summary

```
                    ┌─────────────────────┐
                    │   FREE OSS GEM      │
                    │   (distribution)    │
                    └──────────┬──────────┘
                               │
           ┌───────────────────┼───────────────────┐
           ▼                   ▼                   ▼
   ┌───────────────┐  ┌───────────────┐  ┌───────────────┐
   │  SaaS Cloud   │  │  Marketplace  │  │  Enterprise   │
   │  $29–99/seat  │  │  20–30% cut   │  │  $24K–120K/yr │
   └───────────────┘  └───────────────┘  └───────────────┘
           │                   │                   │
           └───────────────────┼───────────────────┘
                               ▼
                    ┌─────────────────────┐
                    │   $3M+ ARR (Yr 3)   │
                    └─────────────────────┘
```

### Unit economics (target)

| Metric | Target |
|--------|--------|
| CAC (community-led) | $50–150 |
| LTV (Pro developer) | $1,200 (3 yr × $29/mo) |
| LTV (Team seat) | $3,600 (3 yr × $99/mo) |
| LTV (Enterprise) | $150,000+ |
| Gross margin (SaaS) | 75–85% |
| Payback period | < 6 months |

---

## Competitive Moat

| Moat | Why it compounds |
|------|------------------|
| **Rails-specific training data** | Agents that know `has_many :through`, Stimulus, Turbo — Cursor doesn't |
| **Open-source distribution** | Gem in Gemfile = permanent distribution channel |
| **Network effects (marketplace)** | More agents → more users → more agent creators |
| **Switching cost** | Team's custom agents, audit history, CI integrations |
| **Enterprise self-host** | 12-month contracts, deep integration |
| **Community** | Rails devs trust Rails-native tools (see: Sidekiq, Devise, Pagy) |

---

## 12-Month Execution Roadmap

### Q1 — Foundation
- [ ] Ship gem v1.0 to RubyGems
- [ ] Publish Python + JS packages to PyPI / npm
- [ ] Landing page: railsaibuild.com
- [ ] 5 blog posts: "Rails AI without Cursor"
- [ ] Rails-specific skill packs (CRUD, auth, API, tests)
- [ ] GitHub Action: `rails-ai-build/action`

### Q2 — Monetization MVP
- [ ] Rails AI Cloud beta (hosted API + dashboard)
- [ ] Stripe billing integration
- [ ] Team workspaces + shared agents
- [ ] Usage metering and plan limits
- [ ] First 50 paying customers ($5K MRR target)

### Q3 — Team features
- [ ] Audit log + diff preview before apply
- [ ] PR auto-creation (GitHub/GitLab)
- [ ] Slack / Discord notifications
- [ ] Admin UI mount generator (`rails g rails_ai_build:admin`)
- [ ] Agency pilot program (5 agencies)

### Q4 — Scale
- [ ] Agent Marketplace beta
- [ ] Enterprise self-hosted installer
- [ ] SOC 2 Type I preparation
- [ ] RailsConf launch / keynote
- [ ] $30K MRR milestone

---

## Path to $1M ARR (the math)

| Source | Customers | Price | ARR |
|--------|-----------|-------|-----|
| Pro developers | 1,500 | $29/mo | $522K |
| Team seats | 300 teams × 5 seats | $99/mo | $1.78M |
| Agencies | 30 | $499/mo | $180K |
| Enterprise | 5 | $60K/yr | $300K |
| Marketplace (net) | — | — | $100K |

**Realistic Year 2 blend:** ~1,200 Pro + 80 teams + 15 agencies + 2 enterprise = **~$1.1M ARR**

---

## Brand & Company

| Item | Recommendation |
|------|----------------|
| **Company name** | Rails AI Build, Inc. (or **Buildware**, **Railmind**, **Hotbuild**) |
| **Domain** | railsaibuild.com, railmind.dev |
| **Open source** | MIT gem (distribution) |
| **Commercial** | Rails AI Cloud (proprietary hosted) |
| **Inspiration** | GitLab (open core), Sidekiq (free + Pro), Vercel (free + platform) |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Cursor adds Rails-specific features | Move faster on Rails depth; own the server/CI/team layer |
| OpenAI price changes | Multi-provider + fine-tuned smaller models for Rails |
| Low conversion free → paid | Strong wow moment; CI integration requires Cloud |
| Enterprise sales cycle | Start with agencies; use as reference customers |
| Security incident (agent writes bad code) | Diff preview, approval workflows, audit logs (Pro feature) |

---

## The One-Liner Pitch

**For investors:**
> "We're building the AI platform for 500,000 Rails developers — open-source distribution, SaaS monetization, enterprise self-host. GitLab met Copilot, but for Rails."

**For developers:**
> "Forgot Cursor? Add AI agents directly to your Rails app. One gem, every model, your codebase."

**For agencies:**
> "Ship client features 3x faster. White-label AI agents for every Rails project."

---

## Next Actions (this week)

1. **Register** railsaibuild.com + social handles
2. **Publish** gem to RubyGems as `rails_ai_build`
3. **Ship** landing page with waitlist for Rails AI Cloud
4. **Record** 3-minute demo: gem install → agent adds feature → tests pass
5. **Post** on r/rails, Ruby Weekly, Dev.to
6. **Reach out** to 10 Rails agencies for design partners

---

*"Every Rails developer who doesn't use Cursor is a customer waiting to happen."*
