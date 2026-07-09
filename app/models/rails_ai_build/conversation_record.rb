# frozen_string_literal: true

module RailsAiBuild
  class ConversationRecord < ApplicationRecord
    self.table_name = "rails_ai_build_conversations"

    belongs_to :agent, class_name: "RailsAiBuild::AgentRecord", foreign_key: :agent_id
    has_many :messages, class_name: "RailsAiBuild::MessageRecord", foreign_key: :conversation_id, dependent: :destroy

    enum :status, { active: 0, completed: 1, failed: 2 }, default: :active
  end
end
