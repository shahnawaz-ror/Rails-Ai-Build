# frozen_string_literal: true

module RailsAiBuild
  module Models
    class Registry
      class << self
        def register(name, provider_class, default_options = {})
          registry[name.to_sym] = { class: provider_class, default_options: default_options }
        end

        def resolve(name)
          entry = registry[name.to_sym]
          raise ConfigurationError, "Unknown provider: #{name}" unless entry

          entry
        end

        def build(name, **options)
          entry = resolve(name)
          merged = entry[:default_options].merge(options)
          entry[:class].new(name: name, **merged)
        end

        def registered_providers
          registry.keys
        end

        def register_defaults
          register(:openai, OpenaiProvider)
          register(:nvidia, NvidiaProvider)
          register(:anthropic, AnthropicProvider)
          register(:cloud, Cloud::HostedProvider) if defined?(Cloud::HostedProvider)
        end

        def reset!
          @registry = {}
        end

        private

        def registry
          @registry ||= {}
        end
      end
    end

    # Alias for cleaner API
    Providers = Registry
  end
end
