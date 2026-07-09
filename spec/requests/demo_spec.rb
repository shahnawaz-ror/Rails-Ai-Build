# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RailsAiBuild Demo UI', type: :request do
  describe 'GET /rails_ai_build/ui/demo' do
    it 'renders the live demo page' do
      get '/rails_ai_build/ui/demo'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('LIVE DEMO')
      expect(response.body).to include('health-check')
      expect(response.body).to include('Run Live Example')
    end
  end

  describe 'POST /rails_ai_build/demo/stream' do
    it 'streams SSE events for a scenario' do
      post '/rails_ai_build/demo/stream',
           params: { scenario: 'health-check' }.to_json,
           headers: { 'Content-Type' => 'application/json', 'Accept' => 'text/event-stream' }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/event-stream')
      expect(response.body).to include('event: start')
      expect(response.body).to include('event: tool_call')
      expect(response.body).to include('event: complete')
      expect(response.body).to include('read_file')
    end
  end
end
