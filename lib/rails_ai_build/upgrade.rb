# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module RailsAiBuild
  # Guides chat-based install → upgrade flows and version stamping in host apps.
  module Upgrade
    VERSION_MARKER = /rails_ai_build_version:\s*([\d.]+)/

    RELEASE_NOTES = {
      '1.4.0' => ['RuboCop, expanded specs, Appraisal multi-Rails matrix'],
      '1.4.1' => ['Web UI live demo with SSE streaming'],
      '1.4.2' => ['CI coverage reports on pull requests'],
      '1.5.0' => ['Full developer workflow specs, multi-DB CI, upgrade generator'],
      '2.3.0' => [
        'Day-1 Activation OS — encrypted keys, license entitlements, IDE wizard',
        'Doctor panel + upgrade modal with plan_required checkout payloads',
        'Settings auth token; plan no longer spoofable via PATCH /settings'
      ]
    }.freeze

    UPGRADE_STEPS = {
      '1.3.0' => [
        { action: :bundle_update, message: 'bundle update rails_ai_build' },
        { action: :migrate, message: 'rails db:migrate' },
        { action: :doctor, message: 'rails rails_ai_build:doctor' }
      ],
      '1.4.0' => [
        { action: :bundle_update, message: 'bundle update rails_ai_build' },
        { action: :run_generator, generator: 'rails_ai_build:upgrade', message: 'rails generate rails_ai_build:upgrade' },
        { action: :doctor, message: 'rails rails_ai_build:doctor' }
      ],
      '2.3.0' => [
        { action: :bundle_update, message: 'bundle update rails_ai_build' },
        { action: :run_generator, generator: 'rails_ai_build:upgrade', message: 'rails generate rails_ai_build:upgrade' },
        { action: :migrate, message: 'rails db:migrate' },
        { action: :activate, message: 'Open /rails_ai_build/ui/ide and complete the Activate wizard' },
        { action: :doctor, message: 'rails rails_ai_build:doctor' }
      ]
    }.freeze

    class << self
      def status(installed_version: nil, workspace: nil)
        workspace ||= safe_workspace
        installed = installed_version || read_installed_version(workspace)
        current = VERSION
        needs = installed.present? && Gem::Version.new(installed) < Gem::Version.new(current)

        {
          installed_version: installed,
          current_version: current,
          needs_upgrade: needs,
          steps: steps_for(installed),
          release_notes: release_notes_since(installed)
        }
      end

      def steps_for(from_version)
        return default_install_steps if from_version.nil?

        from = Gem::Version.new(from_version)
        return [] if from >= Gem::Version.new(VERSION)

        UPGRADE_STEPS
          .select { |ver, _| Gem::Version.new(ver) > from }
          .sort_by { |ver, _| Gem::Version.new(ver) }
          .flat_map { |_, steps| steps }
          .uniq { |s| s[:message] }
      end

      def chat_guide(installed_version = nil, workspace: nil)
        workspace ||= safe_workspace
        installed = installed_version || read_installed_version(workspace)
        current = VERSION
        needs = installed.present? && Gem::Version.new(installed) < Gem::Version.new(current)

        if installed.nil?
          install_guide
        elsif needs
          upgrade_guide(
            installed_version: installed,
            current_version: current,
            needs_upgrade: needs,
            steps: steps_for(installed),
            release_notes: release_notes_since(installed)
          )
        else
          "You're on rails_ai_build #{VERSION}. No upgrade needed.\nRun `rails rails_ai_build:doctor` to verify your setup."
        end
      end

      def read_installed_version(workspace = nil)
        workspace = Pathname.new(workspace) unless workspace.nil? || workspace.is_a?(Pathname)
        workspace ||= safe_workspace
        init = workspace.join('config/initializers/rails_ai_build.rb')
        return nil unless init.exist?

        match = init.read.match(VERSION_MARKER)
        match&.[](1)
      end

      def stamp_initializer(path, version: VERSION)
        content = File.read(path)
        stamped = if content.match?(VERSION_MARKER)
                    content.sub(VERSION_MARKER, "rails_ai_build_version: #{version}")
                  else
                    content.sub(
                      "# frozen_string_literal: true\n",
                      "# frozen_string_literal: true\n\n# rails_ai_build_version: #{version}\n"
                    )
                  end
        File.write(path, stamped)
      end

      private

      def safe_workspace
        RailsAiBuild.configuration.workspace_path
      rescue StandardError
        Pathname.pwd
      end

      def default_install_steps
        [
          { action: :gemfile, message: 'Add gem "rails_ai_build" to Gemfile' },
          { action: :bundle, message: 'bundle install' },
          { action: :install, message: 'rails generate rails_ai_build:install' },
          { action: :migrate, message: 'rails db:migrate' },
          { action: :setup, message: 'rails rails_ai_build:setup' }
        ]
      end

      def install_guide
        <<~GUIDE.strip
          Install rails_ai_build #{VERSION}:

          1. Add gem "rails_ai_build" to Gemfile
          2. bundle install
          3. rails generate rails_ai_build:install
          4. rails db:migrate
          5. export OPENAI_API_KEY=sk-...
          6. rails rails_ai_build:setup

          Chat with your app: POST /rails_ai_build/chat
          Upgrade later: rails generate rails_ai_build:upgrade
        GUIDE
      end

      def upgrade_guide(info)
        lines = ["Upgrade rails_ai_build from #{info[:installed_version]} → #{info[:current_version]}:"]
        info[:steps].each_with_index { |step, i| lines << "#{i + 1}. #{step[:message]}" }
        if info[:release_notes].any?
          lines << ''
          lines << "What's new:"
          info[:release_notes].each { |note| lines << "  • #{note}" }
        end
        lines.join("\n")
      end

      def release_notes_since(from_version)
        return RELEASE_NOTES.values.flatten if from_version.nil?

        from = Gem::Version.new(from_version)
        RELEASE_NOTES
          .select { |ver, _| Gem::Version.new(ver) > from }
          .sort_by { |ver, _| Gem::Version.new(ver) }
          .flat_map { |_, notes| notes }
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
