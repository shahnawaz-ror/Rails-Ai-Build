# frozen_string_literal: true

require "rails/generators"
require "rails/generators/test_case"
require "generators/rails_ai_build/install/install_generator"

module RailsAiBuild
  module Generators
    class InstallGeneratorTest < Rails::Generators::TestCase
      tests InstallGenerator
      destination Rails.root.join("tmp/generator_test")
      setup :prepare_destination

      test "generates initializer and migration" do
        run_generator
        assert_file "config/initializers/rails_ai_build.rb"
        assert_migration "db/migrate/create_rails_ai_build_tables.rb"
      end
    end
  end
end
