# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe RailsAiBuild::Tools::GrepTool do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }
  let(:tool) { described_class.new(workspace: workspace) }

  before do
    workspace.join("app").mkpath
    workspace.join("app/user.rb").write("class User; end\n")
  end

  after { FileUtils.rm_rf(workspace) }

  it "rejects glob traversal" do
    expect { tool.call("pattern" => "User", "glob" => "../**/*") }
      .to raise_error(RailsAiBuild::SecurityError, /\.\./)
  end

  it "rejects oversized patterns" do
    expect { tool.call("pattern" => "a" * (described_class::MAX_PATTERN_BYTES + 1)) }
      .to raise_error(RailsAiBuild::SecurityError, /too long/)
  end

  it "finds matches inside the workspace" do
    result = tool.call("pattern" => "User", "path" => "app")
    expect(result[:count]).to be >= 1
  end
end
