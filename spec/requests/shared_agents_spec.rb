# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Shared Agents API', type: :request do
  before do
    RailsAiBuild.configure do |c|
      c.plan = :team
      c.api_keys[:openai] = 'sk-test'
    end
    stub_openai_chat(content: 'Shared agent reply.')
  end

  describe 'GET /rails_ai_build/shared_agents' do
    it 'lists published shared agents' do
      build_shared_agent(name: 'Team Helper')
      get '/rails_ai_build/shared_agents'
      expect(response).to have_http_status(:ok)
      expect(json_response[:agents].pluck(:name)).to include('Team Helper')
    end

    it 'requires team plan' do
      RailsAiBuild.configuration.plan = :free
      get '/rails_ai_build/shared_agents'
      expect(response).to have_http_status(:payment_required)
    end
  end

  describe 'POST /rails_ai_build/shared_agents' do
    it 'creates a shared agent' do
      post '/rails_ai_build/shared_agents', params: {
        shared_agent: { name: 'Reviewer', system_prompt: 'Review PRs.' }
      }
      expect(response).to have_http_status(:created)
    end
  end

  describe 'POST /rails_ai_build/shared_agents/:id/run' do
    it 'runs a shared agent' do
      record = build_shared_agent(name: 'Runner')
      post "/rails_ai_build/shared_agents/#{record.id}/run", params: { message: 'Review' }
      expect(response).to have_http_status(:ok)
      expect(json_response[:content]).to include('Shared agent reply')
    end
  end
end
