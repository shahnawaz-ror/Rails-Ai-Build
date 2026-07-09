# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Analytics do
  before do
    RailsAiBuild.reset_configuration!
    described_class.reset!
  end

  it "tracks basic events on free plan" do
    described_class.track_basic(event: "chat", user: "test", tokens: 100)
    summary = described_class.summary(since: Time.now - 3600)
    expect(summary[:total_events]).to be >= 1
    expect(summary[:total_tokens]).to be >= 100
  end

  it "tracks detailed events on team plan" do
    RailsAiBuild.configuration.plan = :team
    described_class.track(event: "chat", user: "test", tokens: 100)
    summary = described_class.summary
    expect(summary[:plan]).to eq(:team) if summary.key?(:plan)
  end
end
