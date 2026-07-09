# frozen_string_literal: true

require 'rails/generators'

module RailsAiBuild
  module Generators
    class UpgradeGenerator < Rails::Generators::Base
      desc 'Upgrade rails_ai_build — stamp version, show migration steps'

      def show_status
        previous = Upgrade.read_installed_version(destination_root)
        say "\n🔄 Rails AI Build Upgrade\n#{'=' * 40}"
        say "Previous: #{previous || 'unknown'}"
        say "Current:  #{RailsAiBuild::VERSION}\n"
      end

      def stamp_initializer
        path = 'config/initializers/rails_ai_build.rb'
        if File.exist?(File.join(destination_root, path))
          Upgrade.stamp_initializer(File.join(destination_root, path))
          say "✅ Stamped #{path} with version #{RailsAiBuild::VERSION}"
        else
          say '⚠️  No initializer found. Run: rails generate rails_ai_build:install', :yellow
        end
      end

      def show_upgrade_guide
        previous = Upgrade.read_installed_version(destination_root)
        say Upgrade.chat_guide(previous)
        say "\n#{'=' * 40}"
        say 'Doctor: rails rails_ai_build:doctor'
        say 'Help:   rails rails_ai_build:help[upgrade]'
      end
    end
  end
end
