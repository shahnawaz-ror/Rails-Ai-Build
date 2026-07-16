# frozen_string_literal: true

module RailsAiBuild
  module Concerns
    module SettingsAuth
      extend ActiveSupport::Concern

      private

      def require_settings_token!
        return if Activation.bypass_settings_auth?

        token = request.headers["X-Rails-Ai-Build-Token"].presence
        unless token
          if production_like_settings_auth?
            render json: {
              error: "Settings authentication required",
              code: "settings_auth_required",
              hint: "Send X-Rails-Ai-Build-Token header (query/body tokens disabled in production)"
            }, status: :unauthorized
            return
          end
          token = params[:settings_token]
        end

        return if Activation.valid_settings_token?(token)

        render json: {
          error: "Settings authentication required",
          code: "settings_auth_required",
          hint: "Send X-Rails-Ai-Build-Token header, or POST /settings/bootstrap once to issue a token"
        }, status: :unauthorized
      end

      def production_like_settings_auth?
        return true if ENV["RAILS_ENV"].to_s == "production"
        return true if defined?(Rails) && Rails.env.production?

        false
      end
    end
  end
end
