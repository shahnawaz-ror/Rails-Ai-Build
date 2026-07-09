# frozen_string_literal: true

module RailsAiBuild
  class AgentRunJob < ActiveJob::Base
    queue_as :rails_ai_build

    def perform(agent_id, conversation_id, user_message)
      agent_record = AgentRecord.find(agent_id)
      conversation = ConversationRecord.find(conversation_id)

      agent_record.running!

      conversation.messages.create!(role: :user, content: user_message)

      agent = agent_record.to_agent
      result = agent.chat(user_message)

      conversation.messages.create!(
        role: :assistant,
        content: result[:content],
        metadata: {
          iterations: result[:iterations],
          usage: result[:usage],
          finish_reason: result[:finish_reason]
        }
      )

      conversation.completed!
      agent_record.completed!
    rescue StandardError => e
      conversation&.failed!
      agent_record&.failed!
      conversation&.messages&.create!(
        role: :assistant,
        content: "Agent failed: #{e.message}",
        metadata: { error: e.class.name }
      )
      raise
    end
  end
end
