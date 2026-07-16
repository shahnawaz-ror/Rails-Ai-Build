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

    initializer "rails_ai_build.mount_routes" do |app|
      next unless RailsAiBuild.configuration.auto_mount

      app.routes.prepend do
        mount RailsAiBuild::Engine => "/rails_ai_build", as: :rails_ai_build
      end
    end
  end
end
