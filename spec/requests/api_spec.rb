# frozen_string_literal: true

require "rails_helper"

RSpec.describe "RailsAiBuild API", type: :request do
  describe "GET /rails_ai_build/help" do
    it "returns help topics and version" do
      get "/rails_ai_build/help"

      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body[:topics]).to be_an(Array)
      expect(body[:topics]).not_to be_empty
      expect(body[:version]).to eq(RailsAiBuild::VERSION)
    end
  end

  describe "GET /rails_ai_build/help/:id" do
    it "returns a specific help topic" do
      get "/rails_ai_build/help/getting-started"

      expect(response).to have_http_status(:ok)
      expect(json_response[:title]).to be_present
      expect(json_response[:content]).to be_present
    end

    it "returns the activation help topic" do
      get "/rails_ai_build/help/activation"

      expect(response).to have_http_status(:ok)
      expect(json_response[:content]).to include("BYOK")
      expect(json_response[:content]).to include("License")
    end

    it "returns 404 for unknown topics" do
      get "/rails_ai_build/help/not-a-real-topic-id"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /rails_ai_build/plans" do
    it "lists all plans with current plan" do
      get "/rails_ai_build/plans"

      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body[:plans].map { |p| p[:id].to_s }).to include("free", "pro", "team", "enterprise")
      expect(body[:current_plan].to_s).to eq("free")
    end
  end

  describe "GET /rails_ai_build/plans/current" do
    it "returns the active plan details" do
      get "/rails_ai_build/plans/current"

      expect(response).to have_http_status(:ok)
      expect(json_response[:plan].to_s).to eq("free")
      expect(json_response[:features]).to be_present
    end
  end

  describe "GET /rails_ai_build/api" do
    it "returns dashboard payload" do
      get "/rails_ai_build/api"

      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body[:version]).to eq(RailsAiBuild::VERSION)
      expect(body[:skills]).to be_an(Array)
      expect(body[:providers].map(&:to_s)).to include("openai", "anthropic")
    end
  end

  describe "GET /rails_ai_build/settings" do
    it "returns current settings" do
      get "/rails_ai_build/settings"

      expect(response).to have_http_status(:ok)
      expect(json_response[:default_model]).to be_present
    end
  end

  describe "PATCH /rails_ai_build/settings" do
    it "updates configuration" do
      patch "/rails_ai_build/settings", params: { default_model: "gpt-4o-mini" }

      expect(response).to have_http_status(:ok)
      expect(json_response[:default_model]).to eq("gpt-4o-mini")
      expect(RailsAiBuild.configuration.default_model).to eq("gpt-4o-mini")
    end
  end

  describe "GET /rails_ai_build/support/doctor" do
    it "runs diagnostics" do
      get "/rails_ai_build/support/doctor"

      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body[:checks]).to be_an(Array)
      expect(body[:version]).to eq(RailsAiBuild::VERSION)
    end
  end

  describe "GET /rails_ai_build/mcp/tools" do
    it "lists MCP tools" do
      get "/rails_ai_build/mcp/tools"

      expect(response).to have_http_status(:ok)
      expect(json_response[:tools]).to be_an(Array)
    end
  end
end
