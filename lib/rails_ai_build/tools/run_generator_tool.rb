# frozen_string_literal: true

module RailsAiBuild
  module Tools
    # Prefer this over freeform write_file / shell for Rails structure.
    class RunGeneratorTool < BaseTool
      name "run_generator"
      description "Run an allowlisted Rails generator (scaffold, model, migration, controller, mailer, job, channel, devise). Prefer this over inventing files with write_file — generators are safer and match Rails conventions. Pass generator name and args, e.g. generator: \"model\", args: [\"Post\", \"title:string\", \"body:text\"]."
      parameters type: "object",
                 properties: {
                   generator: {
                     type: "string",
                     description: "Allowlisted generator: scaffold, model, migration, controller, mailer, job, channel, devise"
                   },
                   args: {
                     type: "array",
                     items: { type: "string" },
                     description: "Arguments for the generator"
                   }
                 },
                 required: %w[generator]

      def execute(args)
        generator = args["generator"].to_s
        argv = Array(args["args"]).map(&:to_s)
        plan = Generators::IntentRouter::Plan.new(
          mode: :generator,
          entry_id: generator,
          generator: generator,
          args: argv,
          score: 99,
          reason: "run_generator tool",
          ai_followup: false
        )
        result = Generators::Runner.execute!(plan, workspace: workspace)
        {
          status: result.ok ? "generated" : "failed",
          command: result.command,
          exit_code: result.exit_code,
          created_files: result.created_files,
          stdout: result.stdout,
          stderr: result.stderr,
          hint: result.ok ? "Generator succeeded — customize with write_file only where needed." : "Generator failed — inspect stderr, then fix or retry."
        }
      end
    end
  end
end
