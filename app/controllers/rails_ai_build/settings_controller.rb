# frozen_string_literal: true

module RailsAiBuild
  class SettingsController < ApplicationController
    include Concerns::SettingsAuth

    before_action :require_settings_token!, only: %i[update update_keys activate_license complete_wizard]

    def show
      render json: Support::Settings.current
    end

    def update
      render json: Support::Settings.update(settings_params)
    rescue SecurityError => e
      render json: { error: e.message, code: "forbidden" }, status: :forbidden
    end

    def update_keys
      render json: Support::Settings.update_keys(keys_params)
    rescue ConfigurationError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def activate_license
      render json: Support::Settings.activate_license(params.require(:license_key))
    rescue ConfigurationError => e
      render json: { error: e.message, code: "invalid_license" }, status: :unprocessable_entity
    end

    def complete_wizard
      render json: Activation.complete_wizard!
    end

    def bootstrap
      token = Activation.bootstrap_settings_token!
      render json: {
        settings_token: token,
        issued: true,
        hint: "Store this token and send it as X-Rails-Ai-Build-Token on settings mutations"
      }
    rescue SecurityError, ConfigurationError => e
      render json: { error: e.message, code: "bootstrap_failed" }, status: :unprocessable_entity
    end

    private

    def settings_params
      params.permit(:default_provider, :default_model, :diff_preview,
                    :audit_enabled, :max_agent_iterations, :auto_mount, :plan)
    end

    def keys_params
      params.permit(:cloud_api_key, :openai, :anthropic, :nvidia, :default_provider, api_keys: {})
    end
  end
end
