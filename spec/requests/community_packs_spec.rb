# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Community Packs API', type: :request do
  before { RailsAiBuild.configuration.plan = :team }

  describe 'GET /rails_ai_build/community' do
    it 'lists approved community packs' do
      build_community_pack(name: 'Auth Pack', approved: true)
      get '/rails_ai_build/community'
      expect(response).to have_http_status(:ok)
      names = json_response[:packs].pluck(:name)
      expect(names).to include('Auth Pack')
    end
  end

  describe 'POST /rails_ai_build/community' do
    it 'submits a pack for review' do
      post '/rails_ai_build/community', params: {
        community_pack: {
          name: 'Test Pack',
          system_prompt: 'Write tests.',
          author: 'dev@example.com'
        }
      }
      expect(response).to have_http_status(:created)
      expect(json_response[:status]).to eq('pending_review')
    end
  end

  describe 'POST /rails_ai_build/community/:id/approve' do
    it 'approves a pending pack' do
      pack = build_community_pack(name: 'Awaiting Approval')
      post "/rails_ai_build/community/#{pack.slug}/approve"
      expect(response).to have_http_status(:ok)
      expect(pack.reload).to be_approved
    end
  end
end
