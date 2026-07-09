# frozen_string_literal: true

module RailsAiBuild
  module Compatibility
    # Detects project conventions from Gemfile and directory layout.
    # Informed by patterns across 1000 GitHub Rails repos.
    class ConventionDetector
      PROFILE = Struct.new(
        :test_framework, :job_backend, :frontend, :api_only, :orm, :features,
        keyword_init: true
      )

      class << self
        def detect(workspace: nil)
          workspace ||= RailsAiBuild.configuration.workspace_path
          gemfile = read_gemfile(workspace)
          app_rb = read_application_rb(workspace)

          PROFILE.new(
            test_framework: detect_test_framework(gemfile, workspace),
            job_backend: detect_job_backend(gemfile),
            frontend: detect_frontend(gemfile),
            api_only: api_only?(app_rb, gemfile),
            orm: detect_orm(gemfile),
            features: detect_features(gemfile, workspace)
          )
        end

        def recommendations(profile = nil)
          profile ||= detect
          recs = []

          recs << 'Use RSpec skill and factories' if profile.test_framework == :rspec
          recs << 'Use Minitest generators' if profile.test_framework == :minitest
          recs << 'Enable Turbo/Hotwire skill for UI changes' if profile.frontend == :hotwire
          recs << 'Skip view/ERB tools — API-only app' if profile.api_only
          recs << "Use background job skill (#{profile.job_backend})" if profile.job_backend
          recs << 'Prefer service objects for monolith extraction' if profile.features.include?(:service_objects)

          recs
        end

        def to_h(workspace: nil)
          detect(workspace: workspace).to_h
        end

        private

        def read_gemfile(workspace)
          path = workspace.join('Gemfile')
          path.exist? ? path.read : ''
        end

        def read_application_rb(workspace)
          path = workspace.join('config/application.rb')
          path.exist? ? path.read : ''
        end

        def detect_test_framework(gemfile, workspace)
          return :rspec if gemfile.include?('rspec') || workspace.join('spec').directory?
          return :minitest if workspace.join('test').directory?

          :unknown
        end

        def detect_job_backend(gemfile)
          return :sidekiq if gemfile.match?(/gem ['"]sidekiq['"]/)
          return :solid_queue if gemfile.include?('solid_queue')
          return :good_job if gemfile.include?('good_job')
          return :delayed_job if gemfile.include?('delayed_job')

          nil
        end

        def detect_frontend(gemfile)
          return :hotwire if gemfile.match?(/turbo-rails|stimulus-rails|hotwire/)
          return :webpacker if gemfile.include?('webpacker')
          return :importmap if gemfile.include?('importmap-rails')

          :classic
        end

        def api_only?(app_rb, gemfile)
          app_rb.include?('api_only = true') || gemfile.match?(/rails.*--api/)
        end

        def detect_orm(gemfile)
          return :sequel if gemfile.include?('sequel')
          return :mongoid if gemfile.include?('mongoid')

          :active_record
        end

        def detect_features(gemfile, workspace)
          features = []
          features << :devise if gemfile.include?('devise')
          features << :pundit if gemfile.include?('pundit')
          features << :sidekiq if gemfile.include?('sidekiq')
          features << :stripe if gemfile.include?('stripe')
          features << :service_objects if workspace.join('app/services').directory?
          features
        end
      end
    end
  end
end
