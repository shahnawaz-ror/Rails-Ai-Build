# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Agents API', type: :request do
  describe 'CRUD /rails_ai_build/agents' do
    it 'lists agents' do
      build_agent_record(name: 'CRUD Bot')
      get '/rails_ai_build/agents'
      expect(response).to have_http_status(:ok)
      expect(json_response.first[:name]).to eq('CRUD Bot')
    end

    it 'creates an agent' do
      post '/rails_ai_build/agents', params: {
        agent: { name: 'New Agent', provider: 'openai', model_name: 'gpt-4o', system_prompt: 'Help.' }
      }
      expect(response).to have_http_status(:created)
      expect(json_response[:name]).to eq('New Agent')
    end

    it 'shows, updates, and destroys an agent' do
      record = build_agent_record(name: 'Editable')
      get "/rails_ai_build/agents/#{record.id}"
      expect(response).to have_http_status(:ok)

      patch "/rails_ai_build/agents/#{record.id}", params: { agent: { description: 'Updated' } }
      expect(json_response[:description]).to eq('Updated')

      delete "/rails_ai_build/agents/#{record.id}"
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'POST /rails_ai_build/agents/:id/run' do
    it 'queues a background job' do
      RailsAiBuild.configure { |c| c.api_keys[:openai] = 'sk-test' }
      stub_openai_chat
      record = build_agent_record

      post "/rails_ai_build/agents/#{record.id}/run", params: { message: 'List files' }

      expect(response).to have_http_status(:accepted)
      expect(json_response[:status]).to eq('queued')
      expect(json_response[:conversation_id]).to be_present
    end
  end
end
