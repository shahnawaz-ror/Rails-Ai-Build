# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pull Requests API', type: :request do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  before do
    RailsAiBuild.configure do |c|
      c.workspace_root = workspace
      c.plan = :team
    end
    init_git_repo(workspace)
    system("git -C #{workspace} remote add origin git@github.com:acme/demo.git", exception: true)
  end

  after { FileUtils.rm_rf(workspace) }

  describe 'POST /rails_ai_build/pull_requests' do
    it 'creates branch and returns PR URL' do
      File.write(workspace.join('ai_change.rb'), 'puts 1')
      post '/rails_ai_build/pull_requests', params: { title: 'AI: add feature' }
      expect(response).to have_http_status(:ok)
      expect(json_response[:branch]).to start_with('ai/rails-ai-build-')
      expect(json_response[:pr_url]).to include('github.com')
    end

    it 'requires team plan' do
      RailsAiBuild.configuration.plan = :free
      post '/rails_ai_build/pull_requests', params: { title: 'AI' }
      expect(response).to have_http_status(:payment_required)
    end
  end
end
