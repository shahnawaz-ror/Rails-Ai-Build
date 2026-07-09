# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RailsAiBuild::SharedAgentRecord do
  it 'requires name and system_prompt' do
    record = described_class.new
    expect(record).not_to be_valid
  end

  it 'enforces unique names' do
    build_shared_agent(name: 'helper')
    dup = described_class.new(name: 'helper', system_prompt: 'x')
    expect(dup).not_to be_valid
  end

  describe '.published' do
    it 'filters published agents' do
      build_shared_agent(name: 'pub', published: true)
      build_shared_agent(name: 'draft', published: false)
      expect(described_class.published.pluck(:name)).to eq(['pub'])
    end
  end

  describe '#to_agent' do
    it 'returns a runnable agent' do
      record = build_shared_agent(system_prompt: 'Review code.')
      expect(record.to_agent.system_prompt).to eq('Review code.')
    end
  end
end
