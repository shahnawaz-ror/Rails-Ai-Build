# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsAiBuild::Models::AnthropicProvider do
  subject(:provider) { described_class.new(api_key: 'sk-ant-test') }

  before do
    stub_request(:post, 'https://api.anthropic.com/v1/messages')
      .to_return(
        status: 200,
        body: {
          content: [{ type: 'text', text: 'Hello from Claude' }],
          usage: { input_tokens: 10, output_tokens: 5 }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  describe '#chat' do
    it 'parses assistant response' do
      result = provider.chat(messages: [{ role: 'user', content: 'hi' }])
      expect(result[:content]).to eq('Hello from Claude')
    end
  end

  describe '#list_models' do
    it 'returns default models' do
      expect(provider.list_models).to include('claude-sonnet-4-20250514')
    end
  end
end
