# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsAiBuild::Configuration do
  around do |example|
    original = {
      'OPENAI_API_KEY' => ENV.fetch('OPENAI_API_KEY', nil),
      'ANTHROPIC_API_KEY' => ENV.fetch('ANTHROPIC_API_KEY', nil),
      'NVIDIA_API_KEY' => ENV.fetch('NVIDIA_API_KEY', nil),
      'NVIDIA_MODEL' => ENV.fetch('NVIDIA_MODEL', nil)
    }
    example.run
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  before do
    RailsAiBuild.reset_configuration!
    %w[OPENAI_API_KEY ANTHROPIC_API_KEY NVIDIA_API_KEY NVIDIA_MODEL].each { |k| ENV.delete(k) }
  end

  it 'prefers NVIDIA when NVIDIA_API_KEY is set' do
    ENV['NVIDIA_API_KEY'] = 'nvapi-demo'
    ENV['NVIDIA_MODEL'] = 'meta/llama-3.3-70b-instruct'

    config = described_class.new
    config.apply_env_providers!

    expect(config.api_keys[:nvidia]).to eq('nvapi-demo')
    expect(config.default_provider).to eq(:nvidia)
    expect(config.default_model).to eq('meta/llama-3.3-70b-instruct')
  end

  it 'falls back to OpenAI when NVIDIA is absent' do
    ENV['OPENAI_API_KEY'] = 'sk-demo'

    config = described_class.new
    config.apply_env_providers!

    expect(config.default_provider).to eq(:openai)
  end
end
