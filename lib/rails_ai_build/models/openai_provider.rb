# frozen_string_literal: true

require "net/http"
require "json"

module RailsAiBuild
  module Models
    class OpenaiProvider < BaseProvider
      DEFAULT_BASE_URL = "https://api.openai.com/v1"
      DEFAULT_MODELS = %w[
        gpt-4o gpt-4o-mini gpt-4-turbo gpt-4 gpt-3.5-turbo
        o1 o1-mini o3-mini
      ].freeze

      def initialize(name: :openai, api_key: nil, base_url: DEFAULT_BASE_URL, **options)
        super(name: name, api_key: api_key, **options)
        @base_url = base_url
      end

      def chat(messages:, tools: [], model: nil, **kwargs)
        validate_api_key!

        payload = {
          model: model || RailsAiBuild.configuration.default_model,
          messages: format_messages(messages)
        }

        payload[:tools] = format_tools(tools) if tools.any?
        payload.merge!(kwargs.slice(:temperature, :max_tokens, :top_p))

        response = post("/chat/completions", payload)
        parse_response(response)
      end

      def list_models
        validate_api_key!
        response = get("/models")
        data = JSON.parse(response.body)
        data.fetch("data", []).map { |m| m["id"] }.sort
      rescue StandardError
        DEFAULT_MODELS
      end

      private

      def format_messages(messages)
        messages.map do |msg|
          entry = { role: msg[:role].to_s, content: msg[:content] }

          if msg[:tool_calls]
            entry[:tool_calls] = msg[:tool_calls].map do |tc|
              {
                id: tc[:id],
                type: "function",
                function: {
                  name: tc[:name],
                  arguments: tc[:arguments].is_a?(String) ? tc[:arguments] : JSON.generate(tc[:arguments])
                }
              }
            end
          end

          entry[:tool_call_id] = msg[:tool_call_id] if msg[:tool_call_id]
          entry[:name] = msg[:name] if msg[:name]
          entry
        end
      end

      def format_tools(tools)
        tools.map do |tool|
          {
            type: "function",
            function: {
              name: tool[:name],
              description: tool[:description],
              parameters: tool[:parameters]
            }
          }
        end
      end

      def parse_response(response)
        body = JSON.parse(response.body)

        if response.code.to_i >= 400
          error_msg = body.dig("error", "message") || body.to_s
          raise ProviderError, "OpenAI API error (#{response.code}): #{error_msg}"
        end

        choice = body.dig("choices", 0) || {}
        message = choice["message"] || {}

        tool_calls = (message["tool_calls"] || []).map do |tc|
          {
            id: tc["id"],
            name: tc.dig("function", "name"),
            arguments: JSON.parse(tc.dig("function", "arguments") || "{}")
          }
        end

        {
          role: message["role"] || "assistant",
          content: message["content"],
          tool_calls: tool_calls,
          finish_reason: choice["finish_reason"],
          usage: body["usage"],
          raw: body
        }
      end

      def post(path, payload)
        uri = URI("#{@base_url}#{path}")
        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{api_key}"
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(payload)
        execute(uri, request)
      end

      def get(path)
        uri = URI("#{@base_url}#{path}")
        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bearer #{api_key}"
        execute(uri, request)
      end

      def execute(uri, request)
        Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.request(request)
        end
      end
    end
  end
end
