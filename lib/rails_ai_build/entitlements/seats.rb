# frozen_string_literal: true

require "monitor"

module RailsAiBuild
  module Entitlements
    # Lightweight seat claims for Team/Enterprise licenses.
    # Process-local with mutex; for multi-worker deploy set seat_limit via Redis/DB later.
    module Seats
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
          mutex.synchronize { claims.size }
        end

        def status
          mutex.synchronize do
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
            uid = normalize(user_id)
            return true if claims.key?(uid)

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
      end
    end
  end
end
