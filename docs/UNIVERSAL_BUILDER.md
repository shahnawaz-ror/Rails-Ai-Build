# Universal Builder — build anything in any Rails app

> **Goal:** Make `rails_ai_build` as capable as Cursor for Rails — any feature, any stack, any Rails version (7.0–8.1).

## One-liner

```ruby
RailsAiBuild::ChatService.build("Add Stripe subscriptions with webhooks")
```

Or from the terminal:

```bash
rails rails_ai_build:build['Add real-time notifications with ActionCable']
rails rails_ai_build:fix['User spec failing on line 42']
rails rails_ai_build:test[spec/models/post_spec.rb]
```

Or via API:

```bash
curl -X POST http://localhost:3000/rails_ai_build/build \
  -H "Content-Type: application/json" \
  -d '{"task":"Add JWT auth to API namespace","verify":true}'
```

## How it works (Cursor loop)

```
Explore → Plan → Build → Verify → Fix (restart) → Done
```

| Phase | Tools |
|-------|-------|
| Explore | `application_info`, `list_models`, `list_routes`, `database_schema`, `grep`, `read_file` |
| Build | `write_file`, `shell` (generators, migrations) |
| Verify | `run_rails_check` (zeitwerk, rspec/minitest, rubocop) |
| Fix | `read_logs`, restart with failure context (up to 3 attempts) |

The **Task Runtime** (`Tasks::Runtime`) implements verify-and-restart automatically when `verify_builds` is enabled (default).

## What you can build

| Category | Examples |
|----------|----------|
| **CRUD & UI** | Resources, Hotwire/Turbo, Stimulus, admin panels |
| **APIs** | REST, JSON:API, GraphQL endpoints, versioning |
| **Auth** | Devise, JWT, OAuth, Pundit policies |
| **Data** | Migrations, models, associations, indexes |
| **Jobs** | Sidekiq, Solid Queue, Good Job, scheduled tasks |
| **Integrations** | Stripe, webhooks, third-party APIs |
| **Quality** | RSpec/Minitest, factories, system specs |
| **Ops** | Health checks, logging, feature flags |
| **Refactors** | Service objects, engine extraction, performance |

## Skills (specialized agents)

| Skill | Use when |
|-------|----------|
| `build` | General — anything (default universal prompt) |
| `feature` | End-to-end product feature |
| `fix` | Bugs, errors, failing specs |
| `crud` | Scaffold resource |
| `api` | JSON API namespace |
| `auth` | Login/sessions/Devise |
| `tests` | Write or fix tests |
| `migration` | Database schema changes |
| `refactor` | Safe code improvement |

```bash
rails rails_ai_build:skill[feature,"Add comment threads on posts"]
```

## Configuration

```ruby
RailsAiBuild.configure do |config|
  config.universal_builder = true   # auto-inject app context (default: true)
  config.verify_builds = true       # run checks after build (default: true)
  config.build_max_attempts = 3     # restart loop limit
  config.allowed_tools += RailsAiBuild::Tools::Registry::BOOST_TOOL_NAMES
end
```

## Works with any Rails app

ConventionDetector auto-detects per project:

- RSpec vs Minitest
- Sidekiq vs Solid Queue vs Good Job
- Hotwire vs classic vs API-only
- Service objects, Devise, Pundit, etc.

No manual config required — the agent adapts to **your** app.

## IDE integration

Open `/rails_ai_build/ui/ide` — the agent prompt uses the same universal builder when `universal_builder` is on.

## Related

- [IDE_UI.md](./IDE_UI.md) — in-app workspace
- [FRAMEWORK_PARITY_ROADMAP.md](./FRAMEWORK_PARITY_ROADMAP.md) — MCP Boost tools
- [COMPATIBILITY_ROADMAP.md](./COMPATIBILITY_ROADMAP.md) — 1000-repo patterns
