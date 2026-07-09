# frozen_string_literal: true

module RailsAiBuild
  class AnalyticsController < ActionController::API
    def show
      render json: Analytics.summary
    rescue ConfigurationError => e
      render json: { error: e.message }, status: :payment_required
    end
  end
end
