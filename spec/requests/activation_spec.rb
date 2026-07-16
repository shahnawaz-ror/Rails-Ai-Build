# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Day-1 Activation OS", type: :request do
  before do
    ENV["RAILS_AI_BUILD_SECRET"] = "test-activation-secret"
    RailsAiBuild::Secrets::Encryptor.send(:reset!)
  end

  after do
    ENV.delete("RAILS_AI_BUILD_SECRET")
    ENV.delete("RAILS_AI_BUILD_SETTINGS_TOKEN")
    ENV.delete("RAILS_AI_BUILD_ALLOW_OPEN_SETTINGS")
    RailsAiBuild::Secrets::Encryptor.send(:reset!)
  end

  describe "GET /rails_ai_build/settings" do
    it "includes activation status" do
      get "/rails_ai_build/settings"
      expect(response).to have_http_status(:ok)
      expect(json_response[:activation]).to include(:needs_wizard, :api_keys_configured)
      expect(json_response[:api_keys_configured]).to include(:nvidia)
    end
  end

  describe "POST /rails_ai_build/settings/keys" do
    it "persists encrypted API keys" do
      post "/rails_ai_build/settings/keys",
           params: { openai: "sk-live-test", nvidia: "nvapi-live-test" }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(json_response[:api_keys_configured][:openai]).to be(true)
      expect(json_response[:api_keys_configured][:nvidia]).to be(true)

      row = RailsAiBuild::ActivationRecord.instance_row
      expect(row.encrypted_api_keys).to start_with("rab1:")
      expect(row.decrypted_api_keys[:openai]).to eq("sk-live-test")
    end
  end

  describe "POST /rails_ai_build/settings/license" do
    it "activates a signed license and persists plan" do
      token = RailsAiBuild::Entitlements::License.issue(plan: :team, org: "agency")

      post "/rails_ai_build/settings/license",
           params: { license_key: token }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(RailsAiBuild.configuration.plan).to eq(:team)
      expect(RailsAiBuild::ActivationRecord.instance_row.plan).to eq("team")
      expect(RailsAiBuild::ActivationRecord.instance_row.entitlement_source).to eq("license")
    end
  end

  describe "PATCH /rails_ai_build/settings plan spoofing" do
    it "forbids setting plan directly" do
      patch "/rails_ai_build/settings",
            params: { plan: "enterprise" }.to_json,
            headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:forbidden)
      expect(RailsAiBuild.configuration.plan).to eq(:free)
    end
  end

  describe "settings token auth" do
    it "requires token after bootstrap" do
      post "/rails_ai_build/settings/bootstrap"
      expect(response).to have_http_status(:ok)
      token = json_response[:settings_token]
      expect(token).to be_present

      patch "/rails_ai_build/settings",
            params: { default_model: "gpt-4o-mini" }.to_json,
            headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:unauthorized)

      patch "/rails_ai_build/settings",
            params: { default_model: "gpt-4o-mini" }.to_json,
            headers: {
              "CONTENT_TYPE" => "application/json",
              "X-Rails-Ai-Build-Token" => token
            }
      expect(response).to have_http_status(:ok)
      expect(json_response[:default_model]).to eq("gpt-4o-mini")
    end
  end

  describe "plan required payloads" do
    it "returns structured upgrade JSON for gated features" do
      get "/rails_ai_build/audit"
      expect(response).to have_http_status(:payment_required)
      expect(json_response[:code]).to eq("plan_required")
      expect(json_response[:suggested_plan].to_s).to eq("team")
      expect(json_response[:checkout]).to include(:endpoint, :plan)
    end
  end

  describe "GET /rails_ai_build/support/doctor" do
    it "includes activation and encryption checks" do
      get "/rails_ai_build/support/doctor"
      names = json_response[:checks].map { |c| c[:name].to_s }
      expect(names).to include("activation", "encryption")
      expect(json_response).to have_key(:activation)
    end
  end

  describe "billing webhook durability" do
    before do
      ENV["STRIPE_SECRET_KEY"] = "sk_test"
      ENV["STRIPE_WEBHOOK_SECRET"] = "whsec"
    end

    after do
      ENV.delete("STRIPE_SECRET_KEY")
      ENV.delete("STRIPE_WEBHOOK_SECRET")
    end

    it "persists plan on checkout completion" do
      payload = {
        type: "checkout.session.completed",
        data: { object: { metadata: { plan: "pro" }, customer: "cus_act" } }
      }.to_json
      sig = RailsAiBuild::Billing::Client.sign_payload(payload, secret: "whsec")

      post "/rails_ai_build/billing/webhook",
           params: payload,
           headers: { "Stripe-Signature" => sig, "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(RailsAiBuild.configuration.plan).to eq(:pro)
      expect(RailsAiBuild::ActivationRecord.instance_row.plan).to eq("pro")
    end
  end
end
