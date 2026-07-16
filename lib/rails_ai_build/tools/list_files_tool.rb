# frozen_string_literal: true

module RailsAiBuild
  module Tools
    class ListFilesTool < BaseTool
      name "list_files"
      description "List files under the Rails app root. Paths are relative to the app root — use '.' or omit path for the project root. Do not pass 'workspace'."
      parameters type: "object",
                 properties: {
                   path: {
                     type: "string",
                     description: "Directory relative to app root (default '.'). Examples: '.', 'app', 'app/models'. Not 'workspace'."
                   },
                   glob: { type: "string", description: "Glob pattern filter, e.g. 'app/**/*.rb'" },
                   max_results: { type: "integer", description: "Maximum results (default: 200)" }
                 }

      def execute(args)
        requested = args["path"]
        base = resolve_path(requested.nil? || requested.to_s.strip.empty? ? '.' : requested)
        max = (args["max_results"] || 200).to_i
        glob = args["glob"] || "**/*"
        display = Workspace::Paths.normalize(
          workspace,
          requested.nil? || requested.to_s.strip.empty? ? '.' : requested
        )

        unless base.directory?
          return {
            error: "Not a directory: #{requested}",
            hint: "Use path '.' or omit path for the app root. Tried: #{display}"
          }
        end

        entries = Dir.glob(base.join(glob).to_s)
                     .reject { |f| f.include?("/.git/") || f.include?("/node_modules/") }
                     .first(max)
                     .map { |f| Pathname.new(f).relative_path_from(workspace).to_s }
                     .sort

        { path: display, entries: entries, count: entries.size }
      end
    end
  end
end
