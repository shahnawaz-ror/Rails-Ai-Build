# frozen_string_literal: true

require 'json'

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
        @applied_files = []
        emit(on_event, :status, { phase: 'start', message: 'Understanding your request…' })

        Intelligence.prepare!(workspace: @workspace, on_event: on_event)

        emit(on_event, :status, { phase: 'context', message: 'Gathering app context…' })
        context = ContextEngine.snapshot(workspace: @workspace)
        emit(on_event, :context, context.to_h)

        @session.add_message(Agents::Message.user(message))
        agent = build_agent(context)

        emit(on_event, :status, {
               phase: 'think',
               message: "Thinking with #{@provider}/#{@model || 'default'}…"
             })

        runner = Agents::Runner.new(agent: agent)
        wire_streaming(runner, on_event)

        result = runner.run!

        @session.add_message(Agents::Message.assistant(result[:content]))
        emit(on_event, :status, { phase: 'done', message: finish_message(result) })
        emit(on_event, :done, done_payload(result))

        build_result(result, context)
      end

      TOOL_STATUS_TEMPLATES = {
        'write_file' => ->(ctx) { "Writing #{ctx[:path] || 'file'}…" },
        'read_file' => ->(ctx) { "Reading #{ctx[:path] || 'file'}…" },
        'grep' => ->(ctx) { ctx[:query] ? "Searching codebase for #{ctx[:query]}…" : 'Searching codebase…' },
        'list_files' => ->(_ctx) { 'Listing files…' },
        'shell' => ->(_ctx) { 'Running shell command…' },
        'run_rails_check' => ->(_ctx) { 'Verifying Rails app (zeitwerk / tests)…' },
        'list_migrations' => ->(_ctx) { 'Inspecting migrations…' },
        'list_routes' => ->(_ctx) { 'Reading routes…' },
        'database_schema' => ->(_ctx) { 'Reading database schema…' },
        'list_models' => ->(_ctx) { 'Listing ActiveRecord models…' },
        'model_attributes' => ->(ctx) { "Inspecting model #{ctx[:path] || ctx[:model] || 'attributes'}…" },
        'application_info' => ->(_ctx) { 'Gathering application info…' },
        'read_logs' => ->(_ctx) { 'Reading logs…' },
        'read_settings' => ->(_ctx) { 'Reading settings…' },
        'list_rake_tasks' => ->(_ctx) { 'Listing rake tasks…' },
        'search_rails_docs' => ->(_ctx) { 'Searching Rails docs…' }
      }.freeze

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

        streamed_tokens = false
        emit(on_event, :session, @session.to_h.merge(model: @model, provider: @provider))

        runner.on(:on_delta) do |chunk|
          emit(on_event, :status, { phase: 'reply', message: 'Streaming reply…' }) unless streamed_tokens
          streamed_tokens = true
          emit(on_event, :delta, { content: chunk[:content].to_s, token: true })
        end

        runner.on(:on_iteration) do |response|
          content = response[:content].to_s
          next if content.empty? || streamed_tokens

          emit(on_event, :delta, { content: content, final: true })
          streamed_tokens = false
        end

        runner.on(:on_tool_call) do |tc|
          emit(on_event, :status, {
                 phase: 'tool',
                 message: human_tool_status(tc[:name], tc[:arguments])
               })
          emit(on_event, :tool_call, { name: tc[:name], arguments: tc[:arguments], tool_call_id: tc[:id] })
        end

        runner.on(:on_tool_result) do |tr|
          track_applied_file!(tr)
          emit(on_event, :tool_result, tr.merge(summary: human_tool_result(tr)))
        end
      end

      def emit(on_event, event, data)
        return unless on_event

        on_event.call(event, data)
      end

      def human_tool_status(name, args)
        ctx = tool_arg_context(args)
        template = TOOL_STATUS_TEMPLATES[name.to_s]
        return template.call(ctx) if template

        "Using tool #{name}…"
      end

      def tool_arg_context(args)
        return {} unless args.is_a?(Hash)

        {
          path: args['path'] || args[:path],
          query: args['query'] || args[:query] || args['pattern'] || args[:pattern],
          model: args['model'] || args[:model]
        }
      end

      def human_tool_result(tool_result)
        parsed = parse_tool_payload(tool_result[:result])
        if parsed.is_a?(Hash) && parsed['status'] == 'written'
          "Applied #{parsed['path']} (#{parsed['bytes_written']} bytes)"
        elsif parsed.is_a?(Hash) && parsed['status'] == 'pending_approval'
          "Queued #{parsed['path']} for review"
        else
          "Finished #{tool_result[:name]}"
        end
      end

      def track_applied_file!(tool_result)
        parsed = parse_tool_payload(tool_result[:result])
        return unless parsed.is_a?(Hash)

        path = parsed['path'] || parsed[:path]
        status = parsed['status'] || parsed[:status]
        return unless path && %w[written pending_approval].include?(status.to_s)

        @applied_files << { path: path, status: status.to_s }
      end

      def parse_tool_payload(result)
        return result unless result.is_a?(String)

        JSON.parse(result)
      rescue StandardError
        nil
      end

      def finish_message(runner_result)
        files = @applied_files || []
        if files.any?
          "Done — #{files.size} file change(s), #{runner_result[:iterations]} step(s)"
        else
          "Done — #{runner_result[:iterations]} step(s)"
        end
      end

      def done_payload(runner_result)
        {
          content: runner_result[:content],
          iterations: runner_result[:iterations],
          usage: runner_result[:usage],
          finish_reason: runner_result[:finish_reason],
          applied_files: @applied_files || [],
          pending_changes: Changes::Store.all(status: :pending).map(&:to_h)
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
