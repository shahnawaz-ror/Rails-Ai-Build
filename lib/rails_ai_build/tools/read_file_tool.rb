# frozen_string_literal: true

module RailsAiBuild
  module Tools
    class ReadFileTool < BaseTool
      name "read_file"
      description "Read a file relative to the Rails app root (e.g. 'app/models/user.rb'). Do not use 'workspace' as a path prefix."
      parameters type: "object",
                 properties: {
                   path: { type: "string", description: "Path relative to app root, e.g. 'config/routes.rb'" },
                   offset: { type: "integer", description: "Line number to start reading from (1-indexed)" },
                   limit: { type: "integer", description: "Maximum number of lines to read" }
                 },
                 required: %w[path]

      MAX_FILE_BYTES = 2_000_000
      DEFAULT_LINE_LIMIT = 2_000

      def execute(args)
        path = resolve_path(args["path"])

        unless path.file?
          return { error: "File not found: #{args['path']}" }
        end

        if path.size > MAX_FILE_BYTES
          return {
            error: "File too large to read (#{path.size} bytes > #{MAX_FILE_BYTES})",
            hint: "Use offset/limit on a smaller slice, or grep for the relevant section."
          }
        end

        lines = path.read.lines
        offset = [(args["offset"] || 1).to_i - 1, 0].max
        limit = args["limit"]&.to_i
        limit = DEFAULT_LINE_LIMIT if limit.nil? || limit <= 0
        limit = [limit, DEFAULT_LINE_LIMIT].min

        selected = lines[offset, limit] || []
        numbered = selected.each_with_index.map { |line, i| "#{offset + i + 1}|#{line.chomp}" }

        {
          path: args["path"],
          content: numbered.join("\n"),
          total_lines: lines.size,
          truncated: (offset + selected.size) < lines.size
        }
      end
    end
  end
end
