# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Models::Registry do
  before { described_class.register_defaults }

  it "registers default providers" do
    expect(described_class.registered_providers).to include(:openai, :anthropic)
  end

  it "builds an OpenAI provider" do
    provider = described_class.build(:openai, api_key: "test-key")
    expect(provider).to be_a(RailsAiBuild::Models::OpenaiProvider)
  end

  it "raises for unknown providers" do
    expect { described_class.build(:unknown) }.to raise_error(RailsAiBuild::ConfigurationError)
  end
end
