# frozen_string_literal: true

module RailsAiBuild
  # Lightweight liveness for load balancers / multi-tenant monitoring.
  class HealthController < ActionController::API
    def show
      render json: {
        status: "ok",
        version: RailsAiBuild::VERSION,
        plan: RailsAiBuild.configuration.plan,
        host_safety: RailsAiBuild.configuration.host_safety != false,
        ssrf: RailsAiBuild.configuration.ssrf_protection != false,
        time: Time.now.utc.iso8601
      }
    end
  end
end
