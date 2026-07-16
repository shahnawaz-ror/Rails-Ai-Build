# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe RailsAiBuild::Tools::ShellTool do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }
  let(:tool) { described_class.new(workspace: workspace) }

  before do
    RailsAiBuild.reset_configuration!
    RailsAiBuild.configuration.shell_enabled = true
  end

  after { FileUtils.rm_rf(workspace) }

  it "blocks dangerous patterns" do
    expect { tool.call("command" => "rm -rf /") }.to raise_error(RailsAiBuild::SecurityError)
  end

  it "rejects non-allowlisted binaries" do
    expect { tool.call("command" => "nc -l 1234") }.to raise_error(RailsAiBuild::SecurityError, /allowlisted|blocked/i)
  end

  it "can be disabled entirely" do
    RailsAiBuild.configuration.shell_enabled = false
    expect { tool.call("command" => "ls") }.to raise_error(RailsAiBuild::SecurityError, /disabled/)
  end
end
