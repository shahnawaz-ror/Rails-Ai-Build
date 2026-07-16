# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Cloud::Client do
  before do
    RailsAiBuild.reset_configuration!
    RailsAiBuild.configuration.plan = :pro
    RailsAiBuild.configuration.cloud_api_key = "rab_cloud_test"
  end

  it "raises CloudUnavailableError with BYOK CTA on connection failure" do
    allow(Net::HTTP).to receive(:start).and_raise(Errno::ECONNREFUSED)

    expect do
      described_class.chat(messages: [{ role: "user", content: "hi" }])
    end.to raise_error(RailsAiBuild::Cloud::Client::CloudUnavailableError) { |error|
      expect(error.as_json[:code]).to eq("cloud_unavailable")
      expect(error.as_json[:byok_cta]).to match(/BYOK/i)
    }
  end
end
