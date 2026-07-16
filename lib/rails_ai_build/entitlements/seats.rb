# frozen_string_literal: true

module RailsAiBuild
  module Entitlements
    # Lightweight seat claims for Team/Enterprise licenses.
    # Enforce when license/config declares a seat limit; otherwise unlimited.
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
          claims.size
        end

        def claims
          @claims ||= {}
        end

        def status
          {
            enabled: enabled?,
            limit: limit,
            active: active_count,
            remaining: enabled? ? [limit - active_count, 0].max : nil,
            seats: claims.keys
          }
        end

        def claim!(user_id)
          return true unless enabled?

          uid = normalize(user_id)
          return true if claims.key?(uid)

          if active_count >= limit
            raise PlanRequiredError.new(
              feature: :shared_agents,
              current_plan: RailsAiBuild.configuration.plan || :free,
              suggested_plan: :team
            )
          end

          claims[uid] = Time.now
          true
        end

        def release!(user_id)
          claims.delete(normalize(user_id))
          true
        end

        def check!(user_id)
          claim!(user_id)
        end

        def clear!
          @claims = {}
        end

        private

        def normalize(user_id)
          user_id.to_s.strip.presence || "anonymous"
        end
      end
    end
  end
end
