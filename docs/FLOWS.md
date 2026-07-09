# Complete Flow Reference — Rails AI Build v1.1.0

All product flows implemented and tested. Use this as the integration guide.

---

## Flow 1: Developer onboarding (5 min)

```bash
gem "rails_ai_build"
bundle install
rails generate rails_ai_build:install
rails db:migrate
export OPENAI_API_KEY=sk-...
rails rails_ai_build:setup
rails rails_ai_build:ask["Add a GET /health endpoint"]
```

---

## Flow 2: Skill-based development

```bash
rails rails_ai_build:skill[crud,"Create a Post resource"]
rails rails_ai_build:skill[tests,"Write RSpec for User model"]
rails rails_ai_build:skill[auth,"Add Devise authentication"]
```

API: `POST /rails_ai_build/skills/run`

---

## Flow 3: Diff preview + approval (Pro+)

```ruby
RailsAiBuild.configure { |c| c.plan = :pro; c.diff_preview = true }
```

```bash
rails rails_ai_build:ask["Refactor the users controller"]
rails rails_ai_build:pending
rails rails_ai_build:apply
```

API:
- `GET /rails_ai_build/changes`
- `POST /rails_ai_build/changes/:id/apply`
- `POST /rails_ai_build/changes/apply_all`

---

## Flow 4: Team admin panel

```bash
rails generate rails_ai_build:admin
# Visit http://localhost:3000/admin/ai
```

Web UI: `GET /rails_ai_build/ui`

---

## Flow 5: Cloud hosted models (Pro+)

```ruby
RailsAiBuild.configure do |c|
  c.plan = :pro
  c.cloud_api_key = ENV["RAILS_AI_BUILD_CLOUD_KEY"]
  c.default_provider = :cloud
end

RailsAiBuild::ChatService.ask("Add pagination to users")
```

---

## Flow 6: Slack / Discord bots (Team+)

```bash
rails generate rails_ai_build:bot --platform=slack
# Set SLACK_SIGNING_SECRET
# Point slash command to POST /rails_ai_build/slack/command
```

```bash
rails generate rails_ai_build:bot --platform=discord
# POST /rails_ai_build/discord/interactions
```

---

## Flow 7: CI pipeline

```bash
rails generate rails_ai_build:ci
```

Or use GitHub Action:
```yaml
- uses: ./.github/actions/rails-ai-build
  with:
    prompt: "Review this PR for Rails best practices"
    create_pr: true
```

---

## Flow 8: PR auto-creation (Team+)

```bash
curl -X POST http://localhost:3000/rails_ai_build/pull_requests \
  -H "Content-Type: application/json" \
  -d '{"title": "AI: add billing feature"}'
```

---

## Flow 9: Marketplace

```bash
# Browse packs
curl http://localhost:3000/rails_ai_build/marketplace

# Install pack
curl -X POST http://localhost:3000/rails_ai_build/marketplace/crud-pro/install \
  -d '{"message": "Create a Blog post resource"}'

# Submit community pack (Team+)
curl -X POST http://localhost:3000/rails_ai_build/community \
  -d '{"community_pack": {"name": "My Agent", "system_prompt": "...", "author": "me"}}'
```

---

## Flow 10: Analytics (Team+)

```bash
curl http://localhost:3000/rails_ai_build/analytics
```

---

## Flow 11: Billing upgrade

```bash
curl -X POST http://localhost:3000/rails_ai_build/billing/checkout \
  -d '{"plan": "pro", "email": "you@company.com"}'
```

---

## Flow 12: Enterprise self-host

```bash
rails generate rails_ai_build:enterprise
docker compose -f docker-compose.rails-ai-build.yml up -d
```

SSO config: `GET /rails_ai_build/auth/saml`

RBAC:
```ruby
RailsAiBuild.configure { |c| c.plan = :enterprise; c.rbac_enabled = true }
RailsAiBuild::Rbac.current_role = :reviewer  # read-only tools
```

---

## Flow 13: Multi-language

**Python:** `pip install rails-ai-build` → `from rails_ai_build import ask`
**JavaScript:** `npm i @rails-ai-build/sdk` → `import { ask } from "@rails-ai-build/sdk"`
**HTTP:** `POST http://localhost:9292/chat`

---

## Flow 14: Shared agents (Team+)

```bash
curl -X POST http://localhost:3000/rails_ai_build/shared_agents \
  -d '{"shared_agent": {"name": "API Dev", "system_prompt": "You build JSON APIs"}}'

curl -X POST http://localhost:3000/rails_ai_build/shared_agents/1/run \
  -d '{"message": "Add v2 users endpoint"}'
```

---

## All PRs merged

| PR | Status | Version |
|----|--------|---------|
| #1 Platform launch | ✅ Squash merged | v1.0.0 |
| #2 Post-launch flows | ✅ Squash merged | v1.1.0 |

**Code scope: 100% complete.** Remaining items are operational (publish gems, Stripe live keys, marketing).
