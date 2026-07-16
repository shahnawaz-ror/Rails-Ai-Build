# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Redis-backed shared stores" do
  # Minimal Redis stand-in covering the commands we use.
  class FakeRedis
    def initialize
      @kv = {}
      @zsets = Hash.new { |h, k| h[k] = {} }
    end

    def ping
      "PONG"
    end

    def incr(key)
      @kv[key] = @kv.fetch(key, 0).to_i + 1
    end

    def expire(_key, _sec)
      true
    end

    def get(key)
      @kv[key]
    end

    def set(key, value, ex: nil)
      @kv[key] = value.to_s
      true
    end

    def del(*keys)
      keys.each do |key|
        @kv.delete(key)
        @zsets.delete(key)
      end
      true
    end

    def zadd(key, score, member)
      @zsets[key][member] = score.to_f
      true
    end

    def zscore(key, member)
      @zsets[key][member]
    end

    def zcard(key)
      @zsets[key].size
    end

    def zrange(key, _start, _stop)
      @zsets[key].keys
    end

    def zrem(key, member)
      @zsets[key].delete(member)
    end

    def zremrangebyscore(key, _min, max)
      cutoff = max.to_f
      @zsets[key].delete_if { |_m, score| score <= cutoff }
    end

    def close
      true
    end
  end

  let(:fake) { FakeRedis.new }

  before do
    RailsAiBuild::RedisStore.reset!
    RailsAiBuild::RateLimit.reset!
    RailsAiBuild::CircuitBreaker.reset!
    RailsAiBuild::Entitlements::Seats.clear!
    allow(RailsAiBuild::RedisStore).to receive(:client).and_return(fake)
    ENV["RAILS_AI_BUILD_RATE_LIMIT"] = "3"
    ENV["RAILS_AI_BUILD_RATE_WINDOW"] = "60"
    ENV["RAILS_AI_BUILD_CIRCUIT_FAILURES"] = "3"
    ENV["RAILS_AI_BUILD_CIRCUIT_COOLDOWN"] = "30"
  end

  after do
    ENV.delete("RAILS_AI_BUILD_RATE_LIMIT")
    ENV.delete("RAILS_AI_BUILD_RATE_WINDOW")
    ENV.delete("RAILS_AI_BUILD_CIRCUIT_FAILURES")
    ENV.delete("RAILS_AI_BUILD_CIRCUIT_COOLDOWN")
    RailsAiBuild::RedisStore.reset!
    RailsAiBuild.reset_configuration!
  end

  it "rate limits via Redis counters" do
    expect(RailsAiBuild::RateLimit.backend).to eq(:redis)
    3.times { RailsAiBuild::RateLimit.check!("tenant-a") }
    expect { RailsAiBuild::RateLimit.check!("tenant-a") }
      .to raise_error(RailsAiBuild::ConfigurationError, /Rate limit/)
  end

  it "opens circuit via Redis after failures" do
    3.times { RailsAiBuild::CircuitBreaker.record_failure!("api.example.com") }
    expect(RailsAiBuild::CircuitBreaker.open?("api.example.com")).to be true
    expect { RailsAiBuild::CircuitBreaker.guard!("api.example.com") }
      .to raise_error(RailsAiBuild::CircuitBreaker::OpenError)
  end

  it "claims seats via Redis zset" do
    RailsAiBuild.configuration.seat_limit = 1
    expect(RailsAiBuild::Entitlements::Seats.backend).to eq(:redis)
    RailsAiBuild::Entitlements::Seats.claim!("alice")
    expect { RailsAiBuild::Entitlements::Seats.claim!("bob") }
      .to raise_error(RailsAiBuild::PlanRequiredError)
  end
end
