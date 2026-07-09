# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Support::Doctor do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  before do
    workspace.join("Gemfile").write('gem "rails_ai_build"\n')
    RailsAiBuild.configuration.workspace_root = workspace
    RailsAiBuild.configuration.api_keys[:openai] = "test-key"
  end

  after { FileUtils.rm_rf(workspace) }

  it "returns healthy status with valid config" do
    result = described_class.check(workspace: workspace)
    expect(result[:status]).to eq(:healthy)
    expect(result[:checks].size).to be >= 5
  end

  it "warns when API keys missing" do
    RailsAiBuild.configuration.api_keys.clear
    result = described_class.check(workspace: workspace)
    api_check = result[:checks].find { |c| c[:name] == "api_keys" }
    expect(api_check[:status]).to eq(:warning)
  end
end
