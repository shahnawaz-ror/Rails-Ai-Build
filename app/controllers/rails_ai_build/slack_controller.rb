# frozen_string_literal: true

module RailsAiBuild
  class SlackController < ApplicationController
    skip_before_action :verify_authenticity_token, raise: false

    def command
      Bots::Slack.verify_signature!(
        request.raw_post,
        request.headers["X-Slack-Request-Timestamp"],
        request.headers["X-Slack-Signature"]
      )
      render json: Bots::Slack.handle(params.to_unsafe_h)
    rescue PlanRequiredError => e
      render json: {
        response_type: "ephemeral",
        text: "#{e.message}\nUpgrade: #{e.upgrade_url} (suggested: #{e.suggested_plan})"
      }, status: :payment_required
    rescue SecurityError, ConfigurationError => e
      render json: { response_type: "ephemeral", text: e.message }, status: :forbidden
    end
  end
end
