# In-App IDE — Cursor inside your Rails app

> **Route:** `/rails_ai_build/ui/ide` (also the engine root `/rails_ai_build`)

## Overview

Rails AI Build IDE brings a **Cursor-style workspace** into any Rails application — file explorer, code viewer, live agent streaming, diff review, Git status, and enterprise controls — all themed and mounted via the gem engine.

## Quick start

```bash
rails generate rails_ai_build:install
rails generate rails_ai_build:boost   # optional introspection tools
rails db:migrate

open http://localhost:3000/rails_ai_build/ui/ide
```

## Layout

```
┌─────────────────────────────────────────────────────────────────┐
│ Top bar: branch · plan badge · provider · theme · nav           │
├────┬──────────────┬─────────────────────────────┬──────────────┤
│ 📁 │  Explorer    │  Editor / Agent stream      │ Changes      │
│ 🤖 │  file tree   │  SSE tool calls + prompt    │ Git / PR     │
│ ⎇  │              │                             │ Enterprise   │
└────┴──────────────┴─────────────────────────────┴──────────────┘
```

## Themes

| Theme | Use case |
|-------|----------|
| **Dark** | Default Cursor-like dark UI |
| **Light** | Daytime / presentation |
| **Enterprise** | Purple/gold accents — GitHub Enterprise × Cursor |

Theme choice persists in `localStorage` (`rab-theme`).

## Panels

### Explorer (left)
- Loads `GET /workspace/tree?depth=3`
- Click file → `GET /workspace/file?path=…` in editor

### Agent (center-bottom)
- **Pro+:** live `POST /stream` (SSE) — same events as demo
- **Free:** falls back to sync `POST /chat`
- Skill dropdown + provider picker in top bar

### Changes (right)
- Pending diffs from `diff_preview` workflow
- Click change → unified diff view
- Apply / Reject / Apply All

### Git (right, Team+)
- Branch + changed files from `Integrations::Git`
- **Create GitHub PR** → `POST /pull_requests` (compare URL)

### Enterprise (right)
- Plan feature matrix (streaming, audit, SSO, RBAC, MCP…)
- **Load audit log** (Team+) → `GET /audit`
- SSO setup via `GET /auth/saml`

## Enterprise mount (like GitHub + Cursor)

```bash
rails generate rails_ai_build:enterprise
rails generate rails_ai_build:admin   # Devise-gated /admin/ai
```

```ruby
# config/initializers/rails_ai_build_enterprise.rb
RailsAiBuild.configure do |config|
  config.plan = :enterprise
  config.audit_enabled = true
  config.rbac_enabled = true
  config.saml_enabled = true
  config.diff_preview = true
end
```

Mount behind your host app auth; set `RailsAiBuild::Rbac.current_role` per request.

## API map

| UI action | Endpoint |
|-----------|----------|
| File tree | `GET /workspace/tree` |
| Read file | `GET /workspace/file?path=` |
| Agent (live) | `POST /stream` |
| Agent (sync) | `POST /chat` |
| Apply change | `POST /changes/:id/apply` |
| Git status | `GET /git/status` |
| Create PR | `POST /pull_requests` |
| Audit log | `GET /audit` |

## Related docs

- [WEB_UI.md](./WEB_UI.md) — dashboard + demo
- [ENTERPRISE.md](./ENTERPRISE.md) — SSO, Docker, air-gap
- [FRAMEWORK_PARITY_ROADMAP.md](./FRAMEWORK_PARITY_ROADMAP.md) — MCP Boost tools
