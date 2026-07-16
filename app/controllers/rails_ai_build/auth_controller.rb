# frozen_string_literal: true

module RailsAiBuild
  class AuthController < ApplicationController
    def saml_config
      Plans.check!(:sso)
      render json: {
        configured: Auth::Saml.configured?,
        status: Auth::Saml.status,
        settings: Auth::Saml.settings.except(:idp_cert).merge(idp_cert_present: Auth::Saml.settings[:idp_cert].present?),
        omniauth_snippet: Auth::Saml.omniauth_config
      }
    rescue PlanRequiredError => e
      render json: e.as_json, status: :payment_required
    end

    # Host OmniAuth callback can POST mapped attributes here to set RBAC role.
    def saml_callback
      Plans.check!(:sso)
      result = Auth::Saml.authenticate_callback!(params.permit!.to_h)
      render json: result
    rescue PlanRequiredError => e
      render json: e.as_json, status: :payment_required
    rescue ConfigurationError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
