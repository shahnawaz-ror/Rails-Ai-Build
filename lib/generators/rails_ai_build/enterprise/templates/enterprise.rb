# frozen_string_literal: true

RailsAiBuild.configure do |config|
  config.plan = :enterprise
  config.diff_preview = true
  config.audit_enabled = true
  config.auto_mount = true

  config.api_keys = {
    openai: ENV["OPENAI_API_KEY"],
    anthropic: ENV["ANTHROPIC_API_KEY"]
  }

  # Self-hosted: point SDKs at local server
  # config.remote_url = "http://localhost:9292"
end
