# frozen_string_literal: true

module RailsAiBuild
  class MessageRecord < ApplicationRecord
    self.table_name = "rails_ai_build_messages"

    belongs_to :conversation, class_name: "RailsAiBuild::ConversationRecord", foreign_key: :conversation_id

    enum :role, { system: 0, user: 1, assistant: 2, tool: 3 }

    serialize :tool_calls, coder: JSON
  end
end
