# frozen_string_literal: true

module RailsAiBuild
  module Ai
    # Model-first AI driver — the brain of rails_ai_build (like Cursor / Claude).
    class Driver
      Result = Struct.new(
        :content, :session, :context, :iterations, :usage, :messages, :finish_reason,
        keyword_init: true
      ) do
        def to_h
          {
            content: content,
            session: session&.to_h,
            context: context&.to_h,
            iterations: iterations,
            usage: usage,
            finish_reason: finish_reason,
            pending_changes: Changes::Store.all(status: :pending).map(&:to_h)
          }
        end
      end

      class << self
        def run(message, session: nil, provider: nil, model: nil, skill: nil, workspace: nil)
          new(
            session: session,
            provider: provider,
            model: model,
            skill: skill,
            workspace: workspace
          ).run(message)
        end

        def stream(message, **opts, &)
          new(**opts).run(message, &)
        end
      end

      def initialize(session: nil, provider: nil, model: nil, skill: nil, workspace: nil)
        @session = session || Session.create(model: model, provider: provider)
        @provider = provider || @session.provider
        @model = model || @session.model
        @skill = skill
        @workspace = workspace || RailsAiBuild.configuration.workspace_path
      end

      def run(message, &on_event)
        context = ContextEngine.snapshot(workspace: @workspace)
        emit(on_event, :context, context.to_h)

        @session.add_message(Agents::Message.user(message))
        agent = build_agent(context)

        runner = Agents::Runner.new(agent: agent)
        wire_streaming(runner, on_event)

        result = runner.run!

        @session.add_message(Agents::Message.assistant(result[:content]))
        emit(on_event, :done, done_payload(result))

        build_result(result, context)
      end

      private

      def build_agent(_context)
        system = ContextEngine.system_prompt(
          workspace: @workspace,
          session: @session,
          skill: @skill
        )

        agent = Agents::Agent.new(
          provider: @provider,
          model: @model,
          system_prompt: system,
          workspace: @workspace
        )

        @session.messages.each do |msg|
          next if msg.role == :system

          agent.add_message(msg)
        end

        agent
      end

      def wire_streaming(runner, on_event)
        return unless on_event

        emit(on_event, :session, @session.to_h.merge(model: @model, provider: @provider))

        runner.on(:on_iteration) do |response|
          content = response[:content].to_s
          emit(on_event, :delta, { content: content }) unless content.empty?
        end

        runner.on(:on_tool_call) do |tc|
          emit(on_event, :tool_call, { name: tc[:name], arguments: tc[:arguments] })
        end
      end

      def emit(on_event, event, data)
        return unless on_event

        on_event.call(event, data)
      end

      def done_payload(runner_result)
        {
          content: runner_result[:content],
          iterations: runner_result[:iterations],
          usage: runner_result[:usage],
          finish_reason: runner_result[:finish_reason]
        }
      end

      def build_result(runner_result, context)
        Result.new(
          content: runner_result[:content],
          session: @session,
          context: context,
          iterations: runner_result[:iterations],
          usage: runner_result[:usage],
          messages: runner_result[:messages],
          finish_reason: runner_result[:finish_reason]
        )
      end
    end
  end
end
