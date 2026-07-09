# frozen_string_literal: true

module RailsAiBuild
  module Builder
    # Build anything in any Rails app — the gem's primary Cursor-like entry point.
    class Universal
      class << self
        def build(task, **options)
          Tasks::Runtime.new(task: task, **options).run!
        end

        def build!(task, **options)
          result = build(task, **options)
          raise AgentError, "Build failed after #{result.attempts.size} attempts" if result.status == :failed

          result
        end

        def fix(issue, **options)
          build("Fix the following issue in this Rails application:\n#{issue}", skill: :fix, **options)
        end

        def test(path, **options)
          task = if path.present?
                   "Write or fix tests for: #{path}. Run them with run_rails_check."
                 else
                   "Audit test coverage and add missing tests for recent changes."
                 end
          build(task, skill: :tests, **options)
        end
      end
    end
  end
end
