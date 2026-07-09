# frozen_string_literal: true

module RailsAiBuild
  module Auth
    # SSO/SAML scaffolding for Enterprise (requires omniauth-saml in host app)
    class Saml
      class << self
        def configured?
          Plans.feature?(:sso) && RailsAiBuild.configuration.saml_enabled
        end

        def settings
          {
            issuer: ENV.fetch("SAML_ISSUER", "rails-ai-build"),
            idp_sso_url: ENV.fetch("SAML_IDP_SSO_URL", nil),
            idp_cert: ENV.fetch("SAML_IDP_CERT", nil),
            assertion_consumer_service_url: ENV.fetch("SAML_ACS_URL", nil)
          }
        end

        def validate!(settings = self.settings)
          Plans.check!(:sso)
          missing = %i[idp_sso_url idp_cert assertion_consumer_service_url].select { |k| settings[k].blank? }
          raise ConfigurationError, "SAML missing: #{missing.join(', ')}" if missing.any?

          settings
        end

        def omniauth_config
          <<~RUBY
            # Add to config/initializers/devise.rb or omniauth.rb:
            # gem 'omniauth-saml'
            config.omniauth :saml,
              issuer: "#{settings[:issuer]}",
              idp_sso_service_url: ENV["SAML_IDP_SSO_URL"],
              idp_cert: ENV["SAML_IDP_CERT"],
              assertion_consumer_service_url: ENV["SAML_ACS_URL"]
          RUBY
        end
      end
    end
  end
end
