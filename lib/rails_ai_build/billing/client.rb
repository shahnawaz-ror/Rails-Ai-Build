# frozen_string_literal: true

require "openssl"
require "json"

module RailsAiBuild
  module Billing
    # Stripe Checkout + Billing Portal + signed webhooks.
    # Set STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, STRIPE_PRICE_PRO/TEAM.
    class Client
      STRIPE_API = "https://api.stripe.com/v1"
      TOLERANCE_SECONDS = 300

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
          plan_sym = plan.to_sym
          raise ConfigurationError, "Unknown plan: #{plan}" unless %i[pro team].include?(plan_sym)

          price_id = PLAN_PRICE_IDS.fetch(plan_sym)

          post("/checkout/sessions", {
            mode: "subscription",
            "line_items[0][price]" => price_id,
            "line_items[0][quantity]" => 1,
            success_url: success_url,
            cancel_url: cancel_url,
            customer_email: customer_email,
            "metadata[plan]" => plan_sym.to_s,
            "metadata[product]" => "rails_ai_build"
          }.compact)
        end

        def create_portal_session(customer_id:, return_url:)
          check_configured!
          raise ConfigurationError, "customer_id required" if customer_id.to_s.strip.empty?

          post("/billing_portal/sessions", {
            customer: customer_id,
            return_url: return_url
          })
        end

        def verify_webhook(payload, signature_header)
          check_configured!
          secret = ENV.fetch("STRIPE_WEBHOOK_SECRET")
          raise ConfigurationError, "Missing Stripe-Signature header" if signature_header.to_s.strip.empty?

          verify_signature!(payload.to_s, signature_header.to_s, secret)
          event = JSON.parse(payload)
          handle_event(event)
        rescue JSON::ParserError
          raise ConfigurationError, "Invalid webhook JSON payload"
        end

        def handle_event(event)
          case event["type"]
          when "checkout.session.completed"
            object = event.dig("data", "object") || {}
            plan = object.dig("metadata", "plan")&.to_sym || :pro
            customer_id = object["customer"]
            Activation.apply_plan!(plan, source: "billing")
            if customer_id.present? && Activation.table_ready?
              row = Activation.record
              meta = (row.metadata || {}).merge("stripe_customer_id" => customer_id)
              row.update!(metadata: meta)
            end
            { status: "upgraded", plan: plan, durable: Activation.table_ready?, customer_id: customer_id }
          when "customer.subscription.deleted"
            Activation.apply_plan!(:free, source: "billing")
            { status: "downgraded", plan: :free, durable: Activation.table_ready? }
          else
            { status: "ignored", type: event["type"] }
          end
        end

        # Build a valid Stripe-Signature header for tests.
        def sign_payload(payload, secret: ENV.fetch("STRIPE_WEBHOOK_SECRET", "whsec_test"), timestamp: Time.now.to_i)
          signed = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")
          "t=#{timestamp},v1=#{signed}"
        end

        private

        def verify_signature!(payload, header, secret)
          parts = header.split(",").to_h { |p| p.split("=", 2) }
          timestamp = parts["t"]
          signatures = header.scan(/v1=([a-f0-9]+)/).flatten
          raise ConfigurationError, "Invalid webhook signature" if timestamp.blank? || signatures.empty?

          if (Time.now.to_i - timestamp.to_i).abs > TOLERANCE_SECONDS
            raise ConfigurationError, "Webhook timestamp outside tolerance"
          end

          expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")
          valid = signatures.any? { |sig| secure_compare(expected, sig) }
          raise ConfigurationError, "Invalid webhook signature" unless valid
        end

        def secure_compare(a, b)
          return false if a.bytesize != b.bytesize

          ActiveSupport::SecurityUtils.secure_compare(a, b)
        end

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
          body = JSON.parse(response.body)
          if response.code.to_i >= 400
            raise ConfigurationError, body["error"]&.dig("message") || "Stripe API error #{response.code}"
          end

          body
        end
      end
    end
  end
end
