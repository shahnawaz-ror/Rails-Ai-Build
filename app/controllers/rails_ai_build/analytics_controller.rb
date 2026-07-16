# frozen_string_literal: true

module RailsAiBuild
  class AnalyticsController < ApplicationController
    def show
      render json: Analytics.dashboard
    end

    def tokens
      render json: TokenUsage.summary
    end
  end
end
