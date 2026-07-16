# frozen_string_literal: true

module RailsAiBuild
  class DiscordController < ApplicationController
    skip_before_action :verify_authenticity_token, raise: false

    def interactions
      render json: Bots::Discord.handle(JSON.parse(request.raw_post))
    rescue PlanRequiredError => e
      render json: {
        type: 4,
        data: {
          content: "#{e.message}\nUpgrade: #{e.upgrade_url} (suggested: #{e.suggested_plan})",
          flags: 64
        }
      }, status: :payment_required
    rescue ConfigurationError => e
      render json: { type: 4, data: { content: e.message } }, status: :unprocessable_entity
    end
  end
end
