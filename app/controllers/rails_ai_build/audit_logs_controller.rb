# frozen_string_literal: true

module RailsAiBuild
  class AuditLogsController < ApplicationController
    def index
      Plans.check!(:audit_log)
      logs = Audit.all
      render json: { logs: logs }
    end
  end
end
