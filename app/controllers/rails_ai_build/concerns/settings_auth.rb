# frozen_string_literal: true

module RailsAiBuild
  module Concerns
    module SettingsAuth
      extend ActiveSupport::Concern

      private

      def require_settings_token!
        return if Activation.bypass_settings_auth?

        token = request.headers["X-Rails-Ai-Build-Token"].presence || params[:settings_token]
        return if Activation.valid_settings_token?(token)

        render json: {
          error: "Settings authentication required",
          code: "settings_auth_required",
          hint: "Send X-Rails-Ai-Build-Token header, or POST /settings/bootstrap once to issue a token"
        }, status: :unauthorized
      end
    end
  end
end
