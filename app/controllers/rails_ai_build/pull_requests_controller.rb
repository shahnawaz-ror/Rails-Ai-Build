# frozen_string_literal: true

module RailsAiBuild
  class PullRequestsController < ActionController::API
    def create
      result = Integrations::PullRequest.create(
        title: params[:title] || "AI: automated changes",
        body: params[:body]
      )
      render json: result
    rescue PlanRequiredError => e
      render json: e.as_json, status: :payment_required
    rescue ConfigurationError => e
      render json: { error: e.message, upgrade: Plans::UPGRADE_URL, code: "configuration_error" },
             status: :payment_required
    end
  end
end
