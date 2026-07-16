# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe RailsAiBuild::Tools::ReadLogsTool do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }
  let(:tool) { described_class.new(workspace: workspace) }

  before do
    workspace.join("log").mkpath
    workspace.join("log/development.log").write("one\ntwo\nthree\n")
    workspace.join("secret.txt").write("nope\n")
  end

  after { FileUtils.rm_rf(workspace) }

  it "tails an allowed log file" do
    result = tool.call("path" => "log/development.log", "lines" => 2)
    expect(result[:error]).to be_nil
    expect(result[:content]).to eq("two\nthree")
  end

  it "rejects paths outside log directories" do
    result = tool.call("path" => "secret.txt")
    expect(result[:error]).to match(/log/)
  end

  it "rejects path traversal" do
    result = tool.call("path" => "log/../secret.txt")
    expect(result[:error]).to match(/log/)
  end
end
