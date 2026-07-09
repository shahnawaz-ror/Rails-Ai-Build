# frozen_string_literal: true

module RailsAiBuild
  class ChatController < ActionController::API
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
        workspace: body[:workspace].present? ? Pathname.new(body[:workspace]) : nil
      )

      Audit.current_user = request.headers["X-User-Id"] || "api"
      result = agent.chat(body[:message])

      render json: result.merge(
        pending_changes: Changes::Store.all(status: :pending).map(&:to_h)
      )
    rescue Error => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
