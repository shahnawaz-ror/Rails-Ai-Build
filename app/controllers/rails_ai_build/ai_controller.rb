# frozen_string_literal: true

module RailsAiBuild
  class AiController < ApplicationController
    include ActionController::Live

    def chat
      body = params.permit(:message, :provider, :model, :skill, :session_id, :workspace)
      Audit.current_user = request.headers['X-User-Id'] || 'api'

      session = Ai::Session.find(body[:session_id]) if body[:session_id].present?
      workspace = sanitize_workspace_param(body[:workspace])

      result = Ai::Driver.run(
        body[:message],
        session: session,
        provider: body[:provider],
        model: body[:model],
        skill: body[:skill],
        workspace: workspace
      )

      render json: result.to_h
    rescue Cloud::Client::CloudUnavailableError => e
      render json: e.as_json, status: :service_unavailable
    rescue Error => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    def stream
      response.headers['Content-Type'] = 'text/event-stream'
      response.headers['Cache-Control'] = 'no-cache'
      response.headers['X-Accel-Buffering'] = 'no'

      body = params.permit(:message, :provider, :model, :skill, :session_id)

      Ai::Stream.stream_chat(
        body[:message],
        session_id: body[:session_id],
        provider: body[:provider],
        model: body[:model],
        skill: body[:skill]
      ) do |sse|
        response.stream.write(sse)
      end
    rescue Cloud::Client::CloudUnavailableError => e
      response.stream.write(Ai::Stream.format(event: :error, data: e.as_json))
    rescue StandardError => e
      response.stream.write(Ai::Stream.format(event: :error, data: { error: e.message }))
    ensure
      response.stream.close
    end
  end
end
