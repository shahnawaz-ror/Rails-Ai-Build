# frozen_string_literal: true

RailsAiBuild.configure do |config|
  # Default AI provider (:openai, :anthropic, or a custom registered provider)
  config.default_provider = :openai
  config.default_model = "gpt-4o"

  # API keys — prefer environment variables in production
  config.api_keys = {
    openai: ENV.fetch("OPENAI_API_KEY", nil),
    anthropic: ENV.fetch("ANTHROPIC_API_KEY", nil)
  }

  # Tools the agent can use
  config.allowed_tools = %i[read_file write_file grep list_files shell]

  # Agent loop safety limits
  config.max_agent_iterations = 25
  config.shell_timeout = 30

  # Plan: :free, :pro, :team, :enterprise
  config.plan = :free

  # Diff preview — queue writes for approval (Pro+ feature)
  # config.diff_preview = true

  # Audit log — track all agent actions (Team+ feature)
  # config.audit_enabled = true

  # Auto-mount engine at /rails_ai_build (set false to mount manually)
  config.auto_mount = true

  # Register a custom OpenAI-compatible provider (e.g. Ollama, Together, Groq)
  # config.register_provider(:ollama, RailsAiBuild::Models::CustomProvider,
  #   base_url: "http://localhost:11434/v1",
  #   models: %w[llama3 codellama],
  #   adapter: :openai_compatible
  # )
end

# Apply registered custom providers after configuration
RailsAiBuild.configuration.providers.each do |name, entry|
  RailsAiBuild::Models::Registry.register(name, entry[:class], entry[:options])
end
