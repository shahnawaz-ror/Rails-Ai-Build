# frozen_string_literal: true

require "net/http"
require "json"

module RailsAiBuild
  module Models
    class AnthropicProvider < BaseProvider
      DEFAULT_BASE_URL = "https://api.anthropic.com/v1"
      DEFAULT_MODELS = %w[
        claude-opus-4-20250514 claude-sonnet-4-20250514 claude-3-5-sonnet-20241022
        claude-3-5-haiku-20241022 claude-3-opus-20240229
      ].freeze
      API_VERSION = "2023-06-01"

      def initialize(name: :anthropic, api_key: nil, base_url: DEFAULT_BASE_URL, **options)
        super(name: name, api_key: api_key, **options)
        @base_url = base_url
      end

      def chat(messages:, tools: [], model: nil, on_delta: nil, **kwargs)
        validate_api_key!

        system_message, conversation = split_system(messages)

        payload = {
          model: model || "claude-sonnet-4-20250514",
          max_tokens: kwargs[:max_tokens] || 4096,
          messages: format_messages(conversation)
        }

        payload[:system] = system_message if system_message
        payload[:tools] = format_tools(tools) if tools.any?
        payload[:temperature] = kwargs[:temperature] if kwargs[:temperature]

        response = post("/messages", payload)
        parsed = parse_response(response)
        emit_token_deltas(parsed[:content], on_delta: on_delta)
        parsed
      end

      def list_models
        DEFAULT_MODELS
      end

      private

      def split_system(messages)
        system_parts = []
        conversation = []

        messages.each do |msg|
          if msg[:role].to_s == "system"
            system_parts << msg[:content]
          else
            conversation << msg
          end
        end

        [system_parts.join("\n\n").presence, conversation]
      end

      def format_messages(messages)
        messages.map do |msg|
          role = msg[:role].to_s
          role = "user" if role == "tool"

          entry = { role: role }

          if msg[:tool_calls]
            entry[:content] = msg[:tool_calls].map do |tc|
              {
                type: "tool_use",
                id: tc[:id],
                name: tc[:name],
                input: tc[:arguments]
              }
            end
          elsif msg[:tool_call_id]
            entry[:content] = [{
              type: "tool_result",
              tool_use_id: msg[:tool_call_id],
              content: msg[:content].to_s
            }]
          else
            entry[:content] = msg[:content].to_s
          end

          entry
        end
      end

      def format_tools(tools)
        tools.map do |tool|
          {
            name: tool[:name],
            description: tool[:description],
            input_schema: tool[:parameters]
          }
        end
      end

      def parse_response(response)
        body = JSON.parse(response.body)

        if response.code.to_i >= 400
          error_msg = body.dig("error", "message") || body.to_s
          raise ProviderError, "Anthropic API error (#{response.code}): #{error_msg}"
        end

        content_blocks = body["content"] || []
        text_parts = []
        tool_calls = []

        content_blocks.each do |block|
          case block["type"]
          when "text"
            text_parts << block["text"]
          when "tool_use"
            tool_calls << {
              id: block["id"],
              name: block["name"],
              arguments: block["input"] || {}
            }
          end
        end

        {
          role: "assistant",
          content: text_parts.join("\n").presence,
          tool_calls: tool_calls,
          finish_reason: body["stop_reason"],
          usage: body["usage"],
          raw: body
        }
      end

      def post(path, payload)
        uri = Security::UrlGuard.safe_uri("#{@base_url}#{path}")
        request = Net::HTTP::Post.new(uri)
        request["x-api-key"] = api_key
        request["anthropic-version"] = API_VERSION
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(payload)

        HttpClient.request(uri, request)
      end
    end
  end
end
