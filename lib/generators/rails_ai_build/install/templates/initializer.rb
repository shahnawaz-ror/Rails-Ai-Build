# frozen_string_literal: true

# rails_ai_build_version: <%= rails_ai_build_version %>

RailsAiBuild.configure do |config|
  # API keys — prefer environment variables in production
  # Get a free NVIDIA NIM key at https://build.nvidia.com
  config.api_keys = {
    openai: ENV.fetch('OPENAI_API_KEY', nil),
    anthropic: ENV.fetch('ANTHROPIC_API_KEY', nil),
    nvidia: ENV.fetch('NVIDIA_API_KEY', nil)
  }

  # Prefer NVIDIA when NVIDIA_API_KEY is set; otherwise OpenAI / Anthropic
  if ENV['NVIDIA_API_KEY'].to_s.start_with?('nvapi-')
    config.default_provider = :nvidia
    config.default_model = ENV.fetch('NVIDIA_MODEL', 'meta/llama-3.1-8b-instruct')
  elsif ENV['ANTHROPIC_API_KEY'].to_s.start_with?('sk-ant-')
    config.default_provider = :anthropic
    config.default_model = ENV.fetch('ANTHROPIC_MODEL', 'claude-sonnet-4-20250514')
  else
    config.default_provider = :openai
    config.default_model = ENV.fetch('OPENAI_MODEL', 'gpt-4o')
  end

  # Tools the agent can use (run_generator preferred over freeform writes)
  config.allowed_tools = %i[read_file write_file grep list_files shell run_generator host_safety_check]

  # Prefer Rails generators (catalog scoring) over inventing files with AI
  config.generator_first = true

  # Host Safety — prevent → detect → isolate → rollback → report
  config.host_safety = true
  config.host_safety_boot_check = true
  config.host_safety_bundle_check = true
  config.host_safety_zeitwerk_check = true
  config.host_safety_soft_preview = true       # queue config/Gemfile/migrate even on Free
  config.host_safety_shadow_worktree = false   # set true for isolate/promote-on-green
  config.host_safety_smoke_routes = false
  config.host_safety_fix_after_rollback = false
  config.host_safety_rollback_on_verify_fail = true

  # SSRF — block private/metadata URLs on provider/webhook/MCP calls
  config.ssrf_protection = true
  config.ssrf_allow_localhost = true   # Ollama / local NIM
  config.ssrf_allow_private = false

  # Production hardening (recommended for public mounts)
  # config.require_engine_token = true
  # config.require_engine_token_for_reads = true
  # config.allow_workspace_override = false
  # config.shell_enabled = false
  # Or mount the engine behind Devise/admin constraint instead of auto_mount.

  # Agent loop safety limits
  config.max_agent_iterations = 25
  config.shell_timeout = 30

  # Plan: :free includes streaming + NVIDIA BYOK; writes auto-apply unless diff_preview
  config.plan = :free

  # false = write_file applies immediately (recommended for local agents)
  # true  = queue diffs for manual Apply in the IDE (Pro+)
  config.diff_preview = false

  # Audit log — track all agent actions (Team+ feature)
  # config.audit_enabled = true

  # Auto-mount engine at /rails_ai_build (set false to mount manually)
  config.auto_mount = true

  # Optional NVIDIA model override examples:
  # config.default_model = "meta/llama-3.3-70b-instruct"
  # config.default_model = "nvidia/nemotron-mini-4b-instruct"

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
