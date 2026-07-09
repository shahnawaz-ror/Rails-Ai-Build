# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe RailsAiBuild::Changes::Store do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  before do
    RailsAiBuild.reset_configuration!
    RailsAiBuild.configuration.workspace_root = workspace
    described_class.clear!
  end

  after { FileUtils.rm_rf(workspace) }

  it "writes immediately when diff_preview is off" do
    result = described_class.record(
      path: "app/test.rb",
      old_content: "",
      new_content: "class Test\nend\n",
      workspace: workspace
    )
    expect(result[:status]).to eq("written")
    expect(workspace.join("app/test.rb")).to exist
  end

  it "queues changes when diff_preview is on" do
    RailsAiBuild.configuration.plan = :pro
    RailsAiBuild.configuration.diff_preview = true

    result = described_class.record(
      path: "app/test.rb",
      old_content: "",
      new_content: "class Test\nend\n",
      workspace: workspace
    )
    expect(result[:status]).to eq("pending_approval")
    expect(workspace.join("app/test.rb")).not_to exist

    apply_result = described_class.apply(result[:change_id], workspace: workspace)
    expect(apply_result[:status]).to eq("applied")
    expect(workspace.join("app/test.rb")).to exist
  end
end
