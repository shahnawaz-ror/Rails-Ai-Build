# frozen_string_literal: true

module Factories
  module_function

  def build_agent_record(attrs = {})
    RailsAiBuild::AgentRecord.create!({
      name: 'Test Agent',
      provider: 'openai',
      model_name: 'gpt-4o',
      system_prompt: 'You are helpful.'
    }.merge(attrs))
  end

  def build_conversation(agent, attrs = {})
    agent.conversations.create!({ title: 'Test conversation' }.merge(attrs))
  end

  def build_message(conversation, attrs = {})
    conversation.messages.create!({
      role: :user,
      content: 'Hello'
    }.merge(attrs))
  end

  def build_model_config(attrs = {})
    RailsAiBuild::ModelConfig.create!({
      name: 'default-openai',
      provider: 'openai',
      model_name: 'gpt-4o',
      enabled: true
    }.merge(attrs))
  end

  def build_shared_agent(attrs = {})
    RailsAiBuild::SharedAgentRecord.create!({
      name: 'Shared Helper',
      system_prompt: 'You assist developers.',
      published: true
    }.merge(attrs))
  end

  def build_community_pack(attrs = {})
    RailsAiBuild::CommunityPackRecord.create!({
      name: 'CRUD Pack',
      system_prompt: 'Build CRUD resources.',
      author: 'tester',
      approved: false
    }.merge(attrs))
  end

  def build_audit_log(attrs = {})
    RailsAiBuild::AuditLogRecord.create!({
      action: 'chat',
      path: '/rails_ai_build/chat',
      user_identifier: 'api'
    }.merge(attrs))
  end

  def build_usage_record(attrs = {})
    RailsAiBuild::UsageRecord.create!({
      event: 'chat',
      tokens: 100,
      user_identifier: 'api'
    }.merge(attrs))
  end
end

RSpec.configure do |config|
  config.include Factories
end
