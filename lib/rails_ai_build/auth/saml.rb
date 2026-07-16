# frozen_string_literal: true

module RailsAiBuild
  module Auth
    # Enterprise SSO/SAML — host installs omniauth-saml; gem validates config + maps roles.
    class Saml
      ROLE_CLAIM_KEYS = %w[role groups Group Role memberOf].freeze

      class << self
        def configured?
          Plans.feature?(:sso) && RailsAiBuild.configuration.saml_enabled
        end

        def settings
          {
            issuer: ENV.fetch("SAML_ISSUER", "rails-ai-build"),
            idp_sso_url: ENV.fetch("SAML_IDP_SSO_URL", nil),
            idp_cert: ENV.fetch("SAML_IDP_CERT", nil),
            assertion_consumer_service_url: ENV.fetch("SAML_ACS_URL", nil),
            name_identifier_format: ENV.fetch("SAML_NAME_ID_FORMAT",
                                              "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress")
          }
        end

        def validate!(settings = self.settings)
          Plans.check!(:sso)
          missing = %i[idp_sso_url idp_cert assertion_consumer_service_url].select { |k| settings[k].blank? }
          raise ConfigurationError, "SAML missing: #{missing.join(', ')}" if missing.any?

          settings
        end

        def status
          cfg = settings
          {
            enabled: RailsAiBuild.configuration.saml_enabled,
            plan_allows: Plans.feature?(:sso),
            configured: cfg[:idp_sso_url].present? && cfg[:idp_cert].present? && cfg[:assertion_consumer_service_url].present?,
            issuer: cfg[:issuer],
            idp_sso_url_present: cfg[:idp_sso_url].present?,
            acs_url_present: cfg[:assertion_consumer_service_url].present?
          }
        end

        # Apply IdP attributes to current RBAC role (host callback should call this).
        def authenticate_callback!(attributes = {})
          Plans.check!(:sso)
          attrs = attributes.transform_keys(&:to_s)
          role = extract_role(attrs) || RailsAiBuild.configuration.default_role
          Rbac.current_role = role.to_sym if Rbac.enabled?
          {
            authenticated: true,
            role: role,
            email: attrs["email"] || attrs["mail"] || attrs["NameID"],
            org: attrs["org"] || attrs["organization"]
          }
        end

        def extract_role(attrs)
          ROLE_CLAIM_KEYS.each do |key|
            value = attrs[key]
            next if value.blank?

            list = Array(value).flat_map { |v| v.to_s.split(/[,;]/) }.map(&:strip)
            found = list.find { |v| %w[admin reviewer developer viewer].include?(v.downcase) }
            return found.downcase if found
          end
          nil
        end

        def omniauth_config
          cfg = settings
          <<~RUBY
            # Add to the host app (requires gem 'omniauth-saml'):
            Rails.application.config.middleware.use OmniAuth::Builder do
              provider :saml,
                issuer: #{cfg[:issuer].inspect},
                idp_sso_service_url: ENV.fetch("SAML_IDP_SSO_URL"),
                idp_cert: ENV.fetch("SAML_IDP_CERT"),
                assertion_consumer_service_url: ENV.fetch("SAML_ACS_URL"),
                name_identifier_format: #{cfg[:name_identifier_format].inspect}
            end

            # In the OmniAuth callback controller:
            # info = RailsAiBuild::Auth::Saml.authenticate_callback!(request.env['omniauth.auth'].extra.raw_info.to_h)
          RUBY
        end
      end
    end
  end
end
