# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Git API', type: :request do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  before do
    RailsAiBuild.configure { |c| c.workspace_root = workspace }
    init_git_repo(workspace)
  end

  after { FileUtils.rm_rf(workspace) }

  describe 'GET /rails_ai_build/git/status' do
    it 'returns git summary' do
      get '/rails_ai_build/git/status'
      expect(response).to have_http_status(:ok)
      expect(json_response[:branch]).to be_present
    end
  end

  describe 'GET /rails_ai_build/git/diff' do
    it 'returns diff output' do
      File.write(workspace.join('change.txt'), 'x')
      get '/rails_ai_build/git/diff'
      expect(response).to have_http_status(:ok)
      expect(json_response[:diff]).to be_a(String)
    end
  end

  describe 'POST /rails_ai_build/git/commit' do
    it 'requires team plan for commits' do
      post '/rails_ai_build/git/commit', params: { message: 'AI changes' }
      expect(response).to have_http_status(:payment_required)
    end

    it 'commits when plan allows' do
      RailsAiBuild.configuration.plan = :team
      File.write(workspace.join('feature.txt'), 'new')
      post '/rails_ai_build/git/commit', params: { message: 'AI changes' }
      expect(response).to have_http_status(:ok)
      expect(json_response[:success]).to be(true)
    end
  end
end
