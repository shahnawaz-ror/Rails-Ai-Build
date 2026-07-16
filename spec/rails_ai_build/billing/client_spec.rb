# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsAiBuild::Billing::Client do
  before do
    ENV['STRIPE_SECRET_KEY'] = 'sk_test'
    ENV['STRIPE_WEBHOOK_SECRET'] = 'whsec_test'
    RailsAiBuild.reset_configuration!
  end

  after do
    ENV.delete('STRIPE_SECRET_KEY')
    ENV.delete('STRIPE_WEBHOOK_SECRET')
  end

  describe '.configured?' do
    it 'is true when secret key is set' do
      expect(described_class.configured?).to be(true)
    end
  end

  describe '.create_checkout_session' do
    it 'posts to Stripe API' do
      stub_request(:post, 'https://api.stripe.com/v1/checkout/sessions')
        .to_return(status: 200, body: { id: 'cs_1', url: 'https://stripe.test' }.to_json)

      session = described_class.create_checkout_session(
        plan: :pro,
        success_url: 'https://app.test/success',
        cancel_url: 'https://app.test/cancel'
      )
      expect(session['url']).to include('stripe.test')
    end
  end

  describe '.create_portal_session' do
    it 'creates a billing portal session' do
      stub_request(:post, 'https://api.stripe.com/v1/billing_portal/sessions')
        .to_return(status: 200, body: { id: 'bps_1', url: 'https://billing.stripe.test' }.to_json)

      session = described_class.create_portal_session(
        customer_id: 'cus_123',
        return_url: 'https://app.test/ide'
      )
      expect(session['url']).to include('billing.stripe.test')
    end
  end

  describe '.verify_webhook' do
    it 'accepts a valid signed payload and upgrades plan' do
      payload = {
        type: 'checkout.session.completed',
        data: { object: { metadata: { plan: 'pro' }, customer: 'cus_abc' } }
      }.to_json
      sig = described_class.sign_payload(payload, secret: 'whsec_test')

      result = described_class.verify_webhook(payload, sig)
      expect(result[:status]).to eq('upgraded')
      expect(RailsAiBuild.configuration.plan).to eq(:pro)
    end

    it 'rejects an invalid signature' do
      payload = { type: 'checkout.session.completed', data: { object: {} } }.to_json
      bad = "t=#{Time.now.to_i},v1=#{'a' * 64}"
      expect do
        described_class.verify_webhook(payload, bad)
      end.to raise_error(RailsAiBuild::ConfigurationError, /signature/i)
    end

    it 'rejects missing signature' do
      expect do
        described_class.verify_webhook('{}', nil)
      end.to raise_error(RailsAiBuild::ConfigurationError, /signature/i)
    end
  end

  describe '.handle_event' do
    it 'downgrades on subscription deleted' do
      RailsAiBuild.configuration.plan = :team
      result = described_class.handle_event({ 'type' => 'customer.subscription.deleted' })
      expect(result[:plan]).to eq(:free)
    end
  end
end
