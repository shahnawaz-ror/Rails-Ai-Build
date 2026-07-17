# frozen_string_literal: true

module RailsAiBuild
  class IdeController < ActionController::Base
    layout 'rails_ai_build'

    def show
      @version = RailsAiBuild::VERSION
      @plan = RailsAiBuild.configuration.plan
      @plan_name = Plans.current[:name]
      @skills = Skills::Registry.all
      @providers = Models::Registry.registered_providers
      @pending = Changes::Store.all(status: :pending)
      @features = feature_flags
      @enterprise = enterprise_context
      @git = safe_git_summary
      @activation = Activation.status
      @upgrade_url = Plans::UPGRADE_URL
      @isolation = isolation_context
    end

    private

    def isolation_context
      {
        shadow_worktree: RailsAiBuild.configuration.host_safety_shadow_worktree == true,
        soft_preview: RailsAiBuild.configuration.host_safety_soft_preview != false,
        label: if RailsAiBuild.configuration.host_safety_shadow_worktree == true
                 'Isolated worktree'
               else
                 'Direct writes'
               end
      }
    end

    def feature_flags
      {
        streaming: Plans.feature?(:streaming),
        diff_preview: Plans.feature?(:diff_preview),
        git_integration: Plans.feature?(:git_integration),
        pr_creation: Plans.feature?(:pr_creation),
        audit_log: Plans.feature?(:audit_log),
        mcp: Plans.feature?(:mcp),
        multi_agent: Plans.feature?(:multi_agent),
        rbac: Plans.feature?(:rbac),
        sso: Plans.feature?(:sso),
        analytics: Plans.feature?(:analytics)
      }
    end

    def enterprise_context
      {
        role: Rbac.current_role,
        rbac_enabled: RailsAiBuild.configuration.rbac_enabled,
        saml_enabled: RailsAiBuild.configuration.saml_enabled,
        audit_enabled: RailsAiBuild.configuration.audit_enabled
      }
    end

    def safe_git_summary
      return { available: false } unless Plans.feature?(:git_integration)

      Integrations::Git.summary.merge(available: true)
    rescue StandardError => e
      { available: false, error: e.message }
    end
  end
end
