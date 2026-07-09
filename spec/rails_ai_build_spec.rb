# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild do
  it "has a version" do
    expect(RailsAiBuild::VERSION).to eq("0.1.0")
  end

  it "supports configuration" do
    RailsAiBuild.configure do |config|
      config.default_model = "claude-sonnet-4-20250514"
    end
    expect(RailsAiBuild.configuration.default_model).to eq("claude-sonnet-4-20250514")
  end
end
