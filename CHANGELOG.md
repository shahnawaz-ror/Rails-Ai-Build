# Changelog

## [1.2.0] - 2026-07-09

### Added
- **Token usage tracking** — prompt/completion tokens, cost estimates (all plans)
- **Enhanced analytics** — dashboard with health, tokens, events (`GET /analytics`, `GET /tokens`)
- **Help & support** — topics API, doctor diagnostics, contact info
- **Settings API** — `GET/PATCH /rails_ai_build/settings`
- **100-repo compatibility suite** — validates gem against OSS Rails catalog
- **Edge case hardening** — unicode, empty files, path traversal, binary skip
- **Rake tasks** — `doctor`, `help`, `stats`, `compatibility`

### Specs
- 25+ spec files covering tools, agents, compatibility, analytics, support

## [1.1.0] - 2026-07-09

### Added
- **Cloud hosted models** — `Cloud::HostedProvider` for Pro+ (no BYOK required)
- **Usage analytics** — track events, tokens, daily breakdown (Team+)
- **RBAC** — role-based tool access (Enterprise)
- **SSO/SAML** — configuration scaffolding (Enterprise)
- **Slack bot** — slash command webhook + generator
- **Discord bot** — interactions webhook + generator
- **Community marketplace** — submit and approve agent packs
- **Web UI dashboard** — `/rails_ai_build/ui` with chat, diff approval, analytics

## [1.0.0] - 2026-07-09

### Added
- **Agent memory** — persist project context across sessions (Pro+)
- **Marketplace** — agent packs catalog with install API
- **Shared agents** — team prompt library (Team+)
- **PR integration** — auto-branch and GitHub PR URL (Team+)
- **CI generator** — `rails generate rails_ai_build:ci`
- **Enterprise generator** — Docker self-hosted installer
- **GitHub workflows** — CI, release (RubyGems/PyPI/npm), landing deploy
- **Launch checklist** — docs/LAUNCH.md

### Complete platform
- Ruby gem, Python SDK, JavaScript SDK, HTTP server
- Diff preview, skill packs, plan tiers, billing, admin generator
- Business plan, GTM playbook, product roadmap

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
