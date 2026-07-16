# frozen_string_literal: true

module RailsAiBuild
  class GitController < ActionController::API
    def status
      render json: Integrations::Git.summary
    end

    def diff
      render json: { diff: Integrations::Git.diff(path: params[:path]) }
    end

    def commit
      result = Integrations::Git.commit(message: params[:message], paths: params[:paths])
      render json: result
    rescue PlanRequiredError => e
      render json: e.as_json, status: :payment_required
    rescue ConfigurationError => e
      render json: { error: e.message, upgrade: Plans::UPGRADE_URL, code: "configuration_error" },
             status: :payment_required
    end
  end
end
