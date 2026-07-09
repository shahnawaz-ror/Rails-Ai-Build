# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Compatibility::EdgeCases do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  after { FileUtils.rm_rf(workspace) }

  it "passes all edge case tests" do
    result = described_class.run(workspace)
    expect(result[:errors]).to be_empty
    expect(result[:passed]).to eq(result[:total])
  end
end
