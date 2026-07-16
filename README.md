[![CI](https://github.com/shahnawaz-ror/Rails-Ai-Build/actions/workflows/ci.yml/badge.svg)](https://github.com/shahnawaz-ror/Rails-Ai-Build/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/shahnawaz-ror/Rails-Ai-Build/graph/badge.svg)](https://codecov.io/gh/shahnawaz-ror/Rails-Ai-Build)

# Rails AI Build

**Cursor-like AI coding agents for any project — Ruby, Python, JavaScript, and more.**

A multi-language monorepo that brings AI coding agents into your applications. Agents read, search, and modify your codebase using multiple AI models — just like Cursor.

## Packages

| Package | Language | Install | Use case |
|---------|----------|---------|----------|
| [`rails_ai_build`](./lib) | Ruby (Rails gem) | `gem "rails_ai_build"` | Full Rails integration with engine, DB, jobs |
| [`rails-ai-build`](./packages/python) | Python | `pip install rails-ai-build` | Django, FastAPI, Flask, scripts, data science |
| [`@rails-ai-build/sdk`](./packages/javascript) | JavaScript/TypeScript | `npm install @rails-ai-build/sdk` | Node.js, Express, Next.js, React |
| [`server`](./server) | Ruby (Sinatra) | `bundle exec rackup` | Language-agnostic HTTP API for any stack |

All packages share the same agent architecture and can work **standalone** (no Ruby required) or connect via the **HTTP API**.

## Quick start by language

### Ruby / Rails

```ruby
gem "rails_ai_build"
# rails generate rails_ai_build:install && rails db:migrate
rails generate rails_ai_build:boost   # Laravel Boost-style introspection tools

RailsAiBuild::Ai::Driver.run("Add Stripe subscriptions")  # model-first — like Cursor/Claude
# Stream: Driver.stream("...") { |event, data| ... }  # SSE: delta, tool_call, tool_result, done
# API: POST /rails_ai_build/ai/stream · POST /build/stream · POST /tasks/:id/stream
# Multi-turn: session = RailsAiBuild::Ai::Session.create; Driver.run("...", session: session)

RailsAiBuild::ChatService.build("Add Stripe subscriptions with webhooks")
# Or: rails rails_ai_build:build['Add comment system with Turbo Streams']

RailsAiBuild::ChatService.ask("Add a health check endpoint")
```

**NVIDIA NIM** (free-tier cloud models at `integrate.api.nvidia.com`):

```ruby
RailsAiBuild.configure do |config|
  config.api_keys[:nvidia] = ENV["NVIDIA_API_KEY"]  # nvapi-… from build.nvidia.com
  config.default_provider = :nvidia
  config.default_model = "meta/llama-3.1-8b-instruct"
end
```

**Live specs** — prove real API + file writes (never commit keys):

```bash
NVIDIA_API_KEY=nvapi-... bundle exec rspec spec/live
```

### 20 Live App Previews — `rails_ai_build` installed, test changes with NVIDIA

Each link opens a **live sandbox** with `rails_ai_build` configured (initializer + Gemfile). You can preview the workspace, run `Ai::Driver` prompts, and see file changes in real time.

**Base server:** [https://rails-ai-build-trust.onrender.com](https://rails-ai-build-trust.onrender.com) · **Local:** `cd server && bundle exec rackup` → `http://localhost:9292/apps/{slug}`

| # | App | Archetype | Rails | Preview & test changes | Upstream |
|---|-----|-----------|-------|------------------------|----------|
| 1 | [fizzy](https://rails-ai-build-trust.onrender.com/apps/basecamp-fizzy) | full_stack | 7.0 | [Open preview](https://rails-ai-build-trust.onrender.com/apps/basecamp-fizzy) | [GitHub](https://github.com/basecamp/fizzy) |
| 2 | [brakeman](https://rails-ai-build-trust.onrender.com/apps/presidentbeef-brakeman) | full_stack | 7.0 | [Open preview](https://rails-ai-build-trust.onrender.com/apps/presidentbeef-brakeman) | [GitHub](https://github.com/presidentbeef/brakeman) |
| 3 | [paper_trail](https://rails-ai-build-trust.onrender.com/apps/paper-trail-gem-paper-trail) | full_stack | 7.0 | [Open preview](https://rails-ai-build-trust.onrender.com/apps/paper-trail-gem-paper-trail) | [GitHub](https://github.com/paper-trail-gem/paper_trail) |
| 4 | [mailcatcher](https://rails-ai-build-trust.onrender.com/apps/sj26-mailcatcher) | full_stack | 7.0 | [Open preview](https://rails-ai-build-trust.onrender.com/apps/sj26-mailcatcher) | [GitHub](https://github.com/sj26/mailcatcher) |
| 5 | [searchkick](https://rails-ai-build-trust.onrender.com/apps/ankane-searchkick) | full_stack | 7.0 | [Open preview](https://rails-ai-build-trust.onrender.com/apps/ankane-searchkick) | [GitHub](https://github.com/ankane/searchkick) |
| 6 | [friendly_id](https://rails-ai-build-trust.onrender.com/apps/norman-friendly-id) | full_stack | 7.0 | [Open preview](https://rails-ai-build-trust.onrender.com/apps/norman-friendly-id) | [GitHub](https://github.com/norman/friendly_id) |
| 7 | [cancan](https://rails-ai-build-trust.onrender.com/apps/ryanb-cancan) | full_stack | 7.0 | [Open preview](https://rails-ai-build-trust.onrender.com/apps/ryanb-cancan) | [GitHub](https://github.com/ryanb/cancan) |
| 8 | [ransack](https://rails-ai-build-trust.onrender.com/apps/activerecord-hackery-ransack) | full_stack | 7.0 | [Open preview](https://rails-ai-build-trust.onrender.com/apps/activerecord-hackery-ransack) | [GitHub](https://github.com/activerecord-hackery/ransack) |
| 9 | [rails_admin](https://rails-ai-build-trust.onrender.com/apps/railsadminteam-rails-admin) | engine | 7.0 | [Open preview](https://rails-ai-build-trust.onrender.com/apps/railsadminteam-rails-admin) | [GitHub](https://github.com/railsadminteam/rails_admin) |
| 10 | [clearance](https://rails-ai-build-trust.onrender.com/apps/thoughtbot-clearance) | engine | 7.0 | [Open preview](https://rails-ai-build-trust.onrender.com/apps/thoughtbot-clearance) | [GitHub](https://github.com/thoughtbot/clearance) |
| 11 | [meta-tags](https://rails-ai-build-trust.onrender.com/apps/kpumuk-meta-tags) | engine | 7.0 | [Open preview](https://rails-ai-build-trust.onrender.com/apps/kpumuk-meta-tags) | [GitHub](https://github.com/kpumuk/meta-tags) |
| 12 | [comfortable-mexican-sofa](https://rails-ai-build-trust.onrender.com/apps/comfy-comfortable-mexican-sofa) | engine | 6.1 | [Open preview](https://rails-ai-build-trust.onrender.com/apps/comfy-comfortable-mexican-sofa) | [GitHub](https://github.com/comfy/comfortable-mexican-sofa) |
| 13 | [rails](https://rails-ai-build-trust.onrender.com/apps/rails-rails) | monolith | 7.0 | [Open preview](https://rails-ai-build-trust.onrender.com/apps/rails-rails) | [GitHub](https://github.com/rails/rails) |
| 14 | [discourse](https://rails-ai-build-trust.onrender.com/apps/discourse-discourse) | monolith | 7.0 | [Open preview](https://rails-ai-build-trust.onrender.com/apps/discourse-discourse) | [GitHub](https://github.com/discourse/discourse) |
| 15 | [chatwoot](https://rails-ai-build-trust.onrender.com/apps/chatwoot-chatwoot) | monolith | 7.0 | [Open preview](https://rails-ai-build-trust.onrender.com/apps/chatwoot-chatwoot) | [GitHub](https://github.com/chatwoot/chatwoot) |
| 16 | [zammad](https://rails-ai-build-trust.onrender.com/apps/zammad-zammad) | api_only | 7.0 | [Open preview](https://rails-ai-build-trust.onrender.com/apps/zammad-zammad) | [GitHub](https://github.com/zammad/zammad) |
| 17 | [graphql-ruby](https://rails-ai-build-trust.onrender.com/apps/rmosolgo-graphql-ruby) | api_only | 7.0 | [Open preview](https://rails-ai-build-trust.onrender.com/apps/rmosolgo-graphql-ruby) | [GitHub](https://github.com/rmosolgo/graphql-ruby) |
| 18 | [rails-api](https://rails-ai-build-trust.onrender.com/apps/rails-api-rails-api) | api_only | 7.0 | [Open preview](https://rails-ai-build-trust.onrender.com/apps/rails-api-rails-api) | [GitHub](https://github.com/rails-api/rails-api) |
| 19 | [refinerycms](https://rails-ai-build-trust.onrender.com/apps/refinery-refinerycms) | legacy | 6.1 | [Open preview](https://rails-ai-build-trust.onrender.com/apps/refinery-refinerycms) | [GitHub](https://github.com/refinery/refinerycms) |
| 20 | [redmine](https://rails-ai-build-trust.onrender.com/apps/edavis10-redmine) | legacy | 7.0 | [Open preview](https://rails-ai-build-trust.onrender.com/apps/edavis10-redmine) | [GitHub](https://github.com/edavis10/redmine) |

**How to test an app:**

1. Open any **Preview** link above
2. Enter a prompt (e.g. `Add GET /health endpoint`)
3. Click **Run Ai::Driver** — NVIDIA NIM applies real file changes in that app's workspace
4. Or use the API: `curl -X POST https://rails-ai-build-trust.onrender.com/apps/discourse-discourse/run -H 'Content-Type: application/json' -d '{"message":"Add health check"}'`

**Trust report:** [Dashboard](https://shahnawaz-ror.github.io/Rails-Ai-Build/trust/) · [apps.json](https://shahnawaz-ror.github.io/Rails-Ai-Build/trust/apps.json) · Deploy server: `render.yaml` + `NVIDIA_API_KEY`

```bash
# Regenerate preview URL manifest
bundle exec rake rails_ai_build:trust:manifest

# Re-run 20-app live verification
NVIDIA_API_KEY=nvapi-... bundle exec rake rails_ai_build:trust:run
```

**Build anything** in any Rails 7.0–8.1 app — multitask queue, IDE, verify loop. See [`docs/UNIVERSAL_BUILDER.md`](./docs/UNIVERSAL_BUILDER.md) and [`docs/PLATFORM_ROADMAP.md`](./docs/PLATFORM_ROADMAP.md).

### Python

```python
pip install rails-ai-build

from rails_ai_build import configure, ask
configure(api_keys={"openai": "sk-..."})
result = ask("Add type hints to all functions in src/")
```

### JavaScript / TypeScript

```typescript
npm install @rails-ai-build/sdk

import { configure, ask } from "@rails-ai-build/sdk";
configure({ apiKeys: { openai: process.env.OPENAI_API_KEY! } });
const result = await ask("Add JSDoc to all exports in src/");
```

### Any language (via HTTP)

```bash
# Start the standalone server
cd server && bundle install && WORKSPACE_ROOT=/your/project bundle exec rackup -p 9292

# Call from Go, Java, PHP, Rust, etc.
curl -X POST http://localhost:9292/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "List all source files", "provider": "openai", "model": "gpt-4o"}'
```

See [`packages/core-protocol/openapi.yaml`](./packages/core-protocol/openapi.yaml) for the full API spec.

## Building a business?

See our strategic plans for turning this gem into a platform company:

- [Client Journey Master Plan](./docs/CLIENT_JOURNEY_MASTER_PLAN.md) — install → BYOK / Cloud / paid → full Cursor-class capability map
- [Business Plan](./docs/BUSINESS_PLAN.md) — market, revenue model, path to $1M+ ARR
- [Product Roadmap](./docs/PRODUCT_ROADMAP.md) — revenue-aligned feature tiers
- [Go-to-Market Playbook](./docs/GTM_PLAYBOOK.md) — "Forgot Cursor?" launch strategy
- **Day-1 Activation (v2.3):** `/rails_ai_build/ui/ide` wizard (BYOK / Cloud / License), Doctor tab, upgrade modal. Keys encrypted at rest; plan only via license or Stripe.

---

## Features

- **Multi-model support** — OpenAI, Anthropic, and custom providers (Ollama, Together, Groq, or any HTTP API)
- **Multi-language SDKs** — Ruby, Python, JavaScript with identical agent capabilities
- **Agent loop** — Tool-calling agent that iterates until the task is complete (like Cursor)
- **Built-in tools** — `read_file`, `write_file`, `grep`, `list_files`, `shell`
- **Rails engine** — REST API, ActiveRecord models, background jobs
- **Secure by default** — Workspace sandboxing, blocked dangerous shell commands
- **Extensible** — Register custom tools and model providers
- **Diff preview** — Review AI code changes before applying (Pro+)
- **Rails skill packs** — CRUD, auth, API, tests, refactor
- **Plan tiers** — Free, Pro ($29), Team ($99), Enterprise
- **GitHub Action** — Run agents in CI, auto-create PRs
- **Admin generator** — Mount team AI panel in your app
- **Token usage** — Track prompt/completion tokens and cost estimates
- **Help & support** — `rails rails_ai_build:doctor`, `help`, `stats`
- **1000-repo compatibility** — GitHub-discovered catalog; smoke (5 archetypes) on PR CI, full 1000 via rake

## Quick setup (5 minutes)

```bash
rails generate rails_ai_build:install
rails db:migrate
rails rails_ai_build:setup

# Run with a skill pack
rails rails_ai_build:skill[crud,"Create a Post resource with title and body"]

# Mount admin panel for your team
rails generate rails_ai_build:admin

# Add CI workflow + enterprise Docker setup
rails generate rails_ai_build:ci
rails generate rails_ai_build:enterprise
```

Add to your Gemfile:

```ruby
gem "rails_ai_build"
```

Then install:

```bash
bundle install
rails generate rails_ai_build:install
rails db:migrate
```

Set API keys in `config/initializers/rails_ai_build.rb` or via environment variables.
**NVIDIA NIM is fully supported** (free key at [build.nvidia.com](https://build.nvidia.com)):

```bash
# Recommended: NVIDIA NIM
export NVIDIA_API_KEY=nvapi-...
export NVIDIA_MODEL=meta/llama-3.1-8b-instruct   # optional

# Or OpenAI / Anthropic
export OPENAI_API_KEY=sk-...
export ANTHROPIC_API_KEY=sk-ant-...
```

When `NVIDIA_API_KEY` is set, the install initializer auto-selects `provider: :nvidia`.

```ruby
# Explicit NVIDIA usage
RailsAiBuild.configure do |config|
  config.api_keys[:nvidia] = ENV["NVIDIA_API_KEY"]
  config.default_provider = :nvidia
  config.default_model = "meta/llama-3.1-8b-instruct"
end

agent = RailsAiBuild::Agents::Agent.new(provider: :nvidia)
agent.chat("Add a health check endpoint")
```

## Quick Start

### Programmatic usage (no database)

```ruby
RailsAiBuild.configure do |config|
  config.apply_env_providers! # picks NVIDIA / OpenAI / Anthropic from ENV
end

result = RailsAiBuild::ChatService.ask(
  "Add a GET /health route that returns { status: 'ok' }"
)

puts result[:content]
```

### Create a persistent agent

```ruby
agent = RailsAiBuild::Agents::Agent.new(
  name: "feature-dev",
  provider: :anthropic,
  model: "claude-sonnet-4-20250514",
  system_prompt: "You are a senior Rails developer. Follow existing conventions."
)

result = agent.chat("Create a User model with name and email validations")
# Agent will read files, search codebase, and write changes using tools
```

### REST API

The engine mounts at `/rails_ai_build` by default.

```bash
# Create an agent
curl -X POST http://localhost:3000/rails_ai_build/agents \
  -H "Content-Type: application/json" \
  -d '{"agent": {"name": "dev-agent", "provider": "openai", "model_name": "gpt-4o"}}'

# Run an agent task (async via ActiveJob)
curl -X POST http://localhost:3000/rails_ai_build/agents/1/run \
  -H "Content-Type: application/json" \
  -d '{"message": "Add pagination to the users index"}'

# List available providers and models
curl http://localhost:3000/rails_ai_build/models/providers
```

## Web UI — Cursor-like IDE

After install, open the in-app IDE (engine root):

| URL | Purpose |
|-----|---------|
| `/rails_ai_build/ui/ide` | **IDE** — file explorer, editor, agent SSE, diff review, Git/PR |
| `/rails_ai_build/ui` | Dashboard — quick chat, pending changes |
| `/rails_ai_build/ui/demo` | **Live demo** — scripted SSE replay (no API key) |

```bash
bin/rails server
open http://localhost:3000/rails_ai_build/ui/ide
```

**Themes:** Dark · Light · Enterprise (GitHub × Cursor palette). See [docs/IDE_UI.md](docs/IDE_UI.md).

Pick a scenario on the demo page or run live agents from the IDE prompt bar — same SSE format as `POST /stream`.

Full guide: [docs/WEB_UI.md](docs/WEB_UI.md) · [docs/IDE_UI.md](docs/IDE_UI.md)

```bash
# Production streaming (requires API key)
curl -N -X POST http://localhost:3000/rails_ai_build/stream \
  -H "Content-Type: application/json" \
  -d '{"message":"Add a health check endpoint"}'
```

## Configuration

```ruby
# config/initializers/rails_ai_build.rb
RailsAiBuild.configure do |config|
  config.default_provider = :openai          # or :anthropic
  config.default_model    = "gpt-4o"
  config.max_agent_iterations = 25           # safety limit
  config.shell_timeout    = 30             # seconds
  config.allowed_tools    = %i[read_file write_file grep list_files shell]
  config.auto_mount       = true             # mount at /rails_ai_build

  config.api_keys = {
    openai:    ENV["OPENAI_API_KEY"],
    anthropic: ENV["ANTHROPIC_API_KEY"]
  }
end
```

### Manual mount

```ruby
# config/routes.rb
RailsAiBuild.configure { |c| c.auto_mount = false }
mount RailsAiBuild::Engine => "/ai"
```

## Custom Model Providers

### OpenAI-compatible (Ollama, Together, Groq, etc.)

```ruby
RailsAiBuild.configure do |config|
  config.register_provider(:ollama, RailsAiBuild::Models::CustomProvider,
    base_url: "http://localhost:11434/v1",
    api_key: "ollama",
    models: %w[llama3 codellama deepseek-coder],
    adapter: :openai_compatible
  )
end

agent = RailsAiBuild::Agents::Agent.new(provider: :ollama, model: "llama3")
```

### Fully custom HTTP endpoint

```ruby
RailsAiBuild::ChatService.register_custom_provider(
  :my_llm,
  api_key: ENV["MY_LLM_KEY"],
  endpoint: "https://api.example.com/v1/generate",
  models: %w[my-model-v1],
  request_builder: ->(messages, _tools, model, _opts) {
    { model: model, prompt: messages.last[:content] }
  },
  response_parser: ->(body) {
    { role: "assistant", content: body["text"], tool_calls: [] }
  }
)
```

## Custom Tools

Built-in **Rails Boost** introspection tools (Laravel Boost / Django AI Boost parity):

```bash
rails generate rails_ai_build:boost
```

| Tool | Purpose |
|------|---------|
| `application_info` | Rails/Ruby versions, convention profile |
| `list_routes` | HTTP routes |
| `database_schema` | Tables and columns |
| `list_rake_tasks` | `rails -T` tasks |
| `read_settings` | Safe config (dot notation) |
| `read_logs` | Tail development logs |
| `search_rails_docs` | Version-aware Guides links |

## Register custom tools

```ruby
class MySchemaTool < RailsAiBuild::Tools::BaseTool
  name "db_schema"
  description "Return the current database schema"
  parameters type: "object", properties: {}

  def execute(_args)
    { tables: ActiveRecord::Base.connection.tables }
  end
end

RailsAiBuild::Tools::Registry.register(:db_schema, MySchemaTool)
RailsAiBuild.configuration.allowed_tools << :db_schema
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Rails Application                     │
├─────────────────────────────────────────────────────────┤
│  RailsAiBuild::Engine                                    │
│  ├── REST API (Agents, Conversations, Models)            │
│  ├── ActiveRecord (AgentRecord, Conversation, Message)   │
│  └── AgentRunJob (background processing)                 │
├─────────────────────────────────────────────────────────┤
│  RailsAiBuild::Agents::Agent                             │
│  └── RailsAiBuild::Agents::Runner (tool-calling loop)  │
├─────────────────────────────────────────────────────────┤
│  Model Providers                                         │
│  ├── OpenaiProvider                                      │
│  ├── AnthropicProvider                                   │
│  └── CustomProvider (adapters + custom HTTP)             │
├─────────────────────────────────────────────────────────┤
│  Tools                                                   │
│  ├── read_file / write_file                              │
│  ├── grep / list_files                                   │
│  ├── shell (sandboxed)                                   │
│  └── Rails Boost (MCP introspection)                     │
│      application_info, list_routes, database_schema, …   │
└─────────────────────────────────────────────────────────┘
```

## Agent Loop

The agent works like Cursor's agent mode:

1. User sends a prompt
2. Model responds with text and/or tool calls
3. Tools execute against the workspace (read files, write code, run commands)
4. Tool results are fed back to the model
5. Loop continues until the model stops calling tools or max iterations is reached

```ruby
runner = RailsAiBuild::Agents::Runner.new(agent: agent)
  .on(:on_tool_call) { |tc| puts "Calling: #{tc[:name]}" }
  .on(:on_complete)  { |r|  puts "Done: #{r[:content]}" }

result = runner.run!
```

## Security

- All file operations are sandboxed to `workspace_root` (defaults to `Rails.root`)
- Shell tool blocks dangerous commands (`rm -rf /`, pipe-to-sh, etc.)
- Tool allowlist via `config.allowed_tools`
- API keys should be stored in environment variables, not committed to source

## Development

```bash
bundle install
bundle exec rspec
```

## Roadmap

- [x] Streaming responses (SSE)
- [x] Web UI dashboard (`/rails_ai_build/ui`)
- [x] Diff preview before applying writes
- [x] Git integration (branch, commit, PR — GitHub & GitLab)
- [x] MCP tool protocol support
- [x] Multi-agent orchestration (planner → coder → reviewer)
- [x] Token usage tracking & analytics
- [x] 100 OSS Rails repo compatibility suite
- [x] Help, support & doctor diagnostics

## License

MIT
