# frozen_string_literal: true

module RailsAiBuild
  # Base API controller — structured plan_required errors for all gated endpoints.
  class ApplicationController < ActionController::API
    include Concerns::PlanErrorRendering
    include Concerns::RateLimited
  end
end

