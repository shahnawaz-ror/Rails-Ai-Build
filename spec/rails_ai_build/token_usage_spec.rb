# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::TokenUsage do
  before { described_class.reset! }

  it "tracks tokens from OpenAI-style usage" do
    record = described_class.track(
      response: { usage: { "prompt_tokens" => 100, "completion_tokens" => 50, "total_tokens" => 150 } },
      provider: :openai,
      model: "gpt-4o"
    )
    expect(record.total_tokens).to eq(150)
    expect(record.prompt_tokens).to eq(100)
    expect(record.completion_tokens).to eq(50)
  end

  it "tracks tokens from Anthropic-style usage" do
    record = described_class.track(
      response: { usage: { "input_tokens" => 80, "output_tokens" => 40 } },
      provider: :anthropic,
      model: "claude-sonnet-4-20250514"
    )
    expect(record.total_tokens).to eq(120)
  end

  it "summarizes token usage" do
    described_class.track(
      response: { usage: { "total_tokens" => 200 } },
      provider: :openai,
      model: "gpt-4o-mini"
    )
    summary = described_class.summary(since: Time.now - 3600)
    expect(summary[:total_tokens]).to eq(200)
    expect(summary[:request_count]).to eq(1)
  end

  it "estimates cost" do
    cost = described_class.estimated_cost(model: "gpt-4o", prompt_tokens: 1000, completion_tokens: 500)
    expect(cost).to be > 0
  end

  it "ignores zero-token responses" do
    result = described_class.track(response: {}, provider: :openai, model: "gpt-4o")
    expect(result).to be_nil
  end
end
