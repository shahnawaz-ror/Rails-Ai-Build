# frozen_string_literal: true

require 'securerandom'

module RailsAiBuild
  module Tasks
    # In-memory multitask queue — Cursor-style parallel background builds.
    class Queue
      Task = Struct.new(
        :id, :description, :status, :skill, :verify, :result, :error,
        :created_at, :started_at, :finished_at,
        keyword_init: true
      ) do
        def to_h
          {
            id: id,
            description: description,
            status: status,
            skill: skill,
            verify: verify,
            result: result&.to_h,
            error: error,
            created_at: created_at,
            started_at: started_at,
            finished_at: finished_at
          }.compact
        end
      end

      STATUSES = %i[queued running success failed cancelled].freeze

      class << self
        def enqueue(description, skill: nil, verify: nil, provider: nil, model: nil)
          ensure_enabled!
          task = Task.new(
            id: SecureRandom.uuid,
            description: description.to_s,
            status: :queued,
            skill: skill,
            verify: verify,
            created_at: Time.zone.now
          )
          store[task.id] = task
          metadata(task.id)[:provider] = provider
          metadata(task.id)[:model] = model
          if RailsAiBuild.configuration.sync_tasks
            run_task(task)
          else
            spawn_workers
          end
          task
        end

        def all
          store.values.sort_by(&:created_at).reverse.map(&:to_h)
        end

        def find(id)
          store[id]
        end

        def cancel(id)
          task = store[id]
          return nil unless task
          return task if task.status == :running

          task.status = :cancelled
          task.finished_at = Time.zone.now
          task
        end

        def clear_finished!
          store.delete_if { |_, t| %i[success failed cancelled].include?(t.status) }
        end

        def reset!
          @store = {}
          @meta = {}
          @mutex = Mutex.new
        end

        private

        def ensure_enabled!
          return if RailsAiBuild.configuration.multitask_enabled

          raise ConfigurationError,
                'Multitask queue requires multitask_enabled (Team+ recommended)'
        end

        def store
          @store ||= {}
        end

        def metadata(id)
          @meta ||= {}
          @meta[id] ||= {}
        end

        def mutex
          @mutex ||= Mutex.new
        end

        def spawn_workers
          max = RailsAiBuild.configuration.max_concurrent_tasks
          running = store.values.count { |t| t.status == :running }
          slots = [max - running, 0].max
          slots.times { Thread.new { process_next } }
        end

        def process_next
          task = nil
          mutex.synchronize do
            task = store.values.find { |t| t.status == :queued }
            task.status = :running if task
            task.started_at = Time.zone.now if task
          end
          return unless task

          run_task(task)
        rescue StandardError => e
          task.status = :failed
          task.error = e.message
          task.finished_at = Time.zone.now
        ensure
          spawn_workers
        end

        def run_task(task)
          meta = metadata(task.id)
          result = Runtime.new(
            task: task.description,
            skill: task.skill,
            verify: task.verify,
            provider: meta[:provider],
            model: meta[:model]
          ).run!

          task.result = result
          task.status = result.status
          task.finished_at = Time.zone.now
          Analytics.track_basic(event: 'task.completed', metadata: { status: task.status }) if defined?(Analytics)
        end
      end
    end
  end
end
