# frozen_string_literal: true

require "monitor"

module RailsAiBuild
  module Entitlements
    # Lightweight seat claims for Team/Enterprise licenses.
    # Redis ZSET when available (multi-worker); else process-local mutex store.
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
          redis_count = RedisStore.with_client { |redis| redis_active_count(redis) }
          return redis_count unless redis_count.nil?

          mutex.synchronize do
            expire_stale!
            claims.size
          end
        end

        def status
          redis_status = RedisStore.with_client { |redis| redis_status(redis) }
          return redis_status unless redis_status.nil?

          mutex.synchronize do
            expire_stale!
            {
              enabled: enabled?,
              limit: limit,
              active: claims.size,
              remaining: enabled? ? [limit - claims.size, 0].max : nil,
              seats: claims.keys,
              backend: :memory
            }
          end
        end

        def claim!(user_id)
          return true unless enabled?

          claimed = RedisStore.with_client { |redis| redis_claim!(redis, user_id) }
          return claimed unless claimed.nil?

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
          RedisStore.with_client { |redis| redis_release!(redis, user_id) }
          mutex.synchronize { claims.delete(normalize(user_id)) }
          true
        end

        def check!(user_id)
          claim!(user_id)
        end

        def clear!
          RedisStore.with_client { |redis| redis.del(RedisStore.key("seats")) }
          mutex.synchronize { claims.clear }
        end

        def backend
          RedisStore.enabled? ? :redis : :memory
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

        def ttl
          ENV.fetch("RAILS_AI_BUILD_SEAT_TTL", DEFAULT_TTL_SECONDS).to_i
        end

        def expire_stale!
          return if ttl <= 0

          cutoff = Time.now - ttl
          claims.delete_if { |_uid, claimed_at| claimed_at < cutoff }
        end

        def redis_active_count(redis)
          zkey = RedisStore.key("seats")
          redis.zremrangebyscore(zkey, "-inf", Time.now.to_i)
          redis.zcard(zkey)
        end

        def redis_status(redis)
          zkey = RedisStore.key("seats")
          redis.zremrangebyscore(zkey, "-inf", Time.now.to_i)
          seats = redis.zrange(zkey, 0, -1)
          {
            enabled: enabled?,
            limit: limit,
            active: seats.size,
            remaining: enabled? ? [limit - seats.size, 0].max : nil,
            seats: seats,
            backend: :redis
          }
        end

        def redis_claim!(redis, user_id)
          uid = normalize(user_id)
          zkey = RedisStore.key("seats")
          now = Time.now.to_i
          redis.zremrangebyscore(zkey, "-inf", now)

          # Refresh existing claim TTL without counting as a new seat.
          if redis.zscore(zkey, uid)
            redis.zadd(zkey, now + [ttl, 60].max, uid)
            return true
          end

          if redis.zcard(zkey) >= limit
            raise PlanRequiredError.new(
              feature: :shared_agents,
              current_plan: RailsAiBuild.configuration.plan || :free,
              suggested_plan: :team
            )
          end

          redis.zadd(zkey, now + [ttl, 60].max, uid)
          true
        end

        def redis_release!(redis, user_id)
          redis.zrem(RedisStore.key("seats"), normalize(user_id))
        end
      end
    end
  end
end
