# frozen_string_literal: true

module RailsAiBuild
  module Tools
    class WriteFileTool < BaseTool
      name "write_file"
      description "Create or overwrite a file relative to the Rails app root. Prefer run_generator for models/controllers/scaffolds/migrations. Use write_file for custom logic after a generator, or non-generator tasks. Ruby syntax is checked before apply."
      parameters type: "object",
                 properties: {
                   path: { type: "string", description: "Path relative to app root, e.g. 'app/models/user.rb'" },
                   content: { type: "string", description: "Full file content to write" }
                 },
                 required: %w[path content]

      def execute(args)
        path = resolve_path(args["path"])
        begin
          HostSafety.validate_write!(args["path"], args["content"])
        rescue ToolError => e
          return { success: false, error: e.message, path: args["path"], syntax_rejected: true }
        end

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
          workspace: workspace,
          session_id: HostSafety.current_session_id,
          source: "write_file"
        )
      end
    end
  end
end
