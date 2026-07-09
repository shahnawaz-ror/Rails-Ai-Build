# frozen_string_literal: true

module RailsAiBuild
  class UiController < ActionController::Base
    layout false

    def dashboard
      @plan = RailsAiBuild.configuration.plan
      @skills = Skills::Registry.all
      @pending = Changes::Store.all(status: :pending)
      @features = {
        analytics: Plans.feature?(:analytics),
        audit: Plans.feature?(:audit_log),
        diff_preview: Plans.feature?(:diff_preview)
      }
    end
  end
end
