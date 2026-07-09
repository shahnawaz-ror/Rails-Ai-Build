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
                  :auto_mount

    def initialize
      @default_model = "gpt-4o"
      @default_provider = :openai
      @api_keys = {}
      @allowed_tools = %i[read_file write_file grep list_files shell]
      @workspace_root = -> { Rails.root }
      @max_agent_iterations = 25
      @shell_timeout = 30
      @providers = {}
      @auto_mount = true
    end

    def workspace_path
      path = workspace_root.respond_to?(:call) ? workspace_root.call : workspace_root
      Pathname.new(path.to_s)
    end

    def api_key_for(provider)
      api_keys[provider.to_sym] || api_keys[provider.to_s]
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
