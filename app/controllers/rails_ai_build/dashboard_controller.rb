# frozen_string_literal: true

module RailsAiBuild
  class DashboardController < ActionController::API
    def show
      payload = {
        plan: RailsAiBuild.configuration.plan,
        version: RailsAiBuild::VERSION,
        skills: Skills::Registry.all,
        providers: Models::Registry.registered_providers,
        pending_changes: Changes::Store.all(status: :pending).map(&:to_h),
        features: {
          diff_preview: Plans.feature?(:diff_preview),
          audit_log: Plans.feature?(:audit_log),
          team_dashboard: Plans.feature?(:team_dashboard)
        }
      }

      if Plans.feature?(:team_dashboard)
        payload[:agents] = AgentRecord.count
        payload[:audit_entries] = Audit.all.size
      end

      render json: payload
    end
  end
end
