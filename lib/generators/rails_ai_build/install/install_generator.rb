# frozen_string_literal: true

require "rails/generators"
require "rails/generators/migration"

module RailsAiBuild
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def self.next_migration_number(dirname)
        next_migration_number = current_migration_number(dirname) + 1
        ActiveRecord::Migration.next_migration_number(next_migration_number)
      end

      def copy_migrations
        migration_template "create_rails_ai_build_tables.rb",
                           "db/migrate/create_rails_ai_build_tables.rb",
                           migration_version: migration_version
      end

      def copy_initializer
        template "initializer.rb", "config/initializers/rails_ai_build.rb"
      end

      def show_readme
        readme "README" if behavior == :invoke
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
