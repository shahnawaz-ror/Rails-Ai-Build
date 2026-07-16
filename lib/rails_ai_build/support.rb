# frozen_string_literal: true

module RailsAiBuild
  module Support
    class Doctor
      Check = Struct.new(:name, :status, :message, :fix, keyword_init: true)

      class << self
        def check(workspace: nil)
          workspace ||= safe_workspace
          checks = [
            check_api_keys,
            check_workspace(workspace),
            check_rails_version,
            check_gemfile(workspace),
            check_migrations(workspace),
            check_providers,
            check_tools(workspace),
            check_plan_features,
            check_upgrade(workspace),
            check_disk_space(workspace)
          ]
          {
            status: checks.all? { |c| c.status == :ok } ? :healthy : :issues_found,
            checks: checks.map(&:to_h),
            version: RailsAiBuild::VERSION,
            plan: RailsAiBuild.configuration.plan
          }
        end

        private

        def safe_workspace
          RailsAiBuild.configuration.workspace_path
        rescue StandardError
          Pathname.pwd
        end

        def check_api_keys
          openai = RailsAiBuild.configuration.api_key_for(:openai)
          anthropic = RailsAiBuild.configuration.api_key_for(:anthropic)
          nvidia = RailsAiBuild.configuration.api_key_for(:nvidia)
          cloud = RailsAiBuild.configuration.cloud_api_key

          configured = [
            openai.present? && "openai",
            anthropic.present? && "anthropic",
            nvidia.present? && "nvidia",
            cloud.present? && "cloud"
          ].compact

          if configured.any?
            ok("api_keys", "API key configured (#{configured.join(', ')})")
          else
            warn("api_keys", "No API keys set",
                 "export NVIDIA_API_KEY=nvapi-... (build.nvidia.com) or OPENAI_API_KEY / ANTHROPIC_API_KEY")
          end
        end

        def check_workspace(workspace)
          if workspace.directory?
            ok("workspace", "Workspace accessible: #{workspace}")
          else
            error("workspace", "Workspace not found: #{workspace}", "Set config.workspace_root in initializer")
          end
        end

        def check_rails_version
          if defined?(Rails)
            ok("rails", "Rails #{Rails.version} detected")
          else
            warn("rails", "Rails not loaded (standalone mode)", "Mount engine in a Rails app for full features")
          end
        end

        def check_gemfile(workspace)
          gemfile = workspace.join("Gemfile")
          if gemfile.exist? && gemfile.read.include?("rails_ai_build")
            ok("gemfile", "rails_ai_build in Gemfile")
          elsif gemfile.exist?
            warn("gemfile", "Gemfile found but rails_ai_build not listed", "Add gem \"rails_ai_build\" to Gemfile")
          else
            warn("gemfile", "No Gemfile (standalone mode)")
          end
        end

        def check_providers
          Models::Registry.register_defaults
          providers = Models::Registry.registered_providers
          ok("providers", "#{providers.size} providers registered: #{providers.join(', ')}")
        rescue StandardError => e
          error("providers", e.message)
        end

        def check_tools(workspace)
          tools = Tools::Registry.definitions
          ok("tools", "#{tools.size} tools available: #{tools.map { |t| t[:name] }.join(', ')}")
        rescue StandardError => e
          error("tools", e.message)
        end

        def check_migrations(workspace)
          dir = workspace.join('db/migrate')
          report = Migrations::Intelligence.diagnose(migrate_dir: dir)
          if report[:healthy]
            ok('migrations', report[:message])
          else
            error('migrations', report[:message],
                  'rails rails_ai_build:fix_migrations')
          end
        end

        def check_plan_features
          plan = Plans.current
          ok("plan", "#{plan[:name]} plan — #{plan[:features].size} features")
        end

        def check_upgrade(workspace)
          info = Upgrade.status(workspace: workspace)
          if info[:installed_version].nil?
            warn("upgrade", "Version not stamped in initializer",
                 "Run: rails generate rails_ai_build:upgrade")
          elsif info[:needs_upgrade]
            warn("upgrade", "Upgrade available: #{info[:installed_version]} → #{info[:current_version]}",
                 "bundle update rails_ai_build && rails generate rails_ai_build:upgrade")
          else
            ok("upgrade", "On latest version #{info[:current_version]}")
          end
        end

        def check_disk_space(workspace)
          stat = File.stat(workspace.to_s)
          ok("permissions", "Workspace readable/writable")
        rescue StandardError => e
          error("permissions", e.message, "Check directory permissions")
        end

        def ok(name, message)
          Check.new(name: name, status: :ok, message: message)
        end

        def warn(name, message, fix = nil)
          Check.new(name: name, status: :warning, message: message, fix: fix)
        end

        def error(name, message, fix = nil)
          Check.new(name: name, status: :error, message: message, fix: fix)
        end
      end
    end

    module Help
      TOPICS = {
        "getting-started" => {
          title: "Getting Started",
          content: <<~HELP
            1. Add gem "rails_ai_build" to Gemfile
            2. bundle install
            3. rails generate rails_ai_build:install
            4. rails db:migrate
            5. export OPENAI_API_KEY=sk-...
            6. rails rails_ai_build:setup
          HELP
        },
        "api-keys" => {
          title: "API Keys",
          content: <<~HELP
            Set via environment variables (any one is enough):
              NVIDIA_API_KEY=nvapi-...          # free key: https://build.nvidia.com
              NVIDIA_MODEL=meta/llama-3.1-8b-instruct
              OPENAI_API_KEY=sk-...
              ANTHROPIC_API_KEY=sk-ant-...

            Or in config/initializers/rails_ai_build.rb:
              config.api_keys[:nvidia] = ENV["NVIDIA_API_KEY"]
              config.default_provider = :nvidia

            When NVIDIA_API_KEY starts with nvapi-, the install initializer
            selects :nvidia automatically.
          HELP
        },
        "skills" => {
          title: "Skill Packs",
          content: <<~HELP
            rails rails_ai_build:skill[crud,"Create a Post resource"]
            rails rails_ai_build:skill[auth,"Add login"]
            rails rails_ai_build:skill[api,"Build JSON API"]
            rails rails_ai_build:skill[tests,"Write RSpec tests"]
            rails rails_ai_build:skill[refactor,"Extract service object"]
          HELP
        },
        "diff-preview" => {
          title: "Diff Preview (Pro+)",
          content: <<~HELP
            Enable in initializer:
              config.plan = :pro
              config.diff_preview = true

            Changes queue for approval:
              rails rails_ai_build:pending
              rails rails_ai_build:apply
          HELP
        },
        "troubleshooting" => {
          title: "Troubleshooting",
          content: <<~HELP
            Run diagnostics:
              rails rails_ai_build:doctor

            Common fixes:
            - "API key missing" → set OPENAI_API_KEY
            - "Max iterations exceeded" → increase config.max_agent_iterations
            - "Path escapes workspace" → use relative paths only
            - "Feature requires higher plan" → upgrade or set config.plan

            Support: https://github.com/shahnawaz-ror/Rails-Ai-Build/issues
          HELP
        },
        "analytics" => {
          title: "Analytics & Token Usage",
          content: <<~HELP
            Token usage tracked automatically on all plans.
            View summary:
              rails rails_ai_build:stats

            API: GET /rails_ai_build/analytics
            Detailed dashboards require Team plan.
          HELP
        },
        "web-ui" => {
          title: "Web UI & Live Demo",
          content: <<~HELP
            After install, open in browser:
              http://localhost:3000/rails_ai_build/ui          — dashboard (chat, changes)
              http://localhost:3000/rails_ai_build/ui/demo     — live SSE demo (no API key)

            Real-time streaming:
              POST /rails_ai_build/stream

            Full guide: docs/WEB_UI.md
          HELP
        },
        "upgrade" => {
          title: "Upgrade rails_ai_build",
          content: <<~HELP
            Check status:
              rails rails_ai_build:upgrade

            Typical upgrade path:
              1. bundle update rails_ai_build
              2. rails generate rails_ai_build:upgrade
              3. rails db:migrate
              4. rails rails_ai_build:doctor

            The upgrade generator stamps your initializer with the installed version.
            Chat install → upgrade: same flow works from any version.
          HELP
        }
      }.freeze

      class << self
        def topics
          TOPICS.map { |id, t| { id: id, title: t[:title] } }
        end

        def topic(id)
          TOPICS[id.to_s] || raise(ConfigurationError, "Unknown help topic: #{id}")
        end

        def all_content
          TOPICS
        end
      end
    end

    module Settings
      class << self
        def current
          config = RailsAiBuild.configuration
          {
            version: RailsAiBuild::VERSION,
            plan: config.plan,
            default_provider: config.default_provider,
            default_model: config.default_model,
            diff_preview: config.diff_preview,
            audit_enabled: config.audit_enabled,
            rbac_enabled: config.rbac_enabled,
            max_iterations: config.max_agent_iterations,
            allowed_tools: config.allowed_tools,
            auto_mount: config.auto_mount,
            features: Plans.current[:features],
            limits: Plans.current[:limits],
            api_keys_configured: {
              openai: config.api_key_for(:openai).present?,
              anthropic: config.api_key_for(:anthropic).present?,
              cloud: config.cloud_api_key.present?
            }
          }
        end

        def update(params)
          normalized = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
          normalized = normalized.transform_keys(&:to_sym)

          allowed = %i[plan default_provider default_model diff_preview audit_enabled
                       max_agent_iterations auto_mount]
          RailsAiBuild.configure do |c|
            allowed.each do |key|
              c.send("#{key}=", normalized[key]) if normalized.key?(key)
            end
          end
          current
        end
      end
    end
  end
end
