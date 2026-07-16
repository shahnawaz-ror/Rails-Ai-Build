# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe RailsAiBuild::Tools::ReadFileTool do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }
  let(:tool) { described_class.new(workspace: workspace) }

  after { FileUtils.rm_rf(workspace) }

  it "reads a file with line numbers" do
    workspace.join("app").mkpath
    workspace.join("app/hi.rb").write("a\nb\nc\n")
    result = tool.call("path" => "app/hi.rb", "limit" => 2)
    expect(result[:error]).to be_nil
    expect(result[:content]).to include("1|a")
    expect(result[:truncated]).to be true
  end

  it "rejects oversized files" do
    workspace.join("big.bin").write("x" * (described_class::MAX_FILE_BYTES + 1))
    result = tool.call("path" => "big.bin")
    expect(result[:error]).to match(/too large/i)
  end
end
