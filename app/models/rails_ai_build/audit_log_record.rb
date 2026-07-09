# frozen_string_literal: true

module RailsAiBuild
  class AuditLogRecord < ApplicationRecord
    self.table_name = "rails_ai_build_audit_logs"
  end
end
