# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RailsAiBuild::ConversationRecord do
  let(:agent_record) { build_agent_record }

  it 'belongs to an agent' do
    conv = build_conversation(agent_record, title: 'CRUD chat')
    expect(conv.agent).to eq(agent_record)
    expect(conv).to be_active
  end

  it 'has many messages' do
    conv = build_conversation(agent_record)
    build_message(conv, content: 'Add Post model')
    expect(conv.messages.count).to eq(1)
  end

  it 'can be marked completed or failed' do
    conv = build_conversation(agent_record)
    conv.completed!
    expect(conv).to be_completed
    conv.failed!
    expect(conv).to be_failed
  end
end
