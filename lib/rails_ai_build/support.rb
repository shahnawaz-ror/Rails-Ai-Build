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
            check_activation,
            check_encryption,
            check_workspace(workspace),
            check_rails_version,
            check_gemfile(workspace),
            check_migrations(workspace),
            check_providers,
            check_tools(workspace),
            check_host_safety,
            check_ssrf,
            check_engine_auth,
            check_plan_features,
            check_upgrade(workspace),
            check_disk_space(workspace)
          ]
          {
            status: checks.all? { |c| c.status == :ok } ? :healthy : :issues_found,
            checks: checks.map(&:to_h),
            version: RailsAiBuild::VERSION,
            plan: RailsAiBuild.configuration.plan,
            activation: Activation.status
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
                 "Open the IDE wizard or POST /settings/keys with openai/anthropic/nvidia/cloud_api_key")
          end
        end

        def check_activation
          status = Activation.status
          if status[:activated]
            source = status[:entitlement_source]
            ok("activation", "Activated (#{status[:providers].join(', ')}; entitlement: #{source})")
          elsif status[:needs_wizard]
            warn("activation", "First-run wizard incomplete",
                 "Open /rails_ai_build/ui/ide and complete BYOK, Cloud key, or License setup")
          else
            warn("activation", "No keys or license yet",
                 "POST /settings/keys or POST /settings/license")
          end
        end

        def check_encryption
          if Secrets::Encryptor.available?
            if Activation.table_ready?
              ok("encryption", "Secret encryption + durable activation store ready")
            else
              warn("encryption", "Encryption ready but activation table missing",
                   "rails db:migrate")
            end
          else
            warn("encryption", "No secret_key_base / RAILS_AI_BUILD_SECRET",
                 "Set SECRET_KEY_BASE or RAILS_AI_BUILD_SECRET for encrypted key storage")
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

        def check_host_safety
          summary = HostSafety.status_summary
          allowed = RailsAiBuild.configuration.allowed_tools.map(&:to_sym)
          tool_ok = allowed.include?(:host_safety_check) || allowed.include?(:run_generator)

          if summary[:enabled] && tool_ok && summary[:catalog_entries].positive?
            bits = [
              "soft_preview=#{summary[:soft_preview]}",
              "bundle=#{summary[:bundle_check]}",
              "zeitwerk=#{summary[:zeitwerk_check]}",
              "shadow=#{summary[:shadow_worktree]}"
            ]
            ok("host_safety", "Host Safety complete (#{bits.join(', ')}; catalog=#{summary[:catalog_entries]})")
          else
            warn(
              "host_safety",
              "Host Safety incomplete: #{summary.inspect}",
              "Enable host_safety + generator_first; include :run_generator / :host_safety_check in allowed_tools"
            )
          end
        rescue StandardError => e
          error("host_safety", e.message)
        end

        def check_ssrf
          if RailsAiBuild.configuration.ssrf_protection != false
            ok(
              "ssrf",
              "SSRF protection on (localhost=#{RailsAiBuild.configuration.ssrf_allow_localhost != false}, private=#{RailsAiBuild.configuration.ssrf_allow_private == true})"
            )
          else
            warn("ssrf", "SSRF protection disabled", "Set config.ssrf_protection = true")
          end
        end

        def check_engine_auth
          if RailsAiBuild.configuration.require_engine_token
            ok("engine_auth", "Engine token required on mutating API routes")
          elsif production_like?
            warn(
              "engine_auth",
              "Engine mounted without require_engine_token in production-like env",
              "Set config.require_engine_token = true and bootstrap a settings token, or mount behind host auth"
            )
          else
            ok("engine_auth", "Dev/test — token optional (enable require_engine_token for production)")
          end
        end

        def production_like?
          return false unless defined?(Rails)

          Rails.env.production? || ENV["RAILS_AI_BUILD_REQUIRE_ENGINE_TOKEN"].to_s == "1"
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
            5. Open http://localhost:3000/rails_ai_build/ui/ide
            6. Complete Activate wizard (BYOK / Cloud / License)
               — or export NVIDIA_API_KEY / OPENAI_API_KEY
            7. rails rails_ai_build:doctor
            8. Ask the agent: "Add a GET /health endpoint"
          HELP
        },
        "activation" => {
          title: "Day-1 Activation",
          content: <<~HELP
            Three doors into power (pick one):

            1) BYOK — paste OpenAI / Anthropic / NVIDIA key in the IDE wizard
               API: POST /rails_ai_build/settings/keys
            2) Cloud key — hosted models (Pro+)
               API: POST /rails_ai_build/settings/keys { "cloud_api_key": "..." }
            3) License — signed paid entitlement
               API: POST /rails_ai_build/settings/license { "license_key": "..." }

            Settings mutations use X-Rails-Ai-Build-Token
            (issue once: POST /rails_ai_build/settings/bootstrap).

            Plan cannot be set via PATCH /settings — use license or Stripe.
            Doctor: GET /rails_ai_build/support/doctor
            Billing portal: POST /rails_ai_build/billing/portal
          HELP
        },
        "api-keys" => {
          title: "API Keys",
          content: <<~HELP
            Preferred: open /rails_ai_build/ui/ide → Activate wizard.

            Or environment variables (any one is enough):
              NVIDIA_API_KEY=nvapi-...          # free key: https://build.nvidia.com
              NVIDIA_MODEL=meta/llama-3.1-8b-instruct
              OPENAI_API_KEY=sk-...
              ANTHROPIC_API_KEY=sk-ant-...

            Or in config/initializers/rails_ai_build.rb:
              config.api_keys[:nvidia] = ENV["NVIDIA_API_KEY"]
              config.default_provider = :nvidia

            When NVIDIA_API_KEY starts with nvapi-, the install initializer
            selects :nvidia automatically.

            Keys saved via POST /settings/keys are encrypted at rest.
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
          activation = Activation.status
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
            api_keys_configured: activation[:api_keys_configured],
            activation: activation,
            upgrade_url: Plans::UPGRADE_URL
          }
        end

        def update(params)
          normalized = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
          normalized = normalized.transform_keys(&:to_sym)

          # Plan is durable — only license / billing / explicit activate_plan may change it.
          if normalized.key?(:plan)
            raise SecurityError,
                  "Plan cannot be set via settings. Activate a license or use billing checkout."
          end

          allowed = %i[default_provider default_model diff_preview audit_enabled
                       max_agent_iterations auto_mount]
          RailsAiBuild.configure do |c|
            allowed.each do |key|
              next unless normalized.key?(key)

              value = normalized[key]
              value = value.to_sym if %i[default_provider].include?(key) && value
              c.send("#{key}=", value)
            end
          end
          current
        end

        def update_keys(params)
          normalized = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
          normalized = normalized.transform_keys(&:to_sym)

          if Activation.table_ready?
            Activation.persist_cloud_api_key!(normalized[:cloud_api_key]) if normalized.key?(:cloud_api_key)

            key_params = normalized.slice(:openai, :anthropic, :nvidia, :api_keys)
            if key_params[:api_keys]
              Activation.persist_api_keys!(key_params[:api_keys])
            elsif (key_params.keys.map(&:to_sym) & %i[openai anthropic nvidia]).any?
              Activation.persist_api_keys!(key_params.slice(:openai, :anthropic, :nvidia))
            end
          else
            %i[openai anthropic nvidia].each do |provider|
              next unless normalized.key?(provider)

              RailsAiBuild.configuration.api_keys[provider] = normalized[provider]
            end
            if normalized.key?(:cloud_api_key)
              RailsAiBuild.configuration.cloud_api_key = normalized[:cloud_api_key]
            end
          end

          prefer_provider_after_keys!(normalized)
          RailsAiBuild.configuration.apply_env_providers!
          current
        end

        def activate_license(token)
          Entitlements::License.apply!(token)
          current
        end

        private

        def prefer_provider_after_keys!(normalized)
          config = RailsAiBuild.configuration
          if normalized[:cloud_api_key].present? || normalized[:default_provider].to_s == "cloud"
            config.default_provider = :cloud
          elsif normalized[:nvidia].present?
            config.default_provider = :nvidia
          elsif normalized[:anthropic].present?
            config.default_provider = :anthropic
          elsif normalized[:openai].present?
            config.default_provider = :openai
          elsif normalized[:default_provider].present?
            config.default_provider = normalized[:default_provider].to_sym
          end
        end
      end
    end
  end
end
