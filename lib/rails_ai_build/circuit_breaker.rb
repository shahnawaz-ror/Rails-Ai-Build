# frozen_string_literal: true

require "monitor"

module RailsAiBuild
  # Per-host circuit breaker for outbound provider/cloud HTTP.
  # Opens after consecutive failures so 5k mounts do not stampede a dead API.
  module CircuitBreaker
    DEFAULT_FAILURE_THRESHOLD = 5
    DEFAULT_COOLDOWN_SECONDS = 30

    class OpenError < ProviderError; end

    class << self
      def guard!(host)
        key = host.to_s
        mutex.synchronize do
          state = states[key] ||= fresh_state
          if state[:open_until] && monotonic_now < state[:open_until]
            raise OpenError,
                  "Circuit open for #{key} (retry after #{(state[:open_until] - monotonic_now).ceil}s)"
          end
        end
      end

      def record_success!(host)
        mutex.synchronize do
          states[host.to_s] = fresh_state
        end
      end

      def record_failure!(host)
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
        mutex.synchronize do
          state = states[host.to_s]
          return false unless state&.dig(:open_until)

          monotonic_now < state[:open_until]
        end
      end

      def reset!
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
    end
  end
end
