# frozen_string_literal: true

module RailsAiBuild
  module Concerns
    # Optional engine-wide token gate for production mounts (config.require_engine_token).
    module EngineAuth
      extend ActiveSupport::Concern

      private

      def enforce_engine_token!
        return unless RailsAiBuild.configuration.require_engine_token
        return if engine_auth_exempt?

        token = request.headers["X-Rails-Ai-Build-Token"].presence || params[:settings_token]
        return if Activation.bypass_settings_auth?
        return if Activation.valid_settings_token?(token)

        # Allow bootstrap path to issue the first token
        return if controller_name == "settings" && action_name == "bootstrap"

        render json: {
          error: "Engine authentication required",
          code: "engine_auth_required",
          hint: "Set X-Rails-Ai-Build-Token (from POST /settings/bootstrap) or disable config.require_engine_token"
        }, status: :unauthorized
      end

      def engine_auth_exempt?
        return true if request.get? || request.head?
        return true if controller_name == "billing" && action_name == "webhook"
        return true if controller_name == "slack" && action_name == "command"
        return true if controller_name == "discord" && action_name == "interactions"

        false
      end
    end
  end
end
