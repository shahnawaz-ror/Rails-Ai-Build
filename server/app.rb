# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require 'rails_ai_build'

# Standalone HTTP server — use from any language via REST.
# Start: bundle exec rackup -p 9292
class RailsAiBuildServer < Sinatra::Base
  configure do
    set :show_exceptions, :after_handler
    set :public_folder, File.expand_path('public', __dir__)
  end

  before do
    setup_config!
    content_type :json unless html_route?
  end

  get '/health' do
    {
      status: 'ok',
      service: 'rails_ai_build',
      version: RailsAiBuild::VERSION,
      nvidia_configured: ENV['NVIDIA_API_KEY'].to_s.start_with?('nvapi-'),
      trust_dashboard: RailsAiBuild::Trust::Report.dashboard_url
    }.to_json
  end

  get '/trust/results.json' do
    report = RailsAiBuild::Trust::Report.read
    if report
      report.merge(
        live_api: RailsAiBuild::Trust::Report.live_api_url,
        dashboard: RailsAiBuild::Trust::Report.dashboard_url
      ).to_json
    else
      status 404
      { error: 'No trust results yet. POST /trust/run or run rails rails_ai_build:trust:run' }.to_json
    end
  end

  get '/apps' do
    { apps: RailsAiBuild::Trust::AppSandbox.manifest, base_url: RailsAiBuild::Trust::AppSandbox.base_url }.to_json
  end

  get '/apps/:slug.json' do
    info = RailsAiBuild::Trust::AppSandbox.info(params['slug'])
    halt 404, { error: 'App not found' }.to_json unless info

    info.to_json
  end

  get '/apps/:slug' do
    html = RailsAiBuild::Trust::AppSandbox.preview_html(params['slug'])
    halt 404, 'App not found' unless html

    content_type :html
    html
  end

  post '/apps/:slug/run' do
    body = begin
      JSON.parse(request.body.read)
    rescue StandardError
      {}
    end
    unless ENV['NVIDIA_API_KEY'].to_s.start_with?('nvapi-')
      status 503
      return { error: 'NVIDIA_API_KEY required for live changes' }.to_json
    end

    RailsAiBuild::Trust::AppSandbox.run_change(params['slug'], body['message']).to_json
  rescue ArgumentError => e
    status 404
    { error: e.message }.to_json
  rescue StandardError => e
    status 500
    { error: e.message }.to_json
  end

  get '/trust' do
    content_type :html
    path = File.expand_path('../../landing/trust/index.html', __dir__)
    File.read(path)
  end

  post '/trust/run' do
    unless ENV['NVIDIA_API_KEY'].to_s.start_with?('nvapi-')
      status 503
      return { error: 'NVIDIA_API_KEY not configured on server' }.to_json
    end

    report = RailsAiBuild::Trust::Runner.run!
    status 200
    report.to_json
  rescue StandardError => e
    status 500
    { error: e.message }.to_json
  end

  post '/chat' do
    body = JSON.parse(request.body.read)

    agent = RailsAiBuild::Agents::Agent.new(
      provider: body['provider'] || 'nvidia',
      model: body['model'],
      system_prompt: body['system_prompt'],
      workspace: body['workspace'] ? Pathname.new(body['workspace']) : nil
    )

    result = agent.chat(body.fetch('message'))
    result.to_json
  rescue JSON::ParserError
    status 400
    { error: 'Invalid JSON' }.to_json
  rescue RailsAiBuild::Error => e
    status 422
    { error: e.message }.to_json
  end

  get '/models/providers' do
    providers = RailsAiBuild::Models::Registry.registered_providers.map do |name|
      provider = RailsAiBuild::Models::Registry.build(name)
      { name: name, models: provider.list_models }
    rescue RailsAiBuild::ConfigurationError => e
      { name: name, models: [], error: e.message }
    end

    custom = RailsAiBuild.configuration.providers.keys.map do |name|
      entry = RailsAiBuild.configuration.providers[name]
      models = entry[:options][:models] || []
      { name: name, models: models, custom: true }
    end

    { providers: providers + custom }.to_json
  end

  post '/models/test' do
    body = JSON.parse(request.body.read)
    provider = RailsAiBuild::Models::Registry.build(body['provider'], api_key: body['api_key'])
    models = provider.list_models
    { provider: body['provider'], models: models, status: 'ok' }.to_json
  rescue StandardError => e
    status 422
    { error: e.message }.to_json
  end

  get '/tools' do
    { tools: RailsAiBuild::Tools::Registry.definitions }.to_json
  end

  private

  def html_route?
    request.path_info == '/trust' ||
      (request.path_info.match?(%r{\A/apps/[^/]+/?\z}) && !request.path_info.end_with?('.json'))
  end

  def setup_config!
    RailsAiBuild.configure do |config|
      config.api_keys[:openai] ||= ENV.fetch('OPENAI_API_KEY', nil)
      config.api_keys[:anthropic] ||= ENV.fetch('ANTHROPIC_API_KEY', nil)
      config.api_keys[:nvidia] ||= ENV.fetch('NVIDIA_API_KEY', nil)
      config.default_provider = :nvidia if ENV['NVIDIA_API_KEY'].to_s.start_with?('nvapi-')
      config.workspace_root = ENV.fetch('WORKSPACE_ROOT', Dir.pwd)
    end
    RailsAiBuild::Models::Registry.register_defaults

    RailsAiBuild.configuration.providers.each do |name, entry|
      RailsAiBuild::Models::Registry.register(name, entry[:class], entry[:options])
    end
  end
end
