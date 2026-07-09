# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RailsAiBuild::ModelConfig do
  it 'validates uniqueness of name' do
    build_model_config(name: 'primary')
    dup = described_class.new(name: 'primary', provider: 'openai')
    expect(dup).not_to be_valid
  end

  it 'scopes enabled configs' do
    build_model_config(name: 'on', enabled: true)
    build_model_config(name: 'off', enabled: false)
    expect(described_class.enabled.pluck(:name)).to eq(['on'])
  end

  describe '#to_provider' do
    it 'builds a provider from config' do
      RailsAiBuild.configure { |c| c.api_keys[:openai] = 'sk-test' }
      cfg = build_model_config(provider: 'openai', config: { model: 'gpt-4o' })
      provider = cfg.to_provider
      expect(provider).to be_a(RailsAiBuild::Models::OpenaiProvider)
    end
  end
end
