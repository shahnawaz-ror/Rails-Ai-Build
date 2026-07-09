# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Billing API', type: :request do
  before do
    ENV['STRIPE_SECRET_KEY'] = 'sk_test_123'
    ENV['STRIPE_WEBHOOK_SECRET'] = 'whsec_test'
  end

  after do
    ENV.delete('STRIPE_SECRET_KEY')
    ENV.delete('STRIPE_WEBHOOK_SECRET')
  end

  describe 'POST /rails_ai_build/billing/checkout' do
    it 'creates a checkout session' do
      stub_request(:post, 'https://api.stripe.com/v1/checkout/sessions')
        .to_return(status: 200, body: { id: 'cs_test', url: 'https://checkout.stripe.com/test' }.to_json)

      post '/rails_ai_build/billing/checkout', params: { plan: 'pro', email: 'dev@example.com' }
      expect(response).to have_http_status(:ok)
      expect(json_response[:checkout_url]).to include('stripe.com')
    end

    it 'returns 422 when Stripe is not configured' do
      ENV.delete('STRIPE_SECRET_KEY')
      post '/rails_ai_build/billing/checkout', params: { plan: 'pro' }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'POST /rails_ai_build/billing/webhook' do
    it 'upgrades plan on checkout.session.completed' do
      payload = {
        type: 'checkout.session.completed',
        data: { object: { metadata: { plan: 'pro' } } }
      }.to_json

      post '/rails_ai_build/billing/webhook',
           params: payload,
           headers: { 'Stripe-Signature' => 'sig_test', 'CONTENT_TYPE' => 'application/json' }

      expect(response).to have_http_status(:ok)
      expect(json_response[:status]).to eq('upgraded')
      expect(RailsAiBuild.configuration.plan).to eq(:pro)
    end
  end
end
