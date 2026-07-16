# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Health", type: :request do
  it "returns liveness JSON" do
    get "/rails_ai_build/health"
    expect(response).to have_http_status(:ok)
    expect(json_response[:status]).to eq("ok")
    expect(json_response[:version]).to eq(RailsAiBuild::VERSION)
  end
end
