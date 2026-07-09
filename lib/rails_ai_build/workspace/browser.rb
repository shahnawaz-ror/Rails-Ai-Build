# frozen_string_literal: true

module RailsAiBuild
  module Workspace
    # Read-only workspace browser for the in-app IDE (file tree + file read).
    class Browser
      SKIP_DIRS = %w[
        .git node_modules vendor/bundle tmp log storage coverage
        .bundle public/assets .cursor
      ].freeze

      MAX_DEPTH = 4
      MAX_ENTRIES = 500

      class << self
        def tree(workspace: nil, path: ".", depth: MAX_DEPTH)
          workspace ||= RailsAiBuild.configuration.workspace_path
          root = resolve(workspace, path)
          return { error: "Not a directory: #{path}" } unless root.directory?

          counter = { n: 0 }
          {
            path: path.to_s,
            entries: build_entries(workspace, root, depth: depth, counter: counter)
          }
        end

        def read_file(workspace: nil, path:)
          workspace ||= RailsAiBuild.configuration.workspace_path
          tool = Tools::ReadFileTool.new(workspace: workspace)
          tool.call("path" => path)
        end

        private

        def build_entries(workspace, dir, depth:, counter:)
          return [] if depth.zero? || counter[:n] >= MAX_ENTRIES

          dir.children.sort_by { |p| [p.directory? ? 0 : 1, p.basename.to_s.downcase] }.filter_map do |entry|
            break [] if counter[:n] >= MAX_ENTRIES

            name = entry.basename.to_s
            next if name.start_with?(".") && name != ".ruby-version"
            next if entry.directory? && SKIP_DIRS.include?(relative_path(workspace, entry))

            counter[:n] += 1
            rel = relative_path(workspace, entry)
            if entry.directory?
              {
                name: name,
                path: rel,
                type: "directory",
                children: depth > 1 ? build_entries(workspace, entry, depth: depth - 1, counter: counter) : []
              }
            else
              { name: name, path: rel, type: "file" }
            end
          end
        end

        def relative_path(workspace, entry)
          entry.relative_path_from(workspace).to_s
        end

        def resolve(workspace, path)
          full = workspace.join(path.to_s.sub(%r{\A/}, ""))
          resolved = full.expand_path
          unless resolved.to_s.start_with?(workspace.expand_path.to_s)
            raise SecurityError, "Path escapes workspace: #{path}"
          end

          resolved
        end
      end
    end
  end
end
