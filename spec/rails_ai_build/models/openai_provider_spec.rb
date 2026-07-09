# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Models::OpenaiProvider do
  subject(:provider) { described_class.new(api_key: "sk-test") }

  before do
    RailsAiBuild.reset_configuration!
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(
        status: 200,
        body: {
          choices: [{
            message: { role: "assistant", content: "Hello from OpenAI" },
            finish_reason: "stop"
          }],
          usage: { prompt_tokens: 12, completion_tokens: 8, total_tokens: 20 }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  describe "#chat" do
    it "parses assistant response and usage" do
      result = provider.chat(messages: [{ role: "user", content: "hi" }])

      expect(result[:content]).to eq("Hello from OpenAI")
      expect(result[:usage]["total_tokens"]).to eq(20)
    end

    it "raises when api key is missing" do
      blank = described_class.new(api_key: nil)
      expect { blank.chat(messages: [{ role: "user", content: "hi" }]) }
        .to raise_error(RailsAiBuild::ConfigurationError, /API key/)
    end
  end

  describe "#list_models" do
    it "falls back to defaults when API fails" do
      stub_request(:get, "https://api.openai.com/v1/models").to_return(status: 500)
      expect(provider.list_models).to include("gpt-4o")
    end
  end
end
