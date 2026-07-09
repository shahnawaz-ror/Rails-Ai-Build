# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsAiBuild::Billing::Client do
  before do
    ENV['STRIPE_SECRET_KEY'] = 'sk_test'
    ENV['STRIPE_WEBHOOK_SECRET'] = 'whsec'
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

  describe '.handle_event' do
    it 'upgrades on checkout.session.completed' do
      result = described_class.handle_event({
                                              'type' => 'checkout.session.completed',
                                              'data' => { 'object' => { 'metadata' => { 'plan' => 'pro' } } }
                                            })
      expect(result[:status]).to eq('upgraded')
      expect(RailsAiBuild.configuration.plan).to eq(:pro)
    end

    it 'downgrades on subscription deleted' do
      RailsAiBuild.configuration.plan = :team
      result = described_class.handle_event({ 'type' => 'customer.subscription.deleted' })
      expect(result[:plan]).to eq(:free)
    end
  end
end
