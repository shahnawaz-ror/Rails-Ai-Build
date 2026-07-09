# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Chat API', type: :request do
  before do
    RailsAiBuild.configure do |c|
      c.api_keys[:openai] = 'sk-test'
      c.workspace_root = Pathname.new(Dir.mktmpdir)
    end
    stub_openai_chat(content: 'Added health endpoint.')
  end

  describe 'POST /rails_ai_build/chat' do
    it 'returns assistant response' do
      post '/rails_ai_build/chat', params: { message: 'Add a health check' }
      expect(response).to have_http_status(:ok)
      expect(json_response[:content]).to include('Added health endpoint')
    end

    it 'runs a skill when skill param is set' do
      post '/rails_ai_build/chat', params: { message: 'Create Post', skill: 'crud' }
      expect(response).to have_http_status(:ok)
      expect(json_response[:content]).to be_present
    end

    it 'returns 422 on configuration errors' do
      RailsAiBuild.configuration.api_keys[:openai] = nil
      post '/rails_ai_build/chat', params: { message: 'hi' }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
