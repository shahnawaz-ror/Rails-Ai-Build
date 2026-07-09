# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild do
  it "has a version number" do
    expect(RailsAiBuild::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    expect(RailsAiBuild::VERSION).to eq("2.1.0")
  end

  it "exposes Providers as an alias to Models::Registry" do
    expect(described_class::Providers).to eq(RailsAiBuild::Models::Registry)
  end

  it "supports configuration" do
    described_class.configure do |config|
      config.default_model = "claude-sonnet-4-20250514"
    end
    expect(described_class.configuration.default_model).to eq("claude-sonnet-4-20250514")
  end

  it "resets configuration" do
    described_class.configuration.plan = :enterprise
    described_class.reset_configuration!
    expect(described_class.configuration.plan).to eq(:free)
  end
end
