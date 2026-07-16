# frozen_string_literal: true

module RailsAiBuild
  module Tools
    class HostSafetyCheckTool < BaseTool
      name "host_safety_check"
      description "Run the Host Safety ladder (syntax → bundle → boot → zeitwerk → optional smoke routes) on changed session files or the whole app. Prefer after risky edits."
      parameters type: "object",
                 properties: {
                   paths: {
                     type: "array",
                     items: { type: "string" },
                     description: "Optional relative paths to check (defaults to current session changes)"
                   }
                 }

      def execute(args)
        session_id = HostSafety.current_session_id
        changed = Array(args["paths"]).map(&:to_s)
        changed = Changes::Store.session_paths(session_id) if changed.empty?
        if changed.empty?
          # Check boot-critical roots when nothing tracked
          changed = %w[config/application.rb Gemfile].select { |p| workspace.join(p).file? }
        end

        report = HostSafety::Ladder.run!(workspace: workspace, changed: changed)
        {
          healthy: report[:healthy],
          failure_class: report[:failure_class],
          checks: report[:checks],
          changed: changed,
          config: HostSafety.status_summary
        }
      end
    end
  end
end
