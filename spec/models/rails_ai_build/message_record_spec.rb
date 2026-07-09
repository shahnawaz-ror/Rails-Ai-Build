# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RailsAiBuild::MessageRecord do
  let(:conv) { build_conversation(build_agent_record) }

  it 'stores roles and content' do
    msg = build_message(conv, role: :assistant, content: 'Done.')
    expect(msg).to be_assistant
    expect(msg.content).to eq('Done.')
  end

  it 'serializes metadata as JSON' do
    msg = build_message(conv, metadata: { tokens: 42 })
    expect(msg.reload.metadata).to eq({ 'tokens' => 42 })
  end
end
