# frozen_string_literal: true

module RailsAiBuild
  class SettingsController < ActionController::API
    def show
      render json: Support::Settings.current
    end

    def update
      render json: Support::Settings.update(settings_params)
    end

    private

    def settings_params
      params.permit(:plan, :default_provider, :default_model, :diff_preview,
                    :audit_enabled, :max_agent_iterations, :auto_mount)
    end
  end
end
