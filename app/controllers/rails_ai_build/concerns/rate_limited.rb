# frozen_string_literal: true

module RailsAiBuild
  module Concerns
    module RateLimited
      extend ActiveSupport::Concern

      private

      def enforce_rate_limit!
        key = request.headers["X-Rails-Ai-Build-Token"].presence ||
              request.remote_ip.presence ||
              "anonymous"
        remaining = RateLimit.check!(key)
        response.set_header("X-RateLimit-Limit", RateLimit.limit.to_s)
        response.set_header("X-RateLimit-Remaining", remaining.to_s)
        response.set_header("X-RateLimit-Window", RateLimit.window.to_s)
      rescue ConfigurationError => e
        response.set_header("Retry-After", RateLimit.window.to_s)
        render json: { error: e.message, code: "rate_limited" }, status: :too_many_requests
      end
    end
  end
end
