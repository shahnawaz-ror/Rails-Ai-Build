# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/migration'

module RailsAiBuild
  module Generators
    class UpgradeGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)
      desc 'Upgrade rails_ai_build — stamp version, copy activations migration, show steps'

      def self.next_migration_number(_dirname)
        now = Time.now.utc.strftime('%Y%m%d%H%M%S')
        @last_migration_number = if @last_migration_number.to_s >= now
                                   (@last_migration_number.to_i + 1).to_s
                                 else
                                   now
                                 end
      end

      def show_status
        previous = Upgrade.read_installed_version(destination_root)
        say "\n🔄 Rails AI Build Upgrade\n#{'=' * 40}"
        say "Previous: #{previous || 'unknown'}"
        say "Current:  #{RailsAiBuild::VERSION}\n"
      end

      def copy_activations_migration
        migrate_dir = File.join(destination_root, 'db/migrate')
        FileUtils.mkdir_p(migrate_dir)

        if activations_migration_present?(migrate_dir)
          say '✓ Activations table already covered by existing migration', :green
          return
        end

        migration_template 'create_rails_ai_build_activations.rb',
                           'db/migrate/create_rails_ai_build_activations.rb',
                           migration_version: migration_version
        say '✅ Added activations migration (encrypted keys + durable plan)', :green
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
        say 'Next:'
        say '  rails db:migrate'
        say '  open /rails_ai_build/ui/ide  # Activate wizard'
        say '  rails rails_ai_build:doctor'
      end

      private

      def migration_version
        "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
      end

      def activations_migration_present?(migrate_dir)
        Dir.glob(File.join(migrate_dir, '*rails_ai_build*')).any? do |path|
          File.read(path).include?('rails_ai_build_activations')
        end
      end
    end
  end
end
