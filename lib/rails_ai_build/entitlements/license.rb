# frozen_string_literal: true

require "json"
require "base64"

module RailsAiBuild
  module Entitlements
    # Durable plan entitlement via signed license tokens.
    # Format: base64(payload).signature  (HMAC-SHA256 via MessageVerifier)
    #
    # Payload example:
    #   { "plan": "pro", "org": "acme", "exp": 1893456000, "iss": "railsaibuild" }
    class License
      ISSUER = "railsaibuild"
      UPGRADE_URL = Plans::UPGRADE_URL

      class << self
        def issue(plan:, org: nil, expires_at: nil, seats: nil)
          payload = {
            "plan" => plan.to_s,
            "org" => org,
            "exp" => expires_at&.to_i,
            "seats" => seats,
            "iss" => ISSUER,
            "iat" => Time.now.to_i
          }.compact

          "#{encode(payload)}.#{sign(encode(payload))}"
        end

        def verify(token)
          return invalid("License token blank") if token.to_s.strip.empty?

          encoded, signature = token.to_s.split(".", 2)
          return invalid("Malformed license token") if encoded.blank? || signature.blank?
          return invalid("Invalid license signature") unless secure_compare(sign(encoded), signature)

          payload = decode(encoded)
          return invalid("Invalid license payload") unless payload.is_a?(Hash)

          plan = payload["plan"]&.to_sym
          return invalid("Unknown plan in license") unless Plans::PLANS.key?(plan)

          if payload["exp"] && Time.now.to_i > payload["exp"].to_i
            return invalid("License expired")
          end

          {
            valid: true,
            plan: plan,
            org: payload["org"],
            seats: payload["seats"],
            expires_at: payload["exp"],
            issuer: payload["iss"],
            raw: token
          }
        end

        def apply!(token)
          result = verify(token)
          raise ConfigurationError, result[:error] unless result[:valid]

          Activation.apply_license!(result)
          result
        end

        def signing_secret
          ENV["RAILS_AI_BUILD_LICENSE_SECRET"].presence ||
            ENV["RAILS_AI_BUILD_SECRET"].presence ||
            (defined?(Rails) && Rails.application&.secret_key_base).presence ||
            ENV["SECRET_KEY_BASE"].presence ||
            "rails-ai-build-dev-license-secret"
        end

        private

        def encode(payload)
          Base64.urlsafe_encode64(JSON.generate(payload), padding: false)
        end

        def decode(encoded)
          JSON.parse(Base64.urlsafe_decode64(encoded))
        rescue ArgumentError, JSON::ParserError
          nil
        end

        def sign(encoded)
          OpenSSL::HMAC.hexdigest("SHA256", signing_secret, encoded)
        end

        def secure_compare(a, b)
          return false if a.bytesize != b.bytesize

          OpenSSL.fixed_length_secure_compare(a, b)
        rescue StandardError
          ActiveSupport::SecurityUtils.secure_compare(a, b)
        end

        def invalid(message)
          { valid: false, error: message }
        end
      end
    end
  end
end
