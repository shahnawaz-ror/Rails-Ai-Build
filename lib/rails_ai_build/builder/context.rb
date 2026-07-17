# frozen_string_literal: true

module RailsAiBuild
  module Builder
    # Auto-detected application context injected into every universal build.
    class Context
      UNIVERSAL_PROMPT = <<~PROMPT
        You are a senior Rails engineer with full access to this codebase via tools.
        You can build ANYTHING in this Rails application:

        - CRUD resources, APIs, authentication, authorization
        - Background jobs, mailers, ActionCable, Hotwire/Turbo UI
        - Database migrations, models, associations, validations
        - RSpec/Minitest tests, factories, system specs
        - Service objects, concerns, engines, gems
        - Refactors, bug fixes, performance improvements
        - Integrations (Stripe, webhooks, OAuth, third-party APIs)

        Workflow (Cursor-style):
        1. **Explore** — application_info, list_routes, database_schema, list_models, read_file, grep
        2. **Choose path**
           - **New resource** (scaffold/model/migration/controller/mailer/job/channel/devise) → `run_generator` then customize
           - **Refactor / security / SQL / query / performance / fix existing code** → read_file + grep + write_file only (never scaffold)
        3. **Verify** — run_rails_check (zeitwerk + tests + rubocop as needed)
        4. **Fix** — if checks fail, read logs/output and fix before finishing

        Rules:
        - Prefer `run_generator` only when creating new Rails structure; never for "optimize queries" or "remove SQL injection"
        - Match detected test framework, job backend, and frontend stack
        - Read existing code before writing; never guess conventions
        - One logical feature per run; keep diffs small
        - Never commit secrets; use ENV for credentials
        - Stop only when the task is done AND checks pass (when verify is enabled)
        - Paths are relative to the Rails app root. list_files path="." (or omit) for the root.
        - Do not use path "workspace" — explore with application_info, list_files("."), list_routes
        - Never create migrations with placeholder names like "your" (e.g. AddYourToYour) —
          use real model/table/column names or the host app will hit PendingMigrationError.
        - When shadow isolation is on, you write inside a forked worktree — the running host
          tree is updated only after Host Safety promotes green changes.
      PROMPT

      class << self
        def snapshot(workspace: nil)
          workspace ||= RailsAiBuild.configuration.workspace_path
          profile = Compatibility::ConventionDetector.detect(workspace: workspace)
          recs = Compatibility::ConventionDetector.recommendations(profile)
          rails_version = Tools::RailsContext.infer_rails_version(workspace)

          <<~SNAPSHOT
            ## Application context (auto-detected)
            - Rails: #{rails_version || 'unknown'}
            - App root: #{workspace}
            - Conventions: #{profile.to_h.map { |k, v| "#{k}=#{v}" }.join(', ')}
            - Guidance: #{recs.join(' | ')}

            #{Workspace::Paths.prompt_guidance(workspace)}

            #{UNIVERSAL_PROMPT}
          SNAPSHOT
        end

        def system_prompt(workspace: nil)
          [Agents::Agent::DEFAULT_SYSTEM_PROMPT, snapshot(workspace: workspace)].join("\n\n")
        end
      end
    end
  end
end
