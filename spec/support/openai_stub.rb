# frozen_string_literal: true

module OpenaiStub
  def stub_openai_chat(content: 'Hello from agent', tool_calls: nil)
    body = {
      choices: [{
        message: {
          role: 'assistant',
          content: content,
          tool_calls: tool_calls
        }.compact,
        finish_reason: tool_calls ? 'tool_calls' : 'stop'
      }],
      usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 }
    }

    stub_request(:post, 'https://api.openai.com/v1/chat/completions')
      .to_return(status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
  end
end

RSpec.configure do |config|
  config.include OpenaiStub
end
