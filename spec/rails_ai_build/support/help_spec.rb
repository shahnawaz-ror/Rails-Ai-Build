# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Support::Help do
  it "lists help topics" do
    topics = described_class.topics
    expect(topics.map { |t| t[:id] }).to include("getting-started", "troubleshooting", "analytics")
  end

  it "returns topic content" do
    topic = described_class.topic("getting-started")
    expect(topic[:content]).to include("rails_ai_build:install")
  end

  it "raises for unknown topics" do
    expect { described_class.topic("nonexistent") }.to raise_error(RailsAiBuild::ConfigurationError)
  end
end
