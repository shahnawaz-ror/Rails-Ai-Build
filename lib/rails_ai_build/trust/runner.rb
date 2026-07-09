# frozen_string_literal: true

require 'json'
require 'fileutils'

module RailsAiBuild
  module Trust
    # Live NVIDIA-powered change tests across real Rails app archetypes.
    class Runner
      AppResult = Struct.new(
        :slug, :name, :archetype, :rails_version, :stars, :github,
        :passed, :marker_path, :duration_ms, :error, :model_response,
        keyword_init: true
      ) do
        def to_h
          {
            slug: slug,
            name: name,
            archetype: archetype,
            rails_version: rails_version,
            stars: stars,
            github: github,
            passed: passed,
            marker_path: marker_path,
            duration_ms: duration_ms,
            error: error,
            model_response: model_response&.to_s&.[](0, 200)
          }.compact
        end
      end

      class << self
        def run!(apps: nil, provider: :nvidia, model: nil, workspace_base: nil)
          apps ||= CatalogSample.apps(count: 20)
          workspace_base ||= Pathname.new(Dir.mktmpdir('rails_ai_build_trust_'))
          started = Time.now.utc
          results = apps.each_with_index.map do |repo, index|
            sleep(1) if index.positive?
            run_one(repo, workspace_base: workspace_base, provider: provider, model: model)
          end
          report = build_report(results, started: started, provider: provider, model: model)
          Report.write!(report)
          report
        ensure
          FileUtils.rm_rf(workspace_base) if workspace_base&.to_s&.include?('rails_ai_build_trust_')
        end

        private

        def run_one(repo, workspace_base:, provider:, model:)
          attempts = 0
          begin
            attempts += 1
            execute_trust_test(repo, workspace_base: workspace_base, provider: provider, model: model)
          rescue StandardError => e
            raise unless e.message.include?('429') && attempts < 3

            sleep(attempts * 2)
            retry
          end
        end

        def execute_trust_test(repo, workspace_base:, provider:, model:)
          workspace = workspace_base.join(repo['slug'].to_s)
          workspace.mkpath
          scaffold!(workspace, repo)
          configure_live!(workspace, provider: provider, model: model)

          marker = "trust/#{repo['slug']}_verified.txt"
          prompt = <<~PROMPT
            Use write_file exactly once to create #{marker}
            with this exact content on one line: TRUST_OK
            Then stop. Do not create any other files.
          PROMPT

          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          response = Ai::Driver.run(prompt)
          elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

          target = workspace.join(marker)
          passed = target.exist? && target.read.include?('TRUST_OK')

          AppResult.new(
            slug: repo['slug'],
            name: repo['name'],
            archetype: repo['archetype'],
            rails_version: repo['rails_version'],
            stars: repo['stars'],
            github: repo['github'],
            passed: passed,
            marker_path: marker,
            duration_ms: elapsed,
            model_response: response.content,
            error: passed ? nil : 'Marker file missing or invalid'
          )
        rescue StandardError => e
          raise e if e.message.include?('429')

          AppResult.new(
            slug: repo['slug'],
            name: repo['name'],
            archetype: repo['archetype'],
            rails_version: repo['rails_version'],
            stars: repo['stars'],
            github: repo['github'],
            passed: false,
            marker_path: nil,
            duration_ms: 0,
            error: e.message
          )
        end

        def scaffold!(workspace, repo)
          Scaffold.call(workspace, repo)
        end

        def configure_live!(workspace, provider:, model:)
          RailsAiBuild.reset_configuration!
          RailsAiBuild.configure do |c|
            c.api_keys[:nvidia] = ENV.fetch('NVIDIA_API_KEY')
            c.default_provider = provider
            c.default_model = model || ENV.fetch('NVIDIA_MODEL', 'meta/llama-3.1-8b-instruct')
            c.workspace_root = workspace
            c.diff_preview = false
            c.verify_builds = false
            c.universal_builder = false
            c.allowed_tools = %i[write_file read_file list_files]
            c.max_agent_iterations = 6
          end
          RailsAiBuild::Changes::Store.clear!
          RailsAiBuild::Models::Registry.register_defaults
        end

        def build_report(results, started:, provider:, model:)
          passed = results.count(&:passed)
          {
            generated_at: Time.now.utc.iso8601,
            provider: provider.to_s,
            model: model || ENV.fetch('NVIDIA_MODEL', 'meta/llama-3.1-8b-instruct'),
            total: results.size,
            passed: passed,
            failed: results.size - passed,
            pass_rate: results.empty? ? 0 : (passed.to_f / results.size).round(4),
            duration_seconds: (Time.now.utc - started).round(1),
            live: true,
            dashboard: Report.dashboard_url,
            live_api: Report.live_api_url,
            apps: results.map(&:to_h)
          }
        end
      end
    end
  end
end
