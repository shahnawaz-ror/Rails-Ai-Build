# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Skills API', type: :request do
  before do
    RailsAiBuild.configure { |c| c.api_keys[:openai] = 'sk-test' }
    stub_openai_chat(content: 'CRUD resource created.')
  end

  describe 'GET /rails_ai_build/skills' do
    it 'lists available skills' do
      get '/rails_ai_build/skills'
      expect(response).to have_http_status(:ok)
      expect(json_response[:skills]).not_to be_empty
    end
  end

  describe 'POST /rails_ai_build/skills/run' do
    it 'runs a skill' do
      post '/rails_ai_build/skills/run', params: { skill: 'crud', message: 'Create Post' }
      expect(response).to have_http_status(:ok)
      expect(json_response[:skill]).to eq('crud')
    end
  end
end
