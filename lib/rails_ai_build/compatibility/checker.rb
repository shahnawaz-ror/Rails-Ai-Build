# frozen_string_literal: true

module RailsAiBuild
  module Compatibility
    # Validates gem operations against Rails app structures
    class Checker
      Result = Struct.new(:repo, :status, :checks, :errors, :warnings, keyword_init: true)

      class << self
        def check_repo(repo_config, workspace:)
          errors = []
          warnings = []
          checks = []

          checks << check_rails_version(repo_config, errors, warnings)
          checks << check_structure(repo_config, workspace, errors, warnings)
          checks << check_gem_install(workspace, errors, warnings)
          checks << check_agent_boot(errors)
          checks << check_tools(workspace, errors, warnings)
          checks << check_edge_cases(workspace, errors, warnings)

          status = errors.empty? ? (warnings.empty? ? :compatible : :compatible_with_warnings) : :incompatible

          Result.new(
            repo: repo_config["name"],
            status: status,
            checks: checks.compact,
            errors: errors,
            warnings: warnings
          )
        end

        def check_all(catalog: nil, fixture_base: nil)
          catalog ||= Catalog.load
          fixture_base ||= default_fixture_base

          catalog.map do |repo|
            workspace = fixture_for(repo, fixture_base)
            workspace.mkpath
            scaffold_fixture(workspace, repo)
            check_repo(repo, workspace: workspace)
          end
        end

        def summary(results)
          {
            total: results.size,
            compatible: results.count { |r| r.status == :compatible },
            with_warnings: results.count { |r| r.status == :compatible_with_warnings },
            incompatible: results.count { |r| r.status == :incompatible },
            by_archetype: results.group_by { |r| r.checks.find { |c| c[:name] == "archetype" }&.dig(:value) }
                                 .transform_values(&:size)
          }
        end

        private

        def default_fixture_base
          Pathname.new(Dir.mktmpdir("rails_ai_build_compat_"))
        end

        def fixture_for(repo, base)
          slug = repo["slug"] || repo["name"].to_s.downcase.gsub(/[^a-z0-9]+/, "-")
          base.join(slug)
        end

        def scaffold_fixture(workspace, repo)
          archetype = (repo["archetype"] || "full_stack").to_s
          writer = {
            "full_stack" => Fixtures::FullStack,
            "api_only" => Fixtures::ApiOnly,
            "engine" => Fixtures::Engine,
            "legacy" => Fixtures::Legacy,
            "monolith" => Fixtures::Monolith
          }[archetype] || Fixtures::FullStack
          writer.call(workspace, repo)
        end

        def check_rails_version(repo, errors, warnings)
          min = repo["rails_min"] || "6.0"
          version = repo["rails_version"] || "7.1"
          if Gem::Version.new(version) < Gem::Version.new(min)
            errors << "Rails #{version} below minimum #{min}"
          end
          { name: "rails_version", status: :ok, value: version }
        end

        def check_structure(repo, workspace, errors, warnings)
          archetype = repo["archetype"] || "full_stack"
          required = repo["requires"] || %w[app config Gemfile]
          missing = required.reject { |p| workspace.join(p).exist? }
          errors << "Missing: #{missing.join(', ')}" if missing.any?
          { name: "archetype", status: missing.empty? ? :ok : :fail, value: archetype }
        end

        def check_gem_install(workspace, errors, warnings)
          RailsAiBuild.reset_configuration!
          RailsAiBuild.configuration.workspace_root = workspace
          Models::Registry.register_defaults
          { name: "gem_boot", status: :ok }
        rescue StandardError => e
          errors << "Gem boot failed: #{e.message}"
          { name: "gem_boot", status: :fail }
        end

        def check_agent_boot(errors)
          agent = Agents::Agent.new
          agent.tool_definitions
          { name: "agent", status: :ok, tools: agent.tool_definitions.size }
        rescue StandardError => e
          errors << "Agent boot failed: #{e.message}"
          { name: "agent", status: :fail }
        end

        def check_tools(workspace, errors, warnings)
          results = {}
          %w[read_file list_files grep].each do |tool_name|
            result = Tools::Registry.execute(tool_name, tool_args(tool_name, workspace), workspace: workspace)
            results[tool_name] = result.key?(:error) ? :fail : :ok
            warnings << "Tool #{tool_name}: #{result[:error]}" if result[:error]
          end
          { name: "tools", status: results.value?(:fail) ? :warning : :ok, results: results }
        end

        def check_edge_cases(workspace, errors, warnings)
          cases = EdgeCases.run(workspace)
          warnings.concat(cases[:warnings])
          errors.concat(cases[:errors])
          { name: "edge_cases", status: cases[:errors].empty? ? :ok : :fail, passed: cases[:passed] }
        end

        def tool_args(tool_name, workspace)
          case tool_name
          when "read_file" then { "path" => "Gemfile" }
          when "list_files" then { "path" => ".", "max_results" => 10 }
          when "grep" then { "pattern" => "rails", "path" => "." }
          else {}
          end
        end
      end
    end
  end
end
