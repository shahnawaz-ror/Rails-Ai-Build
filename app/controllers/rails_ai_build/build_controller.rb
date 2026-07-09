# frozen_string_literal: true

module RailsAiBuild
  class BuildController < ActionController::API
    def create
      body = params.permit(:task, :provider, :model, :skill, :verify, :max_attempts, :workspace)

      workspace = body[:workspace].present? ? Pathname.new(body[:workspace]) : nil
      Audit.current_user = request.headers['X-User-Id'] || 'api'

      result = Builder::Universal.build(
        body[:task],
        provider: body[:provider],
        model: body[:model],
        skill: body[:skill],
        verify: body[:verify].nil? ? nil : ActiveModel::Type::Boolean.new.cast(body[:verify]),
        max_attempts: body[:max_attempts]&.to_i,
        workspace: workspace
      )

      status = result.status == :success ? :ok : :unprocessable_entity
      render json: result.to_h, status: status
    rescue Error => e
      render json: { error: e.message }, status: :unprocessable_content
    end
  end
end
