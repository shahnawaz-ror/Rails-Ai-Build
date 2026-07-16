# frozen_string_literal: true

module RailsAiBuild
  module Notifications
    class Slack
      class << self
        def notify(message:, channel: nil, webhook_url: nil)
          Plans.check!(:slack_bot)
          url = webhook_url || ENV.fetch("SLACK_WEBHOOK_URL", nil)
          raise ConfigurationError, "SLACK_WEBHOOK_URL not set" if url.blank?

          payload = { text: message }
          payload[:channel] = channel if channel

          post_webhook(url, payload)
        end

        def agent_completed(result:, task:)
          notify(
            message: ":robot_face: *Rails AI Build* completed task:\n> #{task}\n\n#{result[:content]&.truncate(500)}"
          )
        end

        private

        def post_webhook(url, payload)
          require "net/http"
          uri = Security::UrlGuard.safe_uri(url)
          request = Net::HTTP::Post.new(uri)
          request["Content-Type"] = "application/json"
          request.body = JSON.generate(payload)
          HttpClient.request(uri, request, read_timeout: 15)
        end
      end
    end
  end
end
