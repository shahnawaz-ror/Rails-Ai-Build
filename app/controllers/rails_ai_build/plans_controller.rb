# frozen_string_literal: true

module RailsAiBuild
  class PlansController < ApplicationController
    def index
      plans = Plans::PLANS.map do |key, plan|
        {
          id: key,
          name: plan[:name],
          price: plan[:price],
          features: plan[:features],
          limits: plan[:limits]
        }
      end

      render json: {
        current_plan: RailsAiBuild.configuration.plan,
        plans: plans
      }
    end

    def current
      plan = Plans.current
      render json: {
        plan: RailsAiBuild.configuration.plan,
        name: plan[:name],
        features: plan[:features],
        limits: plan[:limits]
      }
    end
  end
end
