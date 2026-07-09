# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Marketplace API', type: :request do
  before do
    RailsAiBuild.configure { |c| c.api_keys[:openai] = 'sk-test' }
    stub_openai_chat(content: 'Pack installed.')
  end

  describe 'GET /rails_ai_build/marketplace' do
    it 'lists builtin and community packs' do
      build_community_pack(name: 'Community CRUD', approved: true)
      get '/rails_ai_build/marketplace'
      expect(response).to have_http_status(:ok)
      expect(json_response[:packs]).not_to be_empty
    end
  end

  describe 'POST /rails_ai_build/marketplace/:id/install' do
    it 'installs a pack and runs chat' do
      packs = RailsAiBuild::Marketplace::Registry.all
      pack_id = packs.first[:id]
      post "/rails_ai_build/marketplace/#{pack_id}/install", params: { message: 'Start' }
      expect(response).to have_http_status(:ok)
      expect(json_response[:content]).to include('Pack installed')
    end

    it 'returns 404 for unknown pack' do
      post '/rails_ai_build/marketplace/unknown-pack/install'
      expect(response).to have_http_status(:not_found)
    end
  end
end
