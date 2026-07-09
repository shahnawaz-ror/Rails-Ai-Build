# frozen_string_literal: true

module RailsAiBuild
  class PullRequestsController < ActionController::API
    def create
      result = Integrations::PullRequest.create(
        title: params[:title] || "AI: automated changes",
        body: params[:body]
      )
      render json: result
    rescue ConfigurationError => e
      render json: { error: e.message, upgrade: "https://railsaibuild.com/pricing" }, status: :payment_required
    end
  end
end
