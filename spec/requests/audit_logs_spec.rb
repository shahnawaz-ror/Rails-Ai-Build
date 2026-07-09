# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Audit Logs API', type: :request do
  before do
    RailsAiBuild.configuration.plan = :team
    RailsAiBuild.configuration.audit_enabled = true
  end

  describe 'GET /rails_ai_build/audit' do
    it 'returns audit logs on team plan' do
      RailsAiBuild::Audit.log(action: 'chat', path: '/chat', user: 'dev')
      get '/rails_ai_build/audit'
      expect(response).to have_http_status(:ok)
      expect(json_response[:logs]).not_to be_empty
    end

    it 'requires team plan' do
      RailsAiBuild.configuration.plan = :free
      get '/rails_ai_build/audit'
      expect(response).to have_http_status(:payment_required)
    end
  end
end
