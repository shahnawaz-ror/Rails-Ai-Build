# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe RailsAiBuild::HostSafety::Ladder do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  before do
    RailsAiBuild.reset_configuration!
    RailsAiBuild.configuration.workspace_root = workspace
    RailsAiBuild.configuration.host_safety_boot_check = false
    RailsAiBuild.configuration.host_safety_zeitwerk_check = false
    RailsAiBuild.configuration.host_safety_smoke_routes = false
    RailsAiBuild.configuration.host_safety_bundle_check = true
  end

  after { FileUtils.rm_rf(workspace) }

  it "fails on syntax errors" do
    path = workspace.join("app/models/broken.rb")
    path.dirname.mkpath
    path.write("class Broken\n")

    report = described_class.run!(workspace: workspace, changed: ["app/models/broken.rb"])
    expect(report[:healthy]).to eq(false)
    expect(report[:failure_class]).to eq(:syntax)
  end

  it "runs bundle check when Gemfile changed" do
    workspace.join("Gemfile").write("source 'https://rubygems.org'\ngem 'no_such_gem_xyz_12345'\n")
    allow(described_class).to receive(:bundle_ok?).and_return(
      { name: "bundle", status: :error, message: "missing gems" }
    )

    report = described_class.run!(workspace: workspace, changed: ["Gemfile"])
    expect(report[:healthy]).to eq(false)
    expect(report[:failure_class]).to eq(:bundle)
  end
end
