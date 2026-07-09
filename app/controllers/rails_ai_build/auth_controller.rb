# frozen_string_literal: true

module RailsAiBuild
  class AuthController < ActionController::API
    def saml_config
      Plans.check!(:sso)
      render json: {
        configured: Auth::Saml.configured?,
        settings: Auth::Saml.settings,
        omniauth_snippet: Auth::Saml.omniauth_config
      }
    rescue ConfigurationError => e
      render json: { error: e.message }, status: :payment_required
    end
  end
end
