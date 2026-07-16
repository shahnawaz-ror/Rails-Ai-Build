# frozen_string_literal: true

module RailsAiBuild
  module Billing
    # Stripe integration scaffolding — set STRIPE_SECRET_KEY and STRIPE_WEBHOOK_SECRET
    class Client
      STRIPE_API = "https://api.stripe.com/v1"

      PLAN_PRICE_IDS = {
        pro: ENV.fetch("STRIPE_PRICE_PRO", "price_pro_monthly"),
        team: ENV.fetch("STRIPE_PRICE_TEAM", "price_team_monthly")
      }.freeze

      class << self
        def configured?
          ENV["STRIPE_SECRET_KEY"].present?
        end

        def create_checkout_session(plan:, success_url:, cancel_url:, customer_email: nil)
          check_configured!
          Plans.check!(plan) unless Plans::PLANS.key?(plan.to_sym)

          price_id = PLAN_PRICE_IDS.fetch(plan.to_sym)

          post("/checkout/sessions", {
            mode: "subscription",
            "line_items[0][price]" => price_id,
            "line_items[0][quantity]" => 1,
            success_url: success_url,
            cancel_url: cancel_url,
            customer_email: customer_email,
            "metadata[plan]" => plan.to_s,
            "metadata[product]" => "rails_ai_build"
          }.compact)
        end

        def verify_webhook(payload, signature)
          check_configured!
          # Production: use Stripe::Webhook.construct_event
          # Scaffolding validates presence of webhook secret
          secret = ENV.fetch("STRIPE_WEBHOOK_SECRET")
          raise ConfigurationError, "Invalid webhook signature" if signature.nil?

          event = JSON.parse(payload)
          handle_event(event)
        end

        def handle_event(event)
          case event["type"]
          when "checkout.session.completed"
            plan = event.dig("data", "object", "metadata", "plan")&.to_sym || :pro
            Activation.apply_plan!(plan, source: "billing")
            { status: "upgraded", plan: plan, durable: Activation.table_ready? }
          when "customer.subscription.deleted"
            Activation.apply_plan!(:free, source: "billing")
            { status: "downgraded", plan: :free, durable: Activation.table_ready? }
          else
            { status: "ignored", type: event["type"] }
          end
        end

        private

        def check_configured!
          raise ConfigurationError, "Stripe not configured. Set STRIPE_SECRET_KEY." unless configured?
        end

        def post(path, params)
          require "net/http"
          require "uri"

          uri = URI("#{STRIPE_API}#{path}")
          request = Net::HTTP::Post.new(uri)
          request.basic_auth(ENV.fetch("STRIPE_SECRET_KEY"), "")
          request.set_form_data(params)

          response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
          JSON.parse(response.body)
        end
      end
    end
  end
end
