# frozen_string_literal: true

module RailsAiBuild
  module Tasks
    # Cursor-style task runtime: build → verify → restart on failure.
    class Runtime
      Result = Struct.new(
        :task, :status, :attempts, :content, :iterations, :usage, :verify, :messages,
        keyword_init: true
      ) do
        def to_h
          {
            task: task,
            status: status,
            attempts: attempts,
            content: content,
            iterations: iterations,
            usage: usage,
            verify: verify,
            pending_changes: RailsAiBuild::Changes::Store.all(status: :pending).map(&:to_h)
          }
        end
      end

      def initialize(
        task:,
        workspace: nil,
        provider: nil,
        model: nil,
        skill: nil,
        verify: nil,
        max_attempts: nil
      )
        @task = task.to_s
        @workspace = workspace || RailsAiBuild.configuration.workspace_path
        @provider = provider
        @model = model
        @skill = skill
        @verify = verify.nil? ? RailsAiBuild.configuration.verify_builds : verify
        @max_attempts = max_attempts || RailsAiBuild.configuration.build_max_attempts
        @attempts = []
      end

      def run!
        context = +""
        last_result = nil

        @max_attempts.times do |i|
          prompt = build_prompt(attempt: i + 1, context: context)
          last_result = run_agent(prompt)
          verify_result = @verify ? verify_workspace : { passed: true, skipped: true }

          attempt_record = {
            number: i + 1,
            iterations: last_result[:iterations],
            verify: verify_result,
            content: last_result[:content]
          }
          @attempts << attempt_record

          if verify_result[:passed]
            return success_result(last_result, verify_result)
          end

          context << "\n\n## Attempt #{i + 1} failed verification\n"
          context << format_verify_failure(verify_result)
          context << "\nFix the issues and try again. Do not repeat the same mistake.\n"
        end

        failed_result(last_result)
      end

      private

      def build_prompt(attempt:, context:)
        parts = ["# Task\n#{@task}"]
        parts << context if context.present?
        parts << "\n(This is attempt #{attempt}/#{@max_attempts}.)" if attempt > 1
        parts.join
      end

      def run_agent(prompt)
        agent = build_agent
        agent.chat(prompt)
      end

      def build_agent
        system_prompt = if @skill
                          Skills::Registry.prompt_for(@skill)
                        elsif RailsAiBuild.configuration.universal_builder
                          Builder::Context.system_prompt(workspace: @workspace)
                        end

        Agents::Agent.new(
          provider: @provider,
          model: @model,
          system_prompt: system_prompt,
          workspace: @workspace
        )
      end

      def verify_workspace
        tool = Tools::RunRailsCheckTool.new(workspace: @workspace)
        result = tool.call({ "checks" => %w[zeitwerk test] })
        { passed: result[:passed], checks: result[:checks], output: result }
      rescue StandardError => e
        { passed: false, error: e.message }
      end

      def format_verify_failure(verify_result)
        if verify_result[:checks]
          verify_result[:checks].filter_map do |name, check|
            next if check[:passed]

            "#{name}: exit #{check[:exit_code]}\n#{check[:stdout].to_s[0, 2000]}"
          end.join("\n\n")
        else
          verify_result[:error].to_s
        end
      end

      def success_result(agent_result, verify_result)
        Result.new(
          task: @task,
          status: :success,
          attempts: @attempts,
          content: agent_result[:content],
          iterations: agent_result[:iterations],
          usage: agent_result[:usage],
          verify: verify_result,
          messages: agent_result[:messages]
        )
      end

      def failed_result(agent_result)
        Result.new(
          task: @task,
          status: :failed,
          attempts: @attempts,
          content: agent_result&.dig(:content),
          iterations: agent_result&.dig(:iterations),
          usage: agent_result&.dig(:usage),
          verify: @attempts.last&.dig(:verify),
          messages: agent_result&.dig(:messages)
        )
      end
    end
  end
end
