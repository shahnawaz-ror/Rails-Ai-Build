# Monorepo structure

```
rails-ai-build/
├── lib/                          # Ruby gem (rails_ai_build)
│   └── rails_ai_build/           # Agent, tools, providers, Rails engine
├── app/                          # Rails engine (controllers, models, jobs)
├── server/                       # Standalone Sinatra HTTP server
├── packages/
│   ├── core-protocol/
│   │   └── openapi.yaml          # Shared REST API specification
│   ├── python/
│   │   └── rails_ai_build/       # Python SDK (pip install rails-ai-build)
│   └── javascript/
│       └── src/                  # JS/TS SDK (npm install @rails-ai-build/sdk)
├── spec/                         # Ruby gem tests
└── README.md
```

## Architecture

All SDKs implement the same agent loop:

```
User prompt → Model (OpenAI/Anthropic) → Tool calls → Execute → Repeat → Done
```

Tools: `read_file`, `write_file`, `grep`, `list_files`, `shell`

## Deployment options

1. **Embedded** — Use the SDK directly in your app (Python, JS, or Ruby)
2. **Rails engine** — Mount in a Rails app at `/rails_ai_build`
3. **Standalone server** — Run `server/` and call from any HTTP client
4. **Hybrid** — SDKs in remote mode pointing at your server

## Adding a new language

1. Read `packages/core-protocol/openapi.yaml`
2. Implement tools (file I/O, grep, shell with sandboxing)
3. Implement provider clients (OpenAI + Anthropic tool-calling format)
4. Implement the agent loop (call model → execute tools → repeat)
5. Optionally add a `RemoteClient` that calls `POST /chat`
