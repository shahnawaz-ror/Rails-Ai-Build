# frozen_string_literal: true

module RailsAiBuild
  class AuditLogsController < ActionController::API
    def index
      Plans.check!(:audit_log)
      logs = Audit.all
      render json: { logs: logs }
    rescue ConfigurationError => e
      render json: { error: e.message, upgrade: "https://railsaibuild.com/pricing" }, status: :payment_required
    end
  end
end
