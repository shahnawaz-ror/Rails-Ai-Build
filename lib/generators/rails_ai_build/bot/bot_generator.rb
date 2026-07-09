# frozen_string_literal: true

require "rails/generators"

module RailsAiBuild
  module Generators
    class BotGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      class_option :platform, type: :string, default: "slack", desc: "slack or discord"

      desc "Configure Slack or Discord bot integration"

      def copy_config
        if options[:platform] == "discord"
          template "discord.rb", "config/initializers/rails_ai_build_discord.rb"
        else
          template "slack.rb", "config/initializers/rails_ai_build_slack.rb"
        end
      end

      def show_instructions
        platform = options[:platform]
        say <<~INSTRUCTIONS

          ✅ #{platform.capitalize} bot configured!

          Set environment variables:
            #{platform == "slack" ? "SLACK_SIGNING_SECRET" : "DISCORD_PUBLIC_KEY"}

          Webhook URL:
            POST /rails_ai_build/#{platform}/#{"command" if platform == "slack"}#{"interactions" if platform == "discord"}

          Requires Team plan or higher.

        INSTRUCTIONS
      end
    end
  end
end
