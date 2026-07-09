# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Build API', type: :request do
  before do
    RailsAiBuild.configure { |c| c.api_keys[:openai] = 'sk-test' }
    stub_openai_chat(content: 'Feature implemented.')
  end

  describe 'POST /rails_ai_build/build' do
    it 'runs universal builder with verify' do
      allow_any_instance_of(RailsAiBuild::Tools::RunRailsCheckTool).to receive(:call)
        .and_return({ passed: true, checks: {} })

      post '/rails_ai_build/build',
           params: { task: 'Add GET /health endpoint', verify: false }.to_json,
           headers: { 'CONTENT_TYPE' => 'application/json' }

      expect(response).to have_http_status(:ok)
      expect(json_response[:status]).to eq('success')
      expect(json_response[:content]).to include('Feature')
    end
  end

  describe 'POST /rails_ai_build/build/stream' do
    it 'streams build events' do
      allow_any_instance_of(RailsAiBuild::Tools::RunRailsCheckTool).to receive(:call)
        .and_return({ passed: true, checks: {} })

      post '/rails_ai_build/build/stream',
           params: { task: 'Add health endpoint', verify: false }.to_json,
           headers: { 'CONTENT_TYPE' => 'application/json', 'Accept' => 'text/event-stream' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('event: start')
      expect(response.body).to include('event: complete')
    end
  end
end
