# frozen_string_literal: true

module RailsAiBuild
  module Tools
    class WriteFileTool < BaseTool
      name "write_file"
      description "Create or overwrite a file in the Rails application workspace."
      parameters type: "object",
                 properties: {
                   path: { type: "string", description: "Relative path from workspace root" },
                   content: { type: "string", description: "Full file content to write" }
                 },
                 required: %w[path content]

      def execute(args)
        path = resolve_path(args["path"])
        path.dirname.mkpath
        path.write(args["content"])

        {
          path: args["path"],
          bytes_written: args["content"].bytesize,
          status: "written"
        }
      end
    end
  end
end
