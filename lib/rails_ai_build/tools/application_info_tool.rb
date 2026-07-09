# frozen_string_literal: true

module RailsAiBuild
  module Tools
    class ApplicationInfoTool < BaseTool
      name 'application_info'
      description 'Return Rails application metadata: versions, gem stack, and detected conventions.'
      parameters type: 'object',
                 properties: {},
                 required: []

      def execute(_args)
        rails_version = RailsContext.infer_rails_version(workspace)
        profile = Compatibility::ConventionDetector.detect(workspace: workspace)

        {
          rails_version: rails_version,
          ruby_version: RailsContext.infer_ruby_version(workspace),
          rails_loaded: RailsContext.rails_loaded?,
          environment: rails_env,
          gemfile_gems: count_gemfile_gems,
          conventions: profile.to_h,
          recommendations: Compatibility::ConventionDetector.recommendations(profile),
          engine: RailsContext.rails_loaded? ? Rails.application.class.name : nil
        }
      end

      private

      def rails_env
        return Rails.env if RailsContext.rails_loaded?

        env_file = workspace.join('config/environment.rb')
        return 'development' unless env_file.exist?

        ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
      end

      def count_gemfile_gems
        gemfile = workspace.join('Gemfile')
        return 0 unless gemfile.exist?

        gemfile.read.lines.count { |line| line.match?(/^\s*gem\s+['"]/) }
      end
    end
  end
end
