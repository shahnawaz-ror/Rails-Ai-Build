# frozen_string_literal: true

module RailsAiBuild
  class Engine < ::Rails::Engine
    isolate_namespace RailsAiBuild

    config.generators do |g|
      g.test_framework :rspec
    end

    rake_tasks do
      load root.join("lib/tasks/rails_ai_build.rake")
    end

    initializer "rails_ai_build.register_providers" do
      RailsAiBuild::Providers.register_defaults
    end

    initializer "rails_ai_build.load_activation", after: :load_config_initializers do
      RailsAiBuild.configuration.apply_env_providers!
      RailsAiBuild::Activation.load_into_configuration!
    rescue StandardError => e
      Rails.logger.warn("[rails_ai_build] Activation load skipped: #{e.message}") if defined?(Rails)
    end

    # Auto-heal bad/duplicate migration versions (e.g. padded "000…2024") in dev/test
    # so DuplicateMigrationVersionError does not brick /rails_ai_build.
    initializer "rails_ai_build.heal_migrations", before: :load_config_initializers do
      next unless defined?(Rails)
      next unless rails_env_local?

      report = RailsAiBuild::Migrations::Intelligence.diagnose
      next if report[:healthy]

      healed = RailsAiBuild::Migrations::Intelligence.auto_heal!(dry_run: false)
      if healed[:healed].any?
        Rails.logger.warn(
          "[rails_ai_build] Auto-healed #{healed[:healed].size} migration(s): " \
          "#{healed[:healed].map { |h| "#{h[:from]} → #{h[:to]}" }.join(', ')}"
        )
      end
    rescue StandardError => e
      Rails.logger.warn("[rails_ai_build] Migration heal skipped: #{e.message}")
    end

    initializer "rails_ai_build.mount_routes" do |app|
      next unless RailsAiBuild.configuration.auto_mount

      app.routes.prepend do
        mount RailsAiBuild::Engine => "/rails_ai_build", as: :rails_ai_build
      end
    end

    def self.rails_env_local?
      return Rails.env.local? if Rails.env.respond_to?(:local?)

      Rails.env.development? || Rails.env.test?
    end
  end
end
