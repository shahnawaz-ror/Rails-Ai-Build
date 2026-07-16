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

  it "rolls back a session of applied changes" do
    session_id = "sess-1"
    described_class.begin_session!(session_id)
    described_class.record(
      path: "app/a.rb",
      old_content: "",
      new_content: "A\n",
      workspace: workspace,
      session_id: session_id
    )
    described_class.track_external(
      path: "app/b.rb",
      content: "B\n",
      old_content: "",
      workspace: workspace,
      session_id: session_id
    )
    workspace.join("app/b.rb").dirname.mkpath
    workspace.join("app/b.rb").write("B\n")

    result = described_class.rollback_session(session_id, workspace: workspace)
    expect(result[:count]).to eq(2)
    expect(workspace.join("app/a.rb")).not_to exist
    expect(workspace.join("app/b.rb")).not_to exist
  end
end

