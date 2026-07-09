# frozen_string_literal: true

module RailsAiBuild
  module Plans
    PLANS = {
      free: {
        name: "Free",
        price: 0,
        features: %i[local_agent byok openai anthropic custom_providers],
        limits: { max_iterations: 15, max_agents: 3, shell: true }
      },
      pro: {
        name: "Pro",
        price: 29,
        features: %i[
          local_agent byok openai anthropic custom_providers
          diff_preview hosted_models agent_memory priority_models
        ],
        limits: { max_iterations: 50, max_agents: 10, shell: true }
      },
      team: {
        name: "Team",
        price: 99,
        features: %i[
          local_agent byok openai anthropic custom_providers
          diff_preview hosted_models agent_memory priority_models
          team_dashboard shared_agents audit_log approval_workflow
          pr_creation slack_bot workspaces analytics
        ],
        limits: { max_iterations: 100, max_agents: 100, shell: true }
      },
      enterprise: {
        name: "Enterprise",
        price: nil,
        features: %i[
          local_agent byok openai anthropic custom_providers
          diff_preview hosted_models agent_memory priority_models
          team_dashboard shared_agents audit_log approval_workflow
          pr_creation slack_bot workspaces analytics
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
