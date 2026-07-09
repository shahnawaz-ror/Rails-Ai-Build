# frozen_string_literal: true

module RailsAiBuild
  module Mcp
    # Model Context Protocol — expose rails_ai_build tools to MCP clients
    class Server
      PROTOCOL_VERSION = "2024-11-05"

      class << self
        def handle(request)
          method = request["method"]
          id = request["id"]

          result = case method
                   when "initialize" then initialize_response(request)
                   when "tools/list" then tools_list
                   when "tools/call" then tools_call(request["params"])
                   when "ping" then { content: [{ type: "text", text: "pong" }] }
                   else
                     { error: { code: -32601, message: "Method not found: #{method}" } }
                   end

          { jsonrpc: "2.0", id: id }.merge(result)
        end

        def tools_as_mcp
          Tools::Registry.definitions.map do |tool|
            {
              name: tool[:name],
              description: tool[:description],
              inputSchema: tool[:parameters]
            }
          end
        end

        private

        def initialize_response(request)
          {
            result: {
              protocolVersion: PROTOCOL_VERSION,
              capabilities: { tools: {} },
              serverInfo: { name: "rails_ai_build", version: RailsAiBuild::VERSION }
            }
          }
        end

        def tools_list
          { result: { tools: tools_as_mcp } }
        end

        def tools_call(params)
          name = params.dig("name") || params.dig(:name)
          arguments = params.dig("arguments") || params.dig(:arguments) || {}
          workspace = RailsAiBuild.configuration.workspace_path

          result = Tools::Registry.execute(name, arguments, workspace: workspace)

          {
            result: {
              content: [{ type: "text", text: JSON.pretty_generate(result) }],
              isError: result.key?(:error)
            }
          }
        rescue StandardError => e
          {
            result: {
              content: [{ type: "text", text: e.message }],
              isError: true
            }
          }
        end
      end
    end

    class Client
      # Connect to external MCP servers and register their tools
      class << self
        def connect(url:, name:)
          @external_servers ||= {}
          @external_servers[name.to_sym] = url
          { name: name, url: url, status: "connected" }
        end

        def list_servers
          (@external_servers || {}).map { |name, url| { name: name, url: url } }
        end

        def call_remote(server_name, tool_name, arguments)
          url = (@external_servers || {})[server_name.to_sym]
          raise ConfigurationError, "MCP server not connected: #{server_name}" unless url

          require "net/http"
          uri = URI(url)
          request = Net::HTTP::Post.new(uri)
          request["Content-Type"] = "application/json"
          request.body = JSON.generate(
            jsonrpc: "2.0",
            id: 1,
            method: "tools/call",
            params: { name: tool_name, arguments: arguments }
          )

          response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
            http.request(request)
          end

          JSON.parse(response.body)
        end
      end
    end
  end
end

require "json"
