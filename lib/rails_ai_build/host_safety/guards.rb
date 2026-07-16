# frozen_string_literal: true

module RailsAiBuild
  module HostSafety
    # Phase A — Prevent: reject bad writes before they land.
    module Guards
      MIGRATION_NAME = /\A\d{14}_[a-z0-9_]+\.rb\z/i
      MIGRATION_CLASS = /class\s+[A-Z][\w:]+\s*<\s*(?:ActiveRecord::)?Migration(?:\[\d+(?:\.\d+)*\])?/

      module_function

      def validate_write!(path, content)
        rel = normalize(path)
        validate_ruby_syntax!(rel, content)
        validate_migration!(rel, content)
        validate_gemfile!(rel, content)
        true
      end

      def validate_ruby_syntax!(path, content)
        return true unless path.end_with?(".rb") || gemfile?(path)
        return true if content.to_s.strip.empty?

        ok, message = HostSafety.syntax_ok?(content)
        raise ToolError, "Syntax error in #{path}: #{message}" unless ok

        true
      end

      def validate_migration!(path, content)
        return true unless path.match?(%r{\Adb/migrate/})

        basename = File.basename(path)
        unless basename.match?(MIGRATION_NAME)
          raise ToolError,
                "Migration filename must be YYYYMMDDHHMMSS_name.rb (got #{basename})"
        end

        if content.to_s.strip.empty?
          raise ToolError, "Migration #{basename} is empty"
        end

        unless content.match?(MIGRATION_CLASS)
          raise ToolError,
                "Migration #{basename} must define a class inheriting ActiveRecord::Migration"
        end

        # Soft dry-parse: reject obviously broken change blocks
        if content.match?(/\b(?:change|up)\b/) && !content.match?(/\bend\b/)
          raise ToolError, "Migration #{basename} looks truncated (missing end)"
        end

        true
      end

      def validate_gemfile!(path, content)
        return true unless gemfile?(path)

        if content.to_s.strip.empty?
          raise ToolError, "Gemfile cannot be empty"
        end

        # Catch common AI mistakes before disk write
        if content.match?(/^\s*gem\s+['"]\s*['"]/)
          raise ToolError, "Gemfile contains an empty gem declaration"
        end

        true
      end

      def soft_preview_required?(path)
        return false unless HostSafety.enabled?
        return true if RailsAiBuild.configuration.diff_preview
        return false unless RailsAiBuild.configuration.host_safety_soft_preview != false

        normalize(path).match?(BOOT_CRITICAL)
      end

      def gemfile?(path)
        normalize(path).match?(/\AGemfile(\.lock)?\z/)
      end

      def normalize(path)
        path.to_s.sub(%r{\A/}, "")
      end
    end
  end
end
