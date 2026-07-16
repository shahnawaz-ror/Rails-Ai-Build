# frozen_string_literal: true

module RailsAiBuild
  module Concerns
    # Optional engine-wide token gate for production mounts (config.require_engine_token).
    # When enabled, GET reads of workspace/settings are also protected (5k-company default).
    module EngineAuth
      extend ActiveSupport::Concern

      private

      def enforce_engine_token!
        return unless RailsAiBuild.configuration.require_engine_token
        return if engine_auth_exempt?

        token = request_engine_token
        return if Activation.bypass_settings_auth?
        return if Activation.valid_settings_token?(token)
        return if controller_name == "settings" && action_name == "bootstrap"

        render json: {
          error: "Engine authentication required",
          code: "engine_auth_required",
          hint: "Set X-Rails-Ai-Build-Token (from POST /settings/bootstrap) or disable config.require_engine_token"
        }, status: :unauthorized
      end

      def request_engine_token
        header = request.headers["X-Rails-Ai-Build-Token"].presence
        return header if header
        return nil if production_like_auth?

        params[:settings_token]
      end

      def production_like_auth?
        return true if ENV["RAILS_ENV"].to_s == "production"
        return true if defined?(Rails) && Rails.env.production?

        false
      end

      def engine_auth_exempt?
        # Verified inbound webhooks / bot platforms only
        return true if controller_name == "billing" && action_name == "webhook"
        return true if controller_name == "slack" && action_name == "command"
        return true if controller_name == "discord" && action_name == "interactions"
        return true if controller_name == "health"
        return true if controller_name == "support" && action_name == "doctor" && !strict_read_auth?
        return true if %w[help plans].include?(controller_name) && request.get? && !strict_read_auth?

        false
      end

      def strict_read_auth?
        RailsAiBuild.configuration.require_engine_token_for_reads != false
      end
    end
  end
end
