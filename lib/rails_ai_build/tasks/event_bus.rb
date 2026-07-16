# frozen_string_literal: true

require "monitor"

module RailsAiBuild
  module Tasks
    # Per-task SSE event buffer — Cursor-style live task streams.
    # Caps buffers/listeners so long-running mounts cannot leak memory.
    class EventBus
      MAX_EVENTS_PER_TASK = 500
      MAX_TASKS = 2_000

      class << self
        def emit(task_id, event, data)
          entry = { event: event.to_s, data: data, at: Time.now.utc.iso8601 }
          callbacks = nil
          mutex.synchronize do
            buf = buffer!(task_id)
            buf << entry
            buf.shift while buf.size > MAX_EVENTS_PER_TASK
            evict_tasks! if buffers.size > MAX_TASKS
            callbacks = listeners(task_id).dup
          end
          callbacks.each { |cb| safe_call(cb, event, data) }
          entry
        end

        def buffer(task_id)
          mutex.synchronize { (buffers[task_id.to_s] || []).dup }
        end

        def subscribe(task_id, &block)
          raise ArgumentError, "block required" unless block

          mutex.synchronize do
            listeners(task_id) << block
            buffer!(task_id).each { |entry| safe_call(block, entry[:event].to_sym, entry[:data]) }
          end
          -> { unsubscribe(task_id, block) }
        end

        def unsubscribe(task_id, block)
          mutex.synchronize { listeners(task_id).delete(block) }
        end

        def clear(task_id)
          mutex.synchronize do
            buffers.delete(task_id.to_s)
            @listeners&.delete(task_id.to_s)
          end
        end

        def reset!
          mutex.synchronize do
            @buffers = {}
            @listeners = {}
          end
        end

        private

        def mutex
          @mutex ||= Monitor.new
        end

        def buffers
          @buffers ||= {}
        end

        def buffer!(task_id)
          buffers[task_id.to_s] ||= []
        end

        def listeners(task_id)
          @listeners ||= {}
          @listeners[task_id.to_s] ||= []
        end

        def evict_tasks!
          overflow = buffers.size - MAX_TASKS
          return if overflow <= 0

          overflow.times do
            key = buffers.keys.first
            break unless key

            buffers.delete(key)
            @listeners&.delete(key)
          end
        end

        def safe_call(callback, event, data)
          callback.call(event, data)
        rescue StandardError
          nil
        end
      end
    end
  end
end
