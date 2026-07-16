# frozen_string_literal: true

module RailsAiBuild
  class AuditLogsController < ActionController::API
    def index
      Plans.check!(:audit_log)
      logs = Audit.all
      render json: { logs: logs }
    rescue PlanRequiredError => e
      render json: e.as_json, status: :payment_required
    end
  end
end
