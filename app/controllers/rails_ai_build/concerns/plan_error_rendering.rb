# frozen_string_literal: true

module RailsAiBuild
  module Concerns
    module PlanErrorRendering
      extend ActiveSupport::Concern

      included do
        rescue_from PlanRequiredError do |error|
          render json: error.as_json, status: :payment_required
        end
      end
    end
  end
end
