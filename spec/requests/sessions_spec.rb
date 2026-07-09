# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sessions API', type: :request do
  before { RailsAiBuild::Ai::Session.reset! }
  after { RailsAiBuild::Ai::Session.reset! }

  describe 'GET /rails_ai_build/ai/sessions' do
    it 'lists conversation threads' do
      RailsAiBuild::Ai::Session.create(title: 'Billing feature')
      get '/rails_ai_build/ai/sessions'
      expect(response).to have_http_status(:ok)
      expect(json_response[:sessions].size).to eq(1)
    end
  end

  describe 'POST /rails_ai_build/ai/sessions' do
    it 'creates a new thread' do
      post '/rails_ai_build/ai/sessions', params: { title: 'New chat' }
      expect(response).to have_http_status(:created)
      expect(json_response[:title]).to eq('New chat')
    end
  end
end
