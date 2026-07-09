# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MCP POST API', type: :request do
  describe 'POST /rails_ai_build/mcp' do
    it 'handles tools/list request' do
      post '/rails_ai_build/mcp',
           params: { jsonrpc: '2.0', id: 1, method: 'tools/list' }.to_json,
           headers: { 'CONTENT_TYPE' => 'application/json' }
      expect(response).to have_http_status(:ok)
      expect(json_response[:result][:tools]).to be_an(Array)
    end

    it 'returns 400 for invalid JSON' do
      post '/rails_ai_build/mcp', params: 'not-json', headers: { 'CONTENT_TYPE' => 'application/json' }
      expect(response).to have_http_status(:bad_request)
    end
  end
end
