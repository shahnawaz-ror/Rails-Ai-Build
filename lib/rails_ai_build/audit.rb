# frozen_string_literal: true

module RailsAiBuild
  module Audit
    Entry = Struct.new(:action, :path, :user, :metadata, :created_at, keyword_init: true)

    SENSITIVE_KEY = /(api[_-]?key|token|secret|password|authorization|bearer|private[_-]?key)/i
    SENSITIVE_VALUE = /\b(sk-[A-Za-z0-9_\-]{8,}|sk-ant-[A-Za-z0-9_\-]{8,}|nvapi-[A-Za-z0-9_\-]{8,}|ghp_[A-Za-z0-9]{20,})\b/

    class << self
      def log(action:, path: nil, user: nil, preview: false, **metadata)
        return unless enabled?

        Plans.check!(:audit_log)

        entry = Entry.new(
          action: action,
          path: path,
          user: current_user || user,
          metadata: redact(metadata.merge(preview: preview)),
          created_at: Time.now
        )

        if defined?(RailsAiBuild::AuditLogRecord)
          RailsAiBuild::AuditLogRecord.create!(
            action: action.to_s,
            path: path,
            user_identifier: entry.user.to_s,
            metadata: entry.metadata
          )
        else
          memory_log << entry
        end

        entry
      end

      def all
        if defined?(RailsAiBuild::AuditLogRecord)
          RailsAiBuild::AuditLogRecord.order(created_at: :desc).limit(500)
        else
          memory_log
        end
      end

      def enabled?
        RailsAiBuild.configuration.audit_enabled
      end

      def current_user=(user)
        RequestContext.audit_user = user
      end

      def current_user
        RequestContext.audit_user
      end

      def redact(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, val), out|
            out[key] = if key.to_s.match?(SENSITIVE_KEY)
                         "[REDACTED]"
                       else
                         redact(val)
                       end
          end
        when Array
          value.map { |item| redact(item) }
        when String
          value.gsub(SENSITIVE_VALUE, "[REDACTED]")
        else
          value
        end
      end

      private

      def memory_log
        @memory_log ||= []
        @memory_log = @memory_log.last(1_000) if @memory_log.size > 1_000
        @memory_log
      end
    end
  end
end
