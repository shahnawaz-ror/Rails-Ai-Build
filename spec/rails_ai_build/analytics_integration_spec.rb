# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Analytics integration" do
  before do
    RailsAiBuild.reset_configuration!
    Analytics.reset!
    TokenUsage.reset!
  end

  it "tracks basic events on free plan without raising" do
    expect {
      Analytics.track_basic(event: "test", tokens: 50)
    }.not_to raise_error
  end

  it "dashboard includes doctor and token usage" do
    Analytics.track_basic(event: "agent.run", tokens: 100)
    TokenUsage.track(
      response: { usage: { "total_tokens" => 100 } },
      provider: :openai,
      model: "gpt-4o"
    )
    dash = Analytics.dashboard
    expect(dash).to have_key(:summary)
    expect(dash).to have_key(:token_usage)
    expect(dash).to have_key(:health)
    expect(dash[:health][:status]).to be_in(%i[healthy issues_found])
  end
end
