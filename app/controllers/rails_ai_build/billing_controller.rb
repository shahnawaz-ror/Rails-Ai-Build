# frozen_string_literal: true

module RailsAiBuild
  class BillingController < ActionController::API
    def checkout
      session = Billing::Client.create_checkout_session(
        plan: params[:plan] || :pro,
        success_url: params[:success_url] || "#{request.base_url}/rails_ai_build?upgraded=true",
        cancel_url: params[:cancel_url] || "#{request.base_url}/rails_ai_build",
        customer_email: params[:email]
      )

      render json: { checkout_url: session["url"], session_id: session["id"] }
    rescue ConfigurationError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def webhook
      result = Billing::Client.verify_webhook(
        request.body.read,
        request.headers["Stripe-Signature"]
      )
      render json: result
    rescue ConfigurationError => e
      render json: { error: e.message }, status: :bad_request
    end
  end
end
