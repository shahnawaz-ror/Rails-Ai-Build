# frozen_string_literal: true

module RailsAiBuild
  module Streaming
    # Server-Sent Events streaming for agent responses
    class Sse
      class << self
        def stream_chat(message, provider: nil, model: nil, skill: nil, &block)
          agent = build_agent(provider: provider, model: model, skill: skill)
          agent.add_message(Agents::Message.user(message))

          runner = Agents::Runner.new(agent: agent)
          runner.on(:on_iteration) do |response|
            emit(block, event: "iteration",
                        data: { content: response[:content], tool_calls: response[:tool_calls]&.size || 0 })
          end
          runner.on(:on_tool_call) do |tc|
            emit(block, event: "tool_call", data: { name: tc[:name], arguments: tc[:arguments] })
          end

          emit(block, event: "start", data: { message: message })
          result = runner.run!
          emit(block, event: "complete", data: result)
          result
        end

        def format_sse(event:, data:)
          "event: #{event}\ndata: #{JSON.generate(data)}\n\n"
        end

        private

        def build_agent(provider:, model:, skill:)
          if skill
            Skills::Registry.build_agent(skill: skill, provider: provider, model: model)
          else
            Agents::Agent.new(provider: provider, model: model)
          end
        end

        def emit(block, event:, data:)
          block.call(format_sse(event: event, data: data)) if block
        end
      end
    end
  end
end

require "json"
