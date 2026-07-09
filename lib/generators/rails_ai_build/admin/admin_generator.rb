# frozen_string_literal: true

require "rails/generators"
require "rails/generators/migration"

module RailsAiBuild
  module Generators
    class AdminGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      class_option :path, type: :string, default: "/admin/ai", desc: "Mount path for AI admin panel"
      class_option :user_class, type: :string, default: "User", desc: "User model for authentication"

      desc "Mount the Rails AI Build admin panel for your team"

      def mount_admin_panel
        route <<~ROUTE

          # Rails AI Build — team AI admin panel
          authenticate :user, ->(u) { u.admin? } do
            mount RailsAiBuild::Engine => "#{options[:path]}"
          end
        ROUTE
      end

      def copy_admin_initializer
        template "admin.rb", "config/initializers/rails_ai_build_admin.rb"
      end

      def show_instructions
        say <<~INSTRUCTIONS

          ✅ Rails AI Build admin panel configured!

          Mount path: #{options[:path]}
          Dashboard:  http://localhost:3000#{options[:path]}

          Make sure your User model responds to #admin?
          Or edit config/initializers/rails_ai_build_admin.rb

        INSTRUCTIONS
      end
    end
  end
end
