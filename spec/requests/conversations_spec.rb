# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Conversations API', type: :request do
  let(:agent_record) { build_agent_record }
  let(:conv) { build_conversation(agent_record) }

  before do
    RailsAiBuild.configure { |c| c.api_keys[:openai] = 'sk-test' }
    stub_openai_chat(content: 'Conversation reply.')
  end

  describe 'GET /rails_ai_build/agents/:agent_id/conversations/:id' do
    it 'returns conversation with messages' do
      build_message(conv)
      get "/rails_ai_build/agents/#{agent_record.id}/conversations/#{conv.id}"
      expect(response).to have_http_status(:ok)
      expect(json_response[:messages]).to be_present
    end
  end

  describe 'POST messages' do
    it 'appends user and assistant messages' do
      post "/rails_ai_build/agents/#{agent_record.id}/conversations/#{conv.id}/messages",
           params: { content: 'Continue CRUD work' }

      expect(response).to have_http_status(:ok)
      expect(json_response[:response][:content]).to include('Conversation reply')
      expect(conv.messages.count).to be >= 2
    end
  end
end
