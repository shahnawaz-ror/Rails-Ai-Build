# frozen_string_literal: true

module RailsAiBuild
  class GitController < ApplicationController
    def status
      render json: Integrations::Git.summary
    end

    def diff
      render json: { diff: Integrations::Git.diff(path: params[:path]) }
    end

    def commit
      result = Integrations::Git.commit(message: params[:message], paths: params[:paths])
      render json: result
    rescue ConfigurationError => e
      raise if e.is_a?(PlanRequiredError)

      render json: { error: e.message, upgrade: Plans::UPGRADE_URL, code: "configuration_error" },
             status: :payment_required
    end
  end
end
