# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Upgrade API', type: :request do
  describe 'GET /rails_ai_build/help/upgrade' do
    it 'returns upgrade help topic' do
      get '/rails_ai_build/help/upgrade'
      expect(response).to have_http_status(:ok)
      expect(json_response[:content]).to include('rails generate rails_ai_build:upgrade')
    end
  end
end
