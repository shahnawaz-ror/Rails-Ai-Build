# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Analytics do
  before do
    RailsAiBuild.reset_configuration!
    RailsAiBuild.configuration.plan = :team
  end

  it "tracks events" do
    described_class.track(event: "chat", user: "test", tokens: 100)
    summary = described_class.summary(since: Time.now - 3600)
    expect(summary[:total_events]).to be >= 1
  end
end
