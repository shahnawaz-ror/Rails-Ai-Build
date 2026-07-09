# frozen_string_literal: true

module RailsAiBuild
  class McpController < ActionController::API
    def handle
      request_body = JSON.parse(request.body.read)
      render json: Mcp::Server.handle(request_body)
    rescue JSON::ParserError
      render json: { error: "Invalid JSON" }, status: :bad_request
    end

    def tools
      render json: { tools: Mcp::Server.tools_as_mcp }
    end
  end
end
