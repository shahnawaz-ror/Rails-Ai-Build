# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Memory::Store do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  before do
    RailsAiBuild.reset_configuration!
    RailsAiBuild.configuration.plan = :pro
    RailsAiBuild.configuration.workspace_root = workspace
  end

  after { FileUtils.rm_rf(workspace) }

  it "remembers and recalls values" do
    described_class.remember(workspace: workspace, key: "framework", value: "Rails 7.2")
    expect(described_class.recall(workspace: workspace, key: "framework")).to eq("Rails 7.2")
  end

  it "generates context for agent prompts" do
    described_class.remember(workspace: workspace, key: "test_framework", value: "RSpec")
    context = described_class.context_for(workspace: workspace)
    expect(context).to include("RSpec")
  end
end
