# frozen_string_literal: true

module RailsAiBuild
  module Tools
    class WriteFileTool < BaseTool
      name "write_file"
      description "Create or overwrite a file in the Rails application workspace. Changes may require approval when diff preview is enabled."
      parameters type: "object",
                 properties: {
                   path: { type: "string", description: "Relative path from workspace root" },
                   content: { type: "string", description: "Full file content to write" }
                 },
                 required: %w[path content]

      def execute(args)
        path = resolve_path(args["path"])
        old_content = path.file? ? path.read : ""

        Audit.log(
          action: "write_file",
          path: args["path"],
          preview: RailsAiBuild.configuration.diff_preview
        )

        Changes::Store.record(
          path: args["path"],
          old_content: old_content,
          new_content: args["content"],
          workspace: workspace
        )
      end
    end
  end
end
