# frozen_string_literal: true

module RailsAiBuild
  class SlackController < ActionController::API
    skip_before_action :verify_authenticity_token, raise: false

    def command
      Bots::Slack.verify_signature!(
        request.raw_post,
        request.headers["X-Slack-Request-Timestamp"],
        request.headers["X-Slack-Signature"]
      )
      render json: Bots::Slack.handle(params.to_unsafe_h)
    rescue SecurityError, ConfigurationError => e
      render json: { text: e.message }, status: :forbidden
    end
  end
end
