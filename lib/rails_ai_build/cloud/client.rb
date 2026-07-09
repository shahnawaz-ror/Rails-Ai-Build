# frozen_string_literal: true

module RailsAiBuild
  module Cloud
    # Hosted models via Rails AI Cloud — no API key required (Pro+)
    class Client
      DEFAULT_URL = "https://cloud.railsaibuild.com"

      class << self
        def chat(messages:, tools: [], model: nil, **kwargs)
          Plans.check!(:hosted_models)
          api_key = RailsAiBuild.configuration.cloud_api_key
          raise ConfigurationError, "Cloud API key required. Sign up at https://railsaibuild.com" if api_key.blank?

          payload = {
            messages: messages,
            tools: tools,
            model: model || RailsAiBuild.configuration.default_model,
            **kwargs
          }

          response = post("/v1/chat", payload, api_key)
          parse_chat_response(response)
        end

        def list_models
          api_key = RailsAiBuild.configuration.cloud_api_key
          get("/v1/models", api_key)
        end

        def track_usage(event:, metadata: {})
          Analytics.track(event: event, metadata: metadata)
        end

        private

        def base_url
          ENV.fetch("RAILS_AI_BUILD_CLOUD_URL", DEFAULT_URL)
        end

        def post(path, payload, api_key)
          http_request(:post, path, payload, api_key)
        end

        def get(path, api_key)
          http_request(:get, path, nil, api_key)
        end

        def http_request(method, path, payload, api_key)
          require "net/http"
          require "json"

          uri = URI("#{base_url}#{path}")
          request = method == :post ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
          request["Authorization"] = "Bearer #{api_key}"
          request["Content-Type"] = "application/json"
          request.body = JSON.generate(payload) if payload

          response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
            http.request(request)
          end

          body = JSON.parse(response.body)
          raise ProviderError, body["error"] || "Cloud API error" if response.code.to_i >= 400

          body
        rescue Errno::ECONNREFUSED, SocketError
          # Fallback to local OpenAI when cloud is unavailable (dev mode)
          fallback_local(messages: payload&.dig(:messages) || [], tools: payload&.dig(:tools) || [], model: payload&.dig(:model))
        end

        def fallback_local(messages:, tools:, model:)
          provider = Models::Registry.build(:openai)
          provider.chat(messages: messages, tools: tools, model: model)
        end

        def parse_chat_response(body)
          {
            role: "assistant",
            content: body["content"],
            tool_calls: body["tool_calls"] || [],
            finish_reason: body["finish_reason"],
            usage: body["usage"]
          }
        end
      end
    end

    class HostedProvider < Models::BaseProvider
      def initialize(name: :cloud, api_key: nil, **options)
        super(name: name, api_key: api_key, **options)
      end

      def chat(messages:, tools: [], model: nil, **kwargs)
        Cloud::Client.chat(messages: messages, tools: tools, model: model, **kwargs)
      end

      def list_models
        %w[gpt-4o gpt-4o-mini claude-sonnet-4-20250514 claude-3-5-haiku-20241022]
      end
    end
  end
end
