# frozen_string_literal: true

module RailsAiBuild
  class AuditLogsController < ApplicationController
    def index
      Plans.check!(:audit_log)
      logs = Audit.all
      render json: { logs: logs }
    end

    def export
      Plans.check!(:audit_log)
      logs = Audit.all
      format = params[:format].to_s.downcase

      if format == "csv"
        csv = + "action,path,user,created_at,metadata\n"
        Array(logs).each do |entry|
          row = entry.respond_to?(:to_h) ? entry.to_h : entry
          row = row.symbolize_keys if row.respond_to?(:symbolize_keys)
          csv << [
            csv_escape(row[:action] || row["action"]),
            csv_escape(row[:path] || row["path"]),
            csv_escape(row[:user] || row[:user_identifier] || row["user"]),
            csv_escape(row[:created_at] || row["created_at"]),
            csv_escape((row[:metadata] || row["metadata"]).to_json)
          ].join(",") << "\n"
        end
        send_data csv, filename: "rails_ai_build_audit_#{Time.now.utc.strftime('%Y%m%d')}.csv", type: "text/csv"
      else
        render json: {
          exported_at: Time.now.utc.iso8601,
          count: Array(logs).size,
          logs: logs
        }
      end
    end

    private

    def csv_escape(value)
      str = value.to_s.gsub('"', '""')
      %("#{str}")
    end
  end
end
