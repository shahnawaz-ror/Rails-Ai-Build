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
      expect(json_response[:code]).to eq('plan_required')
    end
  end

  describe 'GET /rails_ai_build/audit/export' do
    it 'exports JSON on team plan' do
      RailsAiBuild::Audit.log(action: 'chat', path: '/chat', user: 'dev')
      get '/rails_ai_build/audit/export'
      expect(response).to have_http_status(:ok)
      expect(json_response[:count]).to be >= 1
      expect(json_response[:logs]).to be_present
    end

    it 'exports CSV when format=csv' do
      RailsAiBuild::Audit.log(action: 'chat', path: '/chat', user: 'dev')
      get '/rails_ai_build/audit/export', params: { format: 'csv' }
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/csv')
      expect(response.body).to include('action,path,user')
    end
  end
end
