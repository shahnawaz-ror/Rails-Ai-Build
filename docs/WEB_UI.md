# Web UI — Live Demo & User Guide

See the agent in action at **`/rails_ai_build/ui/demo`** after installing the gem.

## Quick access

```bash
# 1. Install
gem "rails_ai_build"
bundle install
rails generate rails_ai_build:install
rails db:migrate

# 2. Set API key (for live runs on dashboard)
export OPENAI_API_KEY=sk-...

# 3. Start Rails
bin/rails server

# 4. Open in browser
open http://localhost:3000/rails_ai_build/ui/demo
```

| URL | What it does |
|-----|----------------|
| `/rails_ai_build/ui` | Dashboard — chat, pending changes, analytics |
| `/rails_ai_build/ui/demo` | **Live demo** — real-time SSE agent replay (no API key) |
| `/rails_ai_build/api` | JSON dashboard payload |
| `/rails_ai_build/stream` | SSE streaming agent (production) |

---

## Live demo page

The demo page shows exactly how users interact with the gem in a browser:

```
┌─────────────────┬──────────────────────────────┬─────────────────┐
│ Example         │  SSE event stream            │ API equivalent  │
│ scenarios       │  start → tool_call →         │ curl POST       │
│                 │  iteration → complete          │ /stream         │
└─────────────────┴──────────────────────────────┴─────────────────┘
```

### Built-in scenarios

| Scenario | User prompt | Skill | What the agent does |
|----------|-------------|-------|---------------------|
| Health check | Add GET /health endpoint | — | `read_file` routes → `write_file` controller → `shell` verify |
| Post CRUD | Create Post with title/body | `crud` | `list_files` → `rails g model` → controller + specs |
| Fix test | Fix users_controller_spec:42 | `tests` | `read_file` spec → patch assertion → `rspec` |
| API auth | Add JWT to API namespace | `auth` | Multi-agent: planner → coder → reviewer |

Click **Run Live Example** — events stream in real time via `POST /demo/stream` (same SSE format as production `POST /stream`).

---

## Real-time example: Health check

### 1. User opens dashboard

```
http://localhost:3000/rails_ai_build/ui
```

### 2. User types prompt (or clicks example chip)

```
Add a GET /health endpoint that returns { status: ok, version: Rails.version }
```

### 3. Agent streams events (SSE)

```http
POST /rails_ai_build/stream HTTP/1.1
Content-Type: application/json

{"message":"Add a GET /health endpoint returning JSON status"}
```

**Stream response:**

```
event: start
data: {"message":"Add a GET /health endpoint returning JSON status"}

event: iteration
data: {"content":"I'll inspect your routes first.","tool_calls":1}

event: tool_call
data: {"name":"read_file","arguments":{"path":"config/routes.rb"}}

event: tool_call
data: {"name":"write_file","arguments":{"path":"app/controllers/health_controller.rb"}}

event: complete
data: {"content":"Done! Added GET /health...","usage":{"total_tokens":1620}}
```

### 4. Diff preview (Pro+)

Pending changes appear in the dashboard. User clicks **Apply** or **Apply All**.

```bash
curl -X POST http://localhost:3000/rails_ai_build/changes/demo-1/apply
```

---

## Real-time example: CRUD with skill pack

### Dashboard

1. Select skill: **crud**
2. Prompt: `Create a Post model with title and body`
3. Click **Run Agent**

### CLI equivalent

```bash
rails rails_ai_build:skill[crud,"Create a Post resource with title and body"]
```

### API equivalent

```bash
curl -X POST http://localhost:3000/rails_ai_build/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Create Post CRUD with title and body",
    "skill": "crud"
  }'
```

**Response:**

```json
{
  "role": "assistant",
  "content": "Post CRUD complete: model, migration, controller, routes, specs.",
  "pending_changes": [
    {"id": "abc123", "path": "app/models/post.rb", "status": "pending"},
    {"id": "def456", "path": "app/controllers/posts_controller.rb", "status": "pending"}
  ]
}
```

---

## Multi-agent orchestration (Team+)

```bash
curl -X POST http://localhost:3000/rails_ai_build/orchestrate \
  -H "Content-Type: application/json" \
  -d '{"task":"Add JWT authentication to API namespace"}'
```

Pipeline: **planner** (read-only) → **coder** (write tools) → **reviewer** (read + grep).

Watch this flow in the demo under **Add API authentication**.

---

## Mount in your app

```ruby
# config/routes.rb
mount RailsAiBuild::Engine => "/rails_ai_build"

# Or custom path
RailsAiBuild.configure { |c| c.auto_mount = false }
mount RailsAiBuild::Engine => "/ai"
```

```ruby
# config/initializers/rails_ai_build.rb
RailsAiBuild.configure do |config|
  config.plan = :pro
  config.diff_preview = true
  config.api_keys[:openai] = ENV["OPENAI_API_KEY"]
end
```

---

## Screenshots / snapshot

The demo page (`/rails_ai_build/ui/demo`) is the canonical **web snapshot** of gem usage:

- Left: pick a real-world scenario
- Center: live SSE event feed (tool calls animate in)
- Right: equivalent `curl` command + pending file queue

For GitHub Pages preview, see `landing/demo.html`.

---

## Production checklist

- [ ] Mount engine behind authentication in production
- [ ] Set `OPENAI_API_KEY` or `ANTHROPIC_API_KEY`
- [ ] Restrict `allowed_tools` if needed (e.g. disable `shell`)
- [ ] Enable `diff_preview` on Pro+ for approval workflow
- [ ] Run `rails rails_ai_build:doctor` to verify setup
