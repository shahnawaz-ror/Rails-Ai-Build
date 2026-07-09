# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe RailsAiBuild::Tools::ReadFileTool do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }
  let(:tool) { described_class.new(workspace: workspace) }

  before do
    workspace.join("app/models/user.rb").dirname.mkpath
    workspace.join("app/models/user.rb").write("class User\nend\n")
  end

  after { FileUtils.rm_rf(workspace) }

  it "reads a file with line numbers" do
    result = tool.call("path" => "app/models/user.rb")
    expect(result[:content]).to include("1|class User")
    expect(result[:total_lines]).to eq(2)
  end

  it "rejects paths outside workspace" do
    expect { tool.call("path" => "../../../etc/passwd") }.to raise_error(RailsAiBuild::SecurityError)
  end
end
