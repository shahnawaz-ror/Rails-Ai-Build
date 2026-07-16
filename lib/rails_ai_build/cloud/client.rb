# frozen_string_literal: true

module RailsAiBuild
  module Cloud
    # Hosted models via Rails AI Cloud — Pro+ with cloud_api_key.
    # On outage: clear error + BYOK CTA (no silent provider swap).
    class Client
      DEFAULT_URL = "https://cloud.railsaibuild.com"

      class CloudUnavailableError < ProviderError
        attr_reader :byok_cta, :fallback_available

        def initialize(message, fallback_available: false)
          @byok_cta = "Switch to BYOK: set OPENAI_API_KEY / ANTHROPIC_API_KEY / NVIDIA_API_KEY, " \
                      "or POST /settings/keys, then set default_provider."
          @fallback_available = fallback_available
          super(message)
        end

        def as_json(*)
          {
            error: message,
            code: "cloud_unavailable",
            byok_cta: byok_cta,
            fallback_available: fallback_available,
            hint: "Use BYOK while Cloud is down, or retry later."
          }
        end
      end

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

          uri = Security::UrlGuard.safe_uri("#{base_url}#{path}")
          request = method == :post ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
          request["Authorization"] = "Bearer #{api_key}"
          request["Content-Type"] = "application/json"
          request.body = JSON.generate(payload) if payload

          response = HttpClient.request(uri, request, open_timeout: 5, read_timeout: 60)
          code = response.code.to_i
          body = JSON.parse(response.body)

          if code >= 500
            raise_unavailable!("HTTP #{code}: #{body['error'] || 'server error'}")
          end
          raise ProviderError, body["error"] || "Cloud API error" if code >= 400

          body
        rescue CircuitBreaker::OpenError => e
          raise_unavailable!(e.message)
        rescue ProviderError => e
          raise unless connection_like_error?(e)

          raise_unavailable!(e.message)
        rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
          raise_unavailable!("#{e.class}: #{e.message}")
        end

        def raise_unavailable!(detail)
          byok_ready = Activation.configured_providers.any? { |p| p != :cloud }
          raise CloudUnavailableError.new(
            "Rails AI Cloud unavailable (#{detail}). #{byok_ready ? 'BYOK keys are configured — switch default_provider.' : 'Add a BYOK key to continue.'}",
            fallback_available: byok_ready
          )
        end

        def connection_like_error?(error)
          error.message.to_s.match?(/timeout|connection error|TLS error|Circuit open|redirect not followed/i)
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
