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
    rescue ConfigurationError => e
      render json: { error: e.message }, status: :payment_required
    end
  end
end
