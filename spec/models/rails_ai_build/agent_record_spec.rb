# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RailsAiBuild::AgentRecord do
  describe 'validations' do
    it 'requires name' do
      record = described_class.new
      expect(record).not_to be_valid
      expect(record.errors.attribute_names).to include(:name)
    end
  end

  describe 'status enum' do
    it 'defaults to idle' do
      agent = build_agent_record
      expect(agent).to be_idle
    end

    it 'transitions through statuses' do
      agent = build_agent_record
      agent.running!
      expect(agent).to be_running
      agent.completed!
      expect(agent).to be_completed
    end
  end

  describe '#to_agent' do
    it 'builds an Agents::Agent' do
      record = build_agent_record(system_prompt: 'Build CRUD.')
      agent_obj = record.to_agent
      expect(agent_obj).to be_a(RailsAiBuild::Agents::Agent)
      expect(agent_obj.system_prompt).to eq('Build CRUD.')
    end
  end

  describe 'associations' do
    it 'destroys conversations when agent is destroyed' do
      record = build_agent_record
      conv = build_conversation(record)
      expect { record.destroy! }.to change(RailsAiBuild::ConversationRecord, :count).by(-1)
      expect(RailsAiBuild::MessageRecord.where(conversation_id: conv.id)).to be_empty
    end
  end
end
