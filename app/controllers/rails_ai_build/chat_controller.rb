# frozen_string_literal: true

module RailsAiBuild
  class ChatController < ApplicationController
    def create
      body = params.permit(:message, :provider, :model, :system_prompt, :skill, :workspace)

      system_prompt = if body[:skill].present?
                        Skills::Registry.prompt_for(body[:skill])
                      else
                        body[:system_prompt]
                      end

      agent = Agents::Agent.new(
        provider: body[:provider],
        model: body[:model],
        system_prompt: system_prompt,
        workspace: sanitize_workspace_param(body[:workspace])
      )

      Audit.current_user = request.headers["X-User-Id"] || "api"
      result = agent.chat(body[:message])

      render json: result.merge(
        pending_changes: Changes::Store.all(status: :pending).map(&:to_h)
      )
    rescue Cloud::Client::CloudUnavailableError => e
      render json: e.as_json, status: :service_unavailable
    rescue Error => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
