# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Analytics integration" do
  before do
    RailsAiBuild.reset_configuration!
    RailsAiBuild::Analytics.reset!
    RailsAiBuild::TokenUsage.reset!
  end

  it "tracks basic events on free plan without raising" do
    expect {
      RailsAiBuild::Analytics.track_basic(event: "test", tokens: 50)
    }.not_to raise_error
  end

  it "dashboard includes doctor and token usage" do
    RailsAiBuild::Analytics.track_basic(event: "agent.run", tokens: 100)
    RailsAiBuild::TokenUsage.track(
      response: { usage: { "total_tokens" => 100 } },
      provider: :openai,
      model: "gpt-4o"
    )
    dash = RailsAiBuild::Analytics.dashboard
    expect(dash).to have_key(:summary)
    expect(dash).to have_key(:token_usage)
    expect(dash).to have_key(:health)
    expect(dash[:health][:status]).to be_in(%i[healthy issues_found])
  end
end
