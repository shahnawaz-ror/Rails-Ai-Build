# frozen_string_literal: true

module RailsAiBuild
  module Skills
    class BaseSkill
      class << self
        attr_reader :skill_name, :skill_description

        def name(value = nil)
          return @skill_name if value.nil?
          @skill_name = value.to_s
        end

        def description(value = nil)
          return @skill_description if value.nil?
          @skill_description = value
        end
      end

      def self.prompt
        raise NotImplementedError
      end
    end

    class CrudSkill < BaseSkill
      name "crud"
      description "Scaffold a full Rails CRUD resource with controller, model, views, routes, and RSpec tests"

      def self.prompt
        <<~PROMPT
          You are a senior Rails developer scaffolding a CRUD resource.
          Prefer `run_generator` with scaffold (or model + controller) before write_file.
          Follow these conventions strictly:
          - snake_case file names, CamelCase class names
          - RESTful routes via `resources`
          - Strong parameters in controller
          - ActiveRecord validations in model
          - RSpec request specs + model specs with FactoryBot
          - Hotwire (Turbo Frames) for index/show if views are needed
          Read existing models and controllers first to match project style.
          After the generator, only customize business logic.
        PROMPT
      end
    end

    class AuthSkill < BaseSkill
      name "auth"
      description "Add authentication (Devise or custom) with login, logout, and protected routes"

      def self.prompt
        <<~PROMPT
          You are a senior Rails developer adding authentication.
          Check if Devise is already in the Gemfile before adding it.
          If Devise exists, use `run_generator` with devise (not hand-written auth files).
          Otherwise implement session-based auth with has_secure_password.
          Include: User model, sessions controller, before_action :authenticate_user!
          Add RSpec tests for auth flows.
        PROMPT
      end
    end

    class ApiSkill < BaseSkill
      name "api"
      description "Build a JSON API with serializers, versioning, and request specs"

      def self.prompt
        <<~PROMPT
          You are a senior Rails API developer.
          Prefer `run_generator` for model/controller scaffolding, then customize JSON responses.
          Use namespace :api, version with module Api::V1.
          Return JSON with appropriate HTTP status codes.
          Use jbuilder or manual render json: patterns matching the project.
          Add request specs with JSON response matchers.
          Never expose internal errors in production responses.
        PROMPT
      end
    end

    class TestsSkill < BaseSkill
      name "tests"
      description "Write comprehensive RSpec tests for existing code"

      def self.prompt
        <<~PROMPT
          You are a senior Rails test engineer.
          Write RSpec tests using FactoryBot, shoulda-matchers if present.
          Cover: model validations, associations, scopes, controller actions, edge cases.
          Read the existing spec/ directory structure and match conventions.
          Aim for meaningful tests, not trivial assertions.
          Run tests with bundle exec rspec after writing.
        PROMPT
      end
    end

    class RefactorSkill < BaseSkill
      name "refactor"
      description "Safely refactor code following Rails best practices"

      def self.prompt
        <<~PROMPT
          You are a senior Rails refactoring specialist.
          Make minimal, focused changes. Read all affected files first.
          Extract service objects for complex controller logic.
          Use concerns for shared behavior. Keep fat models skinny controllers.
          Ensure tests still pass after refactoring. Run rspec when done.
        PROMPT
      end
    end

    class MigrationSkill < BaseSkill
      name 'migration'
      description 'Create and run database migrations safely'

      def self.prompt
        <<~PROMPT
          You are a senior Rails database engineer.
          Read database_schema and list_models first.
          Prefer `run_generator` with migration (or model) — do not invent migration files by hand.
          Keep migrations reversible. Add indexes for foreign keys. Use appropriate column types.
          Run rails db:migrate via shell if appropriate, then run_rails_check.
        PROMPT
      end
    end

    class BuildSkill < BaseSkill
      name 'build'
      description 'Build any feature in this Rails application'

      def self.prompt
        Builder::Context.system_prompt
      end
    end

    class FixSkill < BaseSkill
      name 'fix'
      description 'Diagnose and fix bugs, failing tests, or errors'

      def self.prompt
        <<~PROMPT
          You are a senior Rails debugger.
          Read logs (read_logs), failing test output (run_rails_check), and relevant source files.
          Identify root cause, apply minimal fix, verify with run_rails_check.
          Do not refactor unrelated code.
        PROMPT
      end
    end

    class FeatureSkill < BaseSkill
      name 'feature'
      description 'Add a new product feature end-to-end (model → API/UI → tests)'

      def self.prompt
        <<~PROMPT
          You are a senior Rails product engineer shipping a complete feature.
          Explore routes, models, and conventions first.
          Prefer `run_generator` for structure, then write_file for custom logic and tests.
          Deliver: migration (if needed), model, controller, routes, views/API, tests.
          Match Hotwire/API-only patterns detected in the app.
          Verify with run_rails_check before finishing.
        PROMPT
      end
    end

    class Registry
      SKILLS = {
        crud: CrudSkill,
        auth: AuthSkill,
        api: ApiSkill,
        tests: TestsSkill,
        refactor: RefactorSkill,
        migration: MigrationSkill,
        build: BuildSkill,
        fix: FixSkill,
        feature: FeatureSkill
      }.freeze

      class << self
        def all
          SKILLS.map do |key, klass|
            { name: key, description: klass.description }
          end
        end

        def prompt_for(name)
          klass = SKILLS[name.to_sym]
          raise ConfigurationError, "Unknown skill: #{name}" unless klass

          base = Agents::Agent::DEFAULT_SYSTEM_PROMPT
          "#{base}\n\n## Skill: #{klass.name}\n#{klass.prompt}"
        end

        def build_agent(skill:, **options)
          Agents::Agent.new(
            system_prompt: prompt_for(skill),
            **options
          )
        end
      end
    end
  end
end
