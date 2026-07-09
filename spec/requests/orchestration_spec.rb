# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Orchestration API', type: :request do
  before do
    RailsAiBuild.configure do |c|
      c.plan = :team
      c.api_keys[:openai] = 'sk-test'
    end
    stub_openai_chat(content: 'Orchestration complete.')
  end

  describe 'POST /rails_ai_build/orchestrate' do
    it 'runs multi-agent orchestration' do
      post '/rails_ai_build/orchestrate', params: { task: 'Add health endpoint' }
      expect(response).to have_http_status(:ok)
      expect(json_response).to be_present
    end

    it 'runs with review when requested' do
      post '/rails_ai_build/orchestrate', params: { task: 'Refactor service', review: true }
      expect(response).to have_http_status(:ok)
    end
  end
end
