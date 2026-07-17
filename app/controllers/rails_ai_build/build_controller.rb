# frozen_string_literal: true

module RailsAiBuild
  class BuildController < ApplicationController
    include ActionController::Live

    def create
      body = params.permit(:task, :provider, :model, :skill, :verify, :max_attempts, :workspace)

      workspace = sanitize_workspace_param(body[:workspace])
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

    def stream
      response.headers['Content-Type'] = 'text/event-stream'
      response.headers['Cache-Control'] = 'no-cache'
      response.headers['X-Accel-Buffering'] = 'no'

      body = params.permit(:task, :provider, :model, :skill, :verify, :max_attempts, :workspace, :composer, :session_id)
      workspace = sanitize_workspace_param(body[:workspace])

      Builder::Universal.stream(
        body[:task],
        provider: body[:provider],
        model: body[:model],
        skill: body[:skill],
        verify: body[:verify].nil? ? nil : ActiveModel::Type::Boolean.new.cast(body[:verify]),
        max_attempts: body[:max_attempts]&.to_i,
        workspace: workspace,
        session_id: body[:session_id],
        plan_first: ActiveModel::Type::Boolean.new.cast(body[:composer])
      ) do |event, data|
        response.stream.write(Streaming::Sse.format_sse(event: event, data: data))
      end
    rescue StandardError => e
      response.stream.write(Streaming::Sse.format_sse(event: :error, data: { error: e.message }))
    ensure
      response.stream.close
    end
  end
end
