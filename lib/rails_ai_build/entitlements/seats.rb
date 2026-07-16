# frozen_string_literal: true

require "monitor"

module RailsAiBuild
  module Entitlements
    # Lightweight seat claims for Team/Enterprise licenses.
    # Process-local with mutex; for multi-worker deploy set seat_limit via Redis/DB later.
    module Seats
      DEFAULT_TTL_SECONDS = 86_400 # 24h idle release

      class << self
        def limit
          configured = RailsAiBuild.configuration.seat_limit
          return configured.to_i if configured.present? && configured.to_i.positive?

          nil
        end

        def enabled?
          limit.present?
        end

        def active_count
          mutex.synchronize do
            expire_stale!
            claims.size
          end
        end

        def status
          mutex.synchronize do
            expire_stale!
            {
              enabled: enabled?,
              limit: limit,
              active: claims.size,
              remaining: enabled? ? [limit - claims.size, 0].max : nil,
              seats: claims.keys
            }
          end
        end

        def claim!(user_id)
          return true unless enabled?

          mutex.synchronize do
            expire_stale!
            uid = normalize(user_id)
            if claims.key?(uid)
              claims[uid] = Time.now
              return true
            end

            if claims.size >= limit
              raise PlanRequiredError.new(
                feature: :shared_agents,
                current_plan: RailsAiBuild.configuration.plan || :free,
                suggested_plan: :team
              )
            end

            claims[uid] = Time.now
            true
          end
        end

        def release!(user_id)
          mutex.synchronize { claims.delete(normalize(user_id)) }
          true
        end

        def check!(user_id)
          claim!(user_id)
        end

        def clear!
          mutex.synchronize { claims.clear }
        end

        private

        def mutex
          @mutex ||= Monitor.new
        end

        def claims
          @claims ||= {}
        end

        def normalize(user_id)
          user_id.to_s.strip.presence || "anonymous"
        end

        def expire_stale!
          ttl = ENV.fetch("RAILS_AI_BUILD_SEAT_TTL", DEFAULT_TTL_SECONDS).to_i
          return if ttl <= 0

          cutoff = Time.now - ttl
          claims.delete_if { |_uid, claimed_at| claimed_at < cutoff }
        end
      end
    end
  end
end
