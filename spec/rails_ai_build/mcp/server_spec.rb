# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiBuild::Mcp::Server do
  it "handles initialize" do
    response = described_class.handle("method" => "initialize", "id" => 1)
    expect(response[:result][:serverInfo][:name]).to eq("rails_ai_build")
  end

  it "lists tools" do
    response = described_class.handle("method" => "tools/list", "id" => 2)
    tools = response[:result][:tools]
    expect(tools.map { |t| t[:name] }).to include("read_file", "write_file")
  end

  it "calls a tool" do
    workspace = Pathname.new(Dir.mktmpdir)
    workspace.join("test.rb").write("# test\n")
    RailsAiBuild.configuration.workspace_root = workspace

    response = described_class.handle(
      "method" => "tools/call",
      "id" => 3,
      "params" => { "name" => "read_file", "arguments" => { "path" => "test.rb" } }
    )
    expect(response[:result][:isError]).to be false
    FileUtils.rm_rf(workspace)
  end
end
