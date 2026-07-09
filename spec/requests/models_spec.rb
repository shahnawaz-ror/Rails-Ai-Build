# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Models API', type: :request do
  before do
    RailsAiBuild.configure { |c| c.api_keys[:openai] = 'sk-test' }
    stub_request(:get, 'https://api.openai.com/v1/models')
      .to_return(status: 200, body: { data: [{ id: 'gpt-4o' }] }.to_json)
  end

  describe 'GET /rails_ai_build/models' do
    it 'lists enabled model configs' do
      build_model_config(name: 'prod-openai')
      get '/rails_ai_build/models'
      expect(response).to have_http_status(:ok)
      expect(json_response.pluck(:name)).to include('prod-openai')
    end
  end

  describe 'POST /rails_ai_build/models' do
    it 'creates a model config' do
      post '/rails_ai_build/models', params: {
        model_config: { name: 'staging', provider: 'openai', model_name: 'gpt-4o-mini' }
      }
      expect(response).to have_http_status(:created)
    end
  end

  describe 'GET /rails_ai_build/models/providers' do
    it 'lists providers and models' do
      get '/rails_ai_build/models/providers'
      expect(response).to have_http_status(:ok)
      expect(json_response[:providers].map { |p| p[:name].to_s }).to include('openai')
    end
  end

  describe 'POST /rails_ai_build/models/test' do
    it 'tests a provider connection' do
      post '/rails_ai_build/models/test', params: { provider: 'openai', api_key: 'sk-test' }
      expect(response).to have_http_status(:ok)
      expect(json_response[:status]).to eq('ok')
    end
  end
end
