# frozen_string_literal: true

RailsAiBuild.configure do |config|
  config.plan = :team
  config.audit_enabled = true
end

# Slack slash command: /ai your prompt here
# Webhook: POST https://yourapp.com/rails_ai_build/slack/command
# Set SLACK_SIGNING_SECRET in environment
