# frozen_string_literal: true

require 'json'

module RailsAiBuild
  module Ai
    # Model-first AI driver — the brain of rails_ai_build (like Cursor / Claude).
    # Generator-first: IntentRouter scores catalog entries; AI fills gaps / custom logic only.
    class Driver
      Result = Struct.new(
        :content, :session, :context, :iterations, :usage, :messages, :finish_reason,
        :generator_plan, :host_safety,
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
            generator_plan: generator_plan,
            host_safety: host_safety,
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
        @generator_plan = nil
        @generator_result = nil
        @host_safety = nil
        emit(on_event, :status, { phase: 'start', message: 'Understanding your request…' })

        Intelligence.prepare!(workspace: @workspace, on_event: on_event)
        session_info = HostSafety.begin_session!(@session.id, workspace: @workspace, on_event: on_event)
        @workspace = Pathname(session_info[:workspace]) if session_info[:workspace]

        begin
          route_generators!(message, on_event)

          if skip_ai_after_generator?
            return finish_generator_only!(message, on_event)
          end

          emit(on_event, :status, { phase: 'context', message: 'Gathering app context…' })
          context = ContextEngine.snapshot(workspace: @workspace)
          emit(on_event, :context, context.to_h)

          @session.add_message(Agents::Message.user(augmented_user_message(message)))
          agent = build_agent(context)

          emit(on_event, :status, {
                 phase: 'think',
                 message: "Thinking with #{@provider}/#{@model || 'default'}…"
               })

          runner = Agents::Runner.new(agent: agent)
          wire_streaming(runner, on_event)

          result = runner.run!

          content = result[:content].to_s
          @host_safety = HostSafety.verify_after_turn!(
            workspace: @workspace,
            session_id: @session.id,
            on_event: on_event
          )
          content = append_safety_note(content)
          result = result.merge(content: content)

          @session.add_message(Agents::Message.assistant(content))
          emit(on_event, :status, { phase: 'done', message: finish_message(result) })
          emit(on_event, :done, done_payload(result))

          build_result(result, context)
        ensure
          HostSafety.end_session!
        end
      end

      TOOL_STATUS_TEMPLATES = {
        'write_file' => ->(ctx) { "Writing #{ctx[:path] || 'file'}…" },
        'read_file' => ->(ctx) { "Reading #{ctx[:path] || 'file'}…" },
        'grep' => ->(ctx) { ctx[:query] ? "Searching codebase for #{ctx[:query]}…" : 'Searching codebase…' },
        'list_files' => ->(_ctx) { 'Listing files…' },
        'shell' => ->(_ctx) { 'Running shell command…' },
        'run_generator' => ->(ctx) { "Running rails g #{ctx[:generator] || '…'}…" },
        'host_safety_check' => ->(_ctx) { 'Running Host Safety ladder…' },
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

      def route_generators!(message, on_event)
        return unless RailsAiBuild.configuration.generator_first != false

        emit(on_event, :status, { phase: 'route', message: 'Matching Rails generators…' })
        @generator_plan = Generators::IntentRouter.plan(message, skill: @skill, workspace: @workspace)
        emit(on_event, :generator_plan, @generator_plan.to_h)

        return unless @generator_plan.mode == :generator

        emit(on_event, :status, {
               phase: 'generator',
               message: "Running rails g #{@generator_plan.generator} #{Array(@generator_plan.args).join(' ')}…".strip
             })
        @generator_result = Generators::Runner.execute!(
          @generator_plan,
          workspace: @workspace,
          session_id: @session.id
        )
        emit(on_event, :generator_result, @generator_result.to_h)
        Array(@generator_result.created_files).each do |path|
          @applied_files << { path: path, status: 'generated' }
        end
      rescue SecurityError, ToolError => e
        emit(on_event, :status, { phase: 'generator', message: "Generator skipped: #{e.message}" })
        @generator_result = nil
      end

      def skip_ai_after_generator?
        return false unless @generator_result&.ok
        return false if @generator_plan&.ai_followup

        true
      end

      def finish_generator_only!(message, on_event)
        files = Array(@generator_result.created_files)
        content = [
          "Ran `#{@generator_result.command}`.",
          files.any? ? "Created: #{files.join(', ')}." : 'Generator finished.',
          'No custom AI follow-up required for this request.'
        ].join(' ')

        context = ContextEngine.snapshot(workspace: @workspace)
        @session.add_message(Agents::Message.user(message))
        @host_safety = HostSafety.verify_after_turn!(
          workspace: @workspace,
          session_id: @session.id,
          on_event: on_event
        )
        content = append_safety_note(content)
        @session.add_message(Agents::Message.assistant(content))

        result = {
          content: content,
          iterations: 0,
          usage: {},
          finish_reason: 'generator',
          messages: @session.messages
        }
        emit(on_event, :delta, { content: content, final: true })
        emit(on_event, :status, { phase: 'done', message: finish_message(result) })
        emit(on_event, :done, done_payload(result))
        build_result(result, context)
      end

      def augmented_user_message(message)
        return message unless @generator_plan

        notes = []
        if @generator_result&.ok
          notes << "GENERATOR ALREADY RAN: `#{@generator_result.command}`"
          notes << "Created files: #{Array(@generator_result.created_files).join(', ')}" if @generator_result.created_files.any?
          notes << 'Customize with write_file only where needed; do not re-run the same generator.'
        elsif @generator_plan.mode == :hybrid
          notes << "GENERATOR CANDIDATE: #{@generator_plan.generator} (#{@generator_plan.reason})"
          notes << "Suggested args: #{Array(@generator_plan.args).inspect}"
          notes << 'Call run_generator with complete args before inventing files with write_file.'
        elsif @generator_plan.mode == :generator && @generator_result && !@generator_result.ok
          notes << "GENERATOR FAILED: `#{@generator_result.command}` — #{@generator_result.stderr}"
          notes << 'Diagnose and fix, or call run_generator with corrected args.'
        end
        return message if notes.empty?

        "#{message}\n\n[RailsAiBuild routing]\n#{notes.join("\n")}"
      end

      def append_safety_note(content)
        return content unless @host_safety&.dig(:rolled_back)

        "#{content}\n\n⚠️ Host Safety rolled back this turn's file changes " \
          "(#{@host_safety[:failure_class]}). The app should still boot — retry with a safer approach " \
          '(prefer `run_generator`).'
      end

      def build_agent(_context)
        system = ContextEngine.system_prompt(
          workspace: @workspace,
          session: @session,
          skill: @skill
        )
        system = [system, generator_system_hint].compact.join("\n\n")

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

      def generator_system_hint
        return unless RailsAiBuild.configuration.generator_first != false

        <<~HINT
          ## When to use generators (Host Safety)
          Use `run_generator` only when the user asks to create a new scaffold/model/migration/controller/mailer/job/channel/devise.
          For refactor, security hardening, SQL injection fixes, query optimization, or editing existing code:
          use read_file/grep/write_file — do NOT call run_generator or scaffold.
          Ruby syntax is checked before writes; boot-critical failures auto-rollback the turn.
        HINT
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
          model: args['model'] || args[:model],
          generator: args['generator'] || args[:generator]
        }
      end

      def human_tool_result(tool_result)
        parsed = parse_tool_payload(tool_result[:result])
        if parsed.is_a?(Hash) && parsed['status'] == 'written'
          "Applied #{parsed['path']} (#{parsed['bytes_written']} bytes)"
        elsif parsed.is_a?(Hash) && parsed['status'] == 'pending_approval'
          "Queued #{parsed['path']} for review"
        elsif parsed.is_a?(Hash) && parsed['status'] == 'generated'
          "Generated #{Array(parsed['created_files']).join(', ')}"
        else
          "Finished #{tool_result[:name]}"
        end
      end

      def track_applied_file!(tool_result)
        parsed = parse_tool_payload(tool_result[:result])
        return unless parsed.is_a?(Hash)

        if tool_result[:name].to_s == 'run_generator'
          Array(parsed['created_files'] || parsed[:created_files]).each do |path|
            @applied_files << { path: path, status: 'generated' }
          end
          return
        end

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
        if @host_safety&.dig(:rolled_back)
          "Rolled back — Host Safety blocked unsafe changes"
        elsif files.any?
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
          generator_plan: @generator_plan&.to_h,
          host_safety: @host_safety,
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
          finish_reason: runner_result[:finish_reason],
          generator_plan: @generator_plan&.to_h,
          host_safety: @host_safety
        )
      end
    end
  end
end
