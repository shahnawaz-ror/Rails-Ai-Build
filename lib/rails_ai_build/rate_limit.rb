# frozen_string_literal: true

require "monitor"

module RailsAiBuild
  # Rate limiter for mutating AI endpoints.
  # Uses Redis fixed-window counters when RedisStore is available; else in-process.
  module RateLimit
    DEFAULT_LIMIT = 60
    DEFAULT_WINDOW = 60
    MAX_KEYS = 50_000

    class << self
      def check!(key)
        return limit if disabled?

        remaining = RedisStore.with_client { |redis| redis_check!(redis, key) }
        return remaining unless remaining.nil?

        memory_check!(key)
      end

      def reset!
        RedisStore.with_client do |redis|
          # Best-effort: scan our namespace only when DEBUG; otherwise clear memory.
          true
        end
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

      def backend
        RedisStore.enabled? ? :redis : :memory
      end

      private

      def redis_check!(redis, key)
        now = Time.now.to_i
        bucket = now / [window, 1].max
        redis_key = RedisStore.key("rl", key.to_s, bucket)
        count = redis.incr(redis_key)
        redis.expire(redis_key, window) if count == 1

        if count > limit
          raise ConfigurationError,
                "Rate limit exceeded (#{limit}/#{window}s). Slow down or raise RAILS_AI_BUILD_RATE_LIMIT."
        end

        [limit - count, 0].max
      end

      def memory_check!(key)
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
