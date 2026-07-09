# frozen_string_literal: true

module RailsAiBuild
  module Compatibility
    # Validates gem operations against Rails app structures
    # rubocop:disable Metrics/ClassLength
    class Checker
      Result = Struct.new(:repo, :slug, :status, :checks, :errors, :warnings, keyword_init: true)

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

          status = if errors.empty?
                     warnings.empty? ? :compatible : :compatible_with_warnings
                   else
                     :incompatible
                   end

          Result.new(
            repo: repo_config["name"],
            slug: repo_config["slug"],
            status: status,
            checks: checks.compact,
            errors: errors,
            warnings: warnings
          )
        end

        def check_all(catalog: nil, fixture_base: nil, mode: :full, workers: nil, slice: nil)
          catalog ||= resolve_catalog(mode: mode)
          catalog = apply_slice(catalog, slice) if slice
          fixture_base ||= default_fixture_base
          workers ||= ENV.fetch("COMPAT_WORKERS", "4").to_i

          if workers > 1 && catalog.size > 1
            check_all_parallel(catalog, fixture_base: fixture_base, workers: workers)
          else
            catalog.map { |repo| check_one(repo, fixture_base) }
          end
        end

        def summary(results)
          {
            total: results.size,
            compatible: results.count { |r| r.status == :compatible },
            with_warnings: results.count { |r| r.status == :compatible_with_warnings },
            incompatible: results.count { |r| r.status == :incompatible },
            by_archetype: results.group_by { |r| archetype_for(r) }.transform_values(&:size),
            by_check_failure: failure_counts(results),
            failed_repos: results.select { |r| r.status == :incompatible }.map { |r| r.slug || r.repo }
          }
        end

        private

        def resolve_catalog(mode:)
          case mode.to_sym
          when :smoke
            Catalog.smoke_representatives
          else
            Catalog.load
          end
        end

        def apply_slice(catalog, slice)
          index, total = slice.to_s.split("/").map(&:to_i)
          Catalog.slice(catalog, index: index, total: total)
        end

        def check_all_parallel(catalog, fixture_base:, workers:)
          queue = Queue.new
          catalog.each { |repo| queue << repo }
          workers.times { queue << :done }

          results = []
          mutex = Mutex.new
          threads = Array.new(workers) do
            Thread.new do
              loop do
                repo = queue.pop
                break if repo == :done

                result = check_one(repo, fixture_base)
                mutex.synchronize { results << result }
              end
            end
          end
          threads.each(&:join)
          catalog.map { |repo| results.find { |r| r.slug == repo["slug"] } }
        end

        def check_one(repo, fixture_base)
          workspace = fixture_for(repo, fixture_base)
          workspace.mkpath
          scaffold_fixture(workspace, repo)
          check_repo(repo, workspace: workspace)
        end

        def archetype_for(result)
          result.checks.find { |c| c[:name] == "archetype" }&.dig(:value) || "unknown"
        end

        def failure_counts(results)
          counts = Hash.new(0)
          results.each do |result|
            result.checks.each do |check|
              counts[check[:name]] += 1 if check[:status] == :fail
            end
          end
          counts
        end

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
          %w[read_file list_files grep write_file].each do |tool_name|
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
          when "write_file" then { "path" => "compat_test.rb", "content" => "# compat\n" }
          else {}
          end
        end
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
