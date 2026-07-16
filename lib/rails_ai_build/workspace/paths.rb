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
        def resolve(workspace, path)
          workspace = Pathname.new(workspace).expand_path
          relative = normalize(workspace, path)
          candidate = workspace.join(relative).expand_path

          raise SecurityError, "Path escapes workspace: #{path}" unless inside?(workspace, candidate)

          candidate
        end

        # True when path means the workspace root (omit path / use ".").
        def root_alias?(path)
          return true if path.nil?

          text = path.to_s.strip
          return true if text.empty?

          ROOT_ALIASES.include?(text.downcase)
        end

        def normalize(workspace, path)
          return '.' if root_alias?(path)

          text = path.to_s.strip
          text = text.sub(%r{\Afile://}i, '')
          workspace = Pathname.new(workspace).expand_path

          # Absolute path that is the workspace (or under it) → make relative.
          if text.start_with?('/')
            absolute = Pathname.new(text).expand_path
            if absolute == workspace
              return '.'
            elsif inside?(workspace, absolute)
              return absolute.relative_path_from(workspace).to_s
            else
              # Absolute outside workspace — treat as relative by stripping leading /
              text = text.sub(%r{\A/+}, '')
            end
          end

          text = strip_workspace_prefix(workspace, text)
          text = text.delete_prefix('./')
          text = '.' if text.empty? || root_alias?(text)
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

        private

        def inside?(workspace, candidate)
          workspace = workspace.expand_path
          candidate = candidate.expand_path
          return true if candidate == workspace

          relative = candidate.relative_path_from(workspace).to_s
          !relative.start_with?('..')
        rescue ArgumentError
          false
        end

        def strip_workspace_basename_prefix(workspace, text)
          base = workspace.basename.to_s
          return text if base.empty?

          # "mailpilot/app/models" → "app/models" when workspace basename is mailpilot
          pattern = %r{\A#{Regexp.escape(base)}(?:/|\z)}i
          text.sub(pattern, '')
        end

        def strip_workspace_prefix(workspace, text)
          stripped = text.dup
          # Common mistaken prefixes from Cursor-like hosts
          %w[workspace /workspace ./workspace].each do |prefix|
            if stripped.downcase == prefix.downcase
              return ''
            elsif stripped.downcase.start_with?("#{prefix.downcase}/")
              stripped = stripped[(prefix.length + 1)..] || ''
            end
          end

          # Absolute workspace path prefix
          abs = workspace.to_s
          if stripped.start_with?("#{abs}/")
            stripped = stripped[(abs.length + 1)..] || ''
          elsif stripped == abs
            return ''
          end

          strip_workspace_basename_prefix(workspace, stripped)
        end
      end
    end
  end
end
