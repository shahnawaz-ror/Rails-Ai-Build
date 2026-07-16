# frozen_string_literal: true

require "monitor"

module RailsAiBuild
  # Per-host circuit breaker for outbound provider/cloud HTTP.
  # Redis-backed when available so all Puma workers share open/cooldown state.
  module CircuitBreaker
    DEFAULT_FAILURE_THRESHOLD = 5
    DEFAULT_COOLDOWN_SECONDS = 30

    class OpenError < ProviderError; end

    class << self
      def guard!(host)
        key = host.to_s
        blocked = RedisStore.with_client { |redis| redis_open?(redis, key) }
        unless blocked.nil?
          raise OpenError, "Circuit open for #{key}" if blocked

          return true
        end

        mutex.synchronize do
          state = states[key] ||= fresh_state
          if state[:open_until] && monotonic_now < state[:open_until]
            raise OpenError,
                  "Circuit open for #{key} (retry after #{(state[:open_until] - monotonic_now).ceil}s)"
          end
        end
      end

      def record_success!(host)
        RedisStore.with_client { |redis| redis_success!(redis, host.to_s) }
        mutex.synchronize { states[host.to_s] = fresh_state }
      end

      def record_failure!(host)
        recorded = RedisStore.with_client { |redis| redis_failure!(redis, host.to_s) }
        return if recorded

        mutex.synchronize do
          state = states[host.to_s] ||= fresh_state
          state[:failures] += 1
          if state[:failures] >= failure_threshold
            state[:open_until] = monotonic_now + cooldown_seconds
            state[:failures] = 0
          end
        end
      end

      def open?(host)
        blocked = RedisStore.with_client { |redis| redis_open?(redis, host.to_s) }
        return blocked unless blocked.nil?

        mutex.synchronize do
          state = states[host.to_s]
          return false unless state&.dig(:open_until)

          monotonic_now < state[:open_until]
        end
      end

      def reset!
        RedisStore.with_client do |redis|
          # Drop known host keys from memory mirror; Redis keys expire naturally.
          true
        end
        mutex.synchronize { states.clear }
      end

      def status
        mutex.synchronize do
          states.transform_values do |state|
            {
              failures: state[:failures],
              open: state[:open_until] && monotonic_now < state[:open_until],
              open_until: state[:open_until]
            }
          end
        end
      end

      def backend
        RedisStore.enabled? ? :redis : :memory
      end

      private

      def mutex
        @mutex ||= Monitor.new
      end

      def states
        @states ||= {}
      end

      def fresh_state
        { failures: 0, open_until: nil }
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def failure_threshold
        ENV.fetch("RAILS_AI_BUILD_CIRCUIT_FAILURES", DEFAULT_FAILURE_THRESHOLD).to_i
      end

      def cooldown_seconds
        ENV.fetch("RAILS_AI_BUILD_CIRCUIT_COOLDOWN", DEFAULT_COOLDOWN_SECONDS).to_i
      end

      def redis_open?(redis, host)
        open_until = redis.get(RedisStore.key("circuit", host, "open_until"))
        return false if open_until.nil?

        open_until.to_i > Time.now.to_i
      end

      def redis_success!(redis, host)
        redis.del(RedisStore.key("circuit", host, "failures"))
        redis.del(RedisStore.key("circuit", host, "open_until"))
        true
      end

      def redis_failure!(redis, host)
        fail_key = RedisStore.key("circuit", host, "failures")
        open_key = RedisStore.key("circuit", host, "open_until")
        count = redis.incr(fail_key)
        redis.expire(fail_key, cooldown_seconds * 4) if count == 1
        if count >= failure_threshold
          redis.set(open_key, Time.now.to_i + cooldown_seconds, ex: cooldown_seconds)
          redis.del(fail_key)
        end
        true
      end
    end
  end
end
