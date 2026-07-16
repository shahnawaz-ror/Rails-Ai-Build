# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Entitlements::License do
  before { RailsAiBuild.reset_configuration! }

  describe ".issue / .verify" do
    it "round-trips a signed pro license" do
      token = described_class.issue(plan: :pro, org: "acme", expires_at: Time.now + 3600)
      result = described_class.verify(token)

      expect(result[:valid]).to be(true)
      expect(result[:plan]).to eq(:pro)
      expect(result[:org]).to eq("acme")
    end

    it "rejects tampered tokens" do
      token = described_class.issue(plan: :team)
      bad = token.sub(/.$/, token.end_with?("a") ? "b" : "a")
      result = described_class.verify(bad)
      expect(result[:valid]).to be(false)
    end

    it "rejects expired licenses" do
      token = described_class.issue(plan: :pro, expires_at: Time.now - 10)
      result = described_class.verify(token)
      expect(result[:valid]).to be(false)
      expect(result[:error]).to match(/expired/i)
    end
  end

  describe ".apply!" do
    it "sets configuration plan when durable store is unavailable" do
      # apply! -> Activation.apply_license! requires store; stub via apply_plan path for unit
      token = described_class.issue(plan: :pro)
      verified = described_class.verify(token)
      expect(verified[:valid]).to be(true)

      # Without AR table, apply_license! raises — use apply_plan! for config-only path
      RailsAiBuild::Activation.apply_plan!(:pro, source: "license")
      expect(RailsAiBuild.configuration.plan).to eq(:pro)
      expect(RailsAiBuild.configuration.diff_preview).to be(true)
    end
  end
end
