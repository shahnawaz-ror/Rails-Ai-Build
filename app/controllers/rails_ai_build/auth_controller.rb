# frozen_string_literal: true

module RailsAiBuild
  class AuthController < ApplicationController
    def saml_config
      Plans.check!(:sso)
      render json: {
        configured: Auth::Saml.configured?,
        settings: Auth::Saml.settings,
        omniauth_snippet: Auth::Saml.omniauth_config
      }
    end
  end
end
