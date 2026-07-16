# frozen_string_literal: true

module RailsAiBuild
  class PullRequestsController < ApplicationController
    def create
      result = Integrations::PullRequest.create(
        title: params[:title] || "AI: automated changes",
        body: params[:body]
      )
      render json: result
    rescue ConfigurationError => e
      raise if e.is_a?(PlanRequiredError)

      render json: { error: e.message, upgrade: Plans::UPGRADE_URL, code: "configuration_error" },
             status: :payment_required
    end
  end
end
