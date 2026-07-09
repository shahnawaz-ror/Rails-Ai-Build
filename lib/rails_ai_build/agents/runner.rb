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
        @callbacks = { on_iteration: [], on_tool_call: [], on_complete: [] }
      end

      def on(event, &block)
        @callbacks[event] << block if @callbacks.key?(event)
        self
      end

      def run!
        max = RailsAiBuild.configuration.max_agent_iterations

        loop do
          @iterations += 1
          raise AgentError, "Max iterations (#{max}) exceeded" if @iterations > max

          response = agent.provider.chat(
            messages: agent.messages,
            tools: agent.tool_definitions,
            model: agent.model
          )

          @last_response = response
          fire(:on_iteration, response)

          tool_calls = response[:tool_calls] || []

          agent.add_message(
            Message.assistant(response[:content], tool_calls: tool_calls.presence)
          )

          break if tool_calls.empty?

          tool_calls.each do |tc|
            fire(:on_tool_call, tc)
            result = agent.execute_tool(tc[:name], tc[:arguments])

            agent.add_message(
              Message.tool(
                format_tool_result(result),
                tool_call_id: tc[:id],
                name: tc[:name]
              )
            )
          end
        end

        fire(:on_complete, @last_response)
        build_result
      end

      private

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
