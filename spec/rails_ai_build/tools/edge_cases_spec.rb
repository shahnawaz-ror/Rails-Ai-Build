# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "Tool edge cases" do
  let(:workspace) { Pathname.new(Dir.mktmpdir) }

  after { FileUtils.rm_rf(workspace) }

  describe RailsAiBuild::Tools::ReadFileTool do
    it "handles empty files" do
      workspace.join("empty.rb").write("")
      tool = described_class.new(workspace: workspace)
      result = tool.call("path" => "empty.rb")
      expect(result[:total_lines]).to eq(0)
    end

    it "handles unicode content" do
      workspace.join("uni.rb").write("# café 日本語\n")
      tool = described_class.new(workspace: workspace)
      result = tool.call("path" => "uni.rb")
      expect(result[:content]).to include("café")
    end

    it "respects offset and limit" do
      workspace.join("lines.rb").write((1..20).map { |i| "line #{i}" }.join("\n"))
      tool = described_class.new(workspace: workspace)
      result = tool.call("path" => "lines.rb", "offset" => 5, "limit" => 3)
      expect(result[:content]).to include("5|line 5")
      expect(result[:content].lines.count).to eq(3)
    end
  end

  describe RailsAiBuild::Tools::GrepTool do
    it "returns empty matches for no results" do
      workspace.join("test.rb").write("hello world\n")
      tool = described_class.new(workspace: workspace)
      result = tool.call("pattern" => "zzznomatch")
      expect(result[:count]).to eq(0)
    end
  end

  describe RailsAiBuild::Tools::ShellTool do
    it "blocks dangerous commands" do
      tool = described_class.new(workspace: workspace)
      expect { tool.call("command" => "rm -rf /") }
        .to raise_error(RailsAiBuild::SecurityError, /blocked/)
    end
  end
end
