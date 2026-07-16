# frozen_string_literal: true

module RailsAiBuild
  module Workspace
    # Intelligent path normalization for tools + IDE browser.
    # Models often pass conceptual names like "workspace" instead of "." —
    # those must resolve to the configured app root, not a child folder.
    module Paths
      ROOT_ALIASES = %w[
        .
        ./
        /
        workspace
        ./workspace
        workspace/
        ./workspace/
        app root
        project root
        project
        root
        rails.root
        rails_root
        app_root
      ].freeze

      class << self
        # Returns a Pathname inside +workspace+, or raises SecurityError / ArgumentError.
        # Uses realpath containment to block symlink escapes outside the app root.
        def resolve(workspace, path, allow_missing: true)
          workspace = canonical_root(workspace)
          relative = normalize(workspace, path)
          raise SecurityError, "Path escapes workspace: #{path}" if relative.include?("..")

          candidate = workspace.join(relative)
          assert_inside!(workspace, candidate, original: path, allow_missing: allow_missing)
          candidate
        end

        def assert_inside!(workspace, candidate, original: nil, allow_missing: true)
          workspace = canonical_root(workspace)
          candidate = Pathname.new(candidate)

          if candidate.exist?
            real = candidate.realpath
            raise SecurityError, "Path escapes workspace (symlink): #{original || candidate}" unless inside_realpath?(workspace, real)
          else
            raise SecurityError, "Path does not exist: #{original || candidate}" unless allow_missing

            # Ensure parent chain cannot escape via symlink
            parent = candidate.dirname
            parent = parent.realpath if parent.exist?
            raise SecurityError, "Path escapes workspace: #{original || candidate}" unless inside_realpath?(workspace, parent.expand_path)
          end

          true
        end

        # True when path means the workspace root (omit path / use ".").
        def root_alias?(path)
          return true if path.nil?

          text = path.to_s.strip
          return true if text.empty?

          ROOT_ALIASES.include?(text.downcase)
        end

        def normalize(workspace, path)
          return "." if root_alias?(path)

          text = path.to_s.strip
          text = text.sub(%r{\Afile://}i, "")
          workspace = Pathname.new(workspace).expand_path

          # Absolute path that is the workspace (or under it) → make relative.
          if text.start_with?("/")
            absolute = Pathname.new(text).expand_path
            if absolute == workspace
              return "."
            elsif inside?(workspace, absolute)
              return absolute.relative_path_from(workspace).to_s
            else
              # Absolute outside workspace — treat as relative by stripping leading /
              text = text.sub(%r{\A/+}, "")
            end
          end

          text = strip_workspace_prefix(workspace, text)
          text = text.delete_prefix("./")
          text = "." if text.empty? || root_alias?(text)

          # Reject parent traversal segments after normalization
          parts = text.split("/").reject(&:empty?)
          raise SecurityError, "Path escapes workspace: #{path}" if parts.include?("..")

          text
        end

        def prompt_guidance(workspace)
          root = Pathname.new(workspace).expand_path
          <<~GUIDE.strip
            ## Workspace paths
            - App root: `#{root}` (basename: `#{root.basename}`)
            - All tool paths are **relative to the app root**.
            - To list the project root use `list_files` with path `"."` or omit `path`.
            - Never pass `"workspace"` as a folder name — that is not a directory inside the app.
            - Examples: `"app"`, `"app/models"`, `"config/routes.rb"`, `"db/migrate"`.
          GUIDE
        end

        # Reject HTTP/API overrides that point outside the configured root.
        def sanitize_request_workspace!(requested, configured: nil)
          return nil if requested.blank?

          configured = Pathname(configured || RailsAiBuild.configuration.workspace_path).expand_path
          unless RailsAiBuild.configuration.allow_workspace_override
            raise SecurityError,
                  "workspace override disabled (set config.allow_workspace_override = true only for trusted local agents)"
          end

          requested = Pathname(requested).expand_path
          raise SecurityError, "workspace override escapes configured root: #{requested}" unless inside_realpath?(configured, requested)

          requested
        end

        private

        def canonical_root(workspace)
          root = Pathname.new(workspace).expand_path
          root.exist? ? root.realpath : root
        end

        def inside?(workspace, candidate)
          workspace = workspace.expand_path
          candidate = candidate.expand_path
          return true if candidate == workspace

          relative = candidate.relative_path_from(workspace).to_s
          !relative.start_with?("..")
        rescue ArgumentError
          false
        end

        def inside_realpath?(workspace, candidate)
          workspace = canonical_root(workspace)
          candidate = Pathname.new(candidate).expand_path
          candidate = candidate.realpath if candidate.exist?
          inside?(workspace, candidate)
        rescue Errno::ENOENT, ArgumentError
          false
        end

        def strip_workspace_basename_prefix(workspace, text)
          base = workspace.basename.to_s
          return text if base.empty?

          pattern = %r{\A#{Regexp.escape(base)}(?:/|\z)}i
          text.sub(pattern, "")
        end

        def strip_workspace_prefix(workspace, text)
          stripped = text.dup
          %w[workspace /workspace ./workspace].each do |prefix|
            if stripped.downcase == prefix.downcase
              return ""
            elsif stripped.downcase.start_with?("#{prefix.downcase}/")
              stripped = stripped[(prefix.length + 1)..] || ""
            end
          end

          abs = workspace.to_s
          if stripped.start_with?("#{abs}/")
            stripped = stripped[(abs.length + 1)..] || ""
          elsif stripped == abs
            return ""
          end

          strip_workspace_basename_prefix(workspace, stripped)
        end
      end
    end
  end
end
