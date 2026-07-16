# frozen_string_literal: true

require "monitor"

module RailsAiBuild
  # In-process rate limiter for mutating AI endpoints (mutex + key cap).
  # Configure via ENV: RAILS_AI_BUILD_RATE_LIMIT, RAILS_AI_BUILD_RATE_WINDOW.
  module RateLimit
    DEFAULT_LIMIT = 60
    DEFAULT_WINDOW = 60
    MAX_KEYS = 50_000

    class << self
      def check!(key)
        return limit if disabled?

        mutex.synchronize do
          now = Time.now.to_i
          window_start = now - window
          bucket = buckets[key.to_s] ||= []
          bucket.reject! { |t| t < window_start }

          if bucket.size >= limit
            raise ConfigurationError,
                  "Rate limit exceeded (#{limit}/#{window}s). Slow down or raise RAILS_AI_BUILD_RATE_LIMIT."
          end

          bucket << now
          evict_keys! if buckets.size > MAX_KEYS
          [limit - bucket.size, 0].max
        end
      end

      def reset!
        mutex.synchronize { buckets.clear }
      end

      def disabled?
        ENV["RAILS_AI_BUILD_RATE_LIMIT"].to_s == "0"
      end

      def limit
        ENV.fetch("RAILS_AI_BUILD_RATE_LIMIT", DEFAULT_LIMIT).to_i
      end

      def window
        ENV.fetch("RAILS_AI_BUILD_RATE_WINDOW", DEFAULT_WINDOW).to_i
      end

      private

      def mutex
        @mutex ||= Monitor.new
      end

      def buckets
        @buckets ||= {}
      end

      def evict_keys!
        overflow = buckets.size - MAX_KEYS
        return if overflow <= 0

        overflow.times { buckets.shift }
      end
    end
  end
end

