# frozen_string_literal: true

require 'json'
require 'fileutils'

module RailsAiBuild
  module Trust
    # 20 live preview sandboxes — each catalog app with rails_ai_build configured.
    class AppSandbox
      class << self
        def base_url
          Report.live_api_url.chomp('/')
        end

        def root
          @root ||= Pathname.new(ENV.fetch('TRUST_APPS_ROOT', File.expand_path('../../../trust-apps', __dir__)))
        end

        def apps
          CatalogSample.apps(count: 20)
        end

        def manifest
          apps.map { |repo| entry_for(repo) }
        end

        def preview_url(slug)
          "#{base_url}/apps/#{slug}"
        end

        def find(slug)
          apps.find { |r| r['slug'] == slug.to_s }
        end

        def workspace_for(slug)
          repo = find(slug)
          raise ArgumentError, "Unknown app: #{slug}" unless repo

          path = root.join(slug.to_s)
          Scaffold.call(path, repo) unless path.join('Gemfile').exist?
          path
        end

        def info(slug)
          repo = find(slug)
          return nil unless repo

          workspace = workspace_for(slug)
          entry = entry_for(repo)
          entry.merge(
            files: list_files(workspace),
            gem_configured: workspace.join('config/initializers/rails_ai_build.rb').exist?,
            trust_marker: workspace.join("trust/#{slug}_verified.txt").exist?
          )
        end

        def run_change(slug, message)
          repo = find(slug)
          raise ArgumentError, "Unknown app: #{slug}" unless repo

          workspace = workspace_for(slug)
          configure_nvidia!(workspace)

          prompt = message.to_s.strip
          prompt = default_prompt(repo) if prompt.empty?

          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = Ai::Driver.run(prompt)
          elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

          {
            slug: slug,
            name: repo['name'],
            preview_url: preview_url(slug),
            duration_ms: elapsed,
            content: result.content,
            pending_changes: Changes::Store.all(status: :pending).map(&:to_h),
            files: list_files(workspace)
          }
        end

        def preview_html(slug)
          repo = find(slug)
          return nil unless repo

          workspace_for(slug)
          File.read(preview_template).gsub('__SLUG__', slug).gsub('__NAME__', repo['name'].to_s)
              .gsub('__ARCHETYPE__', repo['archetype'].to_s)
              .gsub('__RAILS__', repo['rails_version'].to_s)
              .gsub('__GITHUB__', repo['github'].to_s)
              .gsub('__BASE__', base_url)
        end

        def write_manifest!
          path = File.expand_path('../../../landing/trust/apps.json', __dir__)
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, JSON.pretty_generate({
                                                  generated_at: Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
                                                  base_url: base_url,
                                                  total: manifest.size,
                                                  apps: manifest
                                                }))
        end

        private

        def entry_for(repo)
          {
            slug: repo['slug'],
            name: repo['name'],
            archetype: repo['archetype'],
            rails_version: repo['rails_version'],
            stars: repo['stars'],
            github: repo['github'],
            preview_url: preview_url(repo['slug']),
            api_run_url: "#{base_url}/apps/#{repo['slug']}/run",
            api_info_url: "#{base_url}/apps/#{repo['slug']}.json"
          }
        end

        def list_files(workspace, max: 30)
          entries = Dir.glob(workspace.join('**', '*')).select { |f| File.file?(f) }.first(max).map do |f|
            path = Pathname.new(f)
            rel = path.relative_path_from(workspace).to_s
            { path: rel, size: path.size }
          end
          entries.sort_by { |h| h[:path] }
        end

        def default_prompt(repo)
          <<~PROMPT
            Add a small improvement to this #{repo['archetype']} Rails app (#{repo['name']}).
            Use write_file once to create app/services/ai_preview.rb with a short comment describing the change.
          PROMPT
        end

        def configure_nvidia!(workspace)
          RailsAiBuild.reset_configuration!
          RailsAiBuild.configure do |c|
            c.api_keys[:nvidia] = ENV.fetch('NVIDIA_API_KEY', '')
            c.default_provider = :nvidia
            c.default_model = ENV.fetch('NVIDIA_MODEL', 'meta/llama-3.1-8b-instruct')
            c.workspace_root = workspace
            c.diff_preview = false
            c.verify_builds = false
            c.universal_builder = true
            c.allowed_tools = %i[write_file read_file list_files grep]
            c.max_agent_iterations = 8
          end
          Changes::Store.clear!
          Models::Registry.register_defaults
        end

        def preview_template
          File.expand_path('../../../server/public/apps/preview.html', __dir__)
        end
      end
    end
  end
end
