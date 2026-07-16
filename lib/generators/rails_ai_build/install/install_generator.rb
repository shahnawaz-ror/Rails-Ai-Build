# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/migration'

module RailsAiBuild
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      def self.next_migration_number(_dirname)
        # Full UTC timestamp prevents DuplicateMigrationVersionError (e.g. bare "2024")
        now = Time.now.utc.strftime('%Y%m%d%H%M%S')
        @last_migration_number = if @last_migration_number.to_s >= now
                                   (@last_migration_number.to_i + 1).to_s
                                 else
                                   now
                                 end
      end

      def copy_migrations
        migration_template 'create_rails_ai_build_tables.rb',
                           'db/migrate/create_rails_ai_build_tables.rb',
                           migration_version: migration_version
      end

      def copy_initializer
        template 'initializer.rb', 'config/initializers/rails_ai_build.rb'
      end

      def heal_migration_collisions
        report = RailsAiBuild::Migrations::Intelligence.auto_heal!(
          migrate_dir: File.expand_path('db/migrate', destination_root)
        )
        report[:healed].each do |h|
          say_status :heal, "#{h[:from]} → #{h[:to]} (#{h[:reason]})", :yellow
        end
      rescue StandardError => e
        say_status :warn, "Migration heal skipped: #{e.message}", :yellow
      end

      def show_readme
        readme 'README' if behavior == :invoke
      end

      private

      def migration_version
        "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
      end

      def rails_ai_build_version
        RailsAiBuild::VERSION
      end
    end
  end
end
