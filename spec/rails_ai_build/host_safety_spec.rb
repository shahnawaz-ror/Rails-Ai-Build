# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe RailsAiBuild::HostSafety do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  before do
    RailsAiBuild.reset_configuration!
    RailsAiBuild.configuration.workspace_root = workspace
    RailsAiBuild.configuration.host_safety = true
    RailsAiBuild.configuration.host_safety_boot_check = false
    RailsAiBuild.configuration.host_safety_zeitwerk_check = false
    RailsAiBuild.configuration.host_safety_bundle_check = false
    RailsAiBuild.configuration.host_safety_smoke_routes = false
    RailsAiBuild.configuration.host_safety_soft_preview = true
    RailsAiBuild.configuration.host_safety_shadow_worktree = false
    RailsAiBuild.configuration.host_safety_git_checkpoint = false
    RailsAiBuild::Changes::Store.clear!
  end

  after do
    described_class.end_session!
    FileUtils.rm_rf(workspace)
  end

  it "rejects invalid Ruby writes" do
    expect do
      described_class.validate_write!("app/models/broken.rb", "class Broken\n")
    end.to raise_error(RailsAiBuild::ToolError, /Syntax error/)
  end

  it "rejects bad migration filenames" do
    expect do
      described_class.validate_write!(
        "db/migrate/1_create_x.rb",
        "class CreateX < ActiveRecord::Migration[7.1]; def change; end; end"
      )
    end.to raise_error(RailsAiBuild::ToolError, /YYYYMMDDHHMMSS/)
  end

  it "accepts valid Ruby" do
    expect(described_class.validate_write!("app/models/ok.rb", "class Ok\nend\n")).to eq(true)
  end

  it "rolls back the session when syntax verification fails" do
    session_id = "sess-safety-1"
    described_class.begin_session!(session_id, workspace: workspace)
    path = workspace.join("app/models/post.rb")
    path.dirname.mkpath
    path.write("class Post\nend\n")

    RailsAiBuild::Changes::Store.track_external(
      path: "app/models/post.rb",
      content: "class Post\nend\n",
      old_content: "",
      workspace: workspace,
      session_id: session_id
    )

    path.write("class Post\n")

    report = described_class.verify_after_turn!(workspace: workspace, session_id: session_id)
    expect(report[:healthy]).to eq(false)
    expect(report[:rolled_back]).to eq(true)
    expect(path).not_to exist
  end

  it "soft-previews boot-critical writes without applying" do
    result = RailsAiBuild::Changes::Store.record(
      path: "config/routes.rb",
      old_content: "Rails.application.routes.draw {}\n",
      new_content: "Rails.application.routes.draw { root 'x#y' }\n",
      workspace: workspace
    )
    expect(result[:status]).to eq("pending_approval")
    expect(result[:soft_preview]).to eq(true)
    expect(workspace.join("config/routes.rb")).not_to exist
  end
end
