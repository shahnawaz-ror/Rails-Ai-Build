# frozen_string_literal: true

module RailsAiBuild
  module Models
    class BaseProvider
      attr_reader :name, :options

      def initialize(name:, api_key: nil, **options)
        @name = name
        @api_key = api_key
        @options = options
      end

      def chat(messages:, tools: [], model: nil, **kwargs)
        raise NotImplementedError, "#{self.class}#chat must be implemented"
      end

      def list_models
        raise NotImplementedError, "#{self.class}#list_models must be implemented"
      end

      def supports_tools?
        true
      end

      protected

      def api_key
        @api_key || RailsAiBuild.configuration.api_key_for(name)
      end

      def validate_api_key!
        raise ConfigurationError, "API key missing for provider: #{name}" if api_key.nil? || api_key.empty?
      end
    end
  end
end
