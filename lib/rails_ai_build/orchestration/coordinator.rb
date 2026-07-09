# frozen_string_literal: true

module RailsAiBuild
  module Orchestration
    # Multi-agent orchestration — planner delegates to coder
    class Coordinator
      AGENT_ROLES = {
        planner: {
          system_prompt: <<~PROMPT,
            You are a planning agent. Analyze the task, read relevant files, and produce
            a step-by-step plan. Do NOT write code. Output a numbered plan only.
          PROMPT
          tools: %i[read_file grep list_files]
        },
        coder: {
          system_prompt: <<~PROMPT,
            You are a coding agent. Execute the plan by reading and writing files.
            Follow Rails conventions. Make minimal focused changes.
          PROMPT
          tools: %i[read_file write_file grep list_files shell]
        },
        reviewer: {
          system_prompt: <<~PROMPT,
            You are a review agent. Check the changes for bugs, missing tests,
            and Rails best practices. Suggest fixes if needed.
          PROMPT
          tools: %i[read_file grep list_files shell]
        }
      }.freeze

      def initialize(provider: nil, model: nil)
        @provider = provider
        @model = model
        @agents = {}
      end

      def run(task, roles: %i[planner coder])
        results = {}
        context = +"Task: #{task}\n\n"

        roles.each do |role|
          agent = build_agent(role)
          prompt = role == :planner ? task : "#{context}\nExecute the plan above."
          result = agent.chat(prompt)
          results[role] = result
          context << "\n## #{role.to_s.capitalize} output:\n#{result[:content]}\n"
          Analytics.track_basic(event: "orchestration.#{role}", metadata: { task: task.to_s[0, 80] })
        end

        {
          task: task,
          roles: roles,
          results: results,
          final: results[roles.last]
        }
      end

      def run_with_review(task)
        run(task, roles: %i[planner coder reviewer])
      end

      def run_until_green(task, max_rounds: 3)
        current_task = task.to_s
        rounds = []

        max_rounds.times do |i|
          result = run_with_review(current_task)
          verify = verify_workspace
          round = { round: i + 1, orchestration: result, verify: verify }
          rounds << round
          return { task: task, status: :success, rounds: rounds, final: result } if verify[:passed]

          current_task = <<~FIX
            Fix verification failures from round #{i + 1}:

            #{format_verify_failure(verify)}

            Original task: #{task}
          FIX
        end

        { task: task, status: :failed, rounds: rounds, final: rounds.last[:orchestration] }
      end

      private

      def verify_workspace
        workspace = RailsAiBuild.configuration.workspace_path
        tool = Tools::RunRailsCheckTool.new(workspace: workspace)
        result = tool.call({ 'checks' => %w[zeitwerk] })
        { passed: result[:passed], checks: result[:checks] }
      rescue StandardError => e
        { passed: false, error: e.message }
      end

      def format_verify_failure(verify)
        return verify[:error].to_s unless verify[:checks]

        verify[:checks].filter_map do |name, check|
          next if check[:passed]

          "#{name}: #{check[:stdout].to_s[0, 1000]}"
        end.join("\n")
      end

      def build_agent(role)
        config = AGENT_ROLES.fetch(role)
        original_tools = RailsAiBuild.configuration.allowed_tools
        RailsAiBuild.configuration.allowed_tools = config[:tools]

        Agents::Agent.new(
          name: role.to_s,
          provider: @provider,
          model: @model,
          system_prompt: config[:system_prompt]
        )
      ensure
        RailsAiBuild.configuration.allowed_tools = original_tools
      end
    end
  end
end
