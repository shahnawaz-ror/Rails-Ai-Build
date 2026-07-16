# frozen_string_literal: true

module RailsAiBuild
  # Optional shared Redis for multi-worker RateLimit / Seats / CircuitBreaker.
  # Soft-requires the `redis` gem. Falls back to process-local stores when unset
  # or when Redis is unreachable — never bricks the host app.
  module RedisStore
    PREFIX = "rails_ai_build"

    class << self
      def enabled?
        !!client
      end

      def url
        configured = RailsAiBuild.configuration.redis_url if RailsAiBuild.configuration.respond_to?(:redis_url)
        configured.to_s.strip.presence ||
          ENV["RAILS_AI_BUILD_REDIS_URL"].to_s.strip.presence ||
          ENV["REDIS_URL"].to_s.strip.presence
      end

      def client
        return @client if defined?(@client)

        @client = connect!
      end

      def reset!
        if defined?(@client) && @client
          @client.close rescue nil
        end
        remove_instance_variable(:@client) if defined?(@client)
      end

      def key(*parts)
        ([PREFIX] + parts.map(&:to_s)).join(":")
      end

      def with_client
        c = client
        return nil unless c

        yield c
      rescue RailsAiBuild::Error
        # Domain errors (rate limit, seats, circuit open) must not fall back to memory.
        raise
      rescue StandardError => e
        warn_once("Redis error (falling back to memory): #{e.class}: #{e.message}")
        reset!
        nil
      end

      private

      def connect!
        return nil if url.blank?

        begin
          require "redis"
        rescue LoadError
          warn_once("REDIS_URL set but redis gem missing — add `gem \"redis\"` for multi-worker stores")
          return nil
        end

        redis = ::Redis.new(url: url, timeout: 1.0, reconnect_attempts: 1)
        redis.ping
        redis
      rescue StandardError => e
        warn_once("Redis unavailable (#{e.class}: #{e.message}) — using in-process stores")
        nil
      end

      def warn_once(message)
        return if @warned

        @warned = true
        warn("[RailsAiBuild] #{message}") if $VERBOSE || ENV["RAILS_AI_BUILD_DEBUG"].to_s == "1"
      end
    end
  end
end
