# frozen_string_literal: true

module RailsAiBuild
  class DiscordController < ApplicationController
    skip_before_action :verify_authenticity_token, raise: false

    def interactions
      body = request.raw_post
      Bots::Discord.verify_signature!(
        body,
        request.headers["X-Signature-Ed25519"],
        request.headers["X-Signature-Timestamp"]
      )

      payload = JSON.parse(body)
      # Discord ping
      if payload["type"].to_i == 1
        return render json: { type: 1 }
      end

      render json: Bots::Discord.handle(payload)
    rescue PlanRequiredError => e
      render json: {
        type: 4,
        data: {
          content: "#{e.message}\nUpgrade: #{e.upgrade_url} (suggested: #{e.suggested_plan})",
          flags: 64
        }
      }, status: :payment_required
    rescue SecurityError => e
      render json: { error: e.message }, status: :unauthorized
    rescue ConfigurationError => e
      render json: { type: 4, data: { content: e.message } }, status: :unprocessable_entity
    end
  end
end
