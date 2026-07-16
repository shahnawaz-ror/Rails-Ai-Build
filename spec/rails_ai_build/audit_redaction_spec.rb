# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Audit do
  it "redacts sensitive keys and token-shaped values" do
    result = described_class.redact(
      api_key: "sk-secret1234567890",
      note: "used sk-abcdefghijklmnopqrstuv",
      nested: { settings_token: "abc", ok: "fine" }
    )
    expect(result[:api_key]).to eq("[REDACTED]")
    expect(result[:note]).to include("[REDACTED]")
    expect(result[:nested][:settings_token]).to eq("[REDACTED]")
    expect(result[:nested][:ok]).to eq("fine")
  end
end
