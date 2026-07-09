# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RailsAiBuild errors" do
  it "defines a hierarchy for domain failures" do
    expect(RailsAiBuild::ProviderError).to be < RailsAiBuild::Error
    expect(RailsAiBuild::AgentError).to be < RailsAiBuild::Error
    expect(RailsAiBuild::ToolError).to be < RailsAiBuild::Error
    expect(RailsAiBuild::ConfigurationError).to be < RailsAiBuild::Error
    expect(RailsAiBuild::SecurityError).to be < RailsAiBuild::Error
  end
end
