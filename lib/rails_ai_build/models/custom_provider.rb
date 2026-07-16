# frozen_string_literal: true

require "net/http"
require "json"

module RailsAiBuild
  module Models
  # Register a custom OpenAI-compatible or fully custom HTTP provider.
  #
  # Example (OpenAI-compatible local server):
  #   CustomProvider.new(
  #     name: :ollama,
  #     api_key: "ollama",
  #     base_url: "http://localhost:11434/v1",
  #     models: %w[llama3 codellama],
  #     adapter: :openai_compatible
  #   )
  #
  # Example (fully custom endpoint):
  #   CustomProvider.new(
  #     name: :my_llm,
  #     api_key: ENV["MY_LLM_KEY"],
  #     endpoint: "https://api.example.com/v1/generate",
  #     request_builder: ->(messages, tools, model, options) { { prompt: messages.last[:content] } },
  #     response_parser: ->(body) { { role: "assistant", content: body["text"], tool_calls: [] } }
  #   )
    class CustomProvider < BaseProvider
      ADAPTERS = {
        openai_compatible: OpenaiProvider
      }.freeze

      def initialize(
        name:,
        api_key: nil,
        base_url: nil,
        endpoint: nil,
        models: [],
        adapter: nil,
        request_builder: nil,
        response_parser: nil,
        headers: {},
        **options
      )
        super(name: name, api_key: api_key, **options)
        @base_url = base_url
        @endpoint = endpoint
        @models = models
        @adapter = adapter
        @request_builder = request_builder
        @response_parser = response_parser
        @headers = headers
      end

      def chat(messages:, tools: [], model: nil, **kwargs)
        if @adapter
          delegate_to_adapter(messages: messages, tools: tools, model: model, **kwargs)
        elsif @endpoint && @request_builder && @response_parser
          custom_request(messages: messages, tools: tools, model: model, **kwargs)
        else
          raise ConfigurationError,
                "CustomProvider '#{name}' requires either :adapter or (:endpoint, :request_builder, :response_parser)"
        end
      end

      def list_models
        @models.presence || []
      end

      private

      def delegate_to_adapter(messages:, tools:, model:, **kwargs)
        adapter_class = ADAPTERS.fetch(@adapter) do
          raise ConfigurationError, "Unknown adapter: #{@adapter}"
        end

        adapter = adapter_class.new(name: name, api_key: api_key, base_url: @base_url, **options)
        adapter.chat(messages: messages, tools: tools, model: model, **kwargs)
      end

      def custom_request(messages:, tools:, model:, **kwargs)
        validate_api_key! if api_key

        payload = @request_builder.call(messages, tools, model, kwargs)
        uri = Security::UrlGuard.safe_uri(@endpoint)

        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request["Authorization"] = "Bearer #{api_key}" if api_key
        @headers.each { |k, v| request[k.to_s] = v }
        request.body = JSON.generate(payload)

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.request(request)
        end

        body = JSON.parse(response.body)
        if response.code.to_i >= 400
          raise ProviderError, "Custom provider '#{name}' error (#{response.code}): #{body}"
        end

        @response_parser.call(body)
      end
    end
  end
end
