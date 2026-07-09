# Framework Parity Roadmap — Rails Boost

> Inspired by **Laravel Boost**, **Django AI Boost**, and **django-agentic** — mapped to `rails_ai_build` capabilities.

## Executive summary

Other frameworks already ship **AI-native introspection** (MCP tools that read routes, schema, settings, logs) plus **version-aware install generators**. Rails AI Build had file/shell tools and a basic MCP server but no Rails-specific context. **v1.7** closes that gap with **Rails Boost** introspection tools and a full **Rails 7.0–8.1** release matrix.

---

## Rails release matrix

| Version | Gemspec | Appraisal | CI appraisal | Catalog inference | Notes |
|---------|---------|-----------|--------------|-------------------|-------|
| 6.1 | ❌ `>= 7.0` | ❌ | ❌ | ✅ legacy archetype | Out of support scope |
| 7.0 | ✅ | ✅ `rails-7-0` | ✅ | ✅ default | LTS baseline |
| 7.1 | ✅ | ✅ `rails-7-1` | ✅ | ✅ | |
| 7.2 | ✅ | ✅ `rails-7-2` | ✅ | ✅ | |
| 8.0 | ✅ | ✅ `rails-8-0` | ✅ | ✅ | |
| 8.1 | ✅ | ✅ `rails-8-1` | ✅ matrix job | ✅ **v1.7** | Current lockfile default |

### v1.7 deliverables (this release)

- `appraise "rails-8-1"` in `Appraisals`
- Per-appraisal CI matrix (blocking when green)
- `GithubDiscovery#infer_rails_version` recognizes 8.1
- README documents **Rails 7.0–8.1** support

---

## Competitor feature parity

| Capability | Laravel Boost | Django AI Boost | rails_ai_build v1.7 |
|------------|---------------|-----------------|---------------------|
| MCP server | ✅ 15+ tools | ✅ read-only | ✅ file + **7 introspection tools** |
| `application_info` | ✅ | ✅ app metadata | ✅ `application_info` |
| Routes / URLs | ✅ | ✅ `list_urls` | ✅ `list_routes` |
| DB schema | ✅ | ✅ migrations/schema | ✅ `database_schema` |
| Rake / management cmds | ✅ `list_artisan` | ✅ `list_commands` | ✅ `list_rake_tasks` |
| Settings (safe keys) | ✅ config | ✅ dot notation | ✅ `read_settings` |
| Logs | ✅ | ✅ tail logs | ✅ `read_logs` |
| Docs search (versioned) | ✅ | — | ✅ `search_rails_docs` |
| Install generator | `boost:install` | `django-ai-boost` | ✅ `rails_ai_build:boost` |
| AI guidelines / skills | ✅ version-aware | ✅ | ✅ `.cursor/rules/rails-boost.mdc` |
| HITL write tools | partial | ✅ django-agentic | ✅ `diff_preview` (Pro+) |
| Compatibility program | — | — | ✅ 1000-repo catalog (v1.6) |
| Agent commands (`ai:fix`) | Laravel Tackle | — | 🔜 Phase 3 |

---

## Phase 1 — Rails Boost introspection (v1.7) ✅

```bash
rails generate rails_ai_build:boost
```

Registers MCP tools:

| Tool | Description |
|------|-------------|
| `application_info` | Rails/Ruby versions, gems, ConventionDetector profile |
| `list_routes` | Engine + host routes (live or `routes.rb` parse) |
| `database_schema` | Tables/columns from `schema.rb` or ActiveRecord |
| `list_rake_tasks` | `rails -T` output or `.rake` file scan |
| `read_settings` | Safe config keys via dot notation |
| `read_logs` | Tail `log/development.log` (or custom path) |
| `search_rails_docs` | Version-aware Rails Guides links |

Works **without a running Rails process** (file-based fallbacks) so agents and MCP clients can introspect from workspace files.

---

## Phase 2 — Deep Rails context (v1.8)

| Item | Source inspiration |
|------|-------------------|
| `list_models` / `model_attributes` | Django `list_models` |
| `list_migrations` + pending check | Django schema tools |
| `run_rails_check` (`bin/rails zeitwerk:check`, RuboCop) | Django `run_check` |
| Engine-isolated route mounting | 7% engine archetype (catalog) |
| Browser / test failure logs | Laravel Boost browser logs |

---

## Phase 3 — Agent commands (v1.9)

Inspired by **Laravel Tackle**:

```bash
rails rails_ai_build:code[task]
rails rails_ai_build:fix[failed_spec]
rails rails_ai_build:test[path]
```

With PathGuard (workspace sandbox), self-healer loop on CI failures, and credits/usage logging.

---

## Phase 4 — Rails 6.1 legacy lane (optional)

Only if catalog demand warrants it:

- Separate appraisal `rails-6-1` with `load_defaults 6.1` harness
- Relaxed gemspec constraint behind feature flag
- Legacy archetype fixtures (21 repos in catalog)

---

## How to verify

```bash
# Install Boost tools in a host app
rails generate rails_ai_build:boost

# Run specs (includes introspection tool specs)
bundle exec rspec

# Multi-Rails matrix
bundle exec appraisal install
bundle exec appraisal rake spec

# MCP tools/list includes introspection tools when allowed
curl -X POST http://localhost:3000/rails_ai_build/mcp \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```
