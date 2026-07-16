# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe RailsAiBuild::HostSafety::Shadow do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  before do
    RailsAiBuild.reset_configuration!
    RailsAiBuild.configuration.workspace_root = workspace
    RailsAiBuild.configuration.host_safety_shadow_worktree = true
    RailsAiBuild::Changes::Store.clear!
    # Minimal tree for copy mode (no git)
    workspace.join("app").mkpath
    workspace.join("app/models").mkpath
    workspace.join("README").write("hi")
  end

  after do
    described_class.cleanup!
    FileUtils.rm_rf(workspace)
  end

  it "isolates writes in a shadow copy and promotes on green" do
    shadow = described_class.prepare!("sess-shadow", workspace: workspace)
    expect(shadow.to_s).not_to eq(workspace.to_s)
    expect(shadow).to be_directory

    rel = "app/models/promo.rb"
    shadow.join(rel).dirname.mkpath
    shadow.join(rel).write("class Promo\nend\n")
    RailsAiBuild::Changes::Store.track_external(
      path: rel,
      content: "class Promo\nend\n",
      old_content: "",
      workspace: shadow,
      session_id: "sess-shadow"
    )

    result = described_class.promote!("sess-shadow")
    expect(result[:ok]).to eq(true)
    expect(workspace.join(rel)).to exist
    expect(workspace.join(rel).read).to include("Promo")
  end

  it "discards shadow without touching the host" do
    shadow = described_class.prepare!("sess-discard", workspace: workspace)
    shadow.join("app/models/gone.rb").write("class Gone\nend\n")
    RailsAiBuild::Changes::Store.track_external(
      path: "app/models/gone.rb",
      content: "class Gone\nend\n",
      old_content: "",
      workspace: shadow,
      session_id: "sess-discard"
    )

    described_class.discard!("sess-discard")
    expect(workspace.join("app/models/gone.rb")).not_to exist
  end
end
