# frozen_string_literal: true

module RailsAiBuild
  module Tasks
    # Per-task SSE event buffer — Cursor-style live task streams.
    class EventBus
      class << self
        def emit(task_id, event, data)
          entry = { event: event.to_s, data: data, at: Time.zone.now.iso8601 }
          buffer(task_id) << entry
          listeners(task_id).each { |cb| cb.call(event, data) }
          entry
        end

        def buffer(task_id)
          buffers[task_id.to_s] ||= []
        end

        def subscribe(task_id, &block)
          listeners(task_id.to_s) << block
          buffer(task_id).each { |entry| yield(entry[:event].to_sym, entry[:data]) }
        end

        def clear(task_id)
          buffers.delete(task_id.to_s)
          listeners.delete(task_id.to_s)
        end

        def reset!
          @buffers = {}
          @listeners = {}
        end

        private

        def buffers
          @buffers ||= {}
        end

        def listeners(task_id)
          @listeners ||= {}
          @listeners[task_id.to_s] ||= []
        end
      end
    end
  end
end
