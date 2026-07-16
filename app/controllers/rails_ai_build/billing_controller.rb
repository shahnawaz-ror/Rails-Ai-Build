# frozen_string_literal: true

module RailsAiBuild
  class BillingController < ApplicationController
    def checkout
      session = Billing::Client.create_checkout_session(
        plan: params[:plan] || :pro,
        success_url: params[:success_url] || "#{request.base_url}/rails_ai_build?upgraded=true",
        cancel_url: params[:cancel_url] || "#{request.base_url}/rails_ai_build",
        customer_email: params[:email]
      )

      render json: { checkout_url: session["url"], session_id: session["id"] }
    rescue ConfigurationError => e
      render json: { error: e.message, code: "billing_error" }, status: :unprocessable_entity
    end

    def portal
      customer_id = params[:customer_id].presence || stripe_customer_from_activation
      session = Billing::Client.create_portal_session(
        customer_id: customer_id,
        return_url: params[:return_url] || "#{request.base_url}/rails_ai_build/ui/ide"
      )
      render json: { portal_url: session["url"], session_id: session["id"] }
    rescue ConfigurationError => e
      render json: {
        error: e.message,
        code: "billing_portal_unavailable",
        hint: "Complete checkout first, or pass customer_id. Set STRIPE_SECRET_KEY."
      }, status: :unprocessable_entity
    end

    def webhook
      result = Billing::Client.verify_webhook(
        request.body.read,
        request.headers["Stripe-Signature"]
      )
      render json: result
    rescue ConfigurationError => e
      render json: { error: e.message, code: "invalid_webhook" }, status: :bad_request
    end

    private

    def stripe_customer_from_activation
      return nil unless Activation.table_ready?

      Activation.record&.metadata&.dig("stripe_customer_id")
    end
  end
end
