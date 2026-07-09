# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RailsAiBuild::UsageRecord do
  it 'tracks token usage events' do
    record = build_usage_record(event: 'agent_run', tokens: 250)
    expect(record.reload.tokens).to eq(250)
    expect(record.event).to eq('agent_run')
  end
end
