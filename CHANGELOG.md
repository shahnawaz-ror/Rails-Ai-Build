# Changelog

## [2.2.5] - 2026-07-16

### Fixed — Task queue thread storm (`can't create Thread`)
- **`Tasks::Queue`** no longer recursively spawns workers from every idle `process_next`
- Bounded worker pool: workers drain queued tasks, unregister themselves, then refill only up to `max_concurrent_tasks`
- Stops `ThreadError: Resource temporarily unavailable` infinite spawn loops in host apps

## [2.2.4] - 2026-07-16

### Added — Migration intelligence (auto-heal DuplicateMigrationVersionError)
- **`Migrations::Intelligence`** detects duplicate / short versions (e.g. padded `000…2024` → `2024`)
- **Auto-heal on boot** in development/test — renames bad `rails_ai_build` migrations to unique UTC timestamps
- **`rails rails_ai_build:fix_migrations`** — explicit repair (supports `DRY_RUN=1`)
- Doctor + install + setup all run migration intelligence so the IDE does not brick host apps

## [2.2.3] - 2026-07-16

### Fixed — Free plan streaming + auto-apply + migration versions
- **Free plan** includes `streaming` and `nvidia` (BYOK) so IDE SSE works without Pro
- Install initializer defaults `diff_preview = false` so `write_file` auto-applies
- Install migration numbering always uses UTC timestamps (fixes `DuplicateMigrationVersionError` for version `2024`)
- IDE `data-base` uses `script_name` and strips trailing slash (fixes `/rails_ai_build//tasks`)
- Changes panel explains auto-apply vs pending-diff review mode

## [2.2.2] - 2026-07-16

### Fixed — Engine load in host Rails apps
- Require `rails_ai_build/engine` when Rails is present so `/rails_ai_build` mounts and rake tasks register
- Explicit `rake_tasks` load for `rails_ai_build:setup`, `:doctor`, `:ask`, etc.
- Fixes `UnrecognizedCommandError` for `rails rails_ai_build:setup` and missing `/rails_ai_build` route

## [2.2.1] - 2026-07-16

### Added — NVIDIA API provision for host apps
- Install initializer includes `nvidia` API key + auto-selects `:nvidia` when `NVIDIA_API_KEY=nvapi-…`
- `Configuration#apply_env_providers!` — load OpenAI / Anthropic / NVIDIA from ENV
- Doctor + help topics recognize NVIDIA NIM keys
- README documents NVIDIA as a first-class provider for any Rails app

## [2.2.0] - 2026-07-09

### Added — Cursor parity (real-time + git isolation + threads)
- **Token streaming** — word-by-word `delta` events from providers via `Ai::Driver`
- **`tool_result` SSE** — tool output streamed back to IDE after each call
- **`POST /build/stream`** — SSE for universal builder (attempt/verify/complete events)
- **`POST /tasks/:id/stream`** — per-task live event stream + `Tasks::EventBus`
- **`GET/POST/DELETE /ai/sessions`** — conversation thread API
- **IDE Threads panel** — sidebar thread list, New Chat, session switch
- **Composer mode** — multi-file plan-first builds via `/build/stream?composer=true`
- **Task polling** — auto-refresh + subscribe to running task streams
- **Git isolation** — `branch_per_task` on enqueue, `auto_pr_on_complete` on success
- **Coordinator boost** — planner/coder/reviewer use Rails Boost tools; verify = zeitwerk + test

### Changed
- `Tasks::Runtime` streams through `Ai::Driver` when task has events
- `PullRequest.create` accepts `existing_branch` for branch-per-task flow
- IDE Build mode uses SSE instead of blocking JSON

### Added — NVIDIA NIM provider + live specs
- **`Models::NvidiaProvider`** — OpenAI-compatible `https://integrate.api.nvidia.com/v1`
- **`spec/live/nvidia_integration_spec.rb`** — real API tests (skipped unless `NVIDIA_API_KEY` set)
- Live specs verify: chat, tool calling, `Ai::Driver` file writes, SSE stream, `POST /ai/chat`

