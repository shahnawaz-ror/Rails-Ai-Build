# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::CircuitBreaker do
  before { described_class.reset! }
  after { described_class.reset! }

  it "opens after consecutive failures" do
    described_class.record_failure!("api.example.com")
    described_class.record_failure!("api.example.com")
    described_class.record_failure!("api.example.com")
    described_class.record_failure!("api.example.com")
    expect(described_class.open?("api.example.com")).to be false

    described_class.record_failure!("api.example.com")
    expect(described_class.open?("api.example.com")).to be true
    expect { described_class.guard!("api.example.com") }.to raise_error(RailsAiBuild::CircuitBreaker::OpenError)
  end

  it "resets on success" do
    4.times { described_class.record_failure!("api.example.com") }
    described_class.record_success!("api.example.com")
    4.times { described_class.record_failure!("api.example.com") }
    expect(described_class.open?("api.example.com")).to be false
  end
end
