# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Plans do
  before { RailsAiBuild.reset_configuration! }

  describe ".check!" do
    it "raises PlanRequiredError with upgrade payload" do
      expect { described_class.check!(:diff_preview) }.to raise_error(RailsAiBuild::PlanRequiredError) do |error|
        payload = error.as_json
        expect(payload[:code]).to eq("plan_required")
        expect(payload[:feature]).to eq(:diff_preview)
        expect(payload[:suggested_plan]).to eq(:pro)
        expect(payload[:upgrade]).to include("pricing")
        expect(payload[:checkout][:plan]).to eq(:pro)
      end
    end

    it "passes when feature is available" do
      expect { described_class.check!(:streaming) }.not_to raise_error
    end
  end
end
