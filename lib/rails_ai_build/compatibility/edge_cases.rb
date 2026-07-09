# frozen_string_literal: true

module RailsAiBuild
  module Compatibility
    module EdgeCases
      class << self
        def run(workspace)
          passed = 0
          warnings = []
          errors = []

          tests = [
            -> { test_empty_file(workspace) },
            -> { test_nested_paths(workspace) },
            -> { test_unicode_content(workspace) },
            -> { test_large_file_truncation(workspace) },
            -> { test_path_traversal_blocked(workspace) },
            -> { test_missing_file_read(workspace) },
            -> { test_binary_file_skip(workspace) },
            -> { test_special_chars_filename(workspace) }
          ]

          tests.each do |test|
            result = test.call
            passed += 1 if result[:ok]
            warnings.concat(result[:warnings] || [])
            errors.concat(result[:errors] || [])
          rescue StandardError => e
            errors << e.message
          end

          { passed: passed, total: tests.size, warnings: warnings, errors: errors }
        end

        private

        def test_empty_file(workspace)
          path = workspace.join("empty.rb")
          path.write("")
          tool = Tools::ReadFileTool.new(workspace: workspace)
          result = tool.call("path" => "empty.rb")
          { ok: result[:total_lines].zero?, warnings: [] }
        end

        def test_nested_paths(workspace)
          path = workspace.join("app/deep/nested/file.rb")
          path.dirname.mkpath
          path.write("# nested\n")
          tool = Tools::WriteFileTool.new(workspace: workspace)
          result = tool.call("path" => "app/deep/nested/file.rb", "content" => "# updated\n")
          { ok: result[:status] == "written" }
        end

        def test_unicode_content(workspace)
          tool = Tools::WriteFileTool.new(workspace: workspace)
          tool.call("path" => "unicode.rb", "content" => "# café 日本語 🚀\n")
          read = Tools::ReadFileTool.new(workspace: workspace).call("path" => "unicode.rb")
          { ok: read[:content].include?("café") }
        end

        def test_large_file_truncation(workspace)
          lines = (1..500).map { |i| "line #{i}" }.join("\n")
          workspace.join("large.rb").write(lines)
          tool = Tools::ReadFileTool.new(workspace: workspace)
          result = tool.call("path" => "large.rb", "limit" => 10)
          { ok: result[:content].lines.count <= 10 }
        end

        def test_path_traversal_blocked(workspace)
          tool = Tools::ReadFileTool.new(workspace: workspace)
          tool.call("path" => "../../../etc/passwd")
          { ok: false, errors: ["Should have raised SecurityError"] }
        rescue SecurityError
          { ok: true }
        end

        def test_missing_file_read(workspace)
          tool = Tools::ReadFileTool.new(workspace: workspace)
          result = tool.call("path" => "nonexistent.rb")
          { ok: result.key?(:error) }
        end

        def test_binary_file_skip(workspace)
          File.binwrite(workspace.join("binary.dat"), "\x00\x01\x02\xFF")
          result = Tools::Registry.execute("grep", { "pattern" => "rails", "path" => "binary.dat" }, workspace: workspace)
          { ok: !result.key?(:error), warnings: result[:error] ? [result[:error]] : [] }
        end

        def test_special_chars_filename(workspace)
          tool = Tools::WriteFileTool.new(workspace: workspace)
          tool.call("path" => "app/my-feature_v2.rb", "content" => "# ok\n")
          { ok: workspace.join("app/my-feature_v2.rb").exist? }
        end
      end
    end
  end
end
