# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analytics API', type: :request do
  describe 'GET /rails_ai_build/analytics' do
    it 'returns analytics dashboard' do
      get '/rails_ai_build/analytics'
      expect(response).to have_http_status(:ok)
      expect(json_response).to be_a(Hash)
    end
  end

  describe 'GET /rails_ai_build/tokens' do
    it 'returns token usage summary' do
      get '/rails_ai_build/tokens'
      expect(response).to have_http_status(:ok)
      expect(json_response).to be_a(Hash)
    end
  end
end
