# frozen_string_literal: true

require "rails/generators"

module RailsAiBuild
  module Generators
    class CiGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Add GitHub Actions workflow for Rails AI Build"

      def copy_workflow
        template "rails-ai.yml", ".github/workflows/rails-ai-build.yml"
      end

      def show_instructions
        say <<~INSTRUCTIONS

          ✅ GitHub Actions workflow installed!

          File: .github/workflows/rails-ai-build.yml

          Set these secrets in your GitHub repo:
            OPENAI_API_KEY or ANTHROPIC_API_KEY

          Trigger manually from Actions tab, or on pull_request.

        INSTRUCTIONS
      end
    end
  end
end
