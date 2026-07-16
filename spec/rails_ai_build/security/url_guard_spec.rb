# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Security::UrlGuard do
  before { RailsAiBuild.reset_configuration! }

  it "allows public https URLs" do
    expect(described_class.validate!("https://api.openai.com/v1/chat/completions")).to eq(true)
  end

  it "blocks metadata IPs" do
    expect do
      described_class.validate!("http://169.254.169.254/latest/meta-data/")
    end.to raise_error(RailsAiBuild::ConfigurationError, /metadata|link-local|Blocked/i)
  end

  it "blocks private IPs by default" do
    RailsAiBuild.configuration.ssrf_allow_private = false
    expect do
      described_class.validate!("http://10.0.0.5/secret")
    end.to raise_error(RailsAiBuild::ConfigurationError, /Private/)
  end

  it "allows localhost when configured" do
    RailsAiBuild.configuration.ssrf_allow_localhost = true
    expect(described_class.validate!("http://127.0.0.1:11434/v1")).to eq(true)
  end

  it "rejects non-http schemes" do
    expect do
      described_class.validate!("file:///etc/passwd")
    end.to raise_error(RailsAiBuild::ConfigurationError, /scheme/)
  end
end
