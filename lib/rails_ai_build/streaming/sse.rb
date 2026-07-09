# frozen_string_literal: true

module RailsAiBuild
  module Streaming
    # Server-Sent Events streaming for agent responses
    class Sse
      class << self
        def stream_chat(message, provider: nil, model: nil, skill: nil, session_id: nil, &block)
          Ai::Stream.stream_chat(
            message,
            session_id: session_id,
            provider: provider,
            model: model,
            skill: skill,
            &block
          )
        end

        def format_sse(event:, data:)
          "event: #{event}\ndata: #{JSON.generate(data)}\n\n"
        end
      end
    end
  end
end

require "json"