### Added — Live Trust (20 real Rails apps)
- **`Trust::Runner`** — NVIDIA live tests on 20 catalog app archetypes
- **`Trust::AppSandbox`** — per-app preview UI + `POST /apps/:slug/run` API
- **`spec/live/trust_20_apps_spec.rb`** — 20-app proof suite (19/20+ pass target)
- **README** — table of 20 live preview URLs with gem pre-installed
- **[Trust Dashboard](https://shahnawaz-ror.github.io/Rails-Ai-Build/trust/)** — GitHub Pages public report
- **`render.yaml`** — free Render deploy for live trust API
- `rails rails_ai_build:trust:manifest` / `trust:run` — manifest + results

### Fixed
- **Appraisal CI** — replace `install_if` lambda in Gemfile (Appraisal-incompatible); optional `pg`/`mysql2` via `INSTALL_ALL_DBS`
- **Sinatra routes** — `/apps/:slug` param routes (Mustermann compile error with `$` anchor)

## [2.1.0] - 2026-07-09

### Added — AI Driver (model-first, like Cursor & Claude)
- **`Ai::Driver`** — single model-first entry point for all AI operations
- **`Ai::Session`** — multi-turn conversation threads (Claude-style)
- **`Ai::ContextEngine`** — auto-assembles app context before every model call
- **`POST /ai/chat`** and **`POST /ai/stream`** — unified AI API with SSE events
- SSE events: `session`, `context`, `delta`, `tool_call`, `done`
- **`docs/AI_ARCHITECTURE.md`** — model-first architecture guide
- `ChatService.ask` / `POST /stream` / `Tasks::Runtime` now route through Driver
- IDE uses `/ai/stream` with persistent `session_id` (multi-turn threads)

## [2.0.0] - 2026-07-09

### Added — Multitask platform
- **`Tasks::Queue`** — background task queue with parallel workers (`max_concurrent_tasks: 2`)
- **`POST /tasks`** — enqueue builds; `GET /tasks`, `GET /tasks/:id`, `DELETE /tasks/:id`
- **Tools** — `list_migrations` (pending detection), `model_attributes` (columns/associations)
- **`Coordinator#run_until_green`** — orchestrate until zeitwerk passes (`until_green: true`)
- **IDE** — Tasks panel, Build/Queue/Agent modes in prompt bar
- **`docs/PLATFORM_ROADMAP.md`** — v2.0–v2.4 platform vision
- Config: `multitask_enabled`, `max_concurrent_tasks`, `sync_tasks` (test mode)

## [1.9.0] - 2026-07-09

### Added — Universal Builder (build anything)
- **`Builder::Universal`** — build any feature in any Rails app with verify-and-restart loop
- **`Tasks::Runtime`** — Cursor-style explore → build → verify → fix (max 3 attempts)
- **`POST /build`** — API for universal builder with optional verify
- **Rake** — `rails_ai_build:build`, `:fix`, `:test`
- **Tools** — `list_models`, `run_rails_check` (zeitwerk, rspec/minitest, rubocop)
- **Skills** — `build`, `fix`, `feature`, `migration`
- **Auto context** — ConventionDetector + universal prompt injected into every agent (configurable)
- **`ChatService.build` / `.fix`** — programmatic entry points
- **Docs** — `docs/UNIVERSAL_BUILDER.md`

### Changed
- Default `universal_builder: true`, `verify_builds: true`, `build_max_attempts: 3`

## [1.8.0] - 2026-07-09

### Added — Cursor-like in-app IDE (enterprise UI)
- **`/rails_ai_build/ui/ide`** — full IDE workspace: file explorer, editor, agent SSE stream, diff review
- **Themes** — Dark, Light, and Enterprise (GitHub × Cursor palette) with localStorage persistence
- **Workspace API** — `GET /workspace/tree`, `GET /workspace/file` for IDE panels
- **Enterprise panel** — plan badges, feature gates, audit log, SSO/RBAC indicators
- **GitHub panel** — branch status, changed files, one-click PR (Team+)
- **Root route** — engine root now opens IDE (dashboard + demo still available)
- **`docs/IDE_UI.md`** — IDE user guide

### Changed
- Dashboard and demo link to IDE; shared `rails_ai_build` layout + theme system

## [1.7.0] - 2026-07-09

### Added — Rails Boost (Laravel/Django parity)
- **7 introspection MCP tools** — `application_info`, `list_routes`, `database_schema`, `list_rake_tasks`, `read_settings`, `read_logs`, `search_rails_docs`
- **`rails generate rails_ai_build:boost`** — enables Boost tools, Cursor rules, MCP client config
- **`docs/FRAMEWORK_PARITY_ROADMAP.md`** — Rails release matrix + competitor parity plan
- **Rails 8.1 appraisal** — full matrix 7.0 → 8.1
- **CI** — per-appraisal matrix job (blocking)
- **GitHub discovery** — infers Rails 8.1 from repo metadata

### Changed
- RBAC roles include read-only Boost tools for viewer/reviewer roles
- Tools work with file-based fallbacks when Rails is not loaded

## [1.6.0] - 2026-07-09

### Added — 1000-repo GitHub compatibility program
- **GitHub discovery** — `GithubDiscovery` fetches 1000 public Rails repos via GitHub API
- **Expanded catalog** — `lib/rails_ai_build/compatibility/data/rails_repos.yml` (1000 entries with stars, topics, github URL)
- **Tiered checker** — `:smoke` (5 archetypes) vs `:full` (1000), parallel workers, `COMPAT_SLICE` sharding
- **Improvement plan** — `ImprovementPlan` + `rails rails_ai_build:compatibility:plan` from catalog analytics
- **Convention detector** — RSpec/Minitest, Sidekiq, Hotwire, API-only detection from Gemfile
- **Docs** — `docs/COMPATIBILITY_ROADMAP.md` (broad plan from 1000-repo analysis)
- **CI** — `compatibility-smoke` job on every PR
- **Rake** — `compatibility:discover`, `:smoke`, `:plan`, `:conventions`
- Fixed `grep` binary edge-case test; added `write_file` to compat tool checks

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
