# Changelog

## [1.5.0] - 2026-07-09

### Added — Full developer workflow specs & upgrade path
- **ActiveRecord test harness** — Combustion with full schema, model/job/request coverage
- **Upgrade system** — `RailsAiBuild::Upgrade`, `rails generate rails_ai_build:upgrade`, `rails rails_ai_build:upgrade`
- **Version stamping** — install generator stamps `rails_ai_build_version` in initializer
- **Doctor upgrade check** — diagnostics detect outdated installs
- **Help topic** — `upgrade` for chat-based install → upgrade flows
- **80+ new specs** — models, CRUD APIs, chat, changes, git, billing, marketplace, orchestration, generators, rake tasks
- **Multi-DB CI** — sqlite3, PostgreSQL, MySQL matrix (`TEST_DB_ADAPTER`)
- **Ruby 3.4** added to CI matrix (3.1 → 3.4)

## [1.4.2] - 2026-07-09

### Added — CI/CD coverage
- **SimpleCov** + Cobertura XML for Ruby (`COVERAGE=true bundle exec rspec`)
- **pytest-cov** for Python SDK
- **PR coverage comment** — sticky markdown table (Ruby + Python lines/branches)
- **Codecov upload** (optional `CODECOV_TOKEN` secret)
- CI best practices: concurrency groups, job names, coverage artifacts

## [1.4.1] - 2026-07-09

### Added
- **Web UI live demo** — `/rails_ai_build/ui/demo` with real-time SSE agent replay (no API key)
- **4 example scenarios** — health check, CRUD, fix test, API auth with scripted tool calls
- **`docs/WEB_UI.md`** — complete user guide with curl/API examples
- **`landing/demo.html`** — static web UI snapshot for GitHub Pages
- Dashboard example prompt chips + link to demo
- Help topic: `web-ui`

## [1.4.0] - 2026-07-09

### Added — Gem engineering & quality
- **RuboCop** — `.rubocop.yml` with rubocop-rails, rubocop-rspec, rubocop-performance
- **Rakefile** — `rake` runs RuboCop + RSpec; `rake ci` for CI parity
- **Combustion internal app** — `spec/internal/` for engine integration/request specs
- **Request specs** — HTTP coverage for help, plans, settings, doctor, MCP, dashboard
- **Expanded unit specs** — configuration, registry, OpenAI provider (WebMock), errors, engine
- **Appraisal** — multi-Rails matrix (7.0, 7.1, 7.2, 8.0)
- **Contributor docs** — `CONTRIBUTING.md`, `SECURITY.md`, `.ruby-version`, `bin/setup`, `bin/console`
- **CI** — dedicated RuboCop job, Ruby 3.1–3.3 matrix, appraisal job

### Fixed
- `RailsAiBuild::Providers` top-level alias (engine initializer)
- Settings API accepts string keys from `ActionController::Parameters`
- Version spec drift (`rails_ai_build_spec` expected `0.1.0`)
- Gemspec metadata (homepage, changelog URI, MFA flag)

## [1.3.0] - 2026-07-09

### Added — Final scope complete
- **SSE streaming** — `POST /rails_ai_build/stream` for real-time agent events
- **Git integration** — status, diff, commit, branch (`GET /git/status`, `/git/diff`)
- **GitHub & GitLab PR** support in pull request integration
- **MCP protocol** — `POST /rails_ai_build/mcp` JSON-RPC server for tool exposure
- **Multi-agent orchestration** — planner → coder → reviewer pipeline
- **Slack notifications** — webhook notifications on agent completion
- **Enterprise docs** — `docs/ENTERPRISE.md`, case study template
- **Rake task** — `rails rails_ai_build:orchestrate[task]`

### Roadmap: 100% code complete ✅

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
