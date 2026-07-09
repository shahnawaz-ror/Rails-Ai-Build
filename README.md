# Rails AI Build

**Cursor-like AI agent integration for any Rails application.**

`rails_ai_build` is a Ruby gem that brings AI coding agents into your Rails app. Create agents that read, search, and modify your codebase — powered by OpenAI, Anthropic, or your own custom models.

## Features

- **Multi-model support** — OpenAI, Anthropic, and custom providers (Ollama, Together, Groq, or any HTTP API)
- **Agent loop** — Tool-calling agent that iterates until the task is complete (like Cursor)
- **Built-in tools** — `read_file`, `write_file`, `grep`, `list_files`, `shell`
- **Rails engine** — REST API, ActiveRecord models, background jobs
- **Secure by default** — Workspace sandboxing, blocked dangerous shell commands
- **Extensible** — Register custom tools and model providers

## Installation

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

Set API keys in `config/initializers/rails_ai_build.rb` or via environment variables:

```bash
export OPENAI_API_KEY=sk-...
export ANTHROPIC_API_KEY=sk-ant-...
```

## Quick Start

### Programmatic usage (no database)

```ruby
RailsAiBuild.configure do |config|
  config.api_keys[:openai] = ENV["OPENAI_API_KEY"]
  config.default_model = "gpt-4o"
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
│  └── shell (sandboxed)                                   │
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

- [ ] Streaming responses (SSE/WebSocket)
- [ ] Web UI dashboard
- [ ] Diff preview before applying writes
- [ ] Git integration (branch, commit, PR)
- [ ] MCP tool protocol support
- [ ] Multi-agent orchestration

## License

MIT
