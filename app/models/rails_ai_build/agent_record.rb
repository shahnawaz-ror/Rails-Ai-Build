# frozen_string_literal: true

module RailsAiBuild
  class AgentRecord < ApplicationRecord
    self.table_name = "rails_ai_build_agents"

    has_many :conversations, class_name: "RailsAiBuild::ConversationRecord", foreign_key: :agent_id, dependent: :destroy

    validates :name, presence: true
    validates :provider, presence: true

    enum :status, { idle: 0, running: 1, completed: 2, failed: 3 }, default: :idle

    def to_agent
      Agents::Agent.new(
        name: name,
        provider: provider,
        model: model_name,
        system_prompt: system_prompt,
        workspace: RailsAiBuild.configuration.workspace_path
      )
    end
  end
end
