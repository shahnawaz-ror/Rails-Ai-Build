# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Plans do
  before { RailsAiBuild.reset_configuration! }

  it "returns free plan features by default" do
    expect(described_class.feature?(:local_agent)).to be true
    expect(described_class.feature?(:diff_preview)).to be false
  end

  it "unlocks diff_preview on pro plan" do
    RailsAiBuild.configuration.plan = :pro
    expect(described_class.feature?(:diff_preview)).to be true
  end

  it "raises on unavailable features" do
    expect { described_class.check!(:audit_log) }.to raise_error(RailsAiBuild::ConfigurationError)
  end
end
