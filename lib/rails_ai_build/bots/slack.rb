# frozen_string_literal: true

module RailsAiBuild
  module Bots
    class Slack
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
          return true if secret.blank? # dev mode

          basestring = "v0:#{timestamp}:#{request_body}"
          computed = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", secret, basestring)
          raise SecurityError, "Invalid Slack signature" unless Rack::Utils.secure_compare(computed, signature)
        end

        private

        def help_response
          {
            response_type: "ephemeral",
            text: "Usage: /ai Add pagination to the users index\nSkills: crud, auth, api, tests, refactor"
          }
        end
      end
    end

    class Discord
      class << self
        def handle(payload)
          Plans.check!(:slack_bot) # same plan tier
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
      end
    end
  end
end

require "openssl"
