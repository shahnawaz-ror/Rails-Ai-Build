# frozen_string_literal: true

module RailsAiBuild
  # Base API controller — plan errors, rate limits, optional engine token, seats.
  class ApplicationController < ActionController::API
    include Concerns::PlanErrorRendering
    include Concerns::RateLimited
    include Concerns::EngineAuth

    around_action :isolate_request_context
    before_action :enforce_rate_limit!, if: :rate_limited_request?
    before_action :enforce_engine_token!
    before_action :enforce_seat!, if: :seat_gated_request?

    private

    def isolate_request_context
      RequestContext.reset!
      yield
    ensure
      RequestContext.reset!
    end

    def rate_limited_request?
      return false if request.get? || request.head?
      return false if controller_name == "billing" && action_name == "webhook"

      true
    end

    def seat_gated_request?
      return false unless Entitlements::Seats.enabled?
      return false if request.get? || request.head?
      return false if %w[billing settings support help plans seats].include?(controller_name)

      %w[ai chat build streaming tasks agents skills orchestration demo].include?(controller_name)
    end

    def enforce_seat!
      Entitlements::Seats.check!(request.headers["X-User-Id"].presence || request.remote_ip)
    rescue PlanRequiredError => e
      render json: e.as_json, status: :payment_required
    end

    def sanitize_workspace_param(value)
      Workspace::Paths.sanitize_request_workspace!(value)
    rescue SecurityError => e
      raise ConfigurationError, e.message
    end
  end
end
