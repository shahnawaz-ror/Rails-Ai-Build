# frozen_string_literal: true

RailsAiBuild.configure do |config|
  config.plan = :team
  config.audit_enabled = true
end

# Discord interactions endpoint
# Webhook: POST https://yourapp.com/rails_ai_build/discord/interactions
# Set DISCORD_PUBLIC_KEY in environment
