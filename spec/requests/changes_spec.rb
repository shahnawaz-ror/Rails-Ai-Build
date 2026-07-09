# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Changes API', type: :request do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  before do
    RailsAiBuild.configure do |c|
      c.workspace_root = workspace
      c.plan = :pro
      c.diff_preview = true
    end
  end

  after { FileUtils.rm_rf(workspace) }

  describe 'pending changes workflow' do
    let!(:change_id) do
      result = RailsAiBuild::Changes::Store.record(
        path: 'app/models/post.rb',
        old_content: '',
        new_content: "class Post; end\n",
        workspace: workspace
      )
      result[:change_id]
    end

    it 'lists pending changes' do
      get '/rails_ai_build/changes', params: { status: 'pending' }
      expect(response).to have_http_status(:ok)
      expect(json_response[:changes].size).to eq(1)
    end

    it 'shows a change with diff content' do
      get "/rails_ai_build/changes/#{change_id}"
      expect(response).to have_http_status(:ok)
      expect(json_response[:path]).to eq('app/models/post.rb')
    end

    it 'applies and rejects changes' do
      post "/rails_ai_build/changes/#{change_id}/apply"
      expect(response).to have_http_status(:ok)
      expect(workspace.join('app/models/post.rb')).to exist

      result = RailsAiBuild::Changes::Store.record(
        path: 'app/models/comment.rb',
        old_content: '',
        new_content: "class Comment; end\n",
        workspace: workspace
      )
      post "/rails_ai_build/changes/#{result[:change_id]}/reject"
      expect(response).to have_http_status(:ok)
      expect(workspace.join('app/models/comment.rb')).not_to exist
    end

    it 'applies all pending changes' do
      RailsAiBuild::Changes::Store.record(
        path: 'app/a.rb', old_content: '', new_content: "A\n", workspace: workspace
      )
      post '/rails_ai_build/changes/apply_all'
      expect(response).to have_http_status(:ok)
      expect(json_response[:applied].size).to be >= 1
    end
  end
end
