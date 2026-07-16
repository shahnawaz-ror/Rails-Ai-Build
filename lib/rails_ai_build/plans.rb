# frozen_string_literal: true

module RailsAiBuild
  module Plans
    PLANS = {
      free: {
        name: "Free",
        price: 0,
        # BYOK local use includes streaming + NVIDIA; writes auto-apply when diff_preview is false
        features: %i[
          local_agent byok openai anthropic nvidia custom_providers
          token_tracking basic_analytics streaming
        ],
        limits: { max_iterations: 25, max_agents: 3, shell: true }
      },
      pro: {
        name: "Pro",
        price: 29,
        features: %i[
          local_agent byok openai anthropic nvidia custom_providers
          diff_preview hosted_models agent_memory priority_models
          streaming git_integration mcp
        ],
        limits: { max_iterations: 50, max_agents: 10, shell: true }
      },
      team: {
        name: "Team",
        price: 99,
        features: %i[
          local_agent byok openai anthropic nvidia custom_providers
          diff_preview hosted_models agent_memory priority_models
          team_dashboard shared_agents audit_log approval_workflow
          pr_creation slack_bot workspaces analytics community_submissions
          streaming mcp multi_agent git_integration
        ],
        limits: { max_iterations: 100, max_agents: 100, shell: true }
      },
      enterprise: {
        name: "Enterprise",
        price: nil,
        features: %i[
          local_agent byok openai anthropic nvidia custom_providers
          diff_preview hosted_models agent_memory priority_models
          team_dashboard shared_agents audit_log approval_workflow
          pr_creation slack_bot workspaces analytics community_submissions
          streaming mcp multi_agent git_integration
          self_hosted sso saml custom_models rbac soc2 sla
        ],
        limits: { max_iterations: 500, max_agents: Float::INFINITY, shell: true }
      }
    }.freeze

    class << self
      def current
        PLANS[RailsAiBuild.configuration.plan] || PLANS[:free]
      end

      def feature?(feature)
        current[:features].include?(feature.to_sym)
      end

      def check!(feature)
        return if feature?(feature)

        plan_name = current[:name]
        raise ConfigurationError,
              "Feature :#{feature} requires a higher plan (current: #{plan_name}). " \
              "Upgrade at https://railsaibuild.com/pricing"
      end

      def limit(key)
        current[:limits][key]
      end

      def apply_limits!
        config = RailsAiBuild.configuration
        config.max_agent_iterations = [config.max_agent_iterations, limit(:max_iterations)].min
      end
    end
  end
end
