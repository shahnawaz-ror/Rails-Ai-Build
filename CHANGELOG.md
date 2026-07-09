# Changelog

## [0.3.0] - 2026-07-09

### Added
- **Diff preview** — queue file writes for approval before applying (Pro+)
- **Rails skill packs** — crud, auth, api, tests, refactor with convention-aware prompts
- **Plan tiers** — Free, Pro, Team, Enterprise with feature gates
- **Billing scaffolding** — Stripe checkout + webhook handlers
- **Admin generator** — `rails generate rails_ai_build:admin`
- **Setup task** — `rails rails_ai_build:setup` one-command onboarding
- **Skill task** — `rails rails_ai_build:skill[crud,message]`
- **GitHub Action** — `.github/actions/rails-ai-build` for CI
- **Landing page** — `landing/index.html` with pricing and waitlist
- **Audit log** — track agent actions (Team+)
- **Changes API** — apply/reject pending diffs
- **Dashboard, Chat, Skills, Plans API endpoints**

## [0.2.0] - 2026-07-09

### Added
- **Python SDK** (`packages/python`) — standalone agent with embedded tools, CLI, remote client
- **JavaScript/TypeScript SDK** (`packages/javascript`) — Node.js agent, CLI, remote client
- **Standalone HTTP server** (`server/`) — Sinatra/Rack API callable from any language
- **OpenAPI spec** (`packages/core-protocol/openapi.yaml`) — universal API contract
- Multi-language monorepo documentation

## [0.1.0] - 2026-07-09

### Added
- Initial release of `rails_ai_build` gem
- Rails engine with REST API for agents, conversations, and model configs
- Agent system with tool-calling loop (read/write files, grep, shell)
- OpenAI and Anthropic model providers
- Custom provider support (OpenAI-compatible adapters and custom HTTP endpoints)
- Install generator with migrations and initializer
- Background job processing via ActiveJob
- Workspace sandboxing and shell command safety filters
