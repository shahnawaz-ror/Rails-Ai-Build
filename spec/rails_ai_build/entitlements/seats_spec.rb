# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Entitlements::Seats do
  before do
    RailsAiBuild.reset_configuration!
    described_class.clear!
  end

  it "is unlimited when seat_limit unset" do
    expect(described_class.enabled?).to eq(false)
    expect(described_class.claim!("u1")).to eq(true)
  end

  it "enforces a seat limit" do
    RailsAiBuild.configuration.seat_limit = 1
    expect(described_class.claim!("alice")).to eq(true)
    expect { described_class.claim!("bob") }.to raise_error(RailsAiBuild::PlanRequiredError)
    described_class.release!("alice")
    expect(described_class.claim!("bob")).to eq(true)
  end
end
