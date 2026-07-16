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
        RateLimit.check!(key)
      rescue ConfigurationError => e
        render json: { error: e.message, code: "rate_limited" }, status: :too_many_requests
      end
    end
  end
end
