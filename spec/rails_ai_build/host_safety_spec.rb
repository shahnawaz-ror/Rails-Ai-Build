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

  it "accepts valid Ruby" do
    expect(described_class.validate_write!("app/models/ok.rb", "class Ok\nend\n")).to eq(true)
  end

  it "rolls back the session when syntax verification fails" do
    session_id = "sess-safety-1"
    described_class.begin_session!(session_id)
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

    # Corrupt the file after tracking (simulates a bad applied write)
    path.write("class Post\n")

    report = described_class.verify_after_turn!(workspace: workspace, session_id: session_id)
    expect(report[:healthy]).to eq(false)
    expect(report[:rolled_back]).to eq(true)
    expect(path).not_to exist
  end

  it "skips boot ladder when only non-critical Ruby changed" do
    session_id = "sess-safety-2"
    described_class.begin_session!(session_id)
    RailsAiBuild.configuration.host_safety_boot_check = true

    path = workspace.join("app/services/hello.rb")
    path.dirname.mkpath
    path.write("class Hello\nend\n")
    RailsAiBuild::Changes::Store.track_external(
      path: "app/services/hello.rb",
      content: "class Hello\nend\n",
      old_content: "",
      workspace: workspace,
      session_id: session_id
    )

    report = described_class.verify_after_turn!(workspace: workspace, session_id: session_id)
    expect(report[:healthy]).to eq(true)
    expect(report[:checks].none? { |c| c[:name] == "boot" }).to eq(true)
  end
end
