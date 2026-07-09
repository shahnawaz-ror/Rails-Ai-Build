# Product Roadmap — Revenue-Aligned Features

Features ordered by **adoption impact** and **monetization potential**.

---

## Tier 0: OSS (Free) — Distribution engine

*Goal: become the default `gem "rails_ai_build"` in new Rails apps*

| Feature | Status | Business value |
|---------|--------|----------------|
| Core agent + tool loop | ✅ Done | Wow moment |
| OpenAI + Anthropic providers | ✅ Done | Model choice |
| Python + JS SDKs | ✅ Done | Polyglot teams |
| Standalone HTTP server | ✅ Done | Any language |
| Install generator | ✅ Done | Zero friction |
| Rails skill packs | 🔲 Planned | Viral demos |
| `rails ai:ask` rake task | ✅ Done | CLI habit |
| GitHub Action | 🔲 Planned | CI wedge |

---

## Tier 1: Pro ($29/dev/mo) — Individual power users

*Goal: developers who won't pay for Cursor but will pay for Rails-native AI*

| Feature | Unlock | Why they pay |
|---------|--------|--------------|
| Hosted models (no API key) | Pro | Convenience |
| 10x higher rate limits | Pro | Daily driver |
| Rails convention engine | Pro | Better output than generic AI |
| Diff preview before write | Pro | Safety |
| Agent memory (project context) | Pro | Smarter over time |
| Priority models (faster) | Pro | Speed |

---

## Tier 2: Team ($99/seat/mo) — Where the money is

*Goal: engineering teams at startups and agencies*

| Feature | Unlock | Why they pay |
|---------|--------|--------------|
| Team dashboard | Team | Visibility |
| Shared agents & prompt library | Team | Consistency |
| Audit log (who asked AI to change what) | Team | Compliance |
| Approval workflow (AI proposes → human approves) | Team | Trust |
| PR auto-creation | Team | Workflow integration |
| Slack / Discord bot | Team | "@ai add pagination to users" |
| Per-project workspaces | Team | Multi-repo agencies |
| Usage analytics | Team | Manager buy-in |

**Admin mount (killer demo):**

```ruby
# Only for admin users — internal AI panel
authenticate :user, ->(u) { u.admin? } do
  mount RailsAiBuild::Engine => "/admin/ai"
end
```

---

## Tier 3: Enterprise ($2K–10K/mo) — Million-dollar deals

*Goal: companies that cannot use Cursor*

| Feature | Unlock | Why they pay |
|---------|--------|--------------|
| Self-hosted (VPC / on-prem) | Enterprise | Data sovereignty |
| SSO / SAML | Enterprise | IT requirement |
| Custom model endpoints | Enterprise | Internal LLMs |
| RBAC (who can run shell tool) | Enterprise | Security |
| SOC 2 compliance | Enterprise | Procurement |
| Dedicated support + SLA | Enterprise | Mission-critical |
| Air-gapped installer | Enterprise | Government/defense |

---

## Tier 4: Marketplace (20–30% take) — Ecosystem flywheel

| Agent pack | Price | Built by |
|------------|-------|----------|
| CRUD in 60 seconds | $9/mo | Rails AI Build |
| RSpec test generator | $9/mo | Community |
| Security audit (Brakeman++) | $49/mo | Rails AI Build |
| Hotwire scaffold pro | $15/mo | Community |
| API-only Rails mode | $12/mo | Partner |
| Agency client onboarding | $99/mo | Agency partner |

---

## Rails-Specific Moat Features (build these first)

These are features **Cursor will never build** because they're Rails-only:

### 1. Convention-aware agent
```
Agent knows:
- snake_case files, CamelCase classes
- app/models, app/controllers structure  
- RESTful routes conventions
- Strong params patterns
- ActiveRecord associations
- RSpec + FactoryBot patterns
- Sidekiq job structure
- Hotwire (Turbo + Stimulus) patterns
```

### 2. Generator integration
```bash
rails generate rails_ai_build:agent BillingAssistant
rails generate rails_ai_build:admin  # mounts AI panel in admin
rails generate rails_ai_build:ci     # GitHub Actions workflow
```

### 3. Rails AI CI bot
```yaml
# .github/workflows/rails-ai.yml
- uses: rails-ai-build/action@v1
  with:
    prompt: "Review this PR for Rails best practices"
    model: claude-sonnet-4-20250514
```

### 4. "Forgot Cursor" onboarding
```bash
# One command — developer is hooked in 5 minutes
rails ai:setup   # installs, configures, runs demo task
```

---

## Milestones → Revenue

| Milestone | Metric | Revenue signal |
|-----------|--------|----------------|
| Gem v1.0 on RubyGems | 1,000 installs | Distribution |
| 100 GitHub stars | Community validation | Hiring/investors |
| Cloud beta launch | 50 waitlist signups | Demand |
| First paying customer | $29 MRR | PMF signal |
| 10 agency pilots | $3K MRR | High-LTV channel |
| $10K MRR | ~100 paying seats | Seed fundraise ready |
| $30K MRR | ~400 seats | Sustainable indie SaaS |
| $83K MRR | ~$1M ARR | Series A / acquisition interest |

---

## What to build next (priority order)

1. **Publish to RubyGems** — unlock distribution
2. **Landing page + waitlist** — capture demand before Cloud ships
3. **Rails skill packs** — CRUD, auth, API, tests (viral content)
4. **Diff preview** — safety feature that sells Pro
5. **GitHub Action** — CI wedge, team adoption
6. **Stripe + Cloud MVP** — start charging
7. **Admin panel generator** — agency demo killer
8. **Marketplace** — ecosystem lock-in
