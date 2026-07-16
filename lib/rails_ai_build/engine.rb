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

    # Auto-heal host blockers (migrations, etc.) in local envs before the IDE boots.
    initializer "rails_ai_build.heal_migrations", before: :load_config_initializers do
      next unless defined?(Rails)
      next unless rails_env_local?

      result = RailsAiBuild::Intelligence.prepare!
      if result[:actions].any?
        Rails.logger.warn(
          "[rails_ai_build] Intelligence healed #{result[:actions].size} issue(s): " \
          "#{result[:actions].pluck(:type).join(', ')}"
        )
      end
    rescue StandardError => e
      Rails.logger.warn("[rails_ai_build] Intelligence prepare skipped: #{e.message}")
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
