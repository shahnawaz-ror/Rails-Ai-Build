# frozen_string_literal: true

module RailsAiBuild
  # Simple in-process rate limiter for mutating AI endpoints.
  # Configure via ENV: RAILS_AI_BUILD_RATE_LIMIT (requests), RAILS_AI_BUILD_RATE_WINDOW (seconds).
  module RateLimit
    DEFAULT_LIMIT = 60
    DEFAULT_WINDOW = 60

    class << self
      def check!(key)
        return true if disabled?

        bucket = store[key.to_s]
        now = Time.now.to_i
        window_start = now - window

        bucket.reject! { |t| t < window_start }
        if bucket.size >= limit
          raise ConfigurationError,
                "Rate limit exceeded (#{limit}/#{window}s). Slow down or raise RAILS_AI_BUILD_RATE_LIMIT."
        end

        bucket << now
        true
      end

      def reset!
        @store = Hash.new { |h, k| h[k] = [] }
      end

      def disabled?
        ENV["RAILS_AI_BUILD_RATE_LIMIT"].to_s == "0"
      end

      private

      def store
        @store ||= Hash.new { |h, k| h[k] = [] }
      end

      def limit
        ENV.fetch("RAILS_AI_BUILD_RATE_LIMIT", DEFAULT_LIMIT).to_i
      end

      def window
        ENV.fetch("RAILS_AI_BUILD_RATE_WINDOW", DEFAULT_WINDOW).to_i
      end
    end
  end
end
