# frozen_string_literal: true

require "securerandom"

module RailsAiBuild
  module Agents
    class Runner
      attr_reader :agent, :iterations, :last_response

      def initialize(agent:)
        @agent = agent
        @iterations = 0
        @last_response = nil
        @callbacks = {
          on_iteration: [],
          on_tool_call: [],
          on_tool_result: [],
          on_delta: [],
          on_complete: []
        }
      end

      def on(event, &block)
        @callbacks[event] << block if @callbacks.key?(event)
        self
      end

      def run!
        max = RailsAiBuild.configuration.max_agent_iterations
        stream_tokens = @callbacks[:on_delta].any?

        loop do
          @iterations += 1
          raise AgentError, "Max iterations (#{max}) exceeded" if @iterations > max

          response = fetch_response(stream_tokens: stream_tokens)
          @last_response = response
          fire(:on_iteration, response)
          track_usage(response)

          tool_calls = response[:tool_calls] || []
          agent.add_message(Message.assistant(response[:content], tool_calls: tool_calls.presence))
          break if tool_calls.empty?

          execute_tool_calls(tool_calls)
        end

        fire(:on_complete, @last_response)
        result = build_result
        Analytics.track_agent_run(result: result, provider: agent.provider_name, model: agent.model)
        result
      end

      private

      def fetch_response(stream_tokens:)
        agent.provider.chat(
          messages: agent.messages,
          tools: agent.tool_definitions,
          model: agent.model,
          on_delta: stream_tokens ? method(:emit_delta) : nil
        )
      end

      def track_usage(response)
        TokenUsage.track(
          response: response,
          provider: agent.provider_name,
          model: agent.model,
          event: "agent.iteration"
        )
      end

      def execute_tool_calls(tool_calls)
        tool_calls.each do |tc|
          fire(:on_tool_call, tc)
          result = begin
            agent.execute_tool(tc[:name], tc[:arguments])
          rescue ToolError, SecurityError => e
            # Return error to the model so it can fall back (e.g. write_file)
            # instead of aborting the turn with no Done / Changes summary.
            {
              error: e.message,
              hint: fallback_hint_for(tc[:name], e)
            }
          end
          formatted = format_tool_result(result)
          fire(:on_tool_result, { name: tc[:name], tool_call_id: tc[:id], result: formatted })
          agent.add_message(Message.tool(formatted, tool_call_id: tc[:id], name: tc[:name]))
        end
      end

      def fallback_hint_for(tool_name, error)
        if tool_name.to_s == "run_generator" || error.message.to_s.include?("run_generator")
          "Do not retry run_generator. Use read_file/grep to find the code, then write_file for a minimal fix."
        elsif error.message.to_s.include?("not allowed")
          "That tool is not available. Continue with read_file, grep, list_files, and write_file only."
        else
          "Fix the issue or try a smaller write_file change."
        end
      end

      def emit_delta(chunk)
        fire(:on_delta, chunk)
      end

      def format_tool_result(result)
        case result
        when String then result
        when Hash then JSON.pretty_generate(result)
        else result.to_s
        end
      end

      def fire(event, *args)
        @callbacks[event].each { |cb| cb.call(*args) }
      end

      def build_result
        {
          content: @last_response[:content],
          iterations: @iterations,
          messages: agent.messages,
          usage: @last_response[:usage],
          finish_reason: @last_response[:finish_reason]
        }
      end
    end
  end
end

require "json"
