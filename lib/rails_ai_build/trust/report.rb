# frozen_string_literal: true

require 'json'
require 'fileutils'

module RailsAiBuild
  module Trust
    # Persists trust run results for README + GitHub Pages dashboard.
    class Report
      LANDING_PATH = File.expand_path('../../../landing/trust/results.json', __dir__)
      SERVER_PATH = File.expand_path('../../../server/public/trust/results.json', __dir__)

      class << self
        def write!(report)
          [LANDING_PATH, SERVER_PATH].each do |path|
            FileUtils.mkdir_p(File.dirname(path))
            File.write(path, JSON.pretty_generate(report))
          end
          report
        end

        def read
          path = File.exist?(LANDING_PATH) ? LANDING_PATH : SERVER_PATH
          return nil unless File.exist?(path)

          JSON.parse(File.read(path))
        end

        def dashboard_url
          ENV.fetch(
            'TRUST_DASHBOARD_URL',
            'https://shahnawaz-ror.github.io/Rails-Ai-Build/trust/'
          )
        end

        def live_api_url
          ENV.fetch(
            'TRUST_LIVE_API_URL',
            'https://rails-ai-build-trust.onrender.com'
          )
        end
      end
    end
  end
end
