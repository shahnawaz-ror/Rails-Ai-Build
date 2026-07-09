# frozen_string_literal: true

module LiveHelpers
  NVIDIA_DEFAULT_MODEL = ENV.fetch('NVIDIA_MODEL', 'meta/llama-3.1-8b-instruct')

  def configure_nvidia_live!(workspace:)
    RailsAiBuild.reset_configuration!
    RailsAiBuild.configure do |c|
      c.api_keys[:nvidia] = ENV.fetch('NVIDIA_API_KEY')
      c.default_provider = :nvidia
      c.default_model = NVIDIA_DEFAULT_MODEL
      c.workspace_root = workspace
      c.diff_preview = false
      c.verify_builds = false
      c.universal_builder = false
      c.allowed_tools = %i[write_file read_file list_files]
      c.max_agent_iterations = 8
    end
    RailsAiBuild::Changes::Store.clear!
  end

  def nvidia_live?
    ENV['NVIDIA_API_KEY'].to_s.start_with?('nvapi-')
  end
end

RSpec.configure do |config|
  config.include LiveHelpers, :live

  config.before(:each, :live) do
    skip 'Set NVIDIA_API_KEY (nvapi-…) to run live specs — never commit API keys' unless ENV['NVIDIA_API_KEY'].to_s.start_with?('nvapi-')
    WebMock.allow_net_connect!
  end

  config.after(:each, :live) do
    WebMock.disable_net_connect!(allow_localhost: true)
  end
end
