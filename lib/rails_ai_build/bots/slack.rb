# frozen_string_literal: true

require "openssl"

module RailsAiBuild
  module Bots
    class Slack
      REPLAY_WINDOW = 60 * 5

      class << self
        def handle(payload)
          Plans.check!(:slack_bot)
          command = payload["command"] || "/ai"
          text = payload["text"].to_s.strip
          user = payload["user_name"] || payload["user_id"]

          return help_response if text.blank?

          Audit.current_user = "slack:#{user}"
          result = ChatService.ask(text)
          Analytics.track(event: "slack_command", user: user, metadata: { command: command })

          { response_type: "in_channel", text: result[:content] || "Done." }
        rescue PlanRequiredError
          raise
        rescue StandardError => e
          { response_type: "ephemeral", text: "Error: #{e.message}" }
        end

        def verify_signature!(request_body, timestamp, signature)
          secret = ENV.fetch("SLACK_SIGNING_SECRET", nil)
          if secret.blank?
            if production_like?
              raise SecurityError, "SLACK_SIGNING_SECRET required in production"
            end

            return true
          end

          raise SecurityError, "Missing Slack signature" if signature.to_s.strip.empty?
          raise SecurityError, "Missing Slack timestamp" if timestamp.to_s.strip.empty?
          raise SecurityError, "Slack timestamp outside replay window" if (Time.now.to_i - timestamp.to_i).abs > REPLAY_WINDOW

          basestring = "v0:#{timestamp}:#{request_body}"
          computed = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", secret, basestring)
          raise SecurityError, "Invalid Slack signature" unless Rack::Utils.secure_compare(computed, signature.to_s)

          true
        end

        private

        def production_like?
          return true if ENV["RAILS_ENV"].to_s == "production"
          return true if defined?(Rails) && Rails.env.production?

          false
        end

        def help_response
          {
            response_type: "ephemeral",
            text: "Usage: /ai Add pagination to the users index\nSkills: crud, auth, api, tests, refactor"
          }
        end
      end
    end

    class Discord
      REPLAY_WINDOW = 60 * 5

      class << self
        def handle(payload)
          Plans.check!(:slack_bot)
          content = payload.dig("data", "options", 0, "value") || payload["content"]
          user = payload.dig("member", "user", "username") || "discord"

          Audit.current_user = "discord:#{user}"
          result = ChatService.ask(content.to_s)
          Analytics.track(event: "discord_command", user: user)

          { type: 4, data: { content: (result[:content] || "Done.")[0, 2000] } }
        rescue PlanRequiredError
          raise
        rescue StandardError => e
          { type: 4, data: { content: "Error: #{e.message}" } }
        end

        # Ed25519 verification when DISCORD_PUBLIC_KEY is set (production requires it).
        def verify_signature!(body, signature, timestamp)
          key = ENV.fetch("DISCORD_PUBLIC_KEY", nil)
          if key.blank?
            if production_like?
              raise SecurityError, "DISCORD_PUBLIC_KEY required in production"
            end

            return true
          end

          raise SecurityError, "Missing Discord signature headers" if signature.blank? || timestamp.blank?
          raise SecurityError, "Discord timestamp must be numeric" unless timestamp.to_s.match?(/\A\d+\z/)
          raise SecurityError, "Discord timestamp outside replay window" if (Time.now.to_i - timestamp.to_i).abs > REPLAY_WINDOW

          begin
            require "ed25519"
            verify_key = Ed25519::VerifyKey.new([key].pack("H*"))
            verify_key.verify([signature].pack("H*"), "#{timestamp}#{body}")
          rescue LoadError
            # Fallback: require headers present; recommend ed25519 gem for full verify
            raise SecurityError, "Install ed25519 gem for Discord signature verification" if production_like?

            true
          rescue SecurityError
            raise
          rescue StandardError
            raise SecurityError, "Invalid Discord signature"
          end
        end

        def production_like?
          return true if ENV["RAILS_ENV"].to_s == "production"
          return true if defined?(Rails) && Rails.env.production?

          false
        end
      end
    end
  end
end
