# frozen_string_literal: true

require "sinatra/base"
require "json"
require "rails_ai_build"

# Standalone HTTP server — use from any language via REST.
# Start: bundle exec rackup -p 9292
class RailsAiBuildServer < Sinatra::Base
  configure do
    set :show_exceptions, :after_handler
  end

  before do
    content_type :json
    setup_config!
  end

  get "/health" do
    { status: "ok", service: "rails_ai_build", version: RailsAiBuild::VERSION }.to_json
  end

  # One-shot synchronous chat — primary endpoint for cross-language clients
  post "/chat" do
    body = JSON.parse(request.body.read)

    agent = RailsAiBuild::Agents::Agent.new(
      provider: body["provider"] || "openai",
      model: body["model"],
      system_prompt: body["system_prompt"],
      workspace: body["workspace"] ? Pathname.new(body["workspace"]) : nil
    )

    result = agent.chat(body.fetch("message"))
    result.to_json
  rescue JSON::ParserError
    status 400
    { error: "Invalid JSON" }.to_json
  rescue RailsAiBuild::Error => e
    status 422
    { error: e.message }.to_json
  end

  get "/models/providers" do
    providers = RailsAiBuild::Models::Registry.registered_providers.map do |name|
      begin
        provider = RailsAiBuild::Models::Registry.build(name)
        { name: name, models: provider.list_models }
      rescue RailsAiBuild::ConfigurationError => e
        { name: name, models: [], error: e.message }
      end
    end

  custom = RailsAiBuild.configuration.providers.keys.map do |name|
    entry = RailsAiBuild.configuration.providers[name]
    models = entry[:options][:models] || []
    { name: name, models: models, custom: true }
  end

    { providers: providers + custom }.to_json
  end

  post "/models/test" do
    body = JSON.parse(request.body.read)
    provider = RailsAiBuild::Models::Registry.build(body["provider"], api_key: body["api_key"])
    models = provider.list_models
    { provider: body["provider"], models: models, status: "ok" }.to_json
  rescue StandardError => e
    status 422
    { error: e.message }.to_json
  end

  get "/tools" do
    { tools: RailsAiBuild::Tools::Registry.definitions }.to_json
  end

  private

  def setup_config!
    RailsAiBuild.configure do |config|
      config.api_keys[:openai] ||= ENV["OPENAI_API_KEY"]
      config.api_keys[:anthropic] ||= ENV["ANTHROPIC_API_KEY"]
      config.workspace_root = ENV.fetch("WORKSPACE_ROOT", Dir.pwd)
    end
    RailsAiBuild::Models::Registry.register_defaults

    RailsAiBuild.configuration.providers.each do |name, entry|
      RailsAiBuild::Models::Registry.register(name, entry[:class], entry[:options])
    end
  end
end
