# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Support::Settings do
  before { RailsAiBuild.reset_configuration! }

  describe ".update" do
    it "accepts string keys from controller params" do
      result = described_class.update("default_model" => "gpt-4o-mini")

      expect(RailsAiBuild.configuration.default_model).to eq("gpt-4o-mini")
      expect(result[:default_model]).to eq("gpt-4o-mini")
    end
  end
end
