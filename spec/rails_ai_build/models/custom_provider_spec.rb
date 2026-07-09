# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsAiBuild::Models::CustomProvider do
  describe 'openai_compatible adapter' do
    it 'delegates to OpenAI provider' do
      stub_request(:post, 'http://localhost:11434/v1/chat/completions')
        .to_return(
          status: 200,
          body: {
            choices: [{ message: { role: 'assistant', content: 'Ollama reply' }, finish_reason: 'stop' }],
            usage: { total_tokens: 10 }
          }.to_json
        )

      provider = described_class.new(
        name: :ollama,
        api_key: 'ollama',
        base_url: 'http://localhost:11434/v1',
        adapter: :openai_compatible
      )
      result = provider.chat(messages: [{ role: 'user', content: 'hi' }])
      expect(result[:content]).to eq('Ollama reply')
    end
  end

  describe 'custom endpoint' do
    it 'uses request_builder and response_parser' do
      stub_request(:post, 'https://api.example.com/v1/generate')
        .to_return(status: 200, body: { text: 'custom' }.to_json)

      provider = described_class.new(
        name: :custom,
        endpoint: 'https://api.example.com/v1/generate',
        request_builder: ->(messages, _tools, _model, _opts) { { prompt: messages.last[:content] } },
        response_parser: ->(body) { { role: 'assistant', content: body['text'], tool_calls: [] } }
      )
      result = provider.chat(messages: [{ role: 'user', content: 'hi' }])
      expect(result[:content]).to eq('custom')
    end
  end
end
