# frozen_string_literal: true

module RailsAiBuild
  class SeatsController < ApplicationController
    def show
      render json: Entitlements::Seats.status.merge(plan: RailsAiBuild.configuration.plan)
    end

    def claim
      user_id = params[:user_id].presence || request.headers["X-User-Id"]
      Entitlements::Seats.claim!(user_id)
      render json: Entitlements::Seats.status.merge(claimed: user_id)
    end

    def release
      user_id = params[:user_id].presence || request.headers["X-User-Id"]
      Entitlements::Seats.release!(user_id)
      render json: Entitlements::Seats.status.merge(released: user_id)
    end
  end
end
