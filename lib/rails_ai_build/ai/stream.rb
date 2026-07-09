# frozen_string_literal: true

module RailsAiBuild
  module Ai
    # SSE streaming wrapper for Ai::Driver (Cursor/Claude-style events).
    class Stream
      class << self
        def format(event:, data:)
          Streaming::Sse.format_sse(event: event, data: data)
        end

        def stream_chat(message, session_id: nil, provider: nil, model: nil, skill: nil, &block)
          session = session_id ? Session.find(session_id) : nil

          Driver.stream(
            message,
            session: session,
            provider: provider,
            model: model,
            skill: skill
          ) do |event, data|
            block&.call(format(event: event, data: data))
          end
        end
      end
    end
  end
end
