# frozen_string_literal: true

module RailsAiBuild
  class Configuration
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
                  :generator_first

    def initialize
      @default_model = "gpt-4o"
      @default_provider = :openai
      @api_keys = {}
      @allowed_tools = %i[read_file write_file grep list_files shell run_generator host_safety_check]
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
