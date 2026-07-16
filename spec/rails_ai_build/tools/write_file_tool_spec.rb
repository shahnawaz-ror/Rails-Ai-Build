# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe RailsAiBuild::Tools::WriteFileTool do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }
  let(:tool) { described_class.new(workspace: workspace) }

  after { FileUtils.rm_rf(workspace) }

  before { RailsAiBuild::Changes::Store.clear! }

  it "writes a new file" do
    result = tool.call("path" => "app/services/hello.rb", "content" => "class Hello\nend\n")
    expect(result[:status]).to eq("written")
    expect(workspace.join("app/services/hello.rb")).to exist
  end

  it "rejects invalid Ruby instead of writing" do
    result = tool.call("path" => "app/services/broken.rb", "content" => "class Broken\n")
    expect(result[:syntax_rejected]).to eq(true)
    expect(workspace.join("app/services/broken.rb")).not_to exist
  end
end

