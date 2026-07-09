# frozen_string_literal: true

module RailsAiBuild
  class AnalyticsController < ActionController::API
    def show
      render json: Analytics.dashboard
    end

    def tokens
      render json: TokenUsage.summary
    end
  end
end
