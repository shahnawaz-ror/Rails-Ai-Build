# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rails AI Build IDE', type: :request do
  describe 'GET /rails_ai_build/ui/ide' do
    it 'renders the Agents-first IDE' do
      get '/rails_ai_build/ui/ide'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Rails AI Build')
      expect(response.body).to include('rab-ide')
      expect(response.body).to include('New agent')
      expect(response.body).to include('rab-layout-agents')
      expect(response.body).to include('Changes')
      expect(response.body).to include('What should we build?')
    end
  end

  describe 'GET /rails_ai_build (root)' do
    it 'redirects to IDE as default workspace' do
      get '/rails_ai_build'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('rab-ide')
    end
  end

  describe 'GET /rails_ai_build/workspace/tree' do
    it 'returns workspace file tree' do
      get '/rails_ai_build/workspace/tree', params: { depth: 2 }

      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body[:entries]).to be_an(Array)
    end
  end

  describe 'GET /rails_ai_build/workspace/file' do
    it 'reads a file from workspace' do
      get '/rails_ai_build/workspace/file', params: { path: 'config/application.rb' }

      expect(response).to have_http_status(:ok)
      expect(json_response[:content]).to include('Application')
    end

    it 'rejects paths outside workspace' do
      get '/rails_ai_build/workspace/file', params: { path: '../../../etc/passwd' }

      expect(response).to have_http_status(:forbidden)
    end
  end
end
