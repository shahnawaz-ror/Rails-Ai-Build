# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Support::Settings do
  before { RailsAiBuild.reset_configuration! }

  it "returns current settings" do
    settings = described_class.current
    expect(settings[:version]).to eq(RailsAiBuild::VERSION)
    expect(settings[:plan]).to eq(:free)
    expect(settings).to have_key(:allowed_tools)
  end

  it "updates allowed settings" do
    result = described_class.update(plan: :pro, default_model: "gpt-4o-mini")
    expect(result[:plan]).to eq(:pro)
    expect(result[:default_model]).to eq("gpt-4o-mini")
  end
end
