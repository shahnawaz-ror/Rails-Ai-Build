# frozen_string_literal: true

module RailsAiBuild
  # Per-request isolation for Audit user + RBAC role (avoids cross-thread leaks).
  module RequestContext
    class << self
      def reset!
        Thread.current[:rails_ai_build_audit_user] = nil
        Thread.current[:rails_ai_build_rbac_role] = nil
        HostSafety.end_session! if defined?(HostSafety)
      end

      def audit_user
        Thread.current[:rails_ai_build_audit_user]
      end

      def audit_user=(value)
        Thread.current[:rails_ai_build_audit_user] = value
      end

      def rbac_role
        Thread.current[:rails_ai_build_rbac_role]
      end

      def rbac_role=(value)
        Thread.current[:rails_ai_build_rbac_role] = value
      end
    end
  end
end
