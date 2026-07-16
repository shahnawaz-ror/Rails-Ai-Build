# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::RateLimit do
  before do
    described_class.reset!
    ENV["RAILS_AI_BUILD_RATE_LIMIT"] = "3"
    ENV["RAILS_AI_BUILD_RATE_WINDOW"] = "60"
  end

  after do
    ENV.delete("RAILS_AI_BUILD_RATE_LIMIT")
    ENV.delete("RAILS_AI_BUILD_RATE_WINDOW")
    described_class.reset!
  end

  it "allows requests under the limit and returns remaining" do
    expect(described_class.check!("ip")).to eq(2)
    expect(described_class.check!("ip")).to eq(1)
    expect(described_class.check!("ip")).to eq(0)
  end

  it "raises when limit exceeded" do
    3.times { described_class.check!("ip") }
    expect { described_class.check!("ip") }.to raise_error(RailsAiBuild::ConfigurationError, /Rate limit/)
  end
end
