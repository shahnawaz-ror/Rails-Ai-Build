# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RailsAiBuild::Ai::Driver do
  before do
    RailsAiBuild::Ai::Session.reset!
    RailsAiBuild.configure { |c| c.api_keys[:openai] = 'sk-test' }
    stub_openai_chat(content: 'Hello from the model.')
  end

  after { RailsAiBuild::Ai::Session.reset! }

  it 'runs a model-driven turn' do
    result = described_class.run('Say hello')
    expect(result.content).to include('Hello from the model')
    expect(result.session).to be_a(RailsAiBuild::Ai::Session)
    expect(result.context.rails).to be_present
  end

  it 'continues a multi-turn session' do
    session = RailsAiBuild::Ai::Session.create
    described_class.run('First message', session: session)
    expect(session.messages.size).to eq(2)
    described_class.run('Second message', session: session)
    expect(session.messages.size).to eq(4)
  end

  it 'attaches a generator plan and host_safety report on AI turns' do
    result = described_class.run('Say hello without changing files')
    expect(result.generator_plan).to be_a(Hash)
    expect(result.generator_plan[:mode].to_s).to eq('ai')
    expect(result.host_safety).to be_a(Hash)
    expect(result.host_safety[:healthy]).to eq(true)
  end
end

