# frozen_string_literal: true

require 'securerandom'

module RailsAiBuild
  module Tasks
    # In-memory multitask queue — Cursor-style parallel background builds.
    #
    # Uses a bounded worker pool. Workers must NOT recursively spawn more
    # workers on every exit (that previously exhausted OS threads).
    class Queue
      Task = Struct.new(
        :id, :description, :status, :skill, :verify, :result, :error,
        :branch, :pr_url, :compare_url,
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
            branch: branch,
            pr_url: pr_url,
            compare_url: compare_url || pr_url,
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
          assign_branch!(task)
          EventBus.emit(task.id, :queued, { id: task.id, description: task.description, branch: task.branch })
          if RailsAiBuild.configuration.sync_tasks
            run_task_safely(task)
          else
            ensure_workers!
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
          EventBus.emit(task.id, :cancelled, task.to_h)
          task
        end

        def clear_finished!
          store.delete_if { |_, t| %i[success failed cancelled].include?(t.status) }
        end

        def reset!
          @store = {}
          @meta = {}
          @mutex = Mutex.new
          @workers = []
          EventBus.reset!
        end

        private

        def ensure_enabled!
          return if RailsAiBuild.configuration.multitask_enabled

          raise ConfigurationError,
                'Multitask queue requires multitask_enabled (Team+ recommended)'
        end

        def assign_branch!(task)
          return unless RailsAiBuild.configuration.branch_per_task

          task.branch = "ai/task-#{task.id.to_s[0, 8]}"
          Integrations::Git.create_branch(task.branch)
        rescue StandardError
          task.branch = nil
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

        def workers
          @workers ||= []
        end

        # Fill the pool up to max_concurrent_tasks. Never recursively explode.
        def ensure_workers!
          mutex.synchronize do
            workers.select!(&:alive?)
            max = [RailsAiBuild.configuration.max_concurrent_tasks.to_i, 1].max
            queued = store.values.count { |task| task.status == :queued }
            return if queued.zero?

            needed = [max - workers.size, queued].min
            needed.times do
              workers << Thread.new { drain_queue }
            end
          end
        end

        def drain_queue
          loop do
            task = claim_next
            break unless task

            run_task_safely(task)
          end
        ensure
          # Drop this thread from the pool before refill so exiting workers don't
          # count against max_concurrent_tasks (and never recurse unboundedly).
          mutex.synchronize { workers.delete(Thread.current) }
          ensure_workers!
        end

        def claim_next
          mutex.synchronize do
            task = store.values.find { |candidate| candidate.status == :queued }
            return nil unless task

            task.status = :running
            task.started_at = Time.zone.now
            task
          end
        end

        def run_task_safely(task)
          run_task(task)
        rescue StandardError => e
          task.status = :failed
          task.error = e.message
          task.finished_at = Time.zone.now
          EventBus.emit(task.id, :error, { error: e.message })
        end

        def run_task(task)
          meta = metadata(task.id)
          EventBus.emit(task.id, :running, { id: task.id, branch: task.branch })

          # Mark running before work so slot accounting is accurate for sync mode too.
          task.status = :running
          task.started_at ||= Time.zone.now

          result = Runtime.new(
            task: task.description,
            skill: task.skill,
            verify: task.verify,
            provider: meta[:provider],
            model: meta[:model],
            task_id: task.id
          ).run!

          task.result = result
          task.status = result.status
          task.finished_at = Time.zone.now
          attach_pr!(task) if result.status == :success
          EventBus.emit(task.id, :finished, task.to_h)
          Analytics.track_basic(event: 'task.completed', metadata: { status: task.status }) if defined?(Analytics)
        end

        def attach_pr!(task)
          return unless RailsAiBuild.configuration.auto_pr_on_complete

          pr = Integrations::PullRequest.create(
            title: "AI: #{task.description.to_s[0, 72]}",
            existing_branch: task.branch
          )
          task.pr_url = pr[:pr_url]
          task.compare_url = pr[:compare_url] || pr[:pr_url]
          EventBus.emit(task.id, :pr_ready, { pr_url: task.pr_url, compare_url: task.compare_url, branch: pr[:branch] })
        rescue StandardError => e
          EventBus.emit(task.id, :pr_skipped, { reason: e.message })
        end
      end
    end
  end
end
