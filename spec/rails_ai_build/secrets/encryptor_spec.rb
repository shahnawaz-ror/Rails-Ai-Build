# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Secrets::Encryptor do
  before do
    ENV["RAILS_AI_BUILD_SECRET"] = "test-secret-for-encryptor-specs"
    described_class.send(:reset!)
  end

  after do
    ENV.delete("RAILS_AI_BUILD_SECRET")
    described_class.send(:reset!)
  end

  it "encrypts and decrypts values" do
    cipher = described_class.encrypt("sk-secret")
    expect(cipher).to start_with("rab1:")
    expect(described_class.decrypt(cipher)).to eq("sk-secret")
  end

  it "returns nil for tampered ciphertext" do
    cipher = described_class.encrypt("sk-secret")
    expect(described_class.decrypt(cipher + "x")).to be_nil
  end
end
