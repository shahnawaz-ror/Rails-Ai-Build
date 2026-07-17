# frozen_string_literal: true

module RailsAiBuild
  class Configuration
    # Read-only explore tools the agent needs to plan (always merged into allowed_tools).
    EXPLORE_TOOLS = %i[
      application_info list_routes database_schema list_models list_migrations
      list_rake_tasks read_settings read_logs search_rails_docs model_attributes
      run_rails_check
    ].freeze

    attr_accessor :default_model,
                  :default_provider,
                  :api_keys,
                  :allowed_tools,
                  :workspace_root,
                  :max_agent_iterations,
                  :shell_timeout,
                  :providers,
                  :auto_mount,
                  :diff_preview,
                  :plan,
                  :cloud_api_key,
                  :audit_enabled,
                  :rbac_enabled,
                  :default_role,
                  :saml_enabled,
                  :universal_builder,
                  :verify_builds,
                  :build_max_attempts,
                  :multitask_enabled,
                  :max_concurrent_tasks,
                  :sync_tasks,
                  :branch_per_task,
                  :auto_pr_on_complete,
                  :license_key,
                  :wizard_completed,
                  :settings_token_digest,
                  :host_safety,
                  :host_safety_boot_check,
                  :host_safety_bundle_check,
                  :host_safety_zeitwerk_check,
                  :host_safety_soft_preview,
                  :host_safety_shadow_worktree,
                  :host_safety_smoke_routes,
                  :host_safety_smoke_paths,
                  :host_safety_always_boot,
                  :host_safety_git_checkpoint,
                  :host_safety_fix_after_rollback,
                  :host_safety_fix_max_attempts,
                  :host_safety_rollback_on_verify_fail,
                  :generator_first,
                  :ssrf_protection,
                  :ssrf_allow_localhost,
                  :ssrf_allow_private,
                  :ssrf_allowed_hosts,
                  :require_engine_token,
                  :require_engine_token_for_reads,
                  :seat_limit,
                  :allow_workspace_override,
                  :shell_enabled,
                  :shell_allowlist,
                  :http_open_timeout,
                  :http_read_timeout,
                  :http_write_timeout,
                  :max_ai_sessions,
                  :redis_url

    def initialize
      @default_model = "gpt-4o"
      @default_provider = :openai
      @api_keys = {}
      # Default includes explore/read Boost tools so the agent can plan without
      # "Tool not allowed: application_info" on Free BYOK installs.
      @allowed_tools = %i[
        read_file write_file grep list_files shell run_generator host_safety_check
        application_info list_routes database_schema list_models list_migrations
        list_rake_tasks read_settings read_logs search_rails_docs model_attributes
        run_rails_check
      ]
      @workspace_root = -> { Rails.root }
      @max_agent_iterations = 25
      @shell_timeout = 30
      @providers = {}
      @auto_mount = true
      @diff_preview = false
      @plan = :free
      @cloud_api_key = nil
      @audit_enabled = false
      @rbac_enabled = false
      @default_role = :developer
      @saml_enabled = false
      @universal_builder = true
      @verify_builds = true
      @build_max_attempts = 3
      @multitask_enabled = true
      @max_concurrent_tasks = 2
      @sync_tasks = false
      @branch_per_task = true
      @auto_pr_on_complete = true
      @license_key = nil
      @wizard_completed = false
      @settings_token_digest = nil
      @host_safety = true
      @host_safety_boot_check = true
      @host_safety_bundle_check = true
      @host_safety_zeitwerk_check = true
      @host_safety_soft_preview = true
      @host_safety_shadow_worktree = false
      @host_safety_smoke_routes = false
      @host_safety_smoke_paths = %w[/]
      @host_safety_always_boot = false
      @host_safety_git_checkpoint = true
      @host_safety_fix_after_rollback = false
      @host_safety_fix_max_attempts = 2
      @host_safety_rollback_on_verify_fail = true
      @generator_first = true
      @ssrf_protection = true
      @ssrf_allow_localhost = true
      @ssrf_allow_private = false
      @ssrf_allowed_hosts = []
      @require_engine_token = false
      @require_engine_token_for_reads = true
      @seat_limit = nil
      @allow_workspace_override = false
      @shell_enabled = nil # nil = auto (on in local, off in production)
      @shell_allowlist = nil
      @http_open_timeout = 5
      @http_read_timeout = 60
      @http_write_timeout = 30
      @max_ai_sessions = 2_000
      @redis_url = nil
    end

    def workspace_path
      path = workspace_root.respond_to?(:call) ? workspace_root.call : workspace_root
      Pathname.new(path.to_s)
    end

    def api_key_for(provider)
      api_keys[provider.to_sym] || api_keys[provider.to_s]
    end

    # Load common provider keys from ENV and prefer NVIDIA when available.
    def apply_env_providers!
      api_keys[:openai] ||= ENV.fetch("OPENAI_API_KEY", nil)
      api_keys[:anthropic] ||= ENV.fetch("ANTHROPIC_API_KEY", nil)
      api_keys[:nvidia] ||= ENV.fetch("NVIDIA_API_KEY", nil)

      if api_keys[:nvidia].to_s.start_with?("nvapi-")
        self.default_provider = :nvidia
        self.default_model = ENV.fetch("NVIDIA_MODEL", Models::NvidiaProvider::DEFAULT_MODEL)
      elsif api_keys[:anthropic].to_s.start_with?("sk-ant-")
        self.default_provider = :anthropic
      elsif api_keys[:openai].present?
        self.default_provider = :openai
      end

      self.require_engine_token = true if ENV["RAILS_AI_BUILD_REQUIRE_ENGINE_TOKEN"].to_s == "1"
      if ENV["RAILS_AI_BUILD_SEAT_LIMIT"].to_s.match?(/\A\d+\z/)
        self.seat_limit = ENV["RAILS_AI_BUILD_SEAT_LIMIT"].to_i
      end
      self.redis_url ||= ENV["RAILS_AI_BUILD_REDIS_URL"].presence || ENV["REDIS_URL"].presence
      ensure_explore_tools!
    end

    # Host initializers often omit Boost explore tools; merge them so planning works.
    def ensure_explore_tools!
      self.allowed_tools = Array(allowed_tools).map(&:to_sym) | EXPLORE_TOOLS
    end

    def register_provider(name, provider_class, options = {})
      providers[name.to_sym] = { class: provider_class, options: options }
    end
  end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
