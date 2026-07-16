# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe RailsAiBuild::Workspace::Paths do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  after { FileUtils.rm_rf(workspace) }

  it "rejects parent traversal" do
    expect do
      described_class.resolve(workspace, "../etc/passwd")
    end.to raise_error(RailsAiBuild::SecurityError)
  end

  it "rejects symlink escapes outside the workspace" do
    outside = Pathname.new(Dir.mktmpdir)
    secret = outside.join("secret.txt")
    secret.write("top-secret")
    link = workspace.join("escape")
    FileUtils.ln_s(outside.to_s, link.to_s)

    expect do
      described_class.resolve(workspace, "escape/secret.txt")
    end.to raise_error(RailsAiBuild::SecurityError, /symlink|escapes/i)
  ensure
    FileUtils.rm_rf(outside) if outside
  end

  it "blocks HTTP workspace overrides by default" do
    RailsAiBuild.reset_configuration!
    RailsAiBuild.configuration.workspace_root = workspace
    RailsAiBuild.configuration.allow_workspace_override = false

    expect do
      described_class.sanitize_request_workspace!("/tmp/other")
    end.to raise_error(RailsAiBuild::SecurityError, /override disabled/)
  end
end

