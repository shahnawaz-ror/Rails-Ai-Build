# frozen_string_literal: true

require 'rails/generators'

module RailsAiBuild
  module Generators
    class BoostGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc 'Install Rails Boost — MCP introspection tools and AI guidelines (Laravel Boost parity)'

      class_option :skip_rules, type: :boolean, default: false, desc: 'Skip .cursor/rules copy'

      def enable_boost_tools
        initializer_path = 'config/initializers/rails_ai_build.rb'
        unless File.exist?(initializer_path)
          say 'Run rails generate rails_ai_build:install first', :red
          return
        end

        content = File.read(initializer_path)
        if content.include?('application_info')
          say "Boost tools already enabled in #{initializer_path}", :yellow
        else
          boost_names = Tools::Registry::BOOST_TOOL_NAMES.join(' ')
          inject_into_file initializer_path,
                           "\n  # Rails Boost introspection tools (MCP)\n  " \
                           "config.allowed_tools += %i[#{boost_names}]\n",
                           after: /config\.allowed_tools\s*=\s*%i\[[^\]]+\]\n/
          say "Enabled Boost tools in #{initializer_path}", :green
        end
      end

      def copy_cursor_rules
        return if options[:skip_rules]

        destination = '.cursor/rules/rails-boost.mdc'
        return if File.exist?(destination)

        template 'rails-boost.mdc', destination
        say "Installed AI guidelines: #{destination}", :green
      end

      def copy_mcp_config
        destination = 'config/rails_ai_build_mcp.json'
        return if File.exist?(destination)

        template 'mcp.json', destination
        say "MCP client config: #{destination}", :green
      end

      def show_readme
        readme 'README' if behavior == :invoke
      end
    end
  end
end
