# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Support::Settings do
  before { RailsAiBuild.reset_configuration! }

  it "returns current settings with activation" do
    settings = described_class.current
    expect(settings[:version]).to eq(RailsAiBuild::VERSION)
    expect(settings[:plan]).to eq(:free)
    expect(settings).to have_key(:allowed_tools)
    expect(settings).to have_key(:activation)
    expect(settings[:api_keys_configured]).to include(:openai, :anthropic, :nvidia, :cloud)
  end

  it "updates allowed settings" do
    result = described_class.update(default_model: "gpt-4o-mini")
    expect(result[:default_model]).to eq("gpt-4o-mini")
  end

  it "rejects plan changes via settings" do
    expect do
      described_class.update(plan: :pro, default_model: "gpt-4o-mini")
    end.to raise_error(RailsAiBuild::SecurityError, /license|billing/i)
  end

  it "updates API keys into live configuration" do
    result = described_class.update_keys(openai: "sk-test-123", nvidia: "nvapi-test")
    expect(result[:api_keys_configured][:openai]).to be(true)
    expect(result[:api_keys_configured][:nvidia]).to be(true)
    expect(RailsAiBuild.configuration.api_key_for(:openai)).to eq("sk-test-123")
  end
end
