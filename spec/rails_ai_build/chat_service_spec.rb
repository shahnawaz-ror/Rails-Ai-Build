# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsAiBuild::ChatService do
  before do
    RailsAiBuild.reset_configuration!
    RailsAiBuild.configure { |c| c.api_keys[:openai] = 'sk-test' }
    stub_openai_chat(content: 'Service reply.')
  end

  describe '.ask' do
    it 'returns chat result' do
      result = described_class.ask('Hello')
      expect(result[:content]).to eq('Service reply.')
    end
  end

  describe '.create_agent' do
    it 'builds an agent' do
      agent = described_class.create_agent(system_prompt: 'Test')
      expect(agent).to be_a(RailsAiBuild::Agents::Agent)
    end
  end

  describe '.register_custom_provider' do
    it 'registers a custom provider' do
      described_class.register_custom_provider(
        :local,
        base_url: 'http://localhost:11434/v1',
        models: %w[llama3],
        adapter: :openai_compatible
      )
      expect(RailsAiBuild::Models::Registry.registered_providers).to include(:local)
    end
  end
end
