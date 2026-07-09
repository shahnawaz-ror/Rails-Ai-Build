# frozen_string_literal: true

module RailsAiBuild
  module Tools
    class ListFilesTool < BaseTool
      name "list_files"
      description "List files and directories in the workspace."
      parameters type: "object",
                 properties: {
                   path: { type: "string", description: "Directory path (default: workspace root)" },
                   glob: { type: "string", description: "Glob pattern filter, e.g. 'app/**/*.rb'" },
                   max_results: { type: "integer", description: "Maximum results (default: 200)" }
                 }

      def execute(args)
        base = args["path"] ? resolve_path(args["path"]) : workspace
        max = (args["max_results"] || 200).to_i
        glob = args["glob"] || "**/*"

        unless base.directory?
          return { error: "Not a directory: #{args['path']}" }
        end

        entries = Dir.glob(base.join(glob).to_s)
                     .reject { |f| f.include?("/.git/") || f.include?("/node_modules/") }
                     .first(max)
                     .map { |f| Pathname.new(f).relative_path_from(workspace).to_s }
                     .sort

        { path: args["path"] || ".", entries: entries, count: entries.size }
      end
    end
  end
end
