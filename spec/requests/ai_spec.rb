# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI API', type: :request do
  before do
    RailsAiBuild::Ai::Session.reset!
    RailsAiBuild.configure { |c| c.api_keys[:openai] = 'sk-test' }
    stub_openai_chat(content: 'Model response here.')
  end

  after { RailsAiBuild::Ai::Session.reset! }

  describe 'POST /rails_ai_build/ai/chat' do
    it 'returns model-driven response with session' do
      post '/rails_ai_build/ai/chat', params: { message: 'List models' }
      expect(response).to have_http_status(:ok)
      expect(json_response[:content]).to include('Model response')
      expect(json_response[:session][:id]).to be_present
      expect(json_response[:context]).to be_present
    end
  end

  describe 'POST /rails_ai_build/ai/stream' do
    it 'streams AI driver events' do
      post '/rails_ai_build/ai/stream',
           params: { message: 'Hello' },
           headers: { 'Accept' => 'text/event-stream' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('event: context')
      expect(response.body).to include('event: session')
      expect(response.body).to include('event: done')
    end
  end
end
