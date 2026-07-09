# Platform Roadmap v2 — Cursor for Rails

> **Vision:** Every Rails application gets a full AI platform — build anything, multitask like Cursor, enterprise-ready like GitHub.

## Stack today (v2.2)

| Layer | Status |
|-------|--------|
| Universal Builder | ✅ verify-and-restart loop |
| AI Driver (model-first) | ✅ `Ai::Driver`, sessions, context engine |
| Cursor parity | ✅ SSE streaming, threads, git isolation, Composer |
| NVIDIA NIM provider | ✅ live specs + 20-app trust sandboxes |
| Rails Boost MCP | ✅ 9 introspection tools |
| In-app IDE | ✅ dark/light/enterprise themes + task polling |
| 1000-repo compatibility | ✅ catalog + smoke CI |
| Live trust previews | ✅ 20 app URLs + Render deploy (`render.yaml`) |
| Enterprise gates | ✅ SSO/RBAC/audit/GitHub PR |

## v2.0 — Multitask platform ✅

| Deliverable | Description |
|-------------|-------------|
| **Task Queue** | `POST /tasks` enqueue, `GET /tasks/:id` poll, parallel workers |
| **`list_migrations`** | Pending migration detection |
| **`model_attributes`** | Column/association detail per model |
| **`run_until_green`** | Orchestrator verify loop (planner→coder→reviewer→fix) |
| **IDE tasks panel** | Queue UI + Build mode (`POST /build`) |
| **Platform config** | `max_concurrent_tasks`, `multitask_enabled` |

```bash
# Enqueue background builds
curl -X POST /rails_ai_build/tasks -d '{"task":"Add billing module"}'
curl GET /rails_ai_build/tasks

# Orchestrate until green
curl -X POST /rails_ai_build/orchestrate -d '{"task":"...","until_green":true}'
```

## v2.1 — AI Driver (model-first) ✅

| Item | Detail |
|------|--------|
| `Ai::Driver` | Single brain for chat, build, tasks, IDE |
| `Ai::Session` | Multi-turn conversation threads |
| `Ai::ContextEngine` | Auto-assembled app context per call |
| `POST /ai/chat`, `/ai/stream` | Unified AI API with SSE events |

## v2.2 — Real-time platform + live trust ✅

| Item | Detail |
|------|--------|
| `POST /build/stream` | SSE for universal builder |
| `POST /tasks/:id/stream` | Per-task event stream |
| Token streaming | Provider delta events in IDE |
| Conversation threads | `GET/POST /ai/sessions` + IDE sidebar |
| Composer mode | Multi-file plan-first builds in IDE |
| Git isolation | `branch_per_task`, `auto_pr_on_complete` |
| **20 live app previews** | README URLs → `rails_ai_build` sandboxes on Render |
| **NVIDIA NIM** | `Models::NvidiaProvider` + live trust suite |

## v2.3 — Rails AI Cloud

| Item | Detail |
|------|--------|
| Hosted agents | No API key in host app |
| Team workspaces | Shared task queue + audit |
| Credits & usage | Per-seat billing |
| Marketplace packs | Catalog-derived skill packs |

## v2.4 — Full Cursor parity

| Item | Detail |
|------|--------|
| Monaco editor | In-browser edit + @-mentions |
| Terminal panel | Sandboxed shell UI |
| Composer mode | Multi-file plan preview |
| Background agents | Cloud Agents API bridge |
| Rules / skills sync | `.cursor/rules` ↔ gem skills |

## Architecture

```mermaid
flowchart TB
  subgraph ui [Web UI]
    IDE[IDE /ui/ide]
    Tasks[Task Queue Panel]
  end
  subgraph api [API]
    Build[POST /build]
    TQ[POST /tasks]
    Orch[POST /orchestrate]
  end
  subgraph core [Core]
    Runtime[Tasks::Runtime]
    Queue[Tasks::Queue]
    Coord[Orchestration::Coordinator]
    Tools[Tools Registry]
  end
  IDE --> Build
  IDE --> TQ
  TQ --> Queue
  Queue --> Runtime
  Build --> Runtime
  Orch --> Coord
  Runtime --> Tools
```

## Success metrics

- Any Rails 7.0–8.1 app: `rails rails_ai_build:build['anything']` completes with verify pass
- 2+ tasks enqueued without workspace corruption
- IDE shows live task status without page reload
- Enterprise customer: audit log captures every queued task
