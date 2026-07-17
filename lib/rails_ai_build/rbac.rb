# frozen_string_literal: true

module RailsAiBuild
  module Rbac
    # Role-based access control for tools (Enterprise)
    READ_ONLY_BOOST = Tools::Registry::BOOST_TOOL_NAMES

    DEFAULT_ROLES = {
      admin: %i[read_file write_file grep list_files shell run_generator host_safety_check] + READ_ONLY_BOOST,
      developer: %i[read_file write_file grep list_files shell run_generator host_safety_check] + READ_ONLY_BOOST,
      reviewer: %i[read_file grep list_files] + READ_ONLY_BOOST,
      viewer: %i[read_file list_files] + READ_ONLY_BOOST
    }.freeze

    class << self
      def configure_roles!(mapping)
        Plans.check!(:rbac)
        @roles = DEFAULT_ROLES.merge(mapping.transform_keys(&:to_sym))
      end

      def allowed_tools_for(role)
        roles[role.to_sym] || roles[:viewer]
      end

      def permit?(role, tool)
        return true unless enabled?

        allowed_tools_for(role).include?(tool.to_sym)
      end

      def check!(role, tool)
        return if permit?(role, tool)

        raise SecurityError, "Role '#{role}' cannot use tool '#{tool}'"
      end

      def enabled?
        Plans.feature?(:rbac) && RailsAiBuild.configuration.rbac_enabled
      end

      def current_role
        RequestContext.rbac_role || Thread.current[:rails_ai_build_role] || RailsAiBuild.configuration.default_role
      end

      def current_role=(role)
        RequestContext.rbac_role = role.to_sym
        Thread.current[:rails_ai_build_role] = role.to_sym
      end

      private

      def roles
        @roles ||= DEFAULT_ROLES
      end
    end
  end
end
