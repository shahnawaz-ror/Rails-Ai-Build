# frozen_string_literal: true

require 'fileutils'

module RailsAiBuild
  # App-wide intelligence — heal host-app blockers before any AI build/chat run.
  # Not migration-only: prepares the workspace so the agent can build models,
  # controllers, routes, views, jobs, tests, or anything else in the Rails app.
  class Intelligence
    Check = Struct.new(:name, :status, :message, :action, keyword_init: true)

    WORKSPACE_DIRS = %w[tmp/cache tmp/pids log storage db/migrate].freeze

    class << self
      def prepare!(workspace: nil, on_event: nil, &block)
        on_event ||= block
        workspace ||= RailsAiBuild.configuration.workspace_path
        emit(on_event, :status, { phase: 'prepare', message: 'Preparing workspace for AI build…' })

        actions = []
        actions.concat(ensure_workspace_dirs!(workspace: workspace, on_event: on_event))
        actions.concat(heal_migrations!(workspace: workspace, on_event: on_event))
        checks = diagnose(workspace: workspace)

        emit(on_event, :status, {
               phase: 'ready',
               message: readiness_message(checks, actions),
               checks: checks.map(&:to_h),
               actions: actions
             })

        {
          healthy: checks.none? { |c| c.status == :error },
          checks: checks,
          actions: actions
        }
      end

      def diagnose(workspace: nil)
        workspace ||= RailsAiBuild.configuration.workspace_path
        [
          check_api_key,
          check_workspace(workspace),
          check_rails_app(workspace),
          check_migrations(workspace),
          check_initializer(workspace),
          check_engine_mount
        ]
      end

      private

      def ensure_workspace_dirs!(workspace:, on_event:)
        created = []
        WORKSPACE_DIRS.each do |rel|
          path = workspace.join(rel)
          next if path.directory?

          FileUtils.mkdir_p(path)
          created << rel
        end
        return [] if created.empty?

        emit(on_event, :status, {
               phase: 'heal',
               message: "Created missing dirs: #{created.join(', ')}"
             })
        created.map { |rel| { type: 'mkdir', path: rel } }
      rescue StandardError => e
        emit(on_event, :status, { phase: 'heal', message: "Workspace dirs skipped: #{e.message}" })
        []
      end

      def heal_migrations!(workspace:, on_event:)
        migrate_dir = workspace.join('db/migrate')
        report = RailsAiBuild::Migrations::Intelligence.diagnose(migrate_dir: migrate_dir)
        return [] if report[:healthy]

        emit(on_event, :status, {
               phase: 'heal',
               message: "Fixing migration conflicts (#{report[:message]})…"
             })

        healed = RailsAiBuild::Migrations::Intelligence.auto_heal!(migrate_dir: migrate_dir)
        healed[:healed].map do |h|
          {
            type: 'migration_rename',
            from: h[:from],
            to: h[:to],
            reason: h[:reason]
          }
        end
      rescue StandardError => e
        emit(on_event, :status, { phase: 'heal', message: "Migration heal skipped: #{e.message}" })
        []
      end

      def check_api_key
        providers = %i[nvidia openai anthropic].select { |p| RailsAiBuild.configuration.api_key_for(p).present? }
        if providers.any?
          Check.new(name: 'api_key', status: :ok, message: "API keys: #{providers.join(', ')}")
        else
          Check.new(
            name: 'api_key',
            status: :error,
            message: 'No API key set',
            action: 'export NVIDIA_API_KEY=nvapi-… or OPENAI_API_KEY / ANTHROPIC_API_KEY'
          )
        end
      end

      def check_workspace(workspace)
        if workspace.directory?
          Check.new(name: 'workspace', status: :ok, message: "Workspace: #{workspace}")
        else
          Check.new(name: 'workspace', status: :error, message: "Workspace missing: #{workspace}")
        end
      end

      def check_rails_app(workspace)
        markers = %w[config/application.rb config/routes.rb app]
        missing = markers.reject { |m| workspace.join(m).exist? }
        if missing.empty?
          Check.new(name: 'rails_app', status: :ok, message: 'Rails app structure detected')
        else
          Check.new(
            name: 'rails_app',
            status: :warning,
            message: "Missing Rails markers: #{missing.join(', ')}",
            action: 'Point workspace_root at a Rails app root'
          )
        end
      end

      def check_migrations(workspace)
        report = RailsAiBuild::Migrations::Intelligence.diagnose(migrate_dir: workspace.join('db/migrate'))
        if report[:healthy]
          Check.new(name: 'migrations', status: :ok, message: report[:message])
        else
          Check.new(
            name: 'migrations',
            status: :warning,
            message: report[:message],
            action: 'rails rails_ai_build:fix_migrations'
          )
        end
      end

      def check_initializer(workspace)
        path = workspace.join('config/initializers/rails_ai_build.rb')
        if path.exist?
          Check.new(name: 'initializer', status: :ok, message: 'Initializer present')
        else
          Check.new(
            name: 'initializer',
            status: :warning,
            message: 'Initializer missing',
            action: 'rails generate rails_ai_build:install'
          )
        end
      end

      def check_engine_mount
        return Check.new(name: 'engine', status: :ok, message: 'Engine loaded') unless defined?(Rails) && Rails.respond_to?(:application)

        routes = Rails.application.routes.routes.map do |route|
          route.path.spec.to_s
        rescue StandardError
          ''
        end
        mounted = routes.any? { |p| p.include?('rails_ai_build') }
        if mounted
          Check.new(name: 'engine', status: :ok, message: 'Engine mounted in routes')
        else
          Check.new(
            name: 'engine',
            status: :warning,
            message: 'Engine may not be mounted',
            action: "mount RailsAiBuild::Engine => '/rails_ai_build' in config/routes.rb"
          )
        end
      rescue StandardError => e
        Check.new(name: 'engine', status: :warning, message: "Could not inspect routes: #{e.message}")
      end

      def readiness_message(checks, actions)
        if actions.any?
          "Healed #{actions.size} issue(s); ready to build with AI"
        elsif checks.any? { |c| c.status == :error }
          'Blocked — fix errors before the agent can work'
        else
          'Workspace ready — ask the agent to build anything'
        end
      end

      def emit(on_event, event, data)
        on_event&.call(event, data)
      end
    end
  end
end
