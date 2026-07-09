# frozen_string_literal: true

require "rails/generators"

module RailsAiBuild
  module Generators
    class EnterpriseGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Install enterprise self-hosted configuration"

      def copy_docker
        template "docker-compose.yml", "docker-compose.rails-ai-build.yml"
        template "Dockerfile", "Dockerfile.rails-ai-build"
      end

      def copy_enterprise_config
        template "enterprise.rb", "config/initializers/rails_ai_build_enterprise.rb"
      end

      def show_instructions
        say <<~INSTRUCTIONS

          ✅ Enterprise self-hosted configuration installed!

          Start the AI server:
            docker compose -f docker-compose.rails-ai-build.yml up -d

          Configure in config/initializers/rails_ai_build_enterprise.rb

        INSTRUCTIONS
      end
    end
  end
end
