# frozen_string_literal: true

module RailsAiBuild
  class DiscordController < ActionController::API
    skip_before_action :verify_authenticity_token, raise: false

    def interactions
      render json: Bots::Discord.handle(JSON.parse(request.raw_post))
    rescue ConfigurationError => e
      render json: { type: 4, data: { content: e.message } }, status: :payment_required
    end
  end
end
