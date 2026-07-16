# frozen_string_literal: true

module RailsAiBuild
  class PlanRequiredError < ConfigurationError
    attr_reader :feature, :current_plan, :suggested_plan, :upgrade_url

    def initialize(feature:, current_plan:, suggested_plan: nil)
      @feature = feature.to_sym
      @current_plan = current_plan.to_sym
      @suggested_plan = (suggested_plan || suggest_plan_for(feature)).to_sym
      @upgrade_url = Plans::UPGRADE_URL
      super(
        "Feature :#{feature} requires a higher plan (current: #{Plans::PLANS[@current_plan]&.dig(:name) || @current_plan}). " \
        "Upgrade at #{@upgrade_url}"
      )
    end

    def as_json(*)
      {
        error: message,
        code: "plan_required",
        feature: feature,
        current_plan: current_plan,
        suggested_plan: suggested_plan,
        upgrade: upgrade_url,
        checkout: {
          endpoint: "billing/checkout",
          plan: suggested_plan
        }
      }
    end

    private

    def suggest_plan_for(feature)
      %i[pro team enterprise].find { |plan| Plans::PLANS[plan][:features].include?(feature.to_sym) } || :pro
    end
  end
end
