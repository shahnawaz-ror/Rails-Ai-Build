# frozen_string_literal: true

module RailsAiBuild
  module Tasks
    # Cursor-style task runtime: build → verify → restart on failure.
    class Runtime
      Result = Struct.new(
        :task, :status, :attempts, :content, :iterations, :usage, :verify, :messages,
        :host_safety, :session_id,
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
            host_safety: host_safety,
            session_id: session_id,
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
        max_attempts: nil,
        task_id: nil,
        session_id: nil,
        session: nil
      )
        @task = task.to_s
        @workspace = workspace || RailsAiBuild.configuration.workspace_path
        @provider = provider
        @model = model
        @skill = skill
        @verify = verify.nil? ? RailsAiBuild.configuration.verify_builds : verify
        @max_attempts = max_attempts || RailsAiBuild.configuration.build_max_attempts
        @task_id = task_id
        @session = session
        @session_id = session_id || session&.id
        @attempts = []
      end

      def run!(&on_event)
        streaming = on_event || @task_id
        emit = streaming ? build_emitter(on_event) : nil
        emit&.call(:start, { task: @task })
        context = +''
        last_result = nil

        @max_attempts.times do |i|
          emit&.call(:attempt, { number: i + 1, max: @max_attempts })
          prompt = build_prompt(attempt: i + 1, context: context)
          last_result = run_agent(prompt, emit)
          verify_result = @verify ? verify_workspace : { passed: true, skipped: true }
          emit&.call(:verify, verify_result)

          attempt_record = {
            number: i + 1,
            iterations: last_result[:iterations],
            verify: verify_result,
            content: last_result[:content]
          }
          @attempts << attempt_record

          if verify_result[:passed]
            result = success_result(last_result, verify_result)
            emit&.call(:complete, result.to_h)
            return result
          end

          context << "\n\n## Attempt #{i + 1} failed verification\n"
          context << format_verify_failure(verify_result)
          context << "\nFix the issues and try again. Do not repeat the same mistake.\n"
        end

        result = failed_result(last_result)
        result = apply_verify_fail_rollback!(result, last_result, emit)
        emit&.call(:complete, result.to_h)
        result
      end

      private

      def build_emitter(on_event)
        lambda do |event, data|
          on_event&.call(event, data)
          EventBus.emit(@task_id, event, data) if @task_id
        end
      end

      def build_prompt(attempt:, context:)
        parts = ["# Task\n#{@task}"]
        parts << context if context.present?
        parts << "\n(This is attempt #{attempt}/#{@max_attempts}.)" if attempt > 1
        parts.join
      end

      def run_agent(prompt, emit)
        session = resolve_session!
        result = if emit
                   Ai::Driver.stream(
                     prompt,
                     session: session,
                     provider: @provider,
                     model: @model,
                     skill: @skill,
                     workspace: @workspace
                   ) do |event, data|
                     emit.call(event, data)
                   end
                 else
                   Ai::Driver.run(
                     prompt,
                     session: session,
                     provider: @provider,
                     model: @model,
                     skill: @skill,
                     workspace: @workspace
                   )
                 end
        @session = result.session if result.session
        @session_id = @session&.id
        {
          content: result.content,
          iterations: result.iterations,
          usage: result.usage,
          messages: result.messages,
          session_id: result.session&.id,
          host_safety: result.host_safety
        }
      end

      def resolve_session!
        return @session if @session

        @session = Ai::Session.find(@session_id) if @session_id.present?
        @session ||= Ai::Session.create(provider: @provider, model: @model)
        @session_id = @session.id
        @session
      end

      def verify_workspace
        tool = Tools::RunRailsCheckTool.new(workspace: @workspace)
        result = tool.call({ 'checks' => %w[zeitwerk test] })
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

      def apply_verify_fail_rollback!(result, last_result, emit)
        return result unless RailsAiBuild.configuration.host_safety_rollback_on_verify_fail != false
        return result unless RailsAiBuild.configuration.host_safety != false

        session_id = last_result&.dig(:session_id)
        return result if session_id.blank?

        emit&.call(:status, { phase: 'rollback', message: 'Verify failed — Host Safety rolling back session…' })
        rolled = Changes::Store.rollback_session(session_id, workspace: @workspace)
        host_safety = {
          healthy: false,
          failure_class: :test,
          rolled_back: true,
          rollback: rolled,
          session_id: session_id,
          phase: 'report'
        }
        emit&.call(:host_safety, host_safety)
        Result.new(
          task: result.task,
          status: result.status,
          attempts: result.attempts,
          content: "#{result.content}\n\n⚠️ Host Safety rolled back session changes after verify failures.",
          iterations: result.iterations,
          usage: result.usage,
          verify: result.verify,
          messages: result.messages,
          host_safety: host_safety,
          session_id: session_id
        )
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
          messages: agent_result[:messages],
          host_safety: agent_result[:host_safety],
          session_id: agent_result[:session_id]
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
          messages: agent_result&.dig(:messages),
          host_safety: agent_result&.dig(:host_safety),
          session_id: agent_result&.dig(:session_id)
        )
      end
    end
  end
end
