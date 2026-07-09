# frozen_string_literal: true

module RailsAiBuild
  class SupportController < ActionController::API
    def doctor
      render json: Support::Doctor.check
    end

    def contact
      render json: {
        github_issues: "https://github.com/shahnawaz-ror/Rails-Ai-Build/issues",
        documentation: "https://github.com/shahnawaz-ror/Rails-Ai-Build#readme",
        email: ENV.fetch("RAILS_AI_BUILD_SUPPORT_EMAIL", "support@railsaibuild.com"),
        community: "https://github.com/shahnawaz-ror/Rails-Ai-Build/discussions",
        version: RailsAiBuild::VERSION
      }
    end
  end
end
